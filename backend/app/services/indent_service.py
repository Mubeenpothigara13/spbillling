import re
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.audit import AuditAction
from app.models.indent import Indent, IndentItem, IndentStatus
from app.models.product import ProductVariant
from app.models.user import User
from app.schemas.indent import IndentCreate, IndentSizeRow, IndentUpdate
from app.services import do_sale_service
from app.utils.audit import write_audit

# Cylinder sizes an indent is raised for, in display order.
SIZES_KG = (4, 12, 15, 21)

_KG = re.compile(r"(\d+(?:\.\d+)?)\s*kg", re.IGNORECASE)
_TWO_PLACES = Decimal("0.01")


def _size_of(variant_name: str) -> Optional[int]:
    """`Commercial 15kg` -> 15. Only whole weights in SIZES_KG count, so a
    14.2kg domestic cylinder is not mistaken for a 12 or 15."""
    m = _KG.search(variant_name)
    if not m:
        return None
    kg = float(m.group(1))
    return int(kg) if kg.is_integer() and int(kg) in SIZES_KG else None


def size_summary(db: Session, do_id: Optional[int]) -> list[IndentSizeRow]:
    """Per size: Stock = cylinders this outlet has recorded as sold on the
    Sale screen (all time) minus what earlier indents already took as
    filled, Rate = unit price of the first active variant of that size
    (0 when the catalog has no such product)."""
    sold = {kg: 0 for kg in SIZES_KG}
    for name, qty in do_sale_service.quantities_by_variant_name(db, do_id):
        kg = _size_of(name)
        if kg is not None:
            sold[kg] += qty

    indented = {kg: 0 for kg in SIZES_KG}
    # A rejected indent's filled doesn't count as consumed — rejecting must
    # free that stock back up so the DO can correct and resubmit.
    used = (
        select(IndentItem.size_kg, func.sum(IndentItem.filled))
        .join(Indent, Indent.id == IndentItem.indent_id)
        .where(Indent.status != IndentStatus.REJECTED)
        .group_by(IndentItem.size_kg)
    )
    if do_id is not None:
        used = used.where(Indent.do_id == do_id)
    for kg, qty in db.execute(used):
        if kg in indented:
            indented[kg] = int(qty or 0)

    # Indent rate is the DO's cost price (what it pays S.P. Gas), never the
    # customer-facing unit_price — those two are deliberately different.
    rate: dict[int, Decimal] = {}
    for v in db.scalars(
        select(ProductVariant).where(ProductVariant.is_active.is_(True)).order_by(ProductVariant.id)
    ):
        kg = _size_of(v.name)
        if kg is not None and kg not in rate:
            rate[kg] = v.cost_price

    return [
        IndentSizeRow(
            size_kg=kg,
            stock=max(0, sold[kg] - indented[kg]),
            rate=rate.get(kg, Decimal("0")),
        )
        for kg in SIZES_KG
    ]


def create_indent(db: Session, user: User, payload: IndentCreate) -> Indent:
    if user.do_id is None:
        raise HTTPException(
            status_code=403, detail="Only a distributor outlet login can submit an indent"
        )

    by_size = {r.size_kg: r for r in size_summary(db, user.do_id)}
    items: list[IndentItem] = []
    seen: set[int] = set()
    for it in payload.items:
        if it.size_kg not in by_size:
            raise HTTPException(status_code=400, detail=f"Unknown size {it.size_kg} kg")
        if it.size_kg in seen:
            raise HTTPException(status_code=400, detail=f"{it.size_kg} kg listed twice")
        seen.add(it.size_kg)
        row = by_size[it.size_kg]
        if it.filled > row.stock:
            raise HTTPException(
                status_code=400,
                detail=f"{it.size_kg} kg: filled ({it.filled}) cannot be more than stock ({row.stock})",
            )
        items.append(IndentItem(
            size_kg=it.size_kg,
            stock=row.stock,
            filled=it.filled,
            empty=it.empty,
            rate=row.rate,
            amount=(row.rate * it.filled).quantize(_TWO_PLACES),
        ))

    total_filled = sum(i.filled for i in items)
    total_empty = sum(i.empty for i in items)
    if total_filled + total_empty == 0:
        raise HTTPException(status_code=400, detail="Enter filled or empty cylinders")
    total_amount = sum((i.amount for i in items), Decimal("0"))
    paid = payload.amount_paid.quantize(_TWO_PLACES)
    if paid > total_amount:
        raise HTTPException(
            status_code=400, detail="Paid amount cannot be more than the total amount"
        )

    indent = Indent(
        do_id=user.do_id,
        indent_date=date.today(),
        total_stock=sum(i.stock for i in items),
        total_filled=total_filled,
        total_empty=total_empty,
        total_amount=total_amount,
        amount_paid=paid,
        balance=total_amount - paid,
        created_by_id=user.id,
        items=items,
    )
    db.add(indent)
    db.flush()
    write_audit(db, entity_type="indent", entity_id=indent.id,
                action=AuditAction.CREATE, user_id=user.id,
                changes={"total_filled": total_filled, "total_empty": total_empty,
                         "total_amount": str(total_amount), "amount_paid": str(paid)})
    db.commit()
    db.refresh(indent)
    return indent


def list_indents(*, do_id: Optional[int] = None):
    stmt = select(Indent)
    if do_id is not None:
        stmt = stmt.where(Indent.do_id == do_id)
    return stmt.order_by(Indent.indent_date.desc(), Indent.id.desc())


def get_indent(db: Session, indent_id: int) -> Indent:
    indent = db.get(Indent, indent_id)
    if not indent:
        raise HTTPException(status_code=404, detail="Indent not found")
    return indent


def update_indent(db: Session, user: User, indent_id: int, payload: IndentUpdate) -> Indent:
    """Admin correction of a submitted indent's filled/empty/paid amounts.
    Re-prices each item off its own already-stored rate — never re-fetches
    the current catalog price, since that could drift from what the DO
    actually paid at submission time."""
    indent = get_indent(db, indent_id)
    items_by_size = {i.size_kg: i for i in indent.items}
    seen: set[int] = set()
    for it in payload.items:
        if it.size_kg not in items_by_size:
            raise HTTPException(status_code=400, detail=f"{it.size_kg} kg is not on this indent")
        if it.size_kg in seen:
            raise HTTPException(status_code=400, detail=f"{it.size_kg} kg listed twice")
        seen.add(it.size_kg)
        row = items_by_size[it.size_kg]
        row.filled = it.filled
        row.empty = it.empty
        row.amount = (row.rate * it.filled).quantize(_TWO_PLACES)

    total_filled = sum(i.filled for i in indent.items)
    total_empty = sum(i.empty for i in indent.items)
    total_amount = sum((i.amount for i in indent.items), Decimal("0"))
    paid = payload.amount_paid.quantize(_TWO_PLACES)
    if paid > total_amount:
        raise HTTPException(
            status_code=400, detail="Paid amount cannot be more than the total amount"
        )

    changes = {
        "total_filled": [indent.total_filled, total_filled],
        "total_empty": [indent.total_empty, total_empty],
        "total_amount": [str(indent.total_amount), str(total_amount)],
        "amount_paid": [str(indent.amount_paid), str(paid)],
    }
    indent.total_filled = total_filled
    indent.total_empty = total_empty
    indent.total_amount = total_amount
    indent.amount_paid = paid
    indent.balance = total_amount - paid

    write_audit(db, entity_type="indent", entity_id=indent.id,
                action=AuditAction.UPDATE, user_id=user.id, changes=changes)
    db.commit()
    db.refresh(indent)
    return indent


def approve_indent(db: Session, user: User, indent_id: int) -> Indent:
    indent = get_indent(db, indent_id)
    indent.status = IndentStatus.APPROVED
    indent.reviewed_by_id = user.id
    indent.reviewed_at = datetime.now(timezone.utc)
    indent.review_note = None
    write_audit(db, entity_type="indent", entity_id=indent.id,
                action=AuditAction.UPDATE, user_id=user.id, changes={"status": "approved"})
    db.commit()
    db.refresh(indent)
    return indent


def reject_indent(db: Session, user: User, indent_id: int, note: Optional[str]) -> Indent:
    indent = get_indent(db, indent_id)
    indent.status = IndentStatus.REJECTED
    indent.reviewed_by_id = user.id
    indent.reviewed_at = datetime.now(timezone.utc)
    indent.review_note = note
    write_audit(db, entity_type="indent", entity_id=indent.id,
                action=AuditAction.UPDATE, user_id=user.id,
                changes={"status": "rejected", "note": note})
    db.commit()
    db.refresh(indent)
    return indent

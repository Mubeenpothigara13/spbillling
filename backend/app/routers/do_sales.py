from datetime import date
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.bill import BillOut
from app.schemas.do_sale import DoSaleBillRequest, DoSaleCreate, DoSaleRead, DoSaleSummary
from app.services import billing_service
from app.services import do_sale_service as svc
from app.utils.auth import get_current_user, require_staff
from app.utils.pagination import paginate
from app.utils.scope import resolve_do_filter

router = APIRouter(prefix="/do-sales", tags=["DO Sales"])


@router.get("/summary", response_model=APIResponse[DoSaleSummary])
def summary(
    from_date: Optional[date] = Query(None, alias="from"),
    to_date: Optional[date] = Query(None, alias="to"),
    do_id: Optional[int] = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return APIResponse(data=svc.summary(
        db, do_id=resolve_do_filter(user, do_id), from_date=from_date, to_date=to_date,
    ))


@router.get("", response_model=PaginatedResponse[DoSaleRead])
def list_sales(
    status: Literal["pending", "billed", "all"] = "all",
    from_date: Optional[date] = Query(None, alias="from"),
    to_date: Optional[date] = Query(None, alias="to"),
    do_id: Optional[int] = None,
    customer_id: Optional[int] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(25, ge=1, le=200),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    stmt = svc.list_sales(
        do_id=resolve_do_filter(user, do_id),
        status=None if status == "all" else status,
        from_date=from_date,
        to_date=to_date,
        customer_id=customer_id,
    )
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=DoSaleRead)


@router.post("", response_model=APIResponse[list[DoSaleRead]])
def create_sales(
    payload: DoSaleCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_staff),
):
    rows = svc.create_sales(db, user, payload)
    return APIResponse(
        data=[DoSaleRead.model_validate(r) for r in rows],
        message=f"{len(rows)} sale(s) recorded",
    )


@router.post("/bill", response_model=APIResponse[BillOut])
def bill_sales(
    payload: DoSaleBillRequest,
    db: Session = Depends(get_db),
    user: User = Depends(require_staff),
):
    bill = billing_service.bill_do_sales(db, user, payload.customer_id, payload.sale_date)
    return APIResponse(data=BillOut.model_validate(bill), message=f"Bill {bill.bill_number} created")

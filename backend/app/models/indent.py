from datetime import date
from decimal import Decimal
from typing import Optional

from sqlalchemy import Date, ForeignKey, Index, Integer, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.distributor_outlet import DistributorOutlet  # noqa: F401 (relationship target)


class Indent(Base, TimestampMixin):
    """One submitted indent from a Distributor Outlet: cylinders requested
    (filled) / returned (empty) per size, with the amount and payment status."""

    __tablename__ = "indents"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    do_id: Mapped[int] = mapped_column(
        ForeignKey("distributor_outlets.id", ondelete="RESTRICT"),
        nullable=False, index=True,
    )
    indent_date: Mapped[date] = mapped_column(Date, nullable=False)

    total_stock: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_filled: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_empty: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    amount_paid: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    balance: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)

    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )

    distributor_outlet: Mapped["DistributorOutlet"] = relationship(
        "DistributorOutlet", lazy="joined"
    )
    items: Mapped[list["IndentItem"]] = relationship(
        back_populates="indent",
        cascade="all, delete-orphan",
        order_by="IndentItem.size_kg",
        lazy="selectin",
    )

    __table_args__ = (
        Index("ix_indents_do_date", "do_id", "indent_date"),
    )

    @property
    def do_code(self) -> str:
        return self.distributor_outlet.code

    @property
    def do_name(self) -> str:
        return self.distributor_outlet.owner_name


class IndentItem(Base):
    __tablename__ = "indent_items"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    indent_id: Mapped[int] = mapped_column(
        ForeignKey("indents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    size_kg: Mapped[int] = mapped_column(Integer, nullable=False)
    stock: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    filled: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    empty: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    rate: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)

    indent: Mapped[Indent] = relationship(back_populates="items")

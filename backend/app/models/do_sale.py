from datetime import date
from decimal import Decimal
from typing import Optional

from sqlalchemy import Date, ForeignKey, Index, Integer, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.bill import Bill
from app.models.customer import Customer
from app.models.distributor_outlet import DistributorOutlet
from app.models.product import ProductVariant


class DoSale(Base, TimestampMixin):
    """One sale line recorded by a Distributor Outlet. It is not a bill: the
    outlet only records who bought what and when, and S.P. Gas (admin) turns
    the pending lines into a bill. `bill_id` NULL = still pending; deleting
    the bill puts the lines back to pending (FK SET NULL)."""

    __tablename__ = "do_sales"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    do_id: Mapped[int] = mapped_column(
        ForeignKey("distributor_outlets.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    customer_id: Mapped[int] = mapped_column(
        ForeignKey("customers.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    sale_date: Mapped[date] = mapped_column(Date, nullable=False)
    product_variant_id: Mapped[int] = mapped_column(
        ForeignKey("product_variants.id", ondelete="RESTRICT"), nullable=False
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    rate: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    gst_rate: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=0, nullable=False)
    empty_returned: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    bill_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("bills.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    distributor_outlet: Mapped[DistributorOutlet] = relationship(lazy="joined")
    customer: Mapped[Customer] = relationship(lazy="joined")
    variant: Mapped[ProductVariant] = relationship(lazy="joined")
    bill: Mapped[Optional[Bill]] = relationship(lazy="joined")

    __table_args__ = (
        Index("ix_do_sales_do_date", "do_id", "sale_date"),
    )

    @property
    def do_code(self) -> str:
        return self.distributor_outlet.code

    @property
    def customer_name(self) -> str:
        return self.customer.name

    @property
    def customer_village(self) -> Optional[str]:
        return self.customer.village

    @property
    def customer_mobile(self) -> Optional[str]:
        return self.customer.mobile

    @property
    def variant_name(self) -> str:
        return self.variant.name

    @property
    def bill_number(self) -> Optional[str]:
        return self.bill.bill_number if self.bill else None

    @property
    def status(self) -> str:
        return "billed" if self.bill_id is not None else "pending"

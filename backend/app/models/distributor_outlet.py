from sqlalchemy import Boolean, Index, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class DistributorOutlet(Base, TimestampMixin):
    __tablename__ = "distributor_outlets"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    # Not DB-unique on its own — delete is soft (is_deleted=True), so a
    # deleted outlet's row (and its code) stays forever. Uniqueness only
    # applies among live rows, via the partial index below; otherwise
    # recreating a DO with a previously-deleted code 500s on a raw
    # IntegrityError instead of the app's own "code already exists" check.
    code: Mapped[str] = mapped_column(String(10), nullable=False)
    owner_name: Mapped[str] = mapped_column(String(150), nullable=False)
    location: Mapped[str] = mapped_column(String(150), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)

    __table_args__ = (
        Index("uq_distributor_outlets_code_active", "code", unique=True,
              postgresql_where=text("NOT is_deleted")),
        Index("ix_distributor_outlets_active_deleted", "is_active", "is_deleted"),
    )

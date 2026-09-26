"""indent approve/reject/edit — status + reviewer columns

Revision ID: 008_indent_review
Revises: 007_do_sales
Create Date: 2026-09-26

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "008_indent_review"
down_revision: Union[str, None] = "007_do_sales"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Stored value must be the enum MEMBER NAME ("PENDING"), matching every
    # other Enum(..., native_enum=False) column in this codebase (see
    # BillStatus/CustomerStatus) — not the lowercase .value.
    op.add_column(
        "indents",
        sa.Column("status", sa.String(16), nullable=False, server_default="PENDING"),
    )
    op.add_column("indents", sa.Column("reviewed_by_id", sa.Integer(), nullable=True))
    op.add_column("indents", sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("indents", sa.Column("review_note", sa.Text(), nullable=True))
    op.create_index("ix_indents_status", "indents", ["status"])
    op.create_foreign_key(
        "fk_indents_reviewed_by_id_users", "indents", "users",
        ["reviewed_by_id"], ["id"], ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_indents_reviewed_by_id_users", "indents", type_="foreignkey")
    op.drop_index("ix_indents_status", table_name="indents")
    op.drop_column("indents", "review_note")
    op.drop_column("indents", "reviewed_at")
    op.drop_column("indents", "reviewed_by_id")
    op.drop_column("indents", "status")

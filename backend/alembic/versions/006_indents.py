"""indents + indent_items

Revision ID: 006_indents
Revises: 005_soft_delete_unique
Create Date: 2026-09-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "006_indents"
down_revision: Union[str, None] = "005_soft_delete_unique"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "indents",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("do_id", sa.Integer(), nullable=False),
        sa.Column("indent_date", sa.Date(), nullable=False),
        sa.Column("total_stock", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_filled", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_empty", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("amount_paid", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("balance", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["do_id"], ["distributor_outlets.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_indents_do_id", "indents", ["do_id"])
    op.create_index("ix_indents_created_by_id", "indents", ["created_by_id"])
    op.create_index("ix_indents_do_date", "indents", ["do_id", "indent_date"])

    op.create_table(
        "indent_items",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("indent_id", sa.Integer(), nullable=False),
        sa.Column("size_kg", sa.Integer(), nullable=False),
        sa.Column("stock", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("filled", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("empty", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("rate", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.ForeignKeyConstraint(["indent_id"], ["indents.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_indent_items_indent_id", "indent_items", ["indent_id"])


def downgrade() -> None:
    op.drop_index("ix_indent_items_indent_id", table_name="indent_items")
    op.drop_table("indent_items")
    op.drop_index("ix_indents_do_date", table_name="indents")
    op.drop_index("ix_indents_created_by_id", table_name="indents")
    op.drop_index("ix_indents_do_id", table_name="indents")
    op.drop_table("indents")

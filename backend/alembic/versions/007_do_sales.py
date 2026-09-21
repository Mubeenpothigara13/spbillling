"""do_sales — sale lines recorded by a DO, billed later by S.P. Gas

Revision ID: 007_do_sales
Revises: 006_indents
Create Date: 2026-09-22

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "007_do_sales"
down_revision: Union[str, None] = "006_indents"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "do_sales",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("do_id", sa.Integer(), nullable=False),
        sa.Column("customer_id", sa.Integer(), nullable=False),
        sa.Column("sale_date", sa.Date(), nullable=False),
        sa.Column("product_variant_id", sa.Integer(), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("rate", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("gst_rate", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("empty_returned", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("bill_id", sa.Integer(), nullable=True),
        sa.Column("created_by_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["do_id"], ["distributor_outlets.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["product_variant_id"], ["product_variants.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["bill_id"], ["bills.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_do_sales_do_id", "do_sales", ["do_id"])
    op.create_index("ix_do_sales_customer_id", "do_sales", ["customer_id"])
    op.create_index("ix_do_sales_bill_id", "do_sales", ["bill_id"])
    op.create_index("ix_do_sales_do_date", "do_sales", ["do_id", "sale_date"])


def downgrade() -> None:
    op.drop_index("ix_do_sales_do_date", table_name="do_sales")
    op.drop_index("ix_do_sales_bill_id", table_name="do_sales")
    op.drop_index("ix_do_sales_customer_id", table_name="do_sales")
    op.drop_index("ix_do_sales_do_id", table_name="do_sales")
    op.drop_table("do_sales")

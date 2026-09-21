"""partial-unique DO code and customer consumer_number

Both distributor_outlets.code and customers.consumer_number carried a
global UNIQUE constraint, but delete on both tables is soft (is_deleted
flips true, the row stays). A deleted row's value still occupied the
constraint, so recreating with the same code/consumer number 500'd on a
raw IntegrityError instead of the app's own "already exists" check.
Uniqueness should only ever apply among live (non-deleted) rows.

Revision ID: 005_soft_delete_unique
Revises: 004_user_do_scope
Create Date: 2026-09-19

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "005_soft_delete_unique"
down_revision: Union[str, None] = "004_user_do_scope"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint("uq_distributor_outlets_code", "distributor_outlets", type_="unique")
    op.drop_index("ix_distributor_outlets_code", table_name="distributor_outlets")
    op.create_index(
        "uq_distributor_outlets_code_active",
        "distributor_outlets", ["code"],
        unique=True,
        postgresql_where=sa.text("NOT is_deleted"),
    )

    op.drop_constraint("uq_customers_consumer_number", "customers", type_="unique")
    op.drop_index("ix_customers_consumer_number", table_name="customers")
    op.create_index(
        "uq_customers_consumer_number_active",
        "customers", ["consumer_number"],
        unique=True,
        postgresql_where=sa.text("NOT is_deleted"),
    )


def downgrade() -> None:
    op.drop_index("uq_customers_consumer_number_active", table_name="customers")
    op.create_index("ix_customers_consumer_number", "customers", ["consumer_number"])
    op.create_unique_constraint("uq_customers_consumer_number", "customers", ["consumer_number"])

    op.drop_index("uq_distributor_outlets_code_active", table_name="distributor_outlets")
    op.create_index("ix_distributor_outlets_code", "distributor_outlets", ["code"])
    op.create_unique_constraint("uq_distributor_outlets_code", "distributor_outlets", ["code"])

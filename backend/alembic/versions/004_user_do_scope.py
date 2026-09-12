"""add users.do_id for per-DO login scoping

Revision ID: 004_user_do_scope
Revises: 003_village_optional
Create Date: 2026-09-12

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "004_user_do_scope"
down_revision: Union[str, None] = "003_village_optional"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("do_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_users_do_id_distributor_outlets",
        "users", "distributor_outlets",
        ["do_id"], ["id"],
        ondelete="RESTRICT",
    )
    op.create_index("ix_users_do_id", "users", ["do_id"])


def downgrade() -> None:
    op.drop_index("ix_users_do_id", table_name="users")
    op.drop_constraint("fk_users_do_id_distributor_outlets", "users", type_="foreignkey")
    op.drop_column("users", "do_id")

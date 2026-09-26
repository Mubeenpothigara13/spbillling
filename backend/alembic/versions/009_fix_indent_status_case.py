"""data fix — uppercase any indents.status left lowercase by 008's buggy default

Migration 008 backfilled existing rows with server_default="pending" (the
enum's .value), but every Enum(..., native_enum=False) column in this
codebase stores the member NAME ("PENDING"), so those rows failed to
deserialize with a LookupError on every GET /indents. 008 itself is fixed
to use the right casing going forward; this repairs rows that already went
through the buggy version, wherever this migration chain has run.

Revision ID: 009_fix_indent_status_case
Revises: 008_indent_review
Create Date: 2026-09-26

"""
from typing import Sequence, Union

from alembic import op


revision: str = "009_fix_indent_status_case"
down_revision: Union[str, None] = "008_indent_review"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE indents SET status = upper(status) WHERE status <> upper(status)")


def downgrade() -> None:
    pass

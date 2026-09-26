from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class IndentItemIn(BaseModel):
    size_kg: int
    filled: int = Field(0, ge=0)
    empty: int = Field(0, ge=0)


class IndentCreate(BaseModel):
    items: list[IndentItemIn] = Field(..., min_length=1)
    amount_paid: Decimal = Field(Decimal("0"), ge=0)


class IndentUpdate(BaseModel):
    """Admin correction — same shape as create, re-priced from the item's
    own stored rate (not re-fetched from the catalog)."""
    items: list[IndentItemIn] = Field(..., min_length=1)
    amount_paid: Decimal = Field(..., ge=0)


class IndentReject(BaseModel):
    note: Optional[str] = Field(None, max_length=500)


class IndentSizeRow(BaseModel):
    size_kg: int
    stock: int
    rate: Decimal


class IndentSummary(BaseModel):
    rows: list[IndentSizeRow]


class IndentItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    size_kg: int
    stock: int
    filled: int
    empty: int
    rate: Decimal
    amount: Decimal


class IndentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    do_id: int
    do_code: str
    do_name: str
    indent_date: date
    total_stock: int
    total_filled: int
    total_empty: int
    total_amount: Decimal
    amount_paid: Decimal
    balance: Decimal
    status: str
    reviewed_by_name: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    review_note: Optional[str] = None
    created_at: datetime
    items: list[IndentItemRead]

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class IndentItemIn(BaseModel):
    size_kg: int
    filled: int = Field(0, ge=0)
    empty: int = Field(0, ge=0)


class IndentCreate(BaseModel):
    items: list[IndentItemIn] = Field(..., min_length=1)
    amount_paid: Decimal = Field(Decimal("0"), ge=0)


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
    created_at: datetime
    items: list[IndentItemRead]

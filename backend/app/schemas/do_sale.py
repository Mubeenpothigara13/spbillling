from datetime import date
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class DoSaleLineIn(BaseModel):
    customer_id: int
    product_variant_id: int
    quantity: int = Field(..., ge=1)
    rate: Optional[Decimal] = Field(None, ge=0)
    empty_returned: int = Field(0, ge=0)


class DoSaleCreate(BaseModel):
    sale_date: Optional[date] = None
    lines: list[DoSaleLineIn] = Field(..., min_length=1)


class DoSaleBillRequest(BaseModel):
    customer_id: int
    sale_date: date


class DoSaleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    do_id: int
    do_code: str
    customer_id: int
    customer_name: str
    customer_village: Optional[str] = None
    customer_mobile: Optional[str] = None
    sale_date: date
    product_variant_id: int
    variant_name: str
    quantity: int
    rate: Decimal
    gst_rate: Decimal
    empty_returned: int
    bill_id: Optional[int] = None
    bill_number: Optional[str] = None
    status: str


class DoSaleVariantTotal(BaseModel):
    variant_name: str
    qty: int


class DoSaleSummary(BaseModel):
    total_qty: int
    customer_count: int
    by_variant: list[DoSaleVariantTotal]

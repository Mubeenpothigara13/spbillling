from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.user import UserRole


class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    password: str = Field(..., min_length=4, max_length=128)
    full_name: str = Field(..., max_length=150)
    email: Optional[EmailStr] = None
    role: UserRole = UserRole.BILLING_STAFF
    is_active: bool = True
    # Set to lock this login to one Distributor Outlet. Leave None for a
    # global S.P. Gas login that sees every DO.
    do_id: Optional[int] = None


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None
    password: Optional[str] = Field(None, min_length=4, max_length=128)
    do_id: Optional[int] = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    full_name: str
    email: Optional[str] = None
    role: UserRole
    is_active: bool
    do_id: Optional[int] = None
    last_login: Optional[datetime] = None
    created_at: datetime

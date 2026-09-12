from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.distributor_outlet import DistributorOutlet
from app.models.user import User
from app.schemas.auth import LoginRequest, TokenResponse
from app.utils.auth import create_access_token, verify_password


def get_do_code(db: Session, do_id: int | None) -> str | None:
    if do_id is None:
        return None
    return db.scalar(select(DistributorOutlet.code).where(DistributorOutlet.id == do_id))


def authenticate(db: Session, payload: LoginRequest) -> TokenResponse:
    user = db.scalar(select(User).where(User.username == payload.username))
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is disabled")

    user.last_login = datetime.now(timezone.utc)
    db.commit()

    token = create_access_token(user.id, user.role.value)
    return TokenResponse(
        access_token=token,
        role=user.role,
        user_id=user.id,
        full_name=user.full_name,
        do_id=user.do_id,
        do_code=get_do_code(db, user.do_id),
    )

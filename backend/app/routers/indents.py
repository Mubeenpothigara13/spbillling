from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.models.user import User
from app.schemas.common import APIResponse, PaginatedResponse
from app.schemas.indent import IndentCreate, IndentRead, IndentSummary
from app.services import indent_service as svc
from app.utils.auth import get_current_user, require_staff
from app.utils.pagination import paginate
from app.utils.scope import enforce_do_scope, resolve_do_filter

router = APIRouter(prefix="/indents", tags=["Indents"])


@router.get("/summary", response_model=APIResponse[IndentSummary])
def summary(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    rows = svc.size_summary(db, resolve_do_filter(user, None))
    return APIResponse(data=IndentSummary(rows=rows))


@router.get("", response_model=PaginatedResponse[IndentRead])
def list_indents(
    do_id: Optional[int] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(25, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    stmt = svc.list_indents(do_id=resolve_do_filter(user, do_id))
    return paginate(db, stmt, page=page, per_page=per_page, item_schema=IndentRead)


@router.get("/{indent_id}", response_model=APIResponse[IndentRead])
def get_indent(
    indent_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    indent = svc.get_indent(db, indent_id)
    enforce_do_scope(user, indent.do_id)
    return APIResponse(data=IndentRead.model_validate(indent))


@router.post("", response_model=APIResponse[IndentRead])
def create_indent(
    payload: IndentCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_staff),
):
    indent = svc.create_indent(db, user, payload)
    return APIResponse(data=IndentRead.model_validate(indent), message="Indent submitted")

from typing import Optional

from fastapi import HTTPException

from app.models.user import User


def resolve_do_filter(user: User, requested_do_id: Optional[int]) -> Optional[int]:
    """DO-scoped users can only ever filter to their own DO; global users
    (do_id is None — S.P. Gas) keep today's behavior: free to filter by any
    DO or see all."""
    return user.do_id if user.do_id is not None else requested_do_id


def enforce_do_scope(user: User, entity_do_id: Optional[int]) -> None:
    """Raise 404 if a DO-scoped user reaches another DO's record. 404 (not
    403) so a scoped user can't even confirm the record exists."""
    if user.do_id is not None and entity_do_id != user.do_id:
        raise HTTPException(status_code=404, detail="Not found")

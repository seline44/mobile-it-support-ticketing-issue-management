
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from auth import require_roles
from database import get_db
from models import User

router = APIRouter(prefix="/admin", tags=["Administration"])


class PendingUserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str
    approval_status: str
    created_at: object


class ApprovalRequest(BaseModel):
    approval_status: Literal["Approved", "Rejected"]


class ApprovalResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str
    approval_status: str
    message: str



@router.get("/users", response_model=list[PendingUserResponse])
def list_all_users(
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles("Administrator")),
):
    return (
        db.query(User)
        .order_by(User.created_at.asc())
        .all()
    )




@router.get("/users/pending", response_model=list[PendingUserResponse])
def list_pending_users(
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles("Administrator")),
):
    return (
        db.query(User)
        .filter(
            User.approval_status == "Pending",
            User.role.in_(["Reporter", "Technician"]),
        )
        .order_by(User.created_at.asc())
        .all()
    )


@router.patch(
    "/users/{user_id}/approval",
    response_model=ApprovalResponse,
)
def update_user_approval(
    user_id: int,
    request: ApprovalRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles("Administrator")),
):
    if user_id == admin.id:
        raise HTTPException(
            status_code=400,
            detail="You cannot change your own account approval through this endpoint.",
        )

    user = db.get(User, user_id)

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    if user.role not in {"Reporter", "Technician"}:
        raise HTTPException(
            status_code=403,
            detail="Only Reporter and Technician registrations can be reviewed here.",
        )

    if user.approval_status != "Pending":
        raise HTTPException(
            status_code=409,
            detail="This registration has already been reviewed.",
        )

    user.approval_status = request.approval_status

    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise

    if user.approval_status == "Approved":
        message = "Account approved. The user can now log in."
    else:
        message = "Registration rejected. The user cannot log in."

    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "role": user.role,
        "approval_status": user.approval_status,
        "message": message,
    }

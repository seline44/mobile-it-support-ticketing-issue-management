
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Path
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from auth import require_roles
from database import get_db
from models import User, WhatsAppContact, WhatsAppConversation

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


class WhatsAppLinkRequest(BaseModel):
    phone_number: str = Field(pattern=r"^\+[1-9]\d{7,14}$")


class WhatsAppLinkResponse(BaseModel):
    user_id: int
    phone_number: str
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


@router.put(
    "/users/{user_id}/whatsapp",
    response_model=WhatsAppLinkResponse,
)
def link_whatsapp_number(
    request: WhatsAppLinkRequest,
    user_id: int = Path(gt=0),
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles("Administrator")),
):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role != "Reporter" or not user.is_active or user.approval_status != "Approved":
        raise HTTPException(
            status_code=422,
            detail="Only active, approved Reporter accounts can be linked.",
        )

    existing_phone = db.get(WhatsAppContact, request.phone_number)
    if existing_phone is not None:
        if existing_phone.user_id == user.id:
            return {
                "user_id": user.id,
                "phone_number": existing_phone.phone_number,
                "message": "This WhatsApp number is already linked to the Reporter.",
            }
        raise HTTPException(
            status_code=409,
            detail="This WhatsApp number is already linked to another account.",
        )

    existing_user_link = (
        db.query(WhatsAppContact)
        .filter(WhatsAppContact.user_id == user.id)
        .first()
    )
    if existing_user_link is not None:
        raise HTTPException(
            status_code=409,
            detail="This Reporter already has a linked WhatsApp number. Unlink it first.",
        )

    contact = WhatsAppContact(
        phone_number=request.phone_number,
        user_id=user.id,
        linked_by_user_id=admin.id,
    )
    db.add(contact)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="The WhatsApp number or Reporter account is already linked.",
        )

    return {
        "user_id": user.id,
        "phone_number": contact.phone_number,
        "message": "WhatsApp number linked successfully.",
    }


@router.delete(
    "/users/{user_id}/whatsapp",
    response_model=WhatsAppLinkResponse,
    dependencies=[Depends(require_roles("Administrator"))],
)
def unlink_whatsapp_number(
    user_id: int = Path(gt=0),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    contact = (
        db.query(WhatsAppContact)
        .filter(WhatsAppContact.user_id == user.id)
        .first()
    )
    if contact is None:
        raise HTTPException(
            status_code=404,
            detail="This Reporter does not have a linked WhatsApp number.",
        )

    phone_number = contact.phone_number
    db.delete(contact)
    db.query(WhatsAppConversation).filter(
        WhatsAppConversation.phone_number == phone_number
    ).delete()
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise

    return {
        "user_id": user.id,
        "phone_number": phone_number,
        "message": "WhatsApp number unlinked successfully.",
    }


from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from auth import require_roles
from database import get_db
from models import (
    Ticket,
    TicketHistory,
    TicketNote,
    User,
    WhatsAppContact,
    WhatsAppConversation,
    WhatsAppMessage,
)

router = APIRouter(prefix="/admin", tags=["Administration"])


class PendingUserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str
    approval_status: str
    is_active: bool
    created_at: object


class ApprovalRequest(BaseModel):
    approval_status: Literal["Approved", "Rejected"]


class AccountStatusRequest(BaseModel):
    is_active: bool


class ApprovalResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str
    approval_status: str
    message: str


class DeleteUserResponse(BaseModel):
    id: int
    deleted_tickets: int
    message: str


class AccountStatusResponse(BaseModel):
    id: int
    is_active: bool
    message: str


class WhatsAppLinkRequest(BaseModel):
    phone_number: str = Field(pattern=r"^\+[1-9]\d{7,14}$")


class WhatsAppLinkResponse(BaseModel):
    user_id: int
    phone_number: str
    message: str


class WhatsAppTicketNotification(BaseModel):
    id: int
    ticket_id: int
    ticket_number: str
    title: str
    created_at: datetime



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


@router.get(
    "/notifications/whatsapp",
    response_model=list[WhatsAppTicketNotification],
)
def list_whatsapp_ticket_notifications(
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles("Administrator")),
):
    rows = (
        db.query(TicketHistory, Ticket)
        .join(Ticket, TicketHistory.ticket_id == Ticket.id)
        .filter(TicketHistory.action == "Ticket created via WhatsApp")
        .order_by(TicketHistory.created_at.desc(), TicketHistory.id.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": history.id,
            "ticket_id": ticket.id,
            "ticket_number": ticket.ticket_number,
            "title": ticket.title,
            "created_at": history.created_at,
        }
        for history, ticket in rows
    ]


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


@router.patch(
    "/users/{user_id}/active",
    response_model=AccountStatusResponse,
)
def update_user_active_status(
    request: AccountStatusRequest,
    user_id: int = Path(gt=0),
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles("Administrator")),
):
    if user_id == admin.id and not request.is_active:
        raise HTTPException(
            status_code=400,
            detail="You cannot lock your own account.",
        )

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    if user.role == "Administrator" and not request.is_active and user.is_active:
        another_active_admin = (
            db.query(User)
            .filter(
                User.id != user.id,
                User.role == "Administrator",
                User.is_active.is_(True),
                User.approval_status == "Approved",
            )
            .first()
        )
        if another_active_admin is None:
            raise HTTPException(
                status_code=409,
                detail="The last active administrator cannot be locked.",
            )

    user.is_active = request.is_active
    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise

    action = "unlocked" if user.is_active else "locked"
    return {
        "id": user.id,
        "is_active": user.is_active,
        "message": f"Account {action} successfully.",
    }


@router.delete("/users/{user_id}", response_model=DeleteUserResponse)
def delete_user(
    user_id: int = Path(gt=0),
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles("Administrator")),
):
    if user_id == admin.id:
        raise HTTPException(
            status_code=400,
            detail="You cannot delete your own account.",
        )

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    if user.role == "Administrator":
        another_active_admin = (
            db.query(User)
            .filter(
                User.id != user.id,
                User.role == "Administrator",
                User.is_active.is_(True),
                User.approval_status == "Approved",
            )
            .first()
        )
        if another_active_admin is None:
            raise HTTPException(
                status_code=409,
                detail="The last active administrator cannot be deleted.",
            )

    ticket_ids = [
        row[0]
        for row in db.query(Ticket.id)
        .filter(Ticket.reporter_id == user.id)
        .all()
    ]
    phone_numbers = [
        row[0]
        for row in db.query(WhatsAppContact.phone_number)
        .filter(WhatsAppContact.user_id == user.id)
        .all()
    ]

    try:
        db.query(WhatsAppContact).filter(
            WhatsAppContact.linked_by_user_id == user.id
        ).update(
            {WhatsAppContact.linked_by_user_id: admin.id},
            synchronize_session=False,
        )

        conversation_filter = []
        if phone_numbers:
            conversation_filter.append(
                WhatsAppConversation.phone_number.in_(phone_numbers)
            )
            db.query(WhatsAppMessage).filter(
                WhatsAppMessage.phone_number.in_(phone_numbers)
            ).delete(synchronize_session=False)
        if ticket_ids:
            conversation_filter.append(
                WhatsAppConversation.ticket_id.in_(ticket_ids)
            )
            db.query(TicketNote).filter(
                TicketNote.ticket_id.in_(ticket_ids)
            ).delete(synchronize_session=False)
            db.query(TicketHistory).filter(
                TicketHistory.ticket_id.in_(ticket_ids)
            ).delete(synchronize_session=False)

        if conversation_filter:
            db.query(WhatsAppConversation).filter(
                or_(*conversation_filter)
            ).delete(synchronize_session=False)

        db.query(WhatsAppContact).filter(
            WhatsAppContact.user_id == user.id
        ).delete(synchronize_session=False)

        if ticket_ids:
            db.query(Ticket).filter(Ticket.id.in_(ticket_ids)).delete(
                synchronize_session=False
            )

        db.query(Ticket).filter(
            Ticket.assigned_technician_id == user.id
        ).update(
            {Ticket.assigned_technician_id: None},
            synchronize_session=False,
        )
        db.query(TicketNote).filter(
            TicketNote.author_id == user.id
        ).delete(synchronize_session=False)
        db.query(TicketHistory).filter(
            TicketHistory.actor_id == user.id
        ).update(
            {TicketHistory.actor_id: None},
            synchronize_session=False,
        )

        db.delete(user)
        db.commit()
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="The user could not be deleted because related records remain.",
        ) from error
    except Exception:
        db.rollback()
        raise

    deleted_tickets = len(ticket_ids)
    return {
        "id": user_id,
        "deleted_tickets": deleted_tickets,
        "message": (
            f"User and {deleted_tickets} associated "
            f"{'ticket' if deleted_tickets == 1 else 'tickets'} deleted."
        ),
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

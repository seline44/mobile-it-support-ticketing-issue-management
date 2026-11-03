
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from auth import get_current_user, require_roles
from database import get_db
from models import Ticket, TicketHistory, TicketNote, User, WhatsAppContact
from schemas import (
    NoteCreate,
    NoteResponse,
    ReopenRequest,
    StatusUpdate,
    TicketCreate,
    TicketHistoryResponse,
    TicketNotificationResponse,
    TicketResponse,
)
from whatsapp_notifications import send_reporter_whatsapp_update

router = APIRouter(prefix="/tickets", tags=["Tickets"])

VALID_IMPACTS = {"Low", "Medium", "High"}
VALID_URGENCIES = {"Low", "Medium", "High"}
VALID_STATUSES = {"Open", "In Progress", "Pending", "Resolved", "Closed"}


def calculate_priority(impact: str, urgency: str) -> str:
    scores = {
        ("Low", "Low"): "Low",
        ("Low", "Medium"): "Low",
        ("Low", "High"): "Medium",
        ("Medium", "Low"): "Low",
        ("Medium", "Medium"): "Medium",
        ("Medium", "High"): "High",
        ("High", "Low"): "Medium",
        ("High", "Medium"): "High",
        ("High", "High"): "Critical",
    }
    return scores[(impact, urgency)]


def get_ticket_or_404(db: Session, ticket_id: int) -> Ticket:
    ticket = db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return ticket


def check_ticket_access(ticket: Ticket, user: User) -> None:
    if user.role == "Reporter" and ticket.reporter_id != user.id:
        raise HTTPException(status_code=404, detail="Ticket not found")

    if user.role == "Technician":
        if ticket.assigned_technician_id != user.id:
            raise HTTPException(
                status_code=403,
                detail="This ticket is not assigned to you",
            )


def record_history(
    db: Session,
    ticket: Ticket,
    actor_id: int | None,
    action: str,
    old_status: str | None = None,
    new_status: str | None = None,
    details: str | None = None,
) -> None:
    db.add(
        TicketHistory(
            ticket_id=ticket.id,
            actor_id=actor_id,
            action=action,
            old_status=old_status,
            new_status=new_status,
            details=details,
        )
    )


def serialize_ticket(db: Session, ticket: Ticket) -> dict:
    """Build a ticket response including requester and technician details."""
    assigned_name = None
    if ticket.assigned_technician_id is not None:
        technician = db.get(User, ticket.assigned_technician_id)
        if technician is not None:
            assigned_name = technician.full_name

    reporter = db.get(User, ticket.reporter_id)
    reporter_phone = None
    if reporter is not None:
        contact = (
            db.query(WhatsAppContact)
            .filter(WhatsAppContact.user_id == reporter.id)
            .first()
        )
        if contact is not None:
            reporter_phone = contact.phone_number

    last_history = (
        db.query(TicketHistory)
        .filter(TicketHistory.ticket_id == ticket.id)
        .order_by(TicketHistory.created_at.desc(), TicketHistory.id.desc())
        .first()
    )

    last_editor_name = None
    last_modified_at = ticket.updated_at

    if last_history is not None:
        last_modified_at = last_history.created_at
        if last_history.actor_id is not None:
            editor = db.get(User, last_history.actor_id)
            if editor is not None:
                last_editor_name = editor.full_name

    return {
        "id": ticket.id,
        "ticket_number": ticket.ticket_number,
        "title": ticket.title,
        "description": ticket.description,
        "category": ticket.category,
        "impact": ticket.impact,
        "urgency": ticket.urgency,
        "priority": ticket.priority,
        "device": ticket.device,
        "location": ticket.location,
        "status": ticket.status,
        "resolution": ticket.resolution,
        "reporter_id": ticket.reporter_id,
        "reporter_name": reporter.full_name if reporter is not None else None,
        "reporter_phone": reporter_phone,
        "assigned_technician_id": ticket.assigned_technician_id,
        "assigned_technician_name": assigned_name,
        "last_modified_by_name": last_editor_name,
        "last_modified_at": last_modified_at,
        "created_at": ticket.created_at,
        "updated_at": ticket.updated_at,
        "resolved_at": ticket.resolved_at,
    }


@router.post("", response_model=TicketResponse, status_code=201)
def create_ticket(
    request: TicketCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("Reporter", "Administrator")),
):
    if request.impact not in VALID_IMPACTS:
        raise HTTPException(status_code=422, detail="Invalid impact value")

    if request.urgency not in VALID_URGENCIES:
        raise HTTPException(status_code=422, detail="Invalid urgency value")

    ticket = Ticket(
        ticket_number=f"TD-{uuid4().hex[:8].upper()}",
        title=request.title.strip(),
        description=request.description.strip(),
        category=request.category.strip(),
        impact=request.impact,
        urgency=request.urgency,
        priority=calculate_priority(request.impact, request.urgency),
        device=request.device.strip(),
        location=request.location.strip(),
        status="Open",
        reporter_id=user.id,
    )

    try:
        db.add(ticket)
        db.flush()
        record_history(
            db, ticket, user.id, "Ticket created", new_status="Open"
        )
        db.commit()
        db.refresh(ticket)
        return serialize_ticket(db, ticket)
    except Exception:
        db.rollback()
        raise


@router.get("", response_model=list[TicketResponse])
def list_tickets(
    status: str | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = db.query(Ticket)

    if user.role == "Reporter":
        query = query.filter(Ticket.reporter_id == user.id)
    elif user.role == "Technician":
        query = query.filter(
            or_(
                Ticket.assigned_technician_id == user.id,
                (
                    (Ticket.status == "Open")
                    & (Ticket.assigned_technician_id.is_(None))
                ),
            )
        )
    elif user.role != "Administrator":
        raise HTTPException(status_code=403, detail="Role not permitted")

    if status:
        if status not in VALID_STATUSES:
            raise HTTPException(status_code=422, detail="Invalid status")
        query = query.filter(Ticket.status == status)

    tickets = query.order_by(Ticket.created_at.desc()).all()
    return [serialize_ticket(db, ticket) for ticket in tickets]


@router.get(
    "/notifications",
    response_model=list[TicketNotificationResponse],
)
def list_notifications(
    limit: int = Query(default=50, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = (
        db.query(TicketHistory, Ticket, User.full_name)
        .join(Ticket, TicketHistory.ticket_id == Ticket.id)
        .outerjoin(User, TicketHistory.actor_id == User.id)
    )

    if user.role == "Reporter":
        query = query.filter(
            Ticket.reporter_id == user.id,
            TicketHistory.actor_id != user.id,
        )
    elif user.role == "Technician":
        new_ticket_actions = (
            "Ticket created",
            "Ticket created via WhatsApp",
            "Ticket reopened",
        )
        query = query.filter(
            or_(
                and_(
                    Ticket.assigned_technician_id == user.id,
                    TicketHistory.actor_id != user.id,
                ),
                and_(
                    Ticket.status.in_(("Open", "Pending")),
                    Ticket.assigned_technician_id.is_(None),
                    TicketHistory.action.in_(new_ticket_actions),
                ),
            )
        )
    else:
        raise HTTPException(
            status_code=403,
            detail="Notifications are available to Reporters and Technicians.",
        )

    rows = (
        query.order_by(
            TicketHistory.created_at.desc(),
            TicketHistory.id.desc(),
        )
        .limit(limit)
        .all()
    )
    return [
        {
            "id": history.id,
            "ticket_id": ticket.id,
            "ticket_number": ticket.ticket_number,
            "ticket_title": ticket.title,
            "action": history.action,
            "details": history.details,
            "old_status": history.old_status,
            "new_status": history.new_status,
            "actor_name": actor_name,
            "created_at": history.created_at,
        }
        for history, ticket, actor_name in rows
    ]


@router.get("/{ticket_id}", response_model=TicketResponse)
def get_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = get_ticket_or_404(db, ticket_id)
    check_ticket_access(ticket, user)
    return serialize_ticket(db, ticket)


@router.post("/{ticket_id}/accept", response_model=TicketResponse)
def accept_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("Technician")),
):
    ticket = get_ticket_or_404(db, ticket_id)

    if ticket.status != "Open":
        raise HTTPException(
            status_code=409,
            detail="Only open tickets can be accepted",
        )

    old_status = ticket.status
    ticket.assigned_technician_id = user.id
    ticket.status = "In Progress"
    ticket.updated_at = datetime.now(timezone.utc)

    record_history(
        db,
        ticket,
        user.id,
        "Ticket accepted",
        old_status=old_status,
        new_status=ticket.status,
    )

    db.commit()
    db.refresh(ticket)
    send_reporter_whatsapp_update(
        db,
        ticket,
        f"{user.full_name} accepted ticket {ticket.ticket_number} and is "
        "working on it.",
    )
    return serialize_ticket(db, ticket)


@router.patch("/{ticket_id}/status", response_model=TicketResponse)
def update_ticket_status(
    ticket_id: int,
    request: StatusUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("Technician", "Administrator")),
):
    if request.status not in VALID_STATUSES:
        raise HTTPException(status_code=422, detail="Invalid status")

    ticket = get_ticket_or_404(db, ticket_id)

    if user.role == "Technician":
        if ticket.assigned_technician_id != user.id:
            raise HTTPException(
                status_code=403,
                detail="You can only update tickets assigned to you",
            )
        if (
            request.status in {"Resolved", "Closed"}
            and ticket.status != "In Progress"
        ):
            raise HTTPException(
                status_code=409,
                detail="Only in-progress tickets can be resolved or closed",
            )

    resolution = request.resolution.strip() if request.resolution else None
    note_text = request.note.strip() if request.note else None
    if request.status in {"Resolved", "Closed"} and not resolution:
        raise HTTPException(
            status_code=422,
            detail="A resolution note is required to resolve or close a ticket",
        )
    if request.note is not None and not note_text:
        raise HTTPException(status_code=422, detail="Note cannot be empty")

    old_status = ticket.status
    now = datetime.now(timezone.utc)
    ticket.status = request.status
    ticket.updated_at = now

    history_details = None
    if request.status in {"Resolved", "Closed"}:
        ticket.resolved_at = now
        ticket.resolution = resolution
        history_details = f"Resolution: {resolution}"
    elif old_status in {"Resolved", "Closed"}:
        ticket.resolved_at = None

    action = (
        f"Ticket {request.status.lower()}"
        if request.status in {"Resolved", "Closed"}
        else "Status changed"
    )

    try:
        if note_text:
            db.add(
                TicketNote(
                    ticket_id=ticket.id,
                    author_id=user.id,
                    note=note_text,
                )
            )
        if note_text:
            history_details = (
                f"{history_details}\nUpdate: {note_text}"
                if history_details
                else f"Update: {note_text}"
            )
        record_history(
            db,
            ticket,
            user.id,
            action,
            old_status=old_status,
            new_status=ticket.status,
            details=history_details,
        )
        db.commit()
        db.refresh(ticket)
        if user.role == "Technician":
            update_message = (
                f"{user.full_name} updated ticket {ticket.ticket_number}: "
                f"{old_status} -> {ticket.status}."
            )
            if resolution:
                update_message += f"\nResolution: {resolution}"
            if note_text:
                update_message += f"\nUpdate: {note_text}"
            send_reporter_whatsapp_update(db, ticket, update_message)
        return serialize_ticket(db, ticket)
    except Exception:
        db.rollback()
        raise


@router.post("/{ticket_id}/reopen", response_model=TicketResponse)
def reopen_ticket(
    ticket_id: int,
    request: ReopenRequest,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("Reporter")),
):
    ticket = get_ticket_or_404(db, ticket_id)

    # Reporters may reopen only their own tickets.
    if ticket.reporter_id != user.id:
        raise HTTPException(status_code=404, detail="Ticket not found")

    if ticket.status not in {"Resolved", "Closed"}:
        raise HTTPException(
            status_code=409,
            detail="Only resolved or closed tickets can be reopened",
        )

    reason = request.reason.strip()
    if len(reason) < 3:
        raise HTTPException(
            status_code=422,
            detail="Please provide a reopening reason",
        )

    old_status = ticket.status
    ticket.status = "Open"
    ticket.resolved_at = None
    ticket.assigned_technician_id = None
    ticket.updated_at = datetime.now(timezone.utc)

    # Keep the previous resolution for reference.
    record_history(
        db,
        ticket,
        user.id,
        "Ticket reopened",
        old_status=old_status,
        new_status="Open",
        details=f"Reporter reopening reason: {reason}",
    )

    db.commit()
    db.refresh(ticket)
    return serialize_ticket(db, ticket)


@router.get(
    "/{ticket_id}/history",
    response_model=list[TicketHistoryResponse],
)
def list_ticket_history(
    ticket_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = get_ticket_or_404(db, ticket_id)
    check_ticket_access(ticket, user)

    rows = (
        db.query(TicketHistory, User.full_name)
        .outerjoin(User, TicketHistory.actor_id == User.id)
        .filter(TicketHistory.ticket_id == ticket.id)
        .order_by(TicketHistory.created_at.asc(), TicketHistory.id.asc())
        .all()
    )

    return [
        {
            "id": history.id,
            "ticket_id": history.ticket_id,
            "actor_id": history.actor_id,
            "actor_name": actor_name,
            "action": history.action,
            "old_status": history.old_status,
            "new_status": history.new_status,
            "details": history.details,
            "created_at": history.created_at,
        }
        for history, actor_name in rows
    ]


@router.post(
    "/{ticket_id}/notes",
    response_model=NoteResponse,
    status_code=201,
)
def add_ticket_note(
    ticket_id: int,
    request: NoteCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = get_ticket_or_404(db, ticket_id)
    check_ticket_access(ticket, user)

    note_text = request.note.strip()
    if not note_text:
        raise HTTPException(status_code=422, detail="Note cannot be empty")

    note = TicketNote(
        ticket_id=ticket.id,
        author_id=user.id,
        note=note_text,
    )

    try:
        db.add(note)
        record_history(
            db,
            ticket,
            user.id,
            "Note added",
            details=f"Update: {note_text}",
        )
        ticket.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(note)
        if user.role == "Technician":
            send_reporter_whatsapp_update(
                db,
                ticket,
                f"{user.full_name} added an update to ticket "
                f"{ticket.ticket_number}:\n{note_text}",
            )
        return note
    except Exception:
        db.rollback()
        raise


@router.get(
    "/{ticket_id}/notes",
    response_model=list[NoteResponse],
)
def list_ticket_notes(
    ticket_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = get_ticket_or_404(db, ticket_id)
    check_ticket_access(ticket, user)

    rows = (
        db.query(TicketNote, User.full_name)
        .join(User, TicketNote.author_id == User.id)
        .filter(TicketNote.ticket_id == ticket.id)
        .order_by(TicketNote.created_at.asc())
        .all()
    )
    return [
        {
            "id": note.id,
            "ticket_id": note.ticket_id,
            "author_id": note.author_id,
            "author_name": author_name,
            "note": note.note,
            "created_at": note.created_at,
        }
        for note, author_name in rows
    ]

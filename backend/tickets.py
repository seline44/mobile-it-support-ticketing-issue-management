
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from auth import get_current_user, require_roles
from database import get_db
from models import Ticket, TicketHistory, TicketNote, User
from schemas import (
    NoteCreate,
    NoteResponse,
    StatusUpdate,
    TicketCreate,
    TicketResponse,
)
from sqlalchemy import or_

router = APIRouter(prefix="/tickets", tags=["Tickets"])

VALID_IMPACTS = {"Low", "Medium", "High"}
VALID_URGENCIES = {"Low", "Medium", "High"}
VALID_STATUSES = {"Open", "In Progress", "Pending", "Resolved"}


def calculate_priority(impact: str, urgency: str) -> str:
    # Initial rule-based priority; we can later implement
    # configurable weights and SLA risk scoring.
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
            db,
            ticket,
            user.id,
            "Ticket created",
            new_status="Open",
        )

        db.commit()
        db.refresh(ticket)
        return ticket
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

    return query.order_by(Ticket.created_at.desc()).all()


@router.get("/{ticket_id}", response_model=TicketResponse)
def get_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = get_ticket_or_404(db, ticket_id)
    check_ticket_access(ticket, user)
    return ticket


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
    return ticket


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

    old_status = ticket.status
    ticket.status = request.status
    ticket.updated_at = datetime.now(timezone.utc)

    if request.status == "Resolved":
        ticket.resolved_at = datetime.now(timezone.utc)
    else:
        ticket.resolved_at = None

    record_history(
        db,
        ticket,
        user.id,
        "Status changed",
        old_status=old_status,
        new_status=ticket.status,
    )

    db.commit()
    db.refresh(ticket)
    return ticket


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

    note = TicketNote(
        ticket_id=ticket.id,
        author_id=user.id,
        note=request.note.strip(),
    )

    if not note.note:
        raise HTTPException(status_code=422, detail="Note cannot be empty")

    try:
        db.add(note)
        record_history(
            db,
            ticket,
            user.id,
            "Note added",
            details="Ticket note added",
        )
        ticket.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(note)
        return note
    except Exception:
        db.rollback()
        raise


@router.get("/{ticket_id}/notes", response_model=list[NoteResponse])
def list_ticket_notes(
    ticket_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = get_ticket_or_404(db, ticket_id)
    check_ticket_access(ticket, user)

    return (
        db.query(TicketNote)
        .filter(TicketNote.ticket_id == ticket.id)
        .order_by(TicketNote.created_at.asc())
        .all()
    )

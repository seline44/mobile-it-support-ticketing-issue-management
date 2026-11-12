import logging
import os

from sqlalchemy.orm import Session

from email_service import send_email
from models import Ticket, TicketHistory, User

logger = logging.getLogger(__name__)


def _ticket_email_notifications_enabled() -> bool:
    return (
        os.getenv("TICKET_EMAIL_NOTIFICATIONS_ENABLED", "true")
        .strip()
        .casefold()
        == "true"
    )


def _ticket_was_created_via_whatsapp(db: Session, ticket: Ticket) -> bool:
    return (
        db.query(TicketHistory.id)
        .filter(
            TicketHistory.ticket_id == ticket.id,
            TicketHistory.action == "Ticket created via WhatsApp",
        )
        .first()
        is not None
    )


def _send_ticket_email(
    ticket: Ticket,
    recipient: str,
    subject: str,
    body: str,
) -> bool:
    if recipient.casefold().endswith("@triagedesk.guest"):
        logger.info(
            "Email notification for ticket %s was skipped: %s is a "
            "WhatsApp guest account without an email address.",
            ticket.ticket_number,
            recipient,
        )
        return False
    try:
        send_email(recipient, subject, body)
    except Exception:
        logger.exception(
            "Could not send email notification for ticket %s to %s.",
            ticket.ticket_number,
            recipient,
        )
        return False
    return True


def notify_ticket_created(db: Session, ticket: Ticket) -> None:
    if not _ticket_email_notifications_enabled():
        logger.info(
            "Ticket email notifications are disabled; skipping ticket %s.",
            ticket.ticket_number,
        )
        return
    try:
        reporter = db.get(User, ticket.reporter_id)
        was_created_via_whatsapp = _ticket_was_created_via_whatsapp(db, ticket)
        if reporter is None:
            logger.warning(
                "Could not email the reporter for ticket %s: user not found.",
                ticket.ticket_number,
            )
        elif not was_created_via_whatsapp:
            _send_ticket_email(
                ticket,
                reporter.email,
                f"Ticket {ticket.ticket_number} received",
                (
                    f"Hello {reporter.full_name},\n\n"
                    f"We received your support request: {ticket.title}\n"
                    f"Ticket: {ticket.ticket_number}\n"
                    "Status: Open\n\n"
                    "A technician will review your request."
                ),
            )
        else:
            logger.info(
                "Email creation notification for ticket %s was skipped: "
                "ticket was created via WhatsApp.",
                ticket.ticket_number,
            )

        technicians = (
            db.query(User)
            .filter(
                User.role == "Technician",
                User.is_active.is_(True),
                User.approval_status == "Approved",
            )
            .order_by(User.id)
            .all()
        )
        for technician in technicians:
            _send_ticket_email(
                ticket,
                technician.email,
                f"New ticket {ticket.ticket_number}: {ticket.title}",
                (
                    f"A new support ticket has been submitted.\n\n"
                    f"Ticket: {ticket.ticket_number}\n"
                    f"Title: {ticket.title}\n"
                    f"Category: {ticket.category}\n"
                    f"Priority: {ticket.priority}\n"
                    f"Reporter: {reporter.full_name if reporter else 'Unknown'}\n"
                    f"Description: {ticket.description}\n"
                ),
            )
    except Exception:
        logger.exception(
            "Could not prepare email notifications for ticket %s.",
            ticket.ticket_number,
        )


def notify_reporter_public_reply(
    db: Session,
    ticket: Ticket,
    author: User,
    reply: str,
) -> None:
    if not _ticket_email_notifications_enabled():
        logger.info(
            "Ticket email notifications are disabled; skipping reply email "
            "for ticket %s.",
            ticket.ticket_number,
        )
        return
    try:
        if _ticket_was_created_via_whatsapp(db, ticket):
            logger.info(
                "Email reply notification for ticket %s was skipped: "
                "ticket was created via WhatsApp.",
                ticket.ticket_number,
            )
            return
        reporter = db.get(User, ticket.reporter_id)
        if reporter is None:
            logger.warning(
                "Could not email the reporter for ticket %s: user not found.",
                ticket.ticket_number,
            )
            return
        _send_ticket_email(
            ticket,
            reporter.email,
            f"New reply on ticket {ticket.ticket_number}",
            (
                f"Hello {reporter.full_name},\n\n"
                f"{author.full_name} replied to your support request "
                f"({ticket.ticket_number}):\n\n"
                f"{reply}\n"
            ),
        )
    except Exception:
        logger.exception(
            "Could not prepare a reply email for ticket %s.",
            ticket.ticket_number,
        )


def notify_reporter_resolved(db: Session, ticket: Ticket) -> bool:
    if not _ticket_email_notifications_enabled():
        logger.info(
            "Ticket email notifications are disabled; skipping resolution "
            "email for ticket %s.",
            ticket.ticket_number,
        )
        return False
    try:
        if _ticket_was_created_via_whatsapp(db, ticket):
            logger.info(
                "Email resolution notification for ticket %s was skipped: "
                "ticket was created via WhatsApp.",
                ticket.ticket_number,
            )
            return False
        reporter = db.get(User, ticket.reporter_id)
        if reporter is None:
            logger.warning(
                "Could not email the reporter for ticket %s: user not found.",
                ticket.ticket_number,
            )
            return False
        return _send_ticket_email(
            ticket,
            reporter.email,
            f"Ticket {ticket.ticket_number} resolved",
            (
                f"Hello {reporter.full_name},\n\n"
                f"Your ticket, {ticket.ticket_number} ({ticket.title}), "
                f"is now {ticket.status.casefold()}.\n\n"
                f"Resolution:\n{ticket.resolution or 'No resolution details provided.'}"
            ),
        )
    except Exception:
        logger.exception(
            "Could not prepare a resolution email for ticket %s.",
            ticket.ticket_number,
        )
        return False


def notify_reporter_status_update(
    db: Session,
    ticket: Ticket,
    update: str,
) -> bool:
    if not _ticket_email_notifications_enabled():
        logger.info(
            "Ticket email notifications are disabled; skipping status email "
            "for ticket %s.",
            ticket.ticket_number,
        )
        return False
    try:
        if _ticket_was_created_via_whatsapp(db, ticket):
            logger.info(
                "Email status notification for ticket %s was skipped: "
                "ticket was created via WhatsApp.",
                ticket.ticket_number,
            )
            return False
        reporter = db.get(User, ticket.reporter_id)
        if reporter is None:
            logger.warning(
                "Could not email the reporter for ticket %s: user not found.",
                ticket.ticket_number,
            )
            return False
        return _send_ticket_email(
            ticket,
            reporter.email,
            f"Update on ticket {ticket.ticket_number}",
            (
                f"Hello {reporter.full_name},\n\n"
                f"Your TriageDesk ticket {ticket.ticket_number} has been "
                f"updated.\n\nStatus: {ticket.status}\nUpdate: {update}\n"
            ),
        )
    except Exception:
        logger.exception(
            "Could not prepare a status email for ticket %s.",
            ticket.ticket_number,
        )
        return False

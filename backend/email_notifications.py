import logging

from sqlalchemy.orm import Session

from email_service import send_email
from models import Ticket, User

logger = logging.getLogger(__name__)


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
    try:
        reporter = db.get(User, ticket.reporter_id)
        if reporter is not None:
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
            logger.warning(
                "Could not email the reporter for ticket %s: user not found.",
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
    try:
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
    try:
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

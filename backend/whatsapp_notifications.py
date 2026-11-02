import logging
import os

from sqlalchemy.orm import Session
from twilio.rest import Client

from models import Ticket, WhatsAppContact

logger = logging.getLogger(__name__)


def send_reporter_whatsapp_update(
    db: Session,
    ticket: Ticket,
    message: str,
) -> bool:
    contact = (
        db.query(WhatsAppContact)
        .filter(WhatsAppContact.user_id == ticket.reporter_id)
        .first()
    )
    if contact is None:
        return False

    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    sender = os.getenv("TWILIO_WHATSAPP_FROM")
    if not account_sid or not auth_token or not sender:
        logger.warning(
            "WhatsApp update for %s was not sent: outbound Twilio "
            "credentials are not configured.",
            ticket.ticket_number,
        )
        return False

    sender = sender.strip()
    if not sender.startswith("whatsapp:"):
        sender = f"whatsapp:{sender}"
    recipient = f"whatsapp:{contact.phone_number}"

    try:
        Client(account_sid, auth_token).messages.create(
            body=message,
            from_=sender,
            to=recipient,
        )
    except Exception:
        logger.exception(
            "Could not send WhatsApp update for ticket %s.",
            ticket.ticket_number,
        )
        return False
    return True

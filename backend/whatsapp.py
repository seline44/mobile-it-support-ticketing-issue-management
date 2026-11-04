import hashlib
import hmac
import json
import logging
import os
import re
from datetime import datetime, timezone
from urllib.parse import parse_qsl
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import Response
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool
from twilio.request_validator import RequestValidator
from twilio.twiml.messaging_response import MessagingResponse

from database import get_db
from models import (
    Ticket,
    TicketNote,
    User,
    WhatsAppContact,
    WhatsAppConversation,
    WhatsAppMessage,
)
from meta_whatsapp import send_meta_whatsapp_message
from tickets import calculate_priority, record_history

load_dotenv()

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks/whatsapp", tags=["WhatsApp"])

GREETING_MESSAGES = {
    "hi",
    "hello",
    "hey",
    "start",
    "ticket",
    "new ticket",
    "help",
    "ok",
    "okay",
    "alright",
    "got it",
    "cool",
}
THANK_YOU_MESSAGES = {
    "thanks",
    "thank you",
    "thank you so much",
    "much appreciated",
    "appreciate it",
    "cheers",
}
DISSATISFACTION_PHRASES = (
    "not working",
    "doesn't work",
    "does not work",
    "still not",
    "still doesn't",
    "still does not",
    "not fixed",
    "not solved",
    "not resolved",
    "issue remains",
    "problem persists",
    "not satisfied",
    "look at the issue again",
    "look at this again",
)
MAX_DESCRIPTION_LENGTH = 4000
MAX_NOTE_LENGTH = 5000
DEFAULT_IMPACT = "Medium"
DEFAULT_URGENCY = "Medium"
CATEGORY_KEYWORDS = {
    "Network": (
        "wi-fi",
        "wifi",
        "internet",
        "network",
        "router",
        "connection",
    ),
    "Hardware": (
        "laptop",
        "computer",
        "keyboard",
        "mouse",
        "monitor",
        "screen",
        "battery",
    ),
    "Software": ("software", "application", "app", "program", "crash", "bug"),
    "Email": ("email", "e-mail", "outlook", "mailbox", "inbox"),
    "Account Access": (
        "password",
        "login",
        "log in",
        "sign in",
        "account",
        "locked out",
    ),
    "Printer": ("printer", "printing", "print", "toner", "paper jam"),
}


def _is_greeting(message: str) -> bool:
    normalized = message.casefold().strip(" \t\r\n!?.")
    if normalized in GREETING_MESSAGES:
        return True
    return bool(
        re.fullmatch(
            r"(?:hi|hello|hey|good morning|good afternoon|good evening)"
            r"[, ]+(?:i need help|can you help(?: me)?|please help|help me)"
            r"(?:\s+with\s+(?:an?\s+)?(?:it\s+)?(?:issue|problem))?",
            normalized,
        )
    )


def _is_thank_you(message: str) -> bool:
    normalized = message.casefold().strip(" \t\r\n!?.")
    return normalized in THANK_YOU_MESSAGES or normalized.startswith(
        ("thanks ", "thank you ", "thank you,")
    )


def _is_dissatisfied(message: str) -> bool:
    normalized = message.casefold()
    return any(phrase in normalized for phrase in DISSATISFACTION_PHRASES)


def _infer_category(description: str) -> str:
    normalized = description.casefold()
    scores = {
        category: sum(
            re.search(rf"\b{re.escape(keyword)}\b", normalized) is not None
            for keyword in keywords
        )
        for category, keywords in CATEGORY_KEYWORDS.items()
    }
    best_category = max(scores, key=scores.get)
    if scores[best_category] == 0:
        return "Other"
    return best_category


def _has_issue_description(message: str) -> bool:
    words = re.findall(r"[a-z0-9]+", message.casefold())
    return len(message.strip()) >= 8 and len(words) >= 2


def _new_ticket_description(message: str) -> str | None:
    match = re.match(
        r"^(?:new ticket|create ticket|start a new ticket|"
        r"report another issue)\b\s*[:,-]?\s*(.*)$",
        message,
        flags=re.IGNORECASE,
    )
    return match.group(1).strip() if match else None


def verify_webhook_signature(
    url: str, params: dict[str, str], signature: str | None
) -> bool:
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    if not auth_token or not signature:
        return False

    return RequestValidator(auth_token).validate(url, params, signature)


def verify_meta_webhook_signature(body: bytes, signature: str | None) -> bool:
    app_secret = os.getenv("META_APP_SECRET")
    if not app_secret or not signature or not signature.startswith("sha256="):
        return False
    expected = hmac.new(
        app_secret.encode("utf-8"), body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature.removeprefix("sha256="), expected)


def normalize_phone_number(phone_number: str) -> str:
    digits = re.sub(r"\D", "", phone_number)
    if not 8 <= len(digits) <= 15 or digits.startswith("0"):
        raise ValueError("WhatsApp sender must be a valid international phone number")
    return f"+{digits}"


def whatsapp_twiml_response(text: str) -> Response:
    twiml = MessagingResponse()
    twiml.message(text)
    return Response(content=str(twiml), media_type="application/xml")


async def receive_meta_webhook(request: Request, db: Session):
    raw_body = await request.body()
    if not verify_meta_webhook_signature(
        raw_body, request.headers.get("X-Hub-Signature-256")
    ):
        raise HTTPException(status_code=401, detail="Invalid Meta webhook signature.")
    try:
        payload = json.loads(raw_body)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise HTTPException(
            status_code=400, detail="Webhook body must be valid JSON."
        ) from error
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="Invalid Meta webhook payload.")

    for entry in payload.get("entry", []):
        for change in entry.get("changes", []):
            value = change.get("value", {})
            phone_number_id = value.get("metadata", {}).get("phone_number_id")
            for message in value.get("messages", []):
                message_id = message.get("id")
                sender_number = message.get("from")
                if not message_id or not sender_number or not phone_number_id:
                    raise HTTPException(
                        status_code=400,
                        detail="Meta message is missing required identifiers.",
                    )

                message_type = message.get("type", "")
                body = (
                    message.get("text", {}).get("body", "")
                    if message_type == "text"
                    else ""
                )
                try:
                    response_text = await run_in_threadpool(
                        process_incoming_message,
                        db,
                        message_id,
                        sender_number,
                        message_type,
                        body,
                    )
                    await run_in_threadpool(
                        send_meta_whatsapp_message,
                        phone_number_id,
                        sender_number,
                        response_text,
                    )
                except IntegrityError:
                    db.rollback()
                    duplicate = db.get(WhatsAppMessage, message_id)
                    if duplicate is None:
                        raise
                    try:
                        await run_in_threadpool(
                            send_meta_whatsapp_message,
                            phone_number_id,
                            sender_number,
                            duplicate.response_text,
                        )
                    except RuntimeError as error:
                        logger.exception(
                            "Meta WhatsApp message reply delivery failed."
                        )
                        raise HTTPException(
                            status_code=502,
                            detail="Meta WhatsApp message reply failed.",
                        ) from error
                except RuntimeError as error:
                    logger.exception("Meta WhatsApp message processing failed.")
                    raise HTTPException(
                        status_code=502,
                        detail="Meta WhatsApp message processing failed.",
                    ) from error
                except ValueError as error:
                    raise HTTPException(
                        status_code=400,
                        detail="WhatsApp sender number is invalid.",
                    ) from error
    return {"status": "received"}


def _create_ticket(
    db: Session,
    user: User,
    conversation: WhatsAppConversation,
    category: str,
    impact: str,
    urgency: str,
) -> Ticket:
    description = conversation.description.strip()
    title = (conversation.title or description.splitlines()[0]).strip()[:200]
    ticket = Ticket(
        ticket_number=f"TD-{uuid4().hex[:8].upper()}",
        title=title,
        description=description,
        category=category,
        impact=impact,
        urgency=urgency,
        priority=calculate_priority(impact, urgency),
        device=(conversation.device or "").strip()[:150],
        location="",
        status="Open",
        reporter_id=user.id,
    )
    db.add(ticket)
    db.flush()
    record_history(
        db,
        ticket,
        user.id,
        "Ticket created via WhatsApp",
        new_status="Open",
    )
    return ticket


def _create_quick_ticket(db: Session, user: User, description: str) -> Ticket:
    conversation = WhatsAppConversation(
        phone_number="",
        step="description",
        description=description,
    )
    return _create_ticket(
        db,
        user,
        conversation,
        _infer_category(description),
        DEFAULT_IMPACT,
        DEFAULT_URGENCY,
    )


def _ticket_created_response(ticket: Ticket) -> str:
    return (
        "🎉 *Thanks—I’ve logged your issue.*\n\n"
        f"🎫 *Ticket:* {ticket.ticket_number}\n"
        f"🗂️ *Category:* {ticket.category}\n"
        f"📊 *Priority:* {ticket.priority}\n"
        "📌 *Status:* Open\n\n"
        "A technician can now review it. You can send another message here "
        "to add details."
    )


def _complete_pending_ticket(
    db: Session,
    user: User,
    conversation: WhatsAppConversation,
) -> str:
    description = conversation.description.strip()
    if not _has_issue_description(description):
        return "What’s happening? A short description is enough and I’ll log it."
    ticket = _create_quick_ticket(db, user, description)
    db.delete(conversation)
    return _ticket_created_response(ticket)


def process_incoming_message(
    db: Session,
    message_id: str,
    sender_number: str,
    message_type: str,
    body: str,
) -> str:
    existing_message = db.get(WhatsAppMessage, message_id)
    if existing_message is not None:
        return existing_message.response_text

    phone_number = normalize_phone_number(sender_number)
    response_text: str
    contact = db.get(WhatsAppContact, phone_number)

    if message_type != "text":
        response_text = (
            "📎 I can help with text requests for now.\n"
            "Please send a short message describing your IT issue."
        )
    else:
        if contact is None:
            guest_email = f"guest_{phone_number.lstrip('+')}@triagedesk.guest"
            user = db.query(User).filter(User.email == guest_email).first()
            if user is None:
                user = User(
                    full_name=f"WhatsApp Guest ({phone_number})",
                    email=guest_email,
                    password_hash="guest_no_password",
                    role="Reporter",
                    approval_status="Approved",
                    is_active=True,
                )
                db.add(user)
                db.flush()

            contact = WhatsAppContact(
                phone_number=phone_number,
                user_id=user.id,
                linked_by_user_id=user.id,
            )
            db.add(contact)
            db.flush()
        else:
            user = db.get(User, contact.user_id)

        if (
            user is None
            or not user.is_active
            or user.role != "Reporter"
            or user.approval_status != "Approved"
        ):
            response_text = (
                "⚠️ I couldn’t access your TriageDesk Reporter account right now.\n"
                "Please contact your administrator for help."
            )
        else:
            message_text = body.strip()
            normalized_text = message_text.casefold()
            conversation = db.get(WhatsAppConversation, phone_number)

            if normalized_text == "cancel":
                if conversation is not None:
                    db.delete(conversation)
                if (
                    conversation is not None
                    and conversation.step == "reopen_confirmation"
                ):
                    response_text = (
                        "Okay—I’ll leave your existing ticket as it is. "
                        "Message me anytime if you need more help."
                    )
                else:
                    response_text = (
                        "🛑 *Request cancelled.* No ticket was created.\n"
                        "Whenever you need support, just send me a new message."
                    )
            elif conversation is not None and conversation.step == "reopen_confirmation":
                ticket = db.get(Ticket, conversation.ticket_id)
                if normalized_text in {"yes", "y", "reopen", "confirm"}:
                    if (
                        ticket is None
                        or ticket.reporter_id != user.id
                        or ticket.status not in {"Resolved", "Closed"}
                    ):
                        db.delete(conversation)
                        response_text = (
                            "That ticket has already changed, so I couldn’t "
                            "reopen it. Send *NEW TICKET* if this is a "
                            "different issue."
                        )
                    else:
                        reason = conversation.description.strip()
                        old_status = ticket.status
                        ticket.status = "Open"
                        ticket.resolved_at = None
                        ticket.assigned_technician_id = None
                        ticket.updated_at = datetime.now(timezone.utc)
                        db.add(
                            TicketNote(
                                ticket_id=ticket.id,
                                author_id=user.id,
                                note=reason,
                                is_internal=False,
                            )
                        )
                        record_history(
                            db,
                            ticket,
                            user.id,
                            "Ticket reopened",
                            old_status=old_status,
                            new_status="Open",
                            details="Reporter reopened the ticket via WhatsApp.",
                        )
                        db.delete(conversation)
                        response_text = (
                            f"🔄 *Ticket {ticket.ticket_number} is open again.*\n"
                            "I’ve shared your message with the support team. "
                            "A technician will review it."
                        )
                elif normalized_text in {"no", "n", "don't", "do not"}:
                    db.delete(conversation)
                    response_text = (
                        "No problem—I haven’t reopened the ticket. If you still "
                        "need help, send *NEW TICKET* to start another request."
                    )
                else:
                    response_text = (
                        f"Would you like me to reopen ticket "
                        f"*{ticket.ticket_number if ticket else ''}*? "
                        "Reply *YES* to reopen it or *NO* to leave it closed."
                    )
            elif conversation is not None and _is_thank_you(message_text):
                if conversation.step in {"category", "device", "impact", "urgency"}:
                    response_text = (
                        "You’re welcome! 😊 "
                        + _complete_pending_ticket(db, user, conversation)
                    )
                else:
                    response_text = "You’re welcome! 😊 Take your time."
            elif conversation is not None and _is_greeting(message_text):
                if conversation.step in {"category", "device", "impact", "urgency"}:
                    response_text = _complete_pending_ticket(
                        db, user, conversation
                    )
                else:
                    response_text = (
                        "👋 Hi! Just tell me briefly what’s happening and "
                        "I’ll log it."
                    )
            elif conversation is not None and conversation.step in {
                "category",
                "device",
                "impact",
                "urgency",
            }:
                response_text = _complete_pending_ticket(
                    db, user, conversation
                )
            elif conversation is None:
                active_ticket = (
                    db.query(Ticket)
                    .filter(
                        Ticket.reporter_id == user.id,
                        Ticket.status.in_(("Open", "In Progress", "Pending")),
                    )
                    .order_by(Ticket.updated_at.desc(), Ticket.id.desc())
                    .first()
                )
                if _is_thank_you(message_text):
                    if active_ticket is not None:
                        db.add(
                            TicketNote(
                                ticket_id=active_ticket.id,
                                author_id=user.id,
                                note=message_text,
                                is_internal=False,
                            )
                        )
                        record_history(
                            db,
                            active_ticket,
                            user.id,
                            "Reporter WhatsApp follow-up",
                            details="Reporter sent a WhatsApp follow-up.",
                        )
                        active_ticket.updated_at = datetime.now(timezone.utc)
                        response_text = "You’re very welcome! 😊"
                    else:
                        response_text = (
                            "You’re very welcome! 😊 Message me anytime you "
                            "need help with IT support."
                        )
                elif (new_description := _new_ticket_description(message_text)) is not None:
                    if new_description and _has_issue_description(new_description):
                        if len(new_description) > MAX_DESCRIPTION_LENGTH:
                            response_text = (
                                "Please keep your issue description to 4,000 "
                                "characters or fewer."
                            )
                        else:
                            ticket = _create_quick_ticket(
                                db, user, new_description
                            )
                            response_text = _ticket_created_response(ticket)
                    else:
                        conversation = WhatsAppConversation(
                            phone_number=phone_number,
                            step="description",
                            description="",
                        )
                        db.add(conversation)
                        response_text = (
                            "Sure—what’s happening? Just send a short "
                            "description of the issue and I’ll log it."
                        )
                elif _is_greeting(message_text) or len(message_text) < 3:
                    if active_ticket is not None:
                        response_text = (
                            f"👋 Hi! Your latest ticket, "
                            f"*{active_ticket.ticket_number}*, is "
                            f"*{active_ticket.status.casefold()}*.\n"
                            "Send me an update for the support team, or say "
                            "*NEW TICKET* to report a different issue."
                        )
                    else:
                        response_text = (
                            "👋 *Hi! I’m TriageDesk Support.*\n"
                            "Let’s create a support ticket together. First, "
                            "describe the IT issue you’re experiencing. Include "
                            "any error message and what you’ve already tried.\n\n"
                            "You can send *CANCEL* anytime to stop."
                        )
                elif active_ticket is not None:
                    if len(message_text) > MAX_NOTE_LENGTH:
                        response_text = (
                            "Please keep your ticket update to 5,000 "
                            "characters or fewer."
                        )
                    else:
                        db.add(
                            TicketNote(
                                ticket_id=active_ticket.id,
                                author_id=user.id,
                                note=message_text,
                                is_internal=False,
                            )
                        )
                        record_history(
                            db,
                            active_ticket,
                            user.id,
                            "Reporter WhatsApp follow-up",
                            details="Reporter sent a WhatsApp follow-up.",
                        )
                        active_ticket.updated_at = datetime.now(timezone.utc)
                        response_text = (
                            f"💬 Thanks—I’ve added your message to ticket "
                            f"*{active_ticket.ticket_number}*. The support team can "
                            "see it and follow up with you here."
                        )
                else:
                    resolved_ticket = (
                        db.query(Ticket)
                        .filter(
                            Ticket.reporter_id == user.id,
                            Ticket.status.in_(("Resolved", "Closed")),
                        )
                        .order_by(Ticket.updated_at.desc(), Ticket.id.desc())
                        .first()
                    )
                    if (
                        resolved_ticket is not None
                        and _is_dissatisfied(message_text)
                    ):
                        if len(message_text) > MAX_NOTE_LENGTH:
                            response_text = (
                                "Please keep your ticket update to 5,000 "
                                "characters or fewer."
                            )
                        else:
                            conversation = WhatsAppConversation(
                                phone_number=phone_number,
                                step="reopen_confirmation",
                                description=message_text,
                                ticket_id=resolved_ticket.id,
                            )
                            db.add(conversation)
                            response_text = (
                                f"Sorry the issue is still causing trouble. Would "
                                f"you like me to reopen *ticket "
                                f"{resolved_ticket.ticket_number}* and send this "
                                "message to the support team? Reply *YES* or *NO*."
                            )
                    elif len(message_text) > MAX_DESCRIPTION_LENGTH:
                        response_text = (
                            "Please keep your issue description to 4,000 "
                            "characters or fewer."
                        )
                    elif not _has_issue_description(message_text):
                        response_text = (
                            "I’m happy to help. What’s happening? A short "
                            "description is enough and I’ll create a ticket."
                        )
                    else:
                        ticket = _create_quick_ticket(
                            db, user, message_text
                        )
                        response_text = _ticket_created_response(ticket)
            elif conversation.step == "description":
                if not _has_issue_description(message_text):
                    response_text = (
                        "What’s happening? A short description is enough and "
                        "I’ll log it."
                    )
                elif len(message_text) > MAX_DESCRIPTION_LENGTH:
                    response_text = (
                        "Please keep your issue description to 4,000 characters "
                        "or fewer."
                    )
                else:
                    ticket = _create_quick_ticket(db, user, message_text)
                    db.delete(conversation)
                    response_text = _ticket_created_response(ticket)
            else:
                db.delete(conversation)
                response_text = (
                    "🔄 I’ve reset the previous request because its step was "
                    "out of sync.\n"
                    "Describe your IT issue to start a fresh ticket."
                )

    db.add(
        WhatsAppMessage(
            provider_message_id=message_id,
            phone_number=phone_number,
            response_text=response_text,
        )
    )
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return response_text


@router.get("")
def verify_meta_webhook(request: Request):
    verify_token = os.getenv("META_VERIFY_TOKEN")
    if not verify_token:
        raise HTTPException(
            status_code=503, detail="META_VERIFY_TOKEN is not configured."
        )
    query = request.query_params
    if (
        query.get("hub.mode") != "subscribe"
        or not hmac.compare_digest(query.get("hub.verify_token", ""), verify_token)
        or "hub.challenge" not in query
    ):
        raise HTTPException(status_code=403, detail="Meta webhook verification failed.")
    return Response(content=query["hub.challenge"], media_type="text/plain")


@router.post("")
async def receive_webhook(
    request: Request,
    db: Session = Depends(get_db),
):
    if request.headers.get("content-type", "").split(";", 1)[0].strip().lower() == (
        "application/json"
    ):
        return await receive_meta_webhook(request, db)

    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    if not auth_token:
        raise HTTPException(
            status_code=503,
            detail="TWILIO_AUTH_TOKEN is not configured.",
        )

    raw_body = await request.body()
    try:
        form_data = parse_qsl(raw_body.decode("utf-8"), keep_blank_values=True)
    except UnicodeDecodeError as error:
        raise HTTPException(
            status_code=400, detail="Webhook body must be URL-encoded form data."
        ) from error
    params = dict(form_data)
    signature = request.headers.get("X-Twilio-Signature")
    if not verify_webhook_signature(str(request.url), params, signature):
        raise HTTPException(
            status_code=401, detail="Invalid webhook signature."
        )

    message_id = params.get("MessageSid")
    sender_number = params.get("From")
    if not message_id or not sender_number:
        raise HTTPException(
            status_code=400,
            detail="Webhook must include MessageSid and From.",
        )

    media_count = params.get("NumMedia", "0") or "0"
    if not media_count.isdigit():
        raise HTTPException(
            status_code=400,
            detail="Webhook NumMedia must be a non-negative integer.",
        )
    message_type = "media" if int(media_count) > 0 else "text"
    body = params.get("Body", "")
    try:
        response_text = await run_in_threadpool(
            process_incoming_message,
            db,
            message_id,
            sender_number,
            message_type,
            body,
        )
    except IntegrityError:
        db.rollback()
        duplicate = db.get(WhatsAppMessage, message_id)
        if duplicate is None:
            raise
        response_text = duplicate.response_text
    except RuntimeError as error:
        logger.exception("WhatsApp webhook conversation processing failed.")
        raise HTTPException(
            status_code=502,
            detail="WhatsApp message processing failed.",
        ) from error
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail="WhatsApp sender number is invalid.",
        ) from error

    return whatsapp_twiml_response(response_text)

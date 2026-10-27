import logging
import os
import re
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
    User,
    WhatsAppContact,
    WhatsAppConversation,
    WhatsAppMessage,
)
from tickets import calculate_priority, record_history

load_dotenv()

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks/whatsapp", tags=["WhatsApp"])

CATEGORIES = (
    "Network",
    "Hardware",
    "Software",
    "Email",
    "Account Access",
    "Printer",
    "Other",
)
LEVELS = ("Low", "Medium", "High")
GREETING_MESSAGES = {"hi", "hello", "hey", "start", "ticket", "new ticket", "help"}
MAX_DESCRIPTION_LENGTH = 4000


def verify_webhook_signature(
    url: str, params: dict[str, str], signature: str | None
) -> bool:
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    if not auth_token or not signature:
        return False

    return RequestValidator(auth_token).validate(url, params, signature)


def normalize_phone_number(phone_number: str) -> str:
    digits = re.sub(r"\D", "", phone_number)
    if not 8 <= len(digits) <= 15 or digits.startswith("0"):
        raise ValueError("WhatsApp sender must be a valid international phone number")
    return f"+{digits}"


def whatsapp_twiml_response(text: str) -> Response:
    twiml = MessagingResponse()
    twiml.message(text)
    return Response(content=str(twiml), media_type="application/xml")


def _create_ticket(
    db: Session,
    user: User,
    conversation: WhatsAppConversation,
    category: str,
    impact: str,
    urgency: str,
) -> Ticket:
    description = conversation.description.strip()
    title = description.splitlines()[0].strip()[:200]
    ticket = Ticket(
        ticket_number=f"TD-{uuid4().hex[:8].upper()}",
        title=title,
        description=description,
        category=category,
        impact=impact,
        urgency=urgency,
        priority=calculate_priority(impact, urgency),
        device="",
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
        response_text = "Please send your IT support request as a text message."
    elif contact is None:
        response_text = (
            "This WhatsApp number is not linked to a TriageDesk Reporter account. "
            "Please ask your TriageDesk administrator to link it."
        )
    else:
        user = db.get(User, contact.user_id)
        if (
            user is None
            or not user.is_active
            or user.role != "Reporter"
            or user.approval_status != "Approved"
        ):
            response_text = (
                "Your linked TriageDesk Reporter account is not currently active. "
                "Please contact your administrator."
            )
        else:
            message_text = body.strip()
            normalized_text = message_text.casefold()
            conversation = db.get(WhatsAppConversation, phone_number)

            if normalized_text == "cancel":
                if conversation is not None:
                    db.delete(conversation)
                response_text = (
                    "Your WhatsApp ticket request was cancelled. "
                    "Send a new message whenever you need help."
                )
            elif conversation is None:
                if len(message_text) < 3 or normalized_text in GREETING_MESSAGES:
                    response_text = (
                        "Describe the IT issue you're experiencing in your next message "
                        "to start a ticket. Send CANCEL to stop at any time."
                    )
                elif len(message_text) > MAX_DESCRIPTION_LENGTH:
                    response_text = (
                        "Please describe the issue in 4,000 characters or fewer."
                    )
                else:
                    conversation = WhatsAppConversation(
                        phone_number=phone_number,
                        step="category",
                        description=message_text,
                    )
                    db.add(conversation)
                    response_text = (
                        "What category best describes the issue?\n"
                        + "\n".join(
                            f"{index}. {category}"
                            for index, category in enumerate(CATEGORIES, start=1)
                        )
                        + "\nReply with the category name or number."
                    )
            elif conversation.step == "category":
                category = next(
                    (
                        item
                        for index, item in enumerate(CATEGORIES, start=1)
                        if normalized_text in {item.casefold(), str(index)}
                    ),
                    None,
                )
                if category is None:
                    response_text = (
                        "Please reply with one of these categories: "
                        + ", ".join(CATEGORIES)
                        + "."
                    )
                else:
                    conversation.category = category
                    conversation.step = "impact"
                    response_text = (
                        "How much does the issue affect your work? "
                        "Reply Low, Medium, or High."
                    )
            elif conversation.step == "impact":
                impact = next(
                    (
                        item
                        for index, item in enumerate(LEVELS, start=1)
                        if normalized_text in {item.casefold(), str(index)}
                    ),
                    None,
                )
                if impact is None:
                    response_text = "Reply Low, Medium, or High for impact."
                else:
                    conversation.impact = impact
                    conversation.step = "urgency"
                    response_text = (
                        "How urgent is it? Reply Low, Medium, or High."
                    )
            elif conversation.step == "urgency":
                urgency = next(
                    (
                        item
                        for index, item in enumerate(LEVELS, start=1)
                        if normalized_text in {item.casefold(), str(index)}
                    ),
                    None,
                )
                if urgency is None:
                    response_text = "Reply Low, Medium, or High for urgency."
                elif conversation.category is None or conversation.impact is None:
                    db.delete(conversation)
                    response_text = (
                        "Your ticket details were incomplete, so no ticket was created. "
                        "Describe the issue again to start a new request."
                    )
                else:
                    conversation.urgency = urgency
                    ticket = _create_ticket(
                        db,
                        user,
                        conversation,
                        conversation.category,
                        conversation.impact,
                        urgency,
                    )
                    db.delete(conversation)
                    response_text = (
                        f"Ticket {ticket.ticket_number} was created successfully. "
                        f"Priority: {ticket.priority}. Status: Open."
                    )
            else:
                db.delete(conversation)
                response_text = (
                    "Your previous ticket conversation was reset. "
                    "Describe the IT issue to start again."
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


@router.post("")
async def receive_webhook(
    request: Request,
    db: Session = Depends(get_db),
):
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

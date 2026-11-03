import hashlib
import hmac
import json
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
from meta_whatsapp import send_meta_whatsapp_message
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
    "thanks",
    "thank you",
    "thank you!",
    "cool",
}
MAX_DESCRIPTION_LENGTH = 4000


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
                response_text = (
                    "🛑 *Request cancelled.* No ticket was created.\n"
                    "Whenever you need support, just send me a new message."
                )
            elif conversation is None:
                if len(message_text) < 3 or normalized_text in GREETING_MESSAGES:
                    response_text = (
                        "👋 *Hi! I’m TriageDesk Support.*\n"
                        "Let’s create a support ticket together. First, send a "
                        "short title for the IT issue (up to 200 characters).\n\n"
                        "You can send *CANCEL* anytime to stop."
                    )
                elif len(message_text) > 200:
                    response_text = (
                        "Please shorten the ticket title to 200 characters or "
                        "fewer. You can share the full details in the next step."
                    )
                else:
                    conversation = WhatsAppConversation(
                        phone_number=phone_number,
                        step="description",
                        title=message_text,
                        description="",
                    )
                    db.add(conversation)
                    response_text = (
                        f"📝 *Title:* {message_text}\n\n"
                        "Now describe the issue in more detail. Include any "
                        "error message and what you’ve already tried."
                    )
            elif conversation.step == "description":
                if len(message_text) < 3:
                    response_text = (
                        "Please add a little more detail so the support team "
                        "can understand the issue."
                    )
                elif len(message_text) > MAX_DESCRIPTION_LENGTH:
                    response_text = (
                        "Please keep the issue description to 4,000 characters "
                        "or fewer."
                    )
                else:
                    conversation.description = message_text
                    conversation.step = "device"
                    response_text = (
                        "✅ *Description saved.*\n"
                        "What device is affected? For example, laptop, phone, "
                        "or printer.\n"
                        "Reply *Skip* if there isn’t a specific device."
                    )
            elif conversation.step == "device":
                if normalized_text not in {"skip", "none", "n/a", "na"} and (
                    len(message_text) > 150
                ):
                    response_text = (
                        "Please keep the device name to 150 characters or fewer, "
                        "or reply *Skip*."
                    )
                else:
                    conversation.device = (
                        "" if normalized_text in {"skip", "none", "n/a", "na"}
                        else message_text
                    )
                    conversation.step = "category"
                    response_text = (
                        "What category fits your issue best?\n\n"
                        + "\n".join(
                            f"{index}. {category}"
                            for index, category in enumerate(CATEGORIES, start=1)
                        )
                        + "\n\nReply with a category name or number."
                    )
            elif conversation.step == "category":
                category = next(
                    (
                        item
                        for index, item in enumerate(CATEGORIES, start=1)
                        if normalized_text in {item.casefold(), str(index)}
                        or (
                            item == "Account Access"
                            and normalized_text == "account"
                        )
                    ),
                    None,
                )
                if category is None:
                    response_text = (
                        "I didn’t catch that category. Choose one of these:\n"
                        + "\n".join(
                            f"• {item}" for item in CATEGORIES
                        )
                        + "\n\nYou can reply with the name or its number."
                    )
                else:
                    conversation.category = category
                    conversation.step = "impact"
                    response_text = (
                        f"✅ *{category}* — got it.\n"
                        "How much is this affecting your work?\n"
                        "Reply *Low*, *Medium*, or *High*."
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
                    response_text = (
                        "Please choose how much work is affected:\n"
                        "🟢 *Low* · 🟡 *Medium* · 🔴 *High*"
                    )
                else:
                    conversation.impact = impact
                    conversation.step = "urgency"
                    response_text = (
                        f"👍 Impact: *{impact}*.\n"
                        "How soon do you need this resolved?\n"
                        "Reply *Low*, *Medium*, or *High*."
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
                    response_text = (
                        "Please choose how soon this needs attention:\n"
                        "🟢 *Low* · 🟡 *Medium* · 🔴 *High*"
                    )
                elif conversation.category is None or conversation.impact is None:
                    db.delete(conversation)
                    response_text = (
                        "⚠️ Some request details were missing, so I couldn’t "
                        "create the ticket.\n"
                        "Please describe the issue again to start over."
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
                        "🎉 *Your support ticket is in!*\n\n"
                        f"🎫 *Ticket:* {ticket.ticket_number}\n"
                        f"🗂️ *Category:* {ticket.category}\n"
                        f"📊 *Priority:* {ticket.priority}\n"
                        "📌 *Status:* Open\n\n"
                        "Thanks for the details. Our support team will take it "
                        "from here."
                    )
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

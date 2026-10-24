import hashlib
import hmac
import json
import os
import re
import urllib.error
import urllib.request
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.responses import PlainTextResponse
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

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


def verify_webhook_signature(body: bytes, signature: str | None) -> bool:
    app_secret = os.getenv("WHATSAPP_APP_SECRET")
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


def send_whatsapp_text(phone_number: str, text: str) -> None:
    access_token = os.getenv("WHATSAPP_ACCESS_TOKEN")
    phone_number_id = os.getenv("WHATSAPP_PHONE_NUMBER_ID")
    api_version = os.getenv("WHATSAPP_GRAPH_API_VERSION", "v23.0")
    if not access_token or not phone_number_id:
        raise RuntimeError(
            "WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID must be configured."
        )
    if not re.fullmatch(r"v\d+\.\d+", api_version):
        raise RuntimeError("WHATSAPP_GRAPH_API_VERSION must look like v23.0.")

    payload = json.dumps(
        {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": phone_number.lstrip("+"),
            "type": "text",
            "text": {"preview_url": False, "body": text},
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        f"https://graph.facebook.com/{api_version}/{phone_number_id}/messages",
        data=payload,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            if response.status < 200 or response.status >= 300:
                raise RuntimeError(
                    f"WhatsApp Cloud API returned HTTP {response.status}."
                )
    except urllib.error.HTTPError as error:
        raise RuntimeError(
            f"WhatsApp Cloud API returned HTTP {error.code}."
        ) from error
    except urllib.error.URLError as error:
        raise RuntimeError("Could not reach the WhatsApp Cloud API.") from error


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


@router.get("", response_class=PlainTextResponse)
def verify_webhook(
    mode: str | None = Query(default=None, alias="hub.mode"),
    verify_token: str | None = Query(default=None, alias="hub.verify_token"),
    challenge: str | None = Query(default=None, alias="hub.challenge"),
):
    expected_token = os.getenv("WHATSAPP_VERIFY_TOKEN")
    if not expected_token:
        raise HTTPException(
            status_code=503,
            detail="WHATSAPP_VERIFY_TOKEN is not configured.",
        )
    if mode != "subscribe" or not hmac.compare_digest(
        verify_token or "", expected_token
    ):
        raise HTTPException(status_code=403, detail="Webhook verification failed.")
    return challenge or ""


@router.post("")
async def receive_webhook(
    request: Request,
    x_hub_signature_256: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    raw_body = await request.body()
    if not os.getenv("WHATSAPP_APP_SECRET"):
        raise HTTPException(
            status_code=503,
            detail="WHATSAPP_APP_SECRET is not configured.",
        )
    if not verify_webhook_signature(raw_body, x_hub_signature_256):
        raise HTTPException(status_code=401, detail="Invalid webhook signature.")

    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=400, detail="Webhook body must contain valid JSON."
        ) from error

    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=400, detail="Webhook body must be a JSON object."
        )

    messages = []
    entries = payload.get("entry", [])
    if not isinstance(entries, list):
        raise HTTPException(
            status_code=400, detail="Webhook entry must be a JSON array."
        )
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        changes = entry.get("changes", [])
        if not isinstance(changes, list):
            continue
        for change in changes:
            if not isinstance(change, dict):
                continue
            value = change.get("value", {})
            if not isinstance(value, dict):
                continue
            incoming_messages = value.get("messages", [])
            if isinstance(incoming_messages, list):
                messages.extend(incoming_messages)

    for message in messages:
        if not isinstance(message, dict):
            continue
        message_id = message.get("id")
        sender_number = message.get("from")
        if not isinstance(message_id, str) or not isinstance(sender_number, str):
            continue

        message_type = message.get("type", "")
        text = message.get("text", {})
        body = text.get("body", "") if isinstance(text, dict) else ""
        try:
            response_text = await run_in_threadpool(
                process_incoming_message,
                db,
                message_id,
                sender_number,
                message_type,
                body if isinstance(body, str) else "",
            )
            await run_in_threadpool(
                send_whatsapp_text, sender_number, response_text
            )
        except IntegrityError:
            db.rollback()
            duplicate = db.get(WhatsAppMessage, message_id)
            if duplicate is None:
                raise
            await run_in_threadpool(
                send_whatsapp_text,
                sender_number,
                duplicate.response_text,
            )
        except RuntimeError as error:
            raise HTTPException(
                status_code=502,
                detail="WhatsApp message processing or reply delivery failed.",
            ) from error
        except ValueError as error:
            raise HTTPException(
                status_code=400,
                detail="WhatsApp sender number is invalid.",
            ) from error

    return {"status": "ok"}

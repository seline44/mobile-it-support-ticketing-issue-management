import asyncio
import hashlib
import hmac
import io
import json
import os
import unittest
from urllib.parse import urlencode
from urllib.error import HTTPError
from unittest.mock import patch

from fastapi import HTTPException, Request
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from twilio.request_validator import RequestValidator

from models import (
    Base,
    Ticket,
    TicketHistory,
    TicketNote,
    User,
    WhatsAppContact,
    WhatsAppConversation,
    WhatsAppMessage,
)
from meta_whatsapp import send_meta_whatsapp_message
from whatsapp import (
    process_incoming_message,
    receive_meta_webhook,
    receive_webhook,
    verify_meta_webhook,
    verify_webhook_signature,
    verify_meta_webhook_signature,
    whatsapp_twiml_response,
)
from whatsapp_notifications import send_reporter_whatsapp_update


class WhatsAppIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.reporter = User(
            full_name="WhatsApp Reporter",
            email="whatsapp-reporter@example.test",
            password_hash="unused",
            role="Reporter",
            is_active=True,
            approval_status="Approved",
        )
        self.admin = User(
            full_name="WhatsApp Admin",
            email="whatsapp-admin@example.test",
            password_hash="unused",
            role="Administrator",
            is_active=True,
            approval_status="Approved",
        )
        self.db.add_all([self.reporter, self.admin])
        self.db.flush()
        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def send(self, message_id: str, body: str) -> str:
        return process_incoming_message(
            self.db,
            message_id,
            "15551234567",
            "text",
            body,
        )

    def test_ticket_is_created_from_guided_conversation(self):
        self.assertIn(
            "category",
            self.send(
                "wamid.1",
                "I cannot connect to the lab Wi-Fi. I tried restarting "
                "the laptop, but the issue continues.",
            ).casefold(),
        )
        self.assertIn("device", self.send("wamid.2", "Network").casefold())
        self.assertIn("affecting your work", self.send("wamid.3", "Laptop").casefold())
        self.assertIn("resolved", self.send("wamid.4", "High").casefold())
        response = self.send("wamid.5", "High")

        ticket = self.db.query(Ticket).one()
        self.assertIn(ticket.ticket_number, response)
        self.assertIn("Your support ticket is in", response)
        self.assertIn("Priority", response)
        self.assertEqual(
            ticket.title,
            "I cannot connect to the lab Wi-Fi. I tried restarting the laptop, "
            "but the issue continues.",
        )
        self.assertEqual(
            ticket.description,
            "I cannot connect to the lab Wi-Fi. I tried restarting "
            "the laptop, but the issue continues.",
        )
        self.assertEqual(ticket.reporter_id, self.reporter.id)
        self.assertEqual(ticket.category, "Network")
        self.assertEqual(ticket.impact, "High")
        self.assertEqual(ticket.urgency, "High")
        self.assertEqual(ticket.priority, "Critical")
        self.assertEqual(ticket.status, "Open")
        self.assertEqual(ticket.device, "Laptop")
        self.assertEqual(ticket.location, "")
        self.assertEqual(
            self.db.query(WhatsAppContact).filter_by(user_id=ticket.reporter_id)
            .one()
            .phone_number,
            "+15551234567",
        )
        self.assertEqual(
            self.db.query(TicketHistory).one().action,
            "Ticket created via WhatsApp",
        )

    def test_duplicate_webhook_message_does_not_create_duplicate_ticket(self):
        self.send("wamid.1", "The printer shows offline even after restart.")
        self.send("wamid.2", "Printer")
        self.send("wamid.3", "Skip")
        self.send("wamid.4", "Medium")
        first_response = self.send("wamid.5", "High")
        duplicate_response = self.send(
            "wamid.5", "This content must not be processed twice."
        )

        self.assertEqual(first_response, duplicate_response)
        self.assertEqual(self.db.query(WhatsAppMessage).count(), 5)
        self.assertEqual(self.db.query(Ticket).count(), 1)
        self.assertEqual(self.db.query(Ticket).one().device, "")

    def test_sends_whatsapp_update_to_linked_reporter(self):
        ticket = Ticket(
            ticket_number="TD-WA-UPDATE",
            title="Wi-Fi is unavailable",
            description="Cannot connect to Wi-Fi.",
            category="Network",
            impact="High",
            urgency="High",
            priority="Critical",
            status="In Progress",
            reporter_id=self.reporter.id,
            assigned_technician_id=2,
        )
        self.db.add(ticket)
        self.db.commit()

        with (
            patch.dict(
                os.environ,
                {
                    "TWILIO_ACCOUNT_SID": "AC123",
                    "TWILIO_AUTH_TOKEN": "test-auth-token",
                    "TWILIO_WHATSAPP_FROM": "whatsapp:+14155238886",
                },
            ),
            patch("whatsapp_notifications.Client") as twilio_client,
        ):
            sent = send_reporter_whatsapp_update(
                self.db,
                ticket,
                "The technician resolved TD-WA-UPDATE.",
            )

        self.assertTrue(sent)
        twilio_client.assert_called_once_with("AC123", "test-auth-token")
        twilio_client.return_value.messages.create.assert_called_once_with(
            body="The technician resolved TD-WA-UPDATE.",
            from_="whatsapp:+14155238886",
            to="whatsapp:+15551234567",
        )

    def test_sends_whatsapp_update_through_meta_when_configured(self):
        ticket = Ticket(
            ticket_number="TD-META-UPDATE",
            title="Wi-Fi is unavailable",
            description="Cannot connect to Wi-Fi.",
            category="Network",
            impact="High",
            urgency="High",
            priority="Critical",
            status="In Progress",
            reporter_id=self.reporter.id,
            assigned_technician_id=2,
        )
        self.db.add(ticket)
        self.db.commit()

        with (
            patch.dict(
                os.environ,
                {
                    "META_ACCESS_TOKEN": "test-meta-token",
                    "META_PHONE_NUMBER_ID": "123456",
                },
            ),
            patch("whatsapp_notifications.send_meta_whatsapp_message") as send_message,
        ):
            sent = send_reporter_whatsapp_update(
                self.db,
                ticket,
                "The technician resolved TD-META-UPDATE.",
            )

        self.assertTrue(sent)
        send_message.assert_called_once_with(
            "123456",
            "15551234567",
            "The technician resolved TD-META-UPDATE.",
        )

    def test_acknowledgement_after_ticket_does_not_start_another_conversation(self):
        self.send("wamid.1", "I cannot access the campus Wi-Fi.")
        self.send("wamid.2", "Network")
        self.send("wamid.3", "Laptop")
        self.send("wamid.4", "High")
        self.send("wamid.5", "High")

        response = self.send("wamid.6", "Okay")

        self.assertIn("ticket", response.casefold())
        self.assertEqual(self.db.query(Ticket).count(), 1)
        self.assertEqual(self.db.query(WhatsAppConversation).count(), 0)
        self.assertEqual(self.db.query(TicketNote).count(), 0)

    def test_thank_you_after_ticket_is_added_to_ticket_updates(self):
        self.send("wamid.thank.ticket.1", "I cannot access the campus Wi-Fi.")
        self.send("wamid.thank.ticket.2", "Network")
        self.send("wamid.thank.ticket.3", "Laptop")
        self.send("wamid.thank.ticket.4", "High")
        self.send("wamid.thank.ticket.5", "High")
        ticket = self.db.query(Ticket).one()

        response = self.send("wamid.thank.ticket.6", "Thank you!")

        update = self.db.query(TicketNote).one()
        self.assertEqual(update.ticket_id, ticket.id)
        self.assertEqual(update.note, "Thank you!")
        self.assertFalse(update.is_internal)
        self.assertIn(ticket.ticket_number, response)
        self.assertIn("support team can see it", response)
        self.assertEqual(self.db.query(Ticket).count(), 1)

    def test_greeting_is_friendly_and_does_not_start_an_incomplete_ticket(self):
        response = self.send("wamid.greeting", "Hello, I need help")

        self.assertIn("describe", response.casefold())
        self.assertEqual(self.db.query(Ticket).count(), 0)
        self.assertEqual(self.db.query(WhatsAppConversation).count(), 0)

    def test_thanks_during_intake_keeps_the_current_step(self):
        self.send("wamid.thanks.1", "My laptop cannot connect to Wi-Fi.")

        response = self.send("wamid.thanks.2", "Thank you")

        conversation = self.db.query(WhatsAppConversation).one()
        self.assertEqual(conversation.step, "category")
        self.assertIn("you’re welcome", response.casefold())
        self.assertNotIn("category", response.casefold())
        self.assertEqual(self.db.query(Ticket).count(), 0)

    def test_thanks_during_device_step_does_not_repeat_device_prompt(self):
        self.send("wamid.thanks.device.1", "My laptop cannot connect to Wi-Fi.")
        self.send("wamid.thanks.device.2", "Network")

        response = self.send("wamid.thanks.device.3", "Thank you!")

        conversation = self.db.query(WhatsAppConversation).one()
        self.assertEqual(conversation.step, "device")
        self.assertIn("you’re welcome", response.casefold())
        self.assertNotIn("device", response.casefold())
        self.assertEqual(self.db.query(Ticket).count(), 0)

    def test_follow_up_is_attached_to_the_latest_active_ticket(self):
        tickets = [
            Ticket(
                ticket_number=f"TD-WA-ACTIVE-{index}",
                title=f"Active issue {index}",
                description=f"Active issue description {index}.",
                category="Network",
                impact="Medium",
                urgency="Medium",
                priority="Medium",
                status="Open",
                reporter_id=self.reporter.id,
            )
            for index in range(2)
        ]
        self.db.add_all(tickets)
        self.db.commit()

        response = self.send(
            "wamid.followup",
            "I also restarted the router and the connection still drops.",
        )

        self.assertIn(tickets[1].ticket_number, response)
        self.assertEqual(self.db.query(Ticket).count(), 2)
        self.assertEqual(
            self.db.query(TicketNote).one().ticket_id,
            tickets[1].id,
        )
        self.assertFalse(self.db.query(TicketNote).one().is_internal)

    def test_resolved_ticket_requires_confirmation_before_reopening(self):
        ticket = Ticket(
            ticket_number="TD-WA-RESOLVED",
            title="Password reset",
            description="The user needs a password reset.",
            category="Account Access",
            impact="Medium",
            urgency="High",
            priority="High",
            status="Resolved",
            reporter_id=self.reporter.id,
            resolution="Reset the account password.",
        )
        self.db.add(ticket)
        self.db.commit()

        response = self.send(
            "wamid.reopen.1",
            "The password I was given is not working. Please look at the issue again.",
        )
        conversation = self.db.query(WhatsAppConversation).one()
        self.assertIn("reply *yes* or *no*", response.casefold())
        self.assertEqual(conversation.step, "reopen_confirmation")
        self.assertEqual(conversation.ticket_id, ticket.id)
        self.assertEqual(ticket.status, "Resolved")

        response = self.send("wamid.reopen.2", "Yes")

        self.assertEqual(ticket.status, "Open")
        self.assertIsNone(ticket.assigned_technician_id)
        self.assertEqual(self.db.query(WhatsAppConversation).count(), 0)
        self.assertEqual(self.db.query(TicketNote).one().note,
                         "The password I was given is not working. Please look at the issue again.")
        history = self.db.query(TicketHistory).one()
        self.assertEqual(history.action, "Ticket reopened")
        self.assertIn("open again", response.casefold())

    def test_unlinked_number_automatically_creates_guest_ticket(self):
        response = process_incoming_message(
            self.db,
            "wamid.unlinked",
            "15550000000",
            "text",
            "My account is locked.",
        )

        self.assertIn("category", response.casefold())
        self.assertEqual(
            self.db.query(WhatsAppContact)
            .filter_by(phone_number="+15550000000")
            .count(),
            1,
        )

    def test_account_category_accepts_short_name(self):
        self.send("wamid.account.1", "I forgot my password and cannot log in.")

        response = self.send("wamid.account.2", "Account")

        conversation = self.db.query(WhatsAppConversation).one()
        self.assertEqual(conversation.category, "Account Access")
        self.assertIn("Account Access", response)
        self.assertIn("device", response.casefold())

    def test_webhook_signature_matches_twilio_request_validator(self):
        url = "https://example.test/webhooks/whatsapp"
        params = {"MessageSid": "SM123", "From": "whatsapp:+15551234567"}
        auth_token = "test-auth-token"
        signature = RequestValidator(auth_token).compute_signature(url, params)

        with patch.dict(os.environ, {"TWILIO_AUTH_TOKEN": auth_token}):
            self.assertTrue(verify_webhook_signature(url, params, signature))
            self.assertFalse(
                verify_webhook_signature(url, params, "invalid-signature")
            )

    def test_meta_webhook_signature_is_validated(self):
        body = b'{"object":"whatsapp_business_account"}'
        app_secret = "test-meta-app-secret"
        signature = "sha256=" + hmac.new(
            app_secret.encode("utf-8"), body, hashlib.sha256
        ).hexdigest()

        with patch.dict(os.environ, {"META_APP_SECRET": app_secret}):
            self.assertTrue(verify_meta_webhook_signature(body, signature))
            self.assertFalse(verify_meta_webhook_signature(body, "sha256=invalid"))

    def test_meta_api_error_includes_safe_provider_details(self):
        error_body = json.dumps(
            {
                "error": {
                    "message": "Recipient phone number is not allowed",
                    "type": "OAuthException",
                    "code": 131030,
                }
            }
        ).encode("utf-8")
        http_error = HTTPError(
            "https://graph.facebook.com/v23.0/123/messages",
            400,
            "Bad Request",
            {},
            io.BytesIO(error_body),
        )

        with (
            patch.dict(os.environ, {"META_ACCESS_TOKEN": "private-token"}),
            patch("meta_whatsapp.urlopen", side_effect=http_error),
            self.assertRaises(RuntimeError) as raised,
        ):
            send_meta_whatsapp_message("123", "15550000000", "Hello")

        self.assertIn("HTTP 400", str(raised.exception))
        self.assertIn("Meta error 131030", str(raised.exception))
        self.assertIn("Recipient phone number is not allowed", str(raised.exception))
        self.assertNotIn("private-token", str(raised.exception))

    def test_meta_webhook_verification_returns_challenge(self):
        scope = {
            "type": "http",
            "method": "GET",
            "scheme": "https",
            "server": ("example.test", 443),
            "path": "/webhooks/whatsapp",
            "query_string": (
                b"hub.mode=subscribe&hub.verify_token=meta-secret&hub.challenge=12345"
            ),
            "headers": [(b"host", b"example.test")],
        }
        request = Request(scope)

        with patch.dict(os.environ, {"META_VERIFY_TOKEN": "meta-secret"}):
            response = verify_meta_webhook(request)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.body, b"12345")

    def test_meta_webhook_processes_and_replies_to_text_message(self):
        app_secret = "test-meta-app-secret"
        payload = {
            "object": "whatsapp_business_account",
            "entry": [
                {
                    "changes": [
                        {
                            "value": {
                                "metadata": {"phone_number_id": "123456"},
                                "messages": [
                                    {
                                        "from": "15551234567",
                                        "id": "wamid.meta1",
                                        "type": "text",
                                        "text": {"body": "Printer is not working."},
                                    }
                                ],
                            }
                        }
                    ]
                }
            ],
        }
        body = json.dumps(payload).encode("utf-8")
        signature = "sha256=" + hmac.new(
            app_secret.encode("utf-8"), body, hashlib.sha256
        ).hexdigest()
        scope = {
            "type": "http",
            "method": "POST",
            "scheme": "https",
            "server": ("example.test", 443),
            "path": "/webhooks/whatsapp",
            "query_string": b"",
            "headers": [
                (b"host", b"example.test"),
                (b"content-type", b"application/json"),
                (b"x-hub-signature-256", signature.encode("ascii")),
            ],
        }

        async def receive():
            return {"type": "http.request", "body": body, "more_body": False}

        async def run_in_threadpool(function, *args):
            return function(*args)

        request = Request(scope, receive)
        with (
            patch.dict(os.environ, {"META_APP_SECRET": app_secret}),
            patch("whatsapp.run_in_threadpool", side_effect=run_in_threadpool),
            patch("whatsapp.send_meta_whatsapp_message") as send_message,
        ):
            result = asyncio.run(receive_meta_webhook(request, self.db))

        self.assertEqual(result, {"status": "received"})
        self.assertEqual(
            self.db.get(WhatsAppMessage, "wamid.meta1").phone_number,
            "+15551234567",
        )
        send_message.assert_called_once_with(
            "123456",
            "15551234567",
            "📝 *Issue description saved.*\n"
            "What category fits your issue best?\n\n"
            "1. Network\n2. Hardware\n3. Software\n4. Email\n"
            "5. Account Access\n6. Printer\n7. Other\n\n"
            "Reply with a category name or number.",
        )

    def test_twiml_response_contains_reply_message(self):
        response = whatsapp_twiml_response("Ticket created.")

        self.assertEqual(response.media_type, "application/xml")
        self.assertIn("<Message>Ticket created.</Message>", response.body.decode())

    def test_twilio_webhook_accepts_signed_form_and_replies(self):
        auth_token = "test-auth-token"
        url = "https://example.test/webhooks/whatsapp"
        params = {
            "MessageSid": "SM123",
            "From": "whatsapp:+15551234567",
            "NumMedia": "0",
            "Body": "Printer is not working.",
        }
        signature = RequestValidator(auth_token).compute_signature(url, params)
        body = urlencode(params).encode("utf-8")
        scope = {
            "type": "http",
            "method": "POST",
            "scheme": "https",
            "server": ("example.test", 443),
            "path": "/webhooks/whatsapp",
            "query_string": b"",
            "headers": [
                (b"host", b"example.test"),
                (b"x-twilio-signature", signature.encode("ascii")),
            ],
        }

        async def receive():
            return {"type": "http.request", "body": body, "more_body": False}

        async def run_in_threadpool(function, *args):
            return function(*args)

        request = Request(scope, receive)
        with (
            patch.dict(os.environ, {"TWILIO_AUTH_TOKEN": auth_token}),
            patch("whatsapp.run_in_threadpool", side_effect=run_in_threadpool),
        ):
            result = asyncio.run(receive_webhook(request, self.db))

        self.assertEqual(result.media_type, "application/xml")
        self.assertIn(
            "<Message>📝 *Issue description saved.*",
            result.body.decode(),
        )
        self.assertEqual(
            self.db.get(WhatsAppMessage, "SM123").phone_number,
            "+15551234567",
        )

    def test_webhook_logs_conversation_failure_without_changing_response(self):
        auth_token = "test-auth-token"
        url = "https://example.test/webhooks/whatsapp"
        params = {
            "MessageSid": "SM123",
            "From": "whatsapp:+15551234567",
            "NumMedia": "0",
            "Body": "Printer is not working.",
        }
        signature = RequestValidator(auth_token).compute_signature(url, params)
        body = urlencode(params).encode("utf-8")
        scope = {
            "type": "http",
            "method": "POST",
            "scheme": "https",
            "server": ("example.test", 443),
            "path": "/webhooks/whatsapp",
            "query_string": b"",
            "headers": [
                (b"host", b"example.test"),
                (b"x-twilio-signature", signature.encode("ascii")),
            ],
        }

        async def receive():
            return {"type": "http.request", "body": body, "more_body": False}

        async def fail_in_threadpool(function, *args):
            raise RuntimeError("Conversation storage failed.")

        request = Request(scope, receive)
        with (
            patch.dict(os.environ, {"TWILIO_AUTH_TOKEN": auth_token}),
            patch("whatsapp.run_in_threadpool", side_effect=fail_in_threadpool),
            self.assertLogs("whatsapp", level="ERROR") as captured,
        ):
            with self.assertRaises(HTTPException) as raised:
                asyncio.run(receive_webhook(request, self.db))

        self.assertEqual(raised.exception.status_code, 502)
        self.assertIn(
            "WhatsApp webhook conversation processing failed.",
            captured.output[0],
        )
        self.assertIn("Conversation storage failed.", captured.output[0])


if __name__ == "__main__":
    unittest.main()

import asyncio
import os
import unittest
from urllib.parse import urlencode
from unittest.mock import patch

from fastapi import Request
from requests.exceptions import ConnectionError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from twilio.request_validator import RequestValidator

from models import (
    Base,
    Ticket,
    TicketHistory,
    User,
    WhatsAppContact,
    WhatsAppMessage,
)
from whatsapp import (
    process_incoming_message,
    receive_webhook,
    send_whatsapp_text,
    verify_webhook_signature,
)


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
            self.send("wamid.1", "I cannot connect to the lab Wi-Fi."),
        )
        self.assertIn(
            "affect your work",
            self.send("wamid.2", "Network").casefold(),
        )
        self.assertIn("urgent", self.send("wamid.3", "High").casefold())
        response = self.send("wamid.4", "High")

        ticket = self.db.query(Ticket).one()
        self.assertIn(ticket.ticket_number, response)
        self.assertEqual(ticket.reporter_id, self.reporter.id)
        self.assertEqual(ticket.category, "Network")
        self.assertEqual(ticket.impact, "High")
        self.assertEqual(ticket.urgency, "High")
        self.assertEqual(ticket.priority, "Critical")
        self.assertEqual(ticket.status, "Open")
        self.assertEqual(
            self.db.query(TicketHistory).one().action,
            "Ticket created via WhatsApp",
        )

    def test_duplicate_webhook_message_does_not_create_duplicate_ticket(self):
        self.send("wamid.1", "Printer is not working.")
        self.send("wamid.2", "Printer")
        self.send("wamid.3", "Medium")
        first_response = self.send("wamid.4", "High")
        duplicate_response = self.send(
            "wamid.4", "This content must not be processed twice."
        )

        self.assertEqual(first_response, duplicate_response)
        self.assertEqual(self.db.query(WhatsAppMessage).count(), 4)
        self.assertEqual(self.db.query(Ticket).count(), 1)

    def test_unlinked_number_cannot_create_a_ticket(self):
        response = process_incoming_message(
            self.db,
            "wamid.unlinked",
            "15550000000",
            "text",
            "My account is locked.",
        )

        self.assertIn("not linked", response)
        self.assertEqual(self.db.query(Ticket).count(), 0)

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

    def test_send_whatsapp_text_uses_twilio_whatsapp_addresses(self):
        with (
            patch.dict(
                os.environ,
                {
                    "TWILIO_ACCOUNT_SID": "AC123",
                    "TWILIO_AUTH_TOKEN": "test-auth-token",
                    "TWILIO_WHATSAPP_FROM": "whatsapp:+14155238886",
                },
            ),
            patch("whatsapp.Client") as client,
        ):
            send_whatsapp_text("+15551234567", "Ticket created.")

        client.return_value.messages.create.assert_called_once_with(
            from_="whatsapp:+14155238886",
            to="whatsapp:+15551234567",
            body="Ticket created.",
        )

    def test_send_whatsapp_text_reports_twilio_connection_failure(self):
        with (
            patch.dict(
                os.environ,
                {
                    "TWILIO_ACCOUNT_SID": "AC123",
                    "TWILIO_AUTH_TOKEN": "test-auth-token",
                    "TWILIO_WHATSAPP_FROM": "whatsapp:+14155238886",
                },
            ),
            patch("whatsapp.Client") as client,
        ):
            client.return_value.messages.create.side_effect = ConnectionError(
                "Twilio is unavailable."
            )
            with self.assertRaisesRegex(RuntimeError, "could not deliver"):
                send_whatsapp_text("+15551234567", "Ticket created.")

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
            patch("whatsapp.send_whatsapp_text") as send_message,
        ):
            result = asyncio.run(receive_webhook(request, self.db))

        self.assertEqual(result, {"status": "ok"})
        self.assertEqual(
            self.db.get(WhatsAppMessage, "SM123").phone_number,
            "+15551234567",
        )
        send_message.assert_called_once()


if __name__ == "__main__":
    unittest.main()

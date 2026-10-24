import hashlib
import hmac
import os
import unittest
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from models import (
    Base,
    Ticket,
    TicketHistory,
    User,
    WhatsAppContact,
    WhatsAppMessage,
)
from whatsapp import process_incoming_message, verify_webhook_signature


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

    def test_webhook_signature_matches_meta_hmac(self):
        body = b'{"object":"whatsapp_business_account"}'
        secret = "test-app-secret"
        signature = "sha256=" + hmac.new(
            secret.encode("utf-8"), body, hashlib.sha256
        ).hexdigest()

        with patch.dict(os.environ, {"WHATSAPP_APP_SECRET": secret}):
            self.assertTrue(verify_webhook_signature(body, signature))
            self.assertFalse(verify_webhook_signature(body, "sha256=invalid"))


if __name__ == "__main__":
    unittest.main()

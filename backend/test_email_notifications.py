import os
import unittest
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from email_notifications import (
    notify_reporter_public_reply,
    notify_reporter_resolved,
    notify_reporter_status_update,
    notify_ticket_created,
)
from models import Ticket, TicketHistory, User


class EmailNotificationTests(unittest.TestCase):
    def setUp(self):
        patcher = patch.dict(
            os.environ,
            {"TICKET_EMAIL_NOTIFICATIONS_ENABLED": "true"},
        )
        patcher.start()
        self.addCleanup(patcher.stop)

        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.reporter = User(
            full_name="Ticket Reporter",
            email="reporter@example.test",
            password_hash="unused",
            role="Reporter",
            approval_status="Approved",
        )
        self.technician = User(
            full_name="Ticket Technician",
            email="technician@example.test",
            password_hash="unused",
            role="Technician",
            approval_status="Approved",
        )
        self.inactive_technician = User(
            full_name="Inactive Technician",
            email="inactive@example.test",
            password_hash="unused",
            role="Technician",
            is_active=False,
            approval_status="Approved",
        )
        self.pending_technician = User(
            full_name="Pending Technician",
            email="pending@example.test",
            password_hash="unused",
            role="Technician",
            approval_status="Pending",
        )
        self.db.add_all(
            [
                self.reporter,
                self.technician,
                self.inactive_technician,
                self.pending_technician,
            ]
        )
        self.db.flush()
        self.ticket = Ticket(
            ticket_number="TD-EMAIL-1",
            title="Laptop will not start",
            description="The laptop will not start.",
            category="Hardware",
            impact="Medium",
            urgency="High",
            priority="High",
            status="Open",
            reporter_id=self.reporter.id,
        )
        self.db.add(self.ticket)
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    @patch("email_notifications.send_email")
    def test_creation_notifies_reporter_and_approved_active_technicians(
        self, send_email
    ):
        notify_ticket_created(self.db, self.ticket)

        self.assertEqual(
            {call.args[0] for call in send_email.call_args_list},
            {"reporter@example.test", "technician@example.test"},
        )
        reporter_email = next(
            call for call in send_email.call_args_list
            if call.args[0] == "reporter@example.test"
        )
        technician_email = next(
            call for call in send_email.call_args_list
            if call.args[0] == "technician@example.test"
        )
        self.assertIn("TD-EMAIL-1", reporter_email.args[1])
        self.assertIn("TD-EMAIL-1", technician_email.args[2])
        self.assertIn("The laptop will not start.", technician_email.args[2])

    @patch("email_notifications.send_email")
    def test_creation_notifications_are_enabled_by_default(self, send_email):
        with patch.dict(os.environ, {}, clear=True):
            notify_ticket_created(self.db, self.ticket)

        self.assertIn(
            self.reporter.email,
            {call.args[0] for call in send_email.call_args_list},
        )

    @patch("email_notifications.send_email")
    def test_public_reply_and_resolution_email_the_reporter(self, send_email):
        self.ticket.status = "Resolved"
        self.ticket.resolution = "Replaced the power adapter."

        notify_reporter_public_reply(
            self.db,
            self.ticket,
            self.technician,
            "Please try starting the laptop again.",
        )
        resolved_email_sent = notify_reporter_resolved(self.db, self.ticket)

        self.assertEqual(send_email.call_count, 2)
        self.assertEqual(send_email.call_args_list[0].args[0], self.reporter.email)
        self.assertIn("Please try starting the laptop again.", send_email.call_args_list[0].args[2])
        self.assertIn("Replaced the power adapter.", send_email.call_args_list[1].args[2])
        self.assertTrue(resolved_email_sent)

    @patch("email_notifications.send_email")
    def test_status_update_emails_reporter(self, send_email):
        sent = notify_reporter_status_update(
            self.db,
            self.ticket,
            "A technician accepted your ticket.",
        )

        self.assertTrue(sent)
        send_email.assert_called_once()
        self.assertEqual(send_email.call_args.args[0], self.reporter.email)
        self.assertIn("A technician accepted your ticket.", send_email.call_args.args[2])

    @patch("email_notifications.send_email")
    def test_whatsapp_ticket_does_not_email_reporter_updates(self, send_email):
        self.db.add(
            TicketHistory(
                ticket_id=self.ticket.id,
                actor_id=self.reporter.id,
                action="Ticket created via WhatsApp",
                new_status="Open",
            )
        )
        self.db.commit()

        notify_ticket_created(self.db, self.ticket)
        notify_reporter_public_reply(
            self.db,
            self.ticket,
            self.technician,
            "Your device is ready.",
        )
        self.assertFalse(notify_reporter_resolved(self.db, self.ticket))
        self.assertFalse(
            notify_reporter_status_update(
                self.db,
                self.ticket,
                "A technician accepted your ticket.",
            )
        )

        self.assertEqual(
            [call.args[0] for call in send_email.call_args_list],
            [self.technician.email],
        )

    @patch("email_notifications.send_email")
    def test_whatsapp_guest_reporter_is_not_emailed(self, send_email):
        self.reporter.email = "guest_15551234567@triagedesk.guest"
        self.db.commit()

        notify_ticket_created(self.db, self.ticket)

        self.assertEqual(send_email.call_count, 1)
        self.assertEqual(send_email.call_args.args[0], self.technician.email)

    @patch("email_notifications.send_email")
    def test_ticket_email_notifications_are_disabled_when_not_enabled(
        self, send_email
    ):
        with patch.dict(os.environ, {"TICKET_EMAIL_NOTIFICATIONS_ENABLED": "false"}):
            notify_ticket_created(self.db, self.ticket)
            notify_reporter_public_reply(
                self.db,
                self.ticket,
                self.technician,
                "A public update.",
            )
            sent = notify_reporter_resolved(self.db, self.ticket)

        self.assertFalse(sent)
        send_email.assert_not_called()

    @patch(
        "email_notifications.send_email",
        side_effect=OSError("SMTP unavailable"),
    )
    def test_delivery_failure_does_not_raise(self, _send_email):
        with self.assertLogs("email_notifications", level="ERROR"):
            sent = notify_reporter_resolved(self.db, self.ticket)
        self.assertFalse(sent)


if __name__ == "__main__":
    unittest.main()

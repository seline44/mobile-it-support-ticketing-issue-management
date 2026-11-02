import unittest
from unittest.mock import patch

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from models import Ticket, TicketHistory, TicketNote, User, WhatsAppContact
from schemas import ReopenRequest, StatusUpdate
from tickets import (
    list_notifications,
    list_ticket_history,
    list_ticket_notes,
    reopen_ticket,
    update_ticket_status,
)


class TicketCompletionTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.reporter = User(
            full_name="Ticket Reporter",
            email="ticket-reporter@example.test",
            password_hash="unused",
            role="Reporter",
            approval_status="Approved",
        )
        self.technician = User(
            full_name="Ticket Technician",
            email="ticket-technician@example.test",
            password_hash="unused",
            role="Technician",
            approval_status="Approved",
        )
        self.admin = User(
            full_name="Ticket Admin",
            email="ticket-admin@example.test",
            password_hash="unused",
            role="Administrator",
            approval_status="Approved",
        )
        self.db.add_all([self.reporter, self.technician, self.admin])
        self.db.flush()
        self.ticket = Ticket(
            ticket_number="TD-TEST-1",
            title="Laptop will not start",
            description="The laptop will not start.",
            category="Hardware",
            impact="Medium",
            urgency="High",
            priority="High",
            device="Laptop",
            location="Office",
            status="In Progress",
            reporter_id=self.reporter.id,
            assigned_technician_id=self.technician.id,
        )
        self.db.add(self.ticket)
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def test_technician_resolves_and_closes_ticket_with_resolution_and_note(self):
        for status in ("Resolved", "Closed"):
            with self.subTest(status=status):
                if status == "Closed":
                    self.ticket.status = "In Progress"
                    self.ticket.resolved_at = None
                    self.db.commit()

                result = update_ticket_status(
                    self.ticket.id,
                    StatusUpdate(
                        status=status,
                        resolution="Replaced the faulty power adapter.",
                        note=f"Reporter update for {status.lower()}.",
                    ),
                    self.db,
                    self.technician,
                )

                self.assertEqual(result["status"], status)
                self.assertEqual(
                    result["resolution"],
                    "Replaced the faulty power adapter.",
                )
                self.assertIsNotNone(result["resolved_at"])

                note = (
                    self.db.query(TicketNote)
                    .order_by(TicketNote.id.desc())
                    .first()
                )
                self.assertEqual(
                    note.note,
                    f"Reporter update for {status.lower()}.",
                )
                history = (
                    self.db.query(TicketHistory)
                    .order_by(TicketHistory.id.desc())
                    .first()
                )
                self.assertEqual(history.new_status, status)
                self.assertIn(
                    "Replaced the faulty power adapter.",
                    history.details,
                )

        reporter_notes = list_ticket_notes(self.ticket.id, self.db, self.reporter)
        admin_notes = list_ticket_notes(self.ticket.id, self.db, self.admin)
        self.assertEqual(len(reporter_notes), 2)
        self.assertEqual(len(admin_notes), 2)
        self.assertEqual(reporter_notes[0]["author_name"], "Ticket Technician")

        reporter_history = list_ticket_history(
            self.ticket.id,
            self.db,
            self.reporter,
        )
        admin_history = list_ticket_history(self.ticket.id, self.db, self.admin)
        self.assertEqual(len(reporter_history), 2)
        self.assertEqual(len(admin_history), 2)
        self.assertEqual(reporter_history[-1]["new_status"], "Closed")

    def test_completion_requires_a_resolution_note(self):
        with self.assertRaises(HTTPException) as error:
            update_ticket_status(
                self.ticket.id,
                StatusUpdate(status="Resolved"),
                self.db,
                self.technician,
            )

        self.assertEqual(error.exception.status_code, 422)
        self.assertEqual(self.ticket.status, "In Progress")
        self.assertEqual(self.db.query(TicketHistory).count(), 0)
        self.assertEqual(self.db.query(TicketNote).count(), 0)

    def test_notifications_are_scoped_for_reporters_and_technicians(self):
        self.db.add(
            TicketHistory(
                ticket_id=self.ticket.id,
                actor_id=self.technician.id,
                action="Ticket resolved",
                old_status="In Progress",
                new_status="Resolved",
                details="Resolution: Replaced the faulty adapter.",
            )
        )
        unassigned_ticket = Ticket(
            ticket_number="TD-TEST-2",
            title="Wi-Fi is unavailable",
            description="Cannot connect to Wi-Fi.",
            category="Network",
            impact="High",
            urgency="High",
            priority="Critical",
            status="Open",
            reporter_id=self.reporter.id,
        )
        self.db.add(unassigned_ticket)
        self.db.flush()
        self.db.add(
            TicketHistory(
                ticket_id=unassigned_ticket.id,
                actor_id=self.reporter.id,
                action="Ticket created via WhatsApp",
                new_status="Open",
            )
        )
        self.db.commit()

        reporter_notifications = list_notifications(50, self.db, self.reporter)
        technician_notifications = list_notifications(
            50,
            self.db,
            self.technician,
        )

        self.assertEqual(len(reporter_notifications), 1)
        self.assertEqual(
            reporter_notifications[0]["action"],
            "Ticket resolved",
        )
        self.assertEqual(
            reporter_notifications[0]["actor_name"],
            "Ticket Technician",
        )
        self.assertEqual(len(technician_notifications), 1)
        self.assertEqual(
            technician_notifications[0]["action"],
            "Ticket created via WhatsApp",
        )
        self.assertEqual(
            technician_notifications[0]["ticket_number"],
            "TD-TEST-2",
        )

    def test_technician_status_update_sends_whatsapp_to_linked_reporter(self):
        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

        with patch("tickets.send_reporter_whatsapp_update") as send_update:
            update_ticket_status(
                self.ticket.id,
                StatusUpdate(
                    status="Resolved",
                    resolution="Replaced the faulty adapter.",
                    note="Please test the connection again.",
                ),
                self.db,
                self.technician,
            )

        send_update.assert_called_once()
        message = send_update.call_args.args[2]
        self.assertIn("TD-TEST-1", message)
        self.assertIn("Resolved", message)
        self.assertIn("Replaced the faulty adapter.", message)
        self.assertIn("Please test the connection again.", message)

    def test_reporter_can_reopen_own_resolved_ticket_with_reason(self):
        self.ticket.status = "Resolved"
        self.ticket.resolution = "Replaced the network adapter."
        self.ticket.resolved_at = self.ticket.updated_at
        self.db.commit()

        result = reopen_ticket(
            self.ticket.id,
            ReopenRequest(reason="The network still disconnects."),
            self.db,
            self.reporter,
        )

        self.assertEqual(result["status"], "Open")
        self.assertEqual(
            result["resolution"],
            "Replaced the network adapter.",
        )
        self.assertIsNone(result["assigned_technician_id"])
        self.assertIsNone(result["resolved_at"])
        history = self.db.query(TicketHistory).one()
        self.assertEqual(history.action, "Ticket reopened")
        self.assertEqual(history.old_status, "Resolved")
        self.assertEqual(history.new_status, "Open")
        self.assertIn("The network still disconnects.", history.details)

    def test_reporter_cannot_reopen_another_reporters_ticket(self):
        other_reporter = User(
            full_name="Another Reporter",
            email="another-reporter@example.test",
            password_hash="unused",
            role="Reporter",
            approval_status="Approved",
        )
        self.db.add(other_reporter)
        self.db.flush()
        self.ticket.status = "Closed"
        self.db.commit()

        with self.assertRaises(HTTPException) as error:
            reopen_ticket(
                self.ticket.id,
                ReopenRequest(reason="This issue is still happening."),
                self.db,
                other_reporter,
            )

        self.assertEqual(error.exception.status_code, 404)
        self.assertEqual(self.ticket.status, "Closed")
        self.assertEqual(self.db.query(TicketHistory).count(), 0)

    def test_reporter_cannot_reopen_a_ticket_that_is_not_complete(self):
        with self.assertRaises(HTTPException) as error:
            reopen_ticket(
                self.ticket.id,
                ReopenRequest(reason="This issue is still happening."),
                self.db,
                self.reporter,
            )

        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(self.ticket.status, "In Progress")


if __name__ == "__main__":
    unittest.main()

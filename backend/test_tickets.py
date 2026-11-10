import unittest
from unittest.mock import patch

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from models import Ticket, TicketHistory, TicketNote, User, WhatsAppContact
from schemas import ReopenRequest, StatusUpdate, TicketCreate
from tickets import (
    accept_ticket,
    create_ticket,
    list_notifications,
    list_ticket_history,
    list_ticket_notes,
    reopen_ticket,
    serialize_ticket,
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
                self.assertFalse(result["whatsapp_notification_sent"])
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
                self.assertTrue(note.is_internal)
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
        self.assertEqual(reporter_notes, [])
        self.assertEqual(len(admin_notes), 2)
        self.assertTrue(all(note["is_internal"] for note in admin_notes))

        reporter_history = list_ticket_history(
            self.ticket.id,
            self.db,
            self.reporter,
        )
        admin_history = list_ticket_history(self.ticket.id, self.db, self.admin)
        self.assertEqual(len(reporter_history), 2)
        self.assertEqual(len(admin_history), 2)
        self.assertEqual(reporter_history[-1]["new_status"], "Closed")
        self.assertIn("Resolution:", reporter_history[-1]["details"])
        self.assertNotIn("Reporter update", str(reporter_history[-1]["details"]))

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

    def test_reporter_comments_are_visible_to_staff_not_private(self):
        from schemas import NoteCreate
        from tickets import add_ticket_note

        with patch("tickets.send_reporter_whatsapp_update") as send_update:
            reporter_note = add_ticket_note(
                self.ticket.id,
                NoteCreate(note="The error appeared again."),
                self.db,
                self.reporter,
            )
            technician_note = add_ticket_note(
                self.ticket.id,
                NoteCreate(note="Checking the device logs."),
                self.db,
                self.technician,
            )
        send_update.assert_not_called()

        self.assertFalse(reporter_note.is_internal)
        self.assertTrue(technician_note.is_internal)
        reporter_notes = list_ticket_notes(
            self.ticket.id, self.db, self.reporter
        )
        technician_notes = list_ticket_notes(
            self.ticket.id, self.db, self.technician
        )
        self.assertEqual(
            [note["note"] for note in reporter_notes],
            ["The error appeared again."],
        )
        self.assertEqual(
            [note["note"] for note in technician_notes],
            ["The error appeared again.", "Checking the device logs."],
        )

    def test_technician_can_send_public_reply_to_reporter(self):
        from schemas import NoteCreate
        from tickets import add_ticket_note

        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

        with (
            patch("tickets.send_reporter_whatsapp_update") as send_update,
            patch("tickets.notify_reporter_public_reply") as send_email,
        ):
            send_update.return_value = True
            reply = add_ticket_note(
                self.ticket.id,
                NoteCreate(
                    note="Please try signing in again.",
                    is_internal=False,
                ),
                self.db,
                self.technician,
            )

        send_update.assert_called_once()
        send_email.assert_called_once_with(
            self.db,
            self.ticket,
            self.technician,
            "Please try signing in again.",
        )
        self.assertIn("Support team reply", send_update.call_args.args[2])
        self.assertIn("Please try signing in again.", send_update.call_args.args[2])
        self.assertFalse(reply.is_internal)
        self.assertTrue(reply.whatsapp_notification_sent)
        reporter_notes = list_ticket_notes(
            self.ticket.id, self.db, self.reporter
        )
        self.assertEqual(
            [note["note"] for note in reporter_notes],
            ["Please try signing in again."],
        )

    def test_internal_staff_note_does_not_send_email(self):
        from schemas import NoteCreate
        from tickets import add_ticket_note

        with patch("tickets.notify_reporter_public_reply") as send_email:
            add_ticket_note(
                self.ticket.id,
                NoteCreate(note="Internal investigation note."),
                self.db,
                self.technician,
            )

        send_email.assert_not_called()

    def test_reporter_cannot_create_an_internal_note(self):
        from schemas import NoteCreate
        from tickets import add_ticket_note

        with self.assertRaises(HTTPException) as error:
            add_ticket_note(
                self.ticket.id,
                NoteCreate(note="Hidden note", is_internal=True),
                self.db,
                self.reporter,
            )

        self.assertEqual(error.exception.status_code, 403)
        self.assertEqual(self.db.query(TicketNote).count(), 0)

    def test_ticket_details_include_whatsapp_requester_contact(self):
        self.db.add(
            WhatsAppContact(
                phone_number="+254794045207",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

        result = serialize_ticket(self.db, self.ticket)

        self.assertEqual(result["reporter_name"], "Ticket Reporter")
        self.assertEqual(result["reporter_phone"], "+254794045207")

    def test_app_ticket_creation_sends_open_whatsapp_status(self):
        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

        with (
            patch("tickets.send_reporter_whatsapp_update") as send_update,
            patch("tickets.notify_ticket_created") as send_email,
        ):
            result = create_ticket(
                TicketCreate(
                    title="Email is unavailable",
                    description="I cannot access my email.",
                    category="Email",
                    impact="Medium",
                    urgency="Medium",
                ),
                self.db,
                self.reporter,
            )

        send_update.assert_called_once()
        send_email.assert_called_once_with(
            self.db,
            self.db.get(Ticket, result["id"]),
        )
        message = send_update.call_args.args[2]
        self.assertIn("is open", message)
        self.assertIn("waiting for a technician", message)
        self.assertEqual(result["status"], "Open")

    def test_resolution_sends_reporter_email(self):
        with (
            patch(
                "tickets.notify_reporter_resolved",
                return_value=True,
            ) as send_email,
            patch("tickets.send_reporter_whatsapp_update"),
        ):
            result = update_ticket_status(
                self.ticket.id,
                StatusUpdate(
                    status="Resolved",
                    resolution="Replaced the faulty power adapter.",
                ),
                self.db,
                self.technician,
            )

        send_email.assert_called_once_with(self.db, self.ticket)
        self.assertTrue(result["email_notification_sent"])
        notifications = list_notifications(50, self.db, self.reporter)
        self.assertEqual(len(notifications), 1)
        self.assertEqual(notifications[0]["action"], "Ticket resolved")
        self.assertIn(
            "Replaced the faulty power adapter.",
            notifications[0]["details"],
        )

    def test_accepting_ticket_sends_generic_in_progress_whatsapp(self):
        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()
        open_ticket = Ticket(
            ticket_number="TD-OPEN-1",
            title="Printer offline",
            description="The printer is offline.",
            category="Printer",
            impact="Low",
            urgency="Medium",
            priority="Low",
            status="Open",
            reporter_id=self.reporter.id,
        )
        self.db.add(open_ticket)
        self.db.commit()

        with patch("tickets.send_reporter_whatsapp_update") as send_update:
            result = accept_ticket(open_ticket.id, self.db, self.technician)

        send_update.assert_called_once()
        message = send_update.call_args.args[2]
        self.assertIn("A technician has received your ticket", message)
        self.assertNotIn(self.technician.full_name, message)
        self.assertEqual(result["status"], "In Progress")

    def test_notifications_are_scoped_for_reporters_and_technicians(self):
        self.db.add(
            TicketHistory(
                ticket_id=self.ticket.id,
                actor_id=self.technician.id,
                action="Ticket resolved",
                old_status="In Progress",
                new_status="Resolved",
                details=(
                    "Resolution: Replaced the faulty adapter.\n"
                    "Update: Internal diagnostic details."
                ),
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
        self.assertIn(
            "Replaced the faulty adapter",
            reporter_notifications[0]["details"],
        )
        self.assertNotIn(
            "Internal diagnostic details",
            reporter_notifications[0]["details"],
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
            send_update.return_value = True
            result = update_ticket_status(
                self.ticket.id,
                StatusUpdate(
                    status="Resolved",
                    resolution="Replaced the faulty adapter.",
                    note="Please test the connection again.",
                ),
                self.db,
                self.technician,
            )

        self.assertTrue(result["whatsapp_notification_sent"])
        send_update.assert_called_once()
        message = send_update.call_args.args[2]
        self.assertIn("TD-TEST-1", message)
        self.assertIn("resolved", message.casefold())
        self.assertIn("Replaced the faulty adapter.", message)
        self.assertNotIn("Please test the connection again.", message)
        self.assertNotIn(self.technician.full_name, message)

    def test_updating_resolution_on_already_resolved_ticket_sends_whatsapp(self):
        self.ticket.status = "Resolved"
        self.ticket.resolution = "Initial resolution."
        self.ticket.resolved_at = self.ticket.updated_at
        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

        with patch("tickets.send_reporter_whatsapp_update") as send_update:
            send_update.return_value = True
            result = update_ticket_status(
                self.ticket.id,
                StatusUpdate(
                    status="Resolved",
                    resolution="Updated resolution instructions.",
                ),
                self.db,
                self.admin,
            )

        self.assertTrue(result["whatsapp_notification_sent"])
        send_update.assert_called_once()
        self.assertIn("Updated resolution instructions.", send_update.call_args.args[2])

    def test_closed_ticket_sends_resolution_to_linked_reporter(self):
        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

        with patch("tickets.send_reporter_whatsapp_update") as send_update:
            send_update.return_value = True
            result = update_ticket_status(
                self.ticket.id,
                StatusUpdate(
                    status="Closed",
                    resolution="Reinstalled the printer driver.",
                ),
                self.db,
                self.admin,
            )

        self.assertTrue(result["whatsapp_notification_sent"])
        send_update.assert_called_once()
        message = send_update.call_args.args[2]
        self.assertIn("closed", message.casefold())
        self.assertIn("Reinstalled the printer driver.", message)

    def test_reporter_can_reopen_own_resolved_ticket_with_reason(self):
        self.ticket.status = "Resolved"
        self.ticket.resolution = "Replaced the network adapter."
        self.ticket.resolved_at = self.ticket.updated_at
        self.db.add(
            WhatsAppContact(
                phone_number="+15551234567",
                user_id=self.reporter.id,
                linked_by_user_id=self.admin.id,
            )
        )
        self.db.commit()

        with patch("tickets.send_reporter_whatsapp_update") as send_update:
            result = reopen_ticket(
                self.ticket.id,
                ReopenRequest(reason="The network still disconnects."),
                self.db,
                self.reporter,
            )

        send_update.assert_called_once()
        self.assertIn("is open", send_update.call_args.args[2])
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

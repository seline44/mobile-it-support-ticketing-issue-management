import unittest

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from models import Ticket, TicketHistory, TicketNote, User
from schemas import StatusUpdate
from tickets import (
    list_ticket_history,
    list_ticket_notes,
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


if __name__ == "__main__":
    unittest.main()

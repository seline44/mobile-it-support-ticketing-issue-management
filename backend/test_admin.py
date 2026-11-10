import unittest

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session

from database import Base
from admin import (
    AccountStatusRequest,
    delete_user,
    list_whatsapp_ticket_notifications,
    update_user_active_status,
)
from auth import create_access_token, get_current_user
from models import (
    Ticket,
    TicketHistory,
    TicketNote,
    User,
    WhatsAppContact,
    WhatsAppConversation,
    WhatsAppMessage,
)


class AdminWhatsAppNotificationTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        event.listen(
            self.engine,
            "connect",
            lambda connection, _: connection.execute("PRAGMA foreign_keys=ON"),
        )
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.admin = User(
            full_name="Notification Admin",
            email="notification-admin@example.test",
            password_hash="unused",
            role="Administrator",
            approval_status="Approved",
        )
        self.reporter = User(
            full_name="WhatsApp Reporter",
            email="notification-reporter@example.test",
            password_hash="unused",
            role="Reporter",
            approval_status="Approved",
        )
        self.db.add_all([self.admin, self.reporter])
        self.db.flush()
        self.whatsapp_ticket = Ticket(
            ticket_number="TD-WA-123",
            title="Wi-Fi keeps disconnecting",
            description="Wi-Fi keeps disconnecting",
            category="Network",
            impact="High",
            urgency="High",
            priority="Critical",
            status="Open",
            reporter_id=self.reporter.id,
        )
        self.other_ticket = Ticket(
            ticket_number="TD-APP-123",
            title="Printer issue",
            description="Printer issue",
            category="Printer",
            impact="Low",
            urgency="Low",
            priority="Low",
            status="Open",
            reporter_id=self.reporter.id,
        )
        self.db.add_all([self.whatsapp_ticket, self.other_ticket])
        self.db.flush()
        self.db.add_all(
            [
                TicketHistory(
                    ticket_id=self.whatsapp_ticket.id,
                    actor_id=self.reporter.id,
                    action="Ticket created via WhatsApp",
                    new_status="Open",
                ),
                TicketHistory(
                    ticket_id=self.other_ticket.id,
                    actor_id=self.reporter.id,
                    action="Ticket created",
                    new_status="Open",
                ),
            ]
        )
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def test_notification_feed_returns_whatsapp_tickets(self):
        notifications = list_whatsapp_ticket_notifications(
            limit=20,
            db=self.db,
            admin=self.admin,
        )

        self.assertEqual(len(notifications), 1)
        self.assertEqual(
            notifications[0]["ticket_id"],
            self.whatsapp_ticket.id,
        )
        self.assertEqual(
            notifications[0]["ticket_number"],
            "TD-WA-123",
        )
        self.assertEqual(
            notifications[0]["title"],
            "Wi-Fi keeps disconnecting",
        )

    def test_delete_user_removes_their_data_and_preserves_other_tickets(self):
        phone_number = "+15551234567"
        assigned_ticket = Ticket(
            ticket_number="TD-ASSIGNED-1",
            title="Assigned ticket",
            description="Owned by another reporter",
            category="Network",
            impact="Low",
            urgency="Low",
            priority="Low",
            status="Open",
            reporter_id=self.admin.id,
            assigned_technician_id=self.reporter.id,
        )
        self.db.add(assigned_ticket)
        self.db.flush()
        self.db.add_all(
            [
                WhatsAppContact(
                    phone_number=phone_number,
                    user_id=self.reporter.id,
                    linked_by_user_id=self.admin.id,
                ),
                WhatsAppConversation(
                    phone_number=phone_number,
                    step="description",
                    description="Current conversation",
                    ticket_id=self.whatsapp_ticket.id,
                ),
                WhatsAppMessage(
                    provider_message_id="wamid-delete-test",
                    phone_number=phone_number,
                    response_text="A saved reply",
                ),
                TicketNote(
                    ticket_id=assigned_ticket.id,
                    author_id=self.reporter.id,
                    note="Technician note",
                ),
                TicketHistory(
                    ticket_id=assigned_ticket.id,
                    actor_id=self.reporter.id,
                    action="Ticket updated",
                ),
            ]
        )
        self.db.commit()

        result = delete_user(
            user_id=self.reporter.id,
            db=self.db,
            admin=self.admin,
        )

        self.assertEqual(result["deleted_tickets"], 2)
        self.assertIsNone(self.db.get(User, self.reporter.id))
        self.assertEqual(
            self.db.query(Ticket).filter(Ticket.reporter_id == self.reporter.id).count(),
            0,
        )
        retained_ticket = self.db.get(Ticket, assigned_ticket.id)
        self.assertIsNotNone(retained_ticket)
        self.assertIsNone(retained_ticket.assigned_technician_id)
        self.assertEqual(
            self.db.query(TicketNote)
            .filter(TicketNote.author_id == self.reporter.id)
            .count(),
            0,
        )
        retained_history = (
            self.db.query(TicketHistory)
            .filter(TicketHistory.ticket_id == assigned_ticket.id)
            .one()
        )
        self.assertIsNone(retained_history.actor_id)
        self.assertIsNone(self.db.get(WhatsAppContact, phone_number))
        self.assertIsNone(self.db.get(WhatsAppConversation, phone_number))
        self.assertIsNone(
            self.db.get(WhatsAppMessage, "wamid-delete-test")
        )

    def test_admin_cannot_delete_themselves(self):
        with self.assertRaises(HTTPException) as error:
            delete_user(user_id=self.admin.id, db=self.db, admin=self.admin)

        self.assertEqual(error.exception.status_code, 400)
        self.assertIsNotNone(self.db.get(User, self.admin.id))

    def test_another_administrator_can_be_deleted(self):
        other_admin = User(
            full_name="Other Admin",
            email="other-admin@example.test",
            password_hash="unused",
            role="Administrator",
            approval_status="Approved",
        )
        self.db.add(other_admin)
        self.db.commit()
        self.db.refresh(other_admin)

        result = delete_user(
            user_id=other_admin.id,
            db=self.db,
            admin=self.admin,
        )

        self.assertEqual(result["id"], other_admin.id)
        self.assertIsNone(self.db.get(User, other_admin.id))
        self.assertIsNotNone(self.db.get(User, self.admin.id))

    def test_admin_can_lock_and_unlock_an_account(self):
        locked = update_user_active_status(
            request=AccountStatusRequest(is_active=False),
            user_id=self.reporter.id,
            db=self.db,
            admin=self.admin,
        )

        self.assertFalse(locked["is_active"])
        credentials = HTTPAuthorizationCredentials(
            scheme="Bearer",
            credentials=create_access_token(self.reporter),
        )
        with self.assertRaises(HTTPException) as error:
            get_current_user(credentials=credentials, db=self.db)
        self.assertEqual(error.exception.status_code, 401)

        unlocked = update_user_active_status(
            request=AccountStatusRequest(is_active=True),
            user_id=self.reporter.id,
            db=self.db,
            admin=self.admin,
        )
        self.assertTrue(unlocked["is_active"])
        self.assertIs(get_current_user(credentials=credentials, db=self.db), self.reporter)

    def test_admin_cannot_lock_their_own_account(self):
        with self.assertRaises(HTTPException) as error:
            update_user_active_status(
                request=AccountStatusRequest(is_active=False),
                user_id=self.admin.id,
                db=self.db,
                admin=self.admin,
            )

        self.assertEqual(error.exception.status_code, 400)
        self.assertTrue(self.admin.is_active)


if __name__ == "__main__":
    unittest.main()

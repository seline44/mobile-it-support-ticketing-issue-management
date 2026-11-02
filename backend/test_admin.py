import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from admin import list_whatsapp_ticket_notifications
from models import Ticket, TicketHistory, User


class AdminWhatsAppNotificationTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
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


if __name__ == "__main__":
    unittest.main()

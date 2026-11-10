import smtplib
import unittest
from unittest.mock import patch

from email_service import send_email


class EmailServiceTests(unittest.TestCase):
    @patch.dict(
        "os.environ",
        {
            "SMTP_USERNAME": "sender@example.test",
            "SMTP_PASSWORD": "test-password",
            "SMTP_FROM_EMAIL": "sender@example.test",
        },
        clear=False,
    )
    @patch("email_service.smtplib.SMTP")
    def test_rejected_recipient_is_reported_as_an_error(self, smtp_class):
        server = smtp_class.return_value.__enter__.return_value
        server.send_message.return_value = {
            "reporter@example.test": (550, b"Mailbox unavailable")
        }

        with self.assertRaises(smtplib.SMTPRecipientsRefused):
            send_email(
                "reporter@example.test",
                "Ticket received",
                "Your ticket was received.",
            )

    @patch.dict(
        "os.environ",
        {
            "SMTP_USERNAME": "sender@example.test",
            "SMTP_PASSWORD": "test-password",
            "SMTP_FROM_EMAIL": "sender@example.test",
        },
        clear=False,
    )
    @patch("email_service.smtplib.SMTP")
    def test_accepted_recipient_completes_without_error(self, smtp_class):
        server = smtp_class.return_value.__enter__.return_value
        server.send_message.return_value = {}

        send_email(
            "reporter@example.test",
            "Ticket received",
            "Your ticket was received.",
        )

        server.send_message.assert_called_once()


if __name__ == "__main__":
    unittest.main()

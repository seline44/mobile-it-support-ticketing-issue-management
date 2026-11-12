from datetime import datetime, timedelta, timezone
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from auth import (
    ForgotPasswordRequest,
    ResetPasswordRequest,
    forgot_password,
    hash_reset_token,
    password_hash,
    reset_password,
)
from database import Base, _database_url_from_environment
from models import User, WhatsAppMessage


class DatabaseConfigurationTests(unittest.TestCase):
    def test_database_url_uses_psycopg_driver(self):
        url = _database_url_from_environment(
            {"DATABASE_URL": "postgres://user:secret@db.example.test:5432/triagedesk"}
        )

        self.assertEqual(url.drivername, "postgresql+psycopg")
        self.assertEqual(url.host, "db.example.test")
        self.assertEqual(url.database, "triagedesk")

    def test_existing_postgresql_driver_is_preserved(self):
        url = _database_url_from_environment(
            {
                "DATABASE_URL": (
                    "postgresql+psycopg://user:secret@db.example.test:5432/triagedesk"
                )
            }
        )

        self.assertEqual(url.drivername, "postgresql+psycopg")

    def test_individual_database_variables_remain_supported(self):
        url = _database_url_from_environment(
            {
                "DB_USER": "reporter",
                "DB_PASSWORD": "secret",
                "DB_HOST": "localhost",
                "DB_PORT": "5433",
                "DB_NAME": "support",
            }
        )

        self.assertEqual(url.drivername, "postgresql+psycopg")
        self.assertEqual(url.username, "reporter")
        self.assertEqual(url.host, "localhost")
        self.assertEqual(url.port, 5433)
        self.assertEqual(url.database, "support")


class PasswordResetTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.user = User(
            full_name="Test Reporter",
            email="reset@example.com",
            password_hash=password_hash.hash("old-password-value"),
            role="Reporter",
            approval_status="Approved",
        )
        self.db.add(self.user)
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def test_reset_token_columns_belong_to_users(self):
        self.assertTrue(hasattr(User, "reset_token_hash"))
        self.assertTrue(hasattr(User, "reset_token_expires_at"))
        self.assertFalse(hasattr(WhatsAppMessage, "reset_token_hash"))
        self.assertFalse(hasattr(WhatsAppMessage, "reset_token_expires_at"))

    def test_reset_password_updates_password_and_consumes_token(self):
        token = "test-reset-token-value-with-enough-length"
        self.user.reset_token_hash = hash_reset_token(token)
        self.user.reset_token_expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=30
        )
        self.db.commit()

        response = reset_password(
            ResetPasswordRequest(
                token=token,
                new_password="new-password-value",
            ),
            self.db,
        )

        self.assertIn("successfully", response["message"])
        self.assertTrue(
            password_hash.verify("new-password-value", self.user.password_hash)
        )
        self.assertIsNone(self.user.reset_token_hash)
        self.assertIsNone(self.user.reset_token_expires_at)

    @patch.dict(
        "os.environ",
        {"PASSWORD_RESET_URL": "http://127.0.0.1:8000/reset-password"},
    )
    @patch("email_service.send_email")
    def test_forgot_password_does_not_duplicate_reset_path(self, send_email):
        response = forgot_password(
            ForgotPasswordRequest(email=self.user.email),
            self.db,
        )

        self.assertIn("password-reset link", response["message"])
        email_body = send_email.call_args.kwargs["body"]
        link = next(
            line for line in email_body.splitlines() if line.startswith("http")
        )
        parsed_link = urlsplit(link)

        self.assertEqual(parsed_link.path, "/reset-password")
        self.assertEqual(parsed_link.path.count("reset-password"), 1)
        self.assertIn("token", parse_qs(parsed_link.query))


if __name__ == "__main__":
    unittest.main()

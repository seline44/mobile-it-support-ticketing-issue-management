
from getpass import getpass

from email_service import send_email

recipient = input("Enter an email address you can access: ").strip()

if not recipient:
    raise SystemExit("An email address is required.")

try:
    send_email(
        to_email=recipient,
        subject="TriageDesk email configuration test",
        body=(
            "Hello!\n\n"
            "This is a test email from TriageDesk.\n"
            "If you received this message, email sending is configured.\n\n"
            "You can ignore this test message."
        ),
    )
    print("Email sent successfully. Check your inbox and spam folder.")
except Exception as exc:
    print(f"Email sending failed: {type(exc).__name__}: {exc}")

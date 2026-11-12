
from getpass import getpass

from sqlalchemy.orm import Session

from database import SessionLocal
from models import User
from pwdlib import PasswordHash

password_hash = PasswordHash.recommended()

INITIAL_USERS = [
    ("Reporter", "reporter@triagedesk.com", "Reporter"),
    ("Technician", "technician@triagedesk.com", "Technician"),
    ("Administrator", "admin@triagedesk.com", "Administrator"),
]


def main():
    db: Session = SessionLocal()

    try:
        for full_name, email, role in INITIAL_USERS:
            existing = db.query(User).filter(User.email == email).first()

            if existing:
                if (
                    role == "Administrator"
                    and existing.role == "Administrator"
                    and existing.approval_status == "Pending"
                ):
                    existing.approval_status = "Approved"
                    db.commit()
                    print(f"{email} administrator account approved.")
                    continue
                print(f"{email} already exists; skipping.")
                continue

            print(f"\nCreate account: {email} ({role})")
            password = getpass("Enter a password (minimum 12 characters): ")
            confirmation = getpass("Confirm password: ")

            if len(password) < 12:
                print("Password must contain at least 12 characters. Skipping.")
                continue

            if password != confirmation:
                print("Passwords do not match. Skipping.")
                continue

            user = User(
                full_name=full_name,
                email=email,
                password_hash=password_hash.hash(password),
                role=role,
                is_active=True,
                approval_status=(
                    "Approved" if role == "Administrator" else "Pending"
                ),
            )
            db.add(user)
            db.commit()

            print(f"Created {email} successfully.")

    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()

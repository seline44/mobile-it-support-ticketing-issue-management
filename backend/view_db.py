import sys
from database import SessionLocal
from models import (
    Ticket,
    TicketHistory,
    TicketNote,
    User,
    WhatsAppContact,
)


def print_header(title: str):
    print("\n" + "=" * 80)
    print(f" {title.upper()}")
    print("=" * 80)


def view_users(db):
    print_header("Users")
    users = db.query(User).order_by(User.id).all()
    if not users:
        print("No users found.")
        return
    print(f"{'ID':<4} | {'Role':<13} | {'Status':<10} | {'Email':<32} | {'Full Name'}")
    print("-" * 80)
    for u in users:
        print(f"{u.id:<4} | {u.role:<13} | {u.approval_status:<10} | {u.email:<32} | {u.full_name}")


def view_tickets(db):
    print_header("Tickets")
    tickets = db.query(Ticket).order_by(Ticket.id.desc()).all()
    if not tickets:
        print("No tickets found.")
        return
    print(f"{'ID':<4} | {'Ticket No':<12} | {'Status':<11} | {'Priority':<8} | {'Reporter':<20} | {'Title'}")
    print("-" * 80)
    for t in tickets:
        reporter = db.get(User, t.reporter_id)
        reporter_name = reporter.full_name if reporter else f"User #{t.reporter_id}"
        print(f"{t.id:<4} | {t.ticket_number:<12} | {t.status:<11} | {t.priority:<8} | {reporter_name[:20]:<20} | {t.title[:30]}")


def view_notes(db):
    print_header("Ticket Notes & Replies")
    notes = db.query(TicketNote).order_by(TicketNote.id.desc()).all()
    if not notes:
        print("No notes found.")
        return
    print(f"{'ID':<4} | {'Ticket ID':<9} | {'Scope':<10} | {'Author':<20} | {'Note Preview'}")
    print("-" * 80)
    for n in notes:
        author = db.get(User, n.author_id)
        author_name = author.full_name if author else f"User #{n.author_id}"
        scope = "Internal" if n.is_internal else "Public"
        note_text = n.note.replace("\n", " ")
        print(f"{n.id:<4} | {n.ticket_id:<9} | {scope:<10} | {author_name[:20]:<20} | {note_text[:30]}")


def view_history(db):
    print_header("Ticket Audit History")
    history = db.query(TicketHistory).order_by(TicketHistory.id.desc()).limit(30).all()
    if not history:
        print("No history entries found.")
        return
    print(f"{'ID':<4} | {'Ticket ID':<9} | {'Action':<30} | {'Details'}")
    print("-" * 80)
    for h in history:
        details = (h.details or "").replace("\n", " ")[:35]
        print(f"{h.id:<4} | {h.ticket_id:<9} | {h.action[:30]:<30} | {details}")


def view_whatsapp(db):
    print_header("WhatsApp Contacts")
    contacts = db.query(WhatsAppContact).all()
    if not contacts:
        print("No linked WhatsApp contacts found.")
    else:
        print(f"{'Phone Number':<18} | {'User ID':<8} | {'Linked User Name'}")
        print("-" * 60)
        for c in contacts:
            u = db.get(User, c.user_id)
            name = u.full_name if u else f"User #{c.user_id}"
            print(f"{c.phone_number:<18} | {c.user_id:<8} | {name}")


def main():
    db = SessionLocal()
    try:
        target = sys.argv[1].lower() if len(sys.argv) > 1 else "all"

        print_header("TriageDesk Database Overview")
        print(f"Total Users: {db.query(User).count()}")
        print(f"Total Tickets: {db.query(Ticket).count()}")
        print(f"Total Notes: {db.query(TicketNote).count()}")
        print(f"Total Audit History Entries: {db.query(TicketHistory).count()}")
        print(f"Total Linked WhatsApp Contacts: {db.query(WhatsAppContact).count()}")

        if target in ("all", "users"):
            view_users(db)
        if target in ("all", "tickets"):
            view_tickets(db)
        if target in ("all", "notes"):
            view_notes(db)
        if target in ("all", "history"):
            view_history(db)
        if target in ("all", "whatsapp"):
            view_whatsapp(db)

    finally:
        db.close()


if __name__ == "__main__":
    main()


from sqlalchemy import text
from database import engine

with engine.begin() as connection:
    connection.execute(
        text(
            "ALTER TABLE tickets "
            "ADD COLUMN IF NOT EXISTS resolution TEXT"
        )
    )
    connection.execute(
        text(
            "ALTER TABLE whatsapp_conversations "
            "ADD COLUMN IF NOT EXISTS title VARCHAR(200)"
        )
    )
    connection.execute(
        text(
            "ALTER TABLE whatsapp_conversations "
            "ADD COLUMN IF NOT EXISTS device VARCHAR(150)"
        )
    )
    connection.execute(
        text(
            "ALTER TABLE whatsapp_conversations "
            "ADD COLUMN IF NOT EXISTS ticket_id INTEGER "
            "REFERENCES tickets(id)"
        )
    )
    connection.execute(
        text(
            "ALTER TABLE ticket_notes "
            "ADD COLUMN IF NOT EXISTS is_internal BOOLEAN NOT NULL DEFAULT FALSE"
        )
    )
    connection.execute(
        text(
            "UPDATE ticket_notes SET is_internal = TRUE "
            "WHERE author_id IN ("
            "SELECT id FROM users WHERE role IN ('Technician', 'Administrator')"
            ")"
        )
    )

print(
    "Database migration completed: tickets.resolution and "
    "WhatsApp conversation fields and private staff notes are available."
)

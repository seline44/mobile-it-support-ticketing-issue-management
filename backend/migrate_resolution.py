
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

print(
    "Database migration completed: tickets.resolution and "
    "WhatsApp conversation title/device fields are available."
)

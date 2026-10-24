
from sqlalchemy import text
from database import engine

with engine.begin() as connection:
    connection.execute(
        text(
            "ALTER TABLE tickets "
            "ADD COLUMN IF NOT EXISTS resolution TEXT"
        )
    )

print("Database migration completed: tickets.resolution is available.")

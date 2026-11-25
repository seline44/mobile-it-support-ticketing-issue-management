from sqlalchemy import text

from database import engine


with engine.begin() as connection:
    connection.execute(
        text(
            "ALTER TABLE tickets "
            "ADD COLUMN IF NOT EXISTS attachment_name VARCHAR(255)"
        )
    )

print("Database migration completed: attachment_name column added to tickets table.")

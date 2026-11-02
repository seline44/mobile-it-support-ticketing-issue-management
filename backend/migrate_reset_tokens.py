from sqlalchemy import text

from database import engine


with engine.begin() as connection:
    connection.execute(
        text(
            "ALTER TABLE users "
            "ADD COLUMN IF NOT EXISTS reset_token_hash VARCHAR(64)"
        )
    )
    connection.execute(
        text(
            "ALTER TABLE users "
            "ADD COLUMN IF NOT EXISTS reset_token_expires_at TIMESTAMP WITH TIME ZONE"
        )
    )

print("Database migration completed: user password-reset tokens are available.")

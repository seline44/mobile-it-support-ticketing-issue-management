from sqlalchemy import text

from database import Base, engine
import models  # Registers all database models with Base.

if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
    with engine.begin() as connection:
        connection.execute(
            text(
                "ALTER TABLE tickets "
                "ADD COLUMN IF NOT EXISTS attachment_name VARCHAR(255)"
            )
        )
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
    print("TriageDesk database tables created and migrated successfully.")

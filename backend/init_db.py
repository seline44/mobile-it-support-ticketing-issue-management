
from database import Base, engine
import models  # Registers all database models with Base.

if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
    print("TriageDesk database tables created successfully.")

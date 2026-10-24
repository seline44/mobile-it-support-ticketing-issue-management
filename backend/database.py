
import os
from collections.abc import Mapping

from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, make_url
from sqlalchemy.orm import DeclarativeBase, sessionmaker

load_dotenv()


def _database_url_from_environment(environ: Mapping[str, str]) -> URL:
    connection_string = environ.get("DATABASE_URL")
    if connection_string:
        parsed_url = make_url(connection_string)
        if parsed_url.drivername in {"postgres", "postgresql"}:
            parsed_url = parsed_url.set(drivername="postgresql+psycopg")
        return parsed_url

    return URL.create(
        drivername="postgresql+psycopg",
        username=environ.get("DB_USER", "postgres"),
        password=environ.get("DB_PASSWORD"),
        host=environ.get("DB_HOST", "localhost"),
        port=int(environ.get("DB_PORT", "5432")),
        database=environ.get("DB_NAME", "triagedesk"),
    )


database_url = _database_url_from_environment(os.environ)

engine = create_engine(database_url, pool_pre_ping=True)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

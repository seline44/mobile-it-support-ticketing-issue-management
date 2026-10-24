import getpass
import os
import shutil
import subprocess
import tempfile
from collections.abc import Mapping
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import MetaData, Table, create_engine, inspect, select, text
from sqlalchemy.engine import URL, make_url

load_dotenv()

from database import database_url
import models


def _postgres_url(raw_url: str) -> URL:
    url = make_url(raw_url)
    if url.drivername in {"postgres", "postgresql"}:
        url = url.set(drivername="postgresql+psycopg")
    if url.drivername != "postgresql+psycopg":
        raise ValueError("The destination must be a PostgreSQL connection URL.")
    if not url.host or not url.database:
        raise ValueError("The destination URL must include a host and database.")
    return url


def _postgres_environment(
    base_environment: Mapping[str, str], url: URL
) -> dict[str, str]:
    environment = dict(base_environment)
    if url.password:
        environment["PGPASSWORD"] = url.password
    else:
        environment.pop("PGPASSWORD", None)

    sslmode = url.query.get("sslmode")
    if sslmode:
        environment["PGSSLMODE"] = str(sslmode)
    return environment


def _find_postgres_tool(tool_name: str, server_version: str) -> str:
    executable = shutil.which(tool_name)
    if executable:
        return executable

    major_version = server_version.split(".", maxsplit=1)[0]
    program_files = os.environ.get("ProgramFiles", r"C:\Program Files")
    candidates = (
        Path(program_files) / "PostgreSQL" / major_version / "bin" / f"{tool_name}.exe",
        Path(program_files) / "PostgreSQL" / "bin" / f"{tool_name}.exe",
    )
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    raise RuntimeError(
        f"{tool_name} was not found. Install PostgreSQL command-line tools "
        f"for major version {major_version} or add them to PATH."
    )


def _table_counts(engine) -> dict[str, int]:
    metadata = MetaData()
    counts = {}
    for table_name in inspect(engine).get_table_names(schema="public"):
        table = Table(table_name, metadata, schema="public", autoload_with=engine)
        with engine.connect() as connection:
            counts[table_name] = connection.execute(
                select(text("count(*)")).select_from(table)
            ).scalar_one()
    return counts


def _run_tool(
    arguments: list[str],
    environment: dict[str, str],
    passwords: tuple[str | None, ...],
) -> None:
    result = subprocess.run(
        arguments,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        error = result.stderr
        for password in passwords:
            if password:
                error = error.replace(password, "[redacted]")
        raise RuntimeError(error.strip() or "PostgreSQL migration command failed.")


def migrate() -> None:
    if database_url.drivername != "postgresql+psycopg":
        raise RuntimeError("The configured source database must be PostgreSQL.")

    raw_target_url = getpass.getpass(
        "Paste the Render External Database URL (input hidden): "
    )
    target_url = _postgres_url(raw_target_url)
    if (
        target_url.host == database_url.host
        and target_url.port == database_url.port
        and target_url.database == database_url.database
    ):
        raise RuntimeError("The destination matches the configured source database.")

    source_engine = create_engine(database_url, pool_pre_ping=True)
    target_engine = create_engine(target_url, pool_pre_ping=True)

    try:
        with source_engine.connect() as source_connection:
            source_version = source_connection.execute(
                text("SHOW server_version")
            ).scalar_one()
        with target_engine.connect() as target_connection:
            target_version = target_connection.execute(
                text("SHOW server_version")
            ).scalar_one()
            existing_tables = target_connection.execute(
                text(
                    "SELECT count(*) FROM information_schema.tables "
                    "WHERE table_schema = 'public' AND table_type = 'BASE TABLE'"
                )
            ).scalar_one()

        if existing_tables:
            raise RuntimeError(
                "The Render destination is not empty. Refusing to overwrite it."
            )
        if int(target_version.split(".", maxsplit=1)[0]) < int(
            source_version.split(".", maxsplit=1)[0]
        ):
            raise RuntimeError(
                "The Render PostgreSQL version must be the same as or newer "
                "than the source database."
            )

        source_counts = _table_counts(source_engine)
        print(f"Source PostgreSQL: {source_version}")
        print(f"Destination PostgreSQL: {target_version}")
        print(f"Source tables: {len(source_counts)}")
        print(f"Source users: {source_counts.get('users', 0)}")
        print(f"Source tickets: {source_counts.get('tickets', 0)}")
        print(f"Destination: {target_url.host}/{target_url.database}")
        confirmation = input(
            "This copies source data to the empty destination. "
            "Type MIGRATE to continue: "
        )
        if confirmation != "MIGRATE":
            print("Migration cancelled. No data was copied.")
            return

        source_tool_environment = _postgres_environment(
            os.environ, database_url
        )
        target_tool_environment = _postgres_environment(os.environ, target_url)
        pg_dump = _find_postgres_tool("pg_dump", source_version)
        pg_restore = _find_postgres_tool("pg_restore", source_version)

        with tempfile.TemporaryDirectory(prefix="triagedesk-db-migration-") as folder:
            dump_path = str(Path(folder) / "triagedesk.dump")
            dump_arguments = [
                pg_dump,
                "--format=custom",
                "--no-owner",
                "--no-privileges",
                "--no-password",
                "--file",
                dump_path,
                "--host",
                database_url.host or "",
                "--port",
                str(database_url.port or 5432),
                "--username",
                database_url.username or "",
                "--dbname",
                database_url.database or "",
            ]
            _run_tool(
                dump_arguments,
                source_tool_environment,
                (database_url.password,),
            )

            restore_arguments = [
                pg_restore,
                "--exit-on-error",
                "--single-transaction",
                "--no-owner",
                "--no-privileges",
                "--no-password",
                "--host",
                target_url.host or "",
                "--port",
                str(target_url.port or 5432),
                "--username",
                target_url.username or "",
                "--dbname",
                target_url.database or "",
                dump_path,
            ]
            _run_tool(
                restore_arguments,
                target_tool_environment,
                (target_url.password,),
            )

        models.Base.metadata.create_all(bind=target_engine)
        with target_engine.begin() as connection:
            connection.execute(
                text(
                    "ALTER TABLE tickets "
                    "ADD COLUMN IF NOT EXISTS resolution TEXT"
                )
            )

        destination_counts = _table_counts(target_engine)
        mismatches = {
            table_name: (count, destination_counts.get(table_name))
            for table_name, count in source_counts.items()
            if destination_counts.get(table_name) != count
        }
        if mismatches:
            raise RuntimeError(
                f"Migration completed but row counts did not match: {mismatches}"
            )

        print("Migration completed and source table row counts match.")
        print(f"Users migrated: {destination_counts.get('users', 0)}")
        print(f"Tickets migrated: {destination_counts.get('tickets', 0)}")
        print("The original source database was not changed.")
    finally:
        target_engine.dispose()
        source_engine.dispose()


if __name__ == "__main__":
    migrate()

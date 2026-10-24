import unittest

from database import _database_url_from_environment


class DatabaseConfigurationTests(unittest.TestCase):
    def test_database_url_uses_psycopg_driver(self):
        url = _database_url_from_environment(
            {"DATABASE_URL": "postgres://user:secret@db.example.test:5432/triagedesk"}
        )

        self.assertEqual(url.drivername, "postgresql+psycopg")
        self.assertEqual(url.host, "db.example.test")
        self.assertEqual(url.database, "triagedesk")

    def test_existing_postgresql_driver_is_preserved(self):
        url = _database_url_from_environment(
            {
                "DATABASE_URL": (
                    "postgresql+psycopg://user:secret@db.example.test:5432/triagedesk"
                )
            }
        )

        self.assertEqual(url.drivername, "postgresql+psycopg")

    def test_individual_database_variables_remain_supported(self):
        url = _database_url_from_environment(
            {
                "DB_USER": "reporter",
                "DB_PASSWORD": "secret",
                "DB_HOST": "localhost",
                "DB_PORT": "5433",
                "DB_NAME": "support",
            }
        )

        self.assertEqual(url.drivername, "postgresql+psycopg")
        self.assertEqual(url.username, "reporter")
        self.assertEqual(url.host, "localhost")
        self.assertEqual(url.port, 5433)
        self.assertEqual(url.database, "support")


if __name__ == "__main__":
    unittest.main()

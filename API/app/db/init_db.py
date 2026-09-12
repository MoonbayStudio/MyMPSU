"""Create the database schema required by a fresh MyMPSU installation."""

from app.db import models  # noqa: F401 - registers every SQLAlchemy model
from app.db.session import Base, engine
from app.services.schema_bootstrap_service import ensure_runtime_feature_tables


def initialize_database() -> None:
    """Create missing tables, then apply the legacy compatibility bootstrap."""
    Base.metadata.create_all(bind=engine)
    ensure_runtime_feature_tables(engine)


if __name__ == "__main__":
    initialize_database()

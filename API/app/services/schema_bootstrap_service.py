from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.db.models import (
    AppSetting,
    AuthProvider,
    Badge,
    GroupChangeRequest,
    SystemNotice,
    UserBadge,
    UserSession,
)


def _run_schema_statement(conn, statement: str) -> None:
    try:
        conn.execute(text(statement))
        conn.commit()
    except Exception:
        conn.rollback()


def _ensure_user_auth_columns(conn) -> None:
    user_columns = [
        "ALTER TABLE users ADD COLUMN apple_email VARCHAR",
        "ALTER TABLE users ADD COLUMN contact_email VARCHAR",
        "ALTER TABLE users ADD COLUMN contact_email_verified BOOLEAN NOT NULL DEFAULT FALSE",
        "ALTER TABLE users ADD COLUMN contact_email_verified_at TIMESTAMP",
        "ALTER TABLE users ADD COLUMN pending_contact_email VARCHAR",
        "ALTER TABLE users ADD COLUMN pending_contact_email_token_hash VARCHAR",
        "ALTER TABLE users ADD COLUMN pending_contact_email_expires_at TIMESTAMP",
        "ALTER TABLE users ADD COLUMN password_hash VARCHAR",
        "ALTER TABLE users ADD COLUMN password_created_at TIMESTAMP",
        "ALTER TABLE users ADD COLUMN password_updated_at TIMESTAMP",
        "ALTER TABLE users ADD COLUMN last_password_reset_at TIMESTAMP",
        "ALTER TABLE users ADD COLUMN password_reset_token_hash VARCHAR",
        "ALTER TABLE users ADD COLUMN password_reset_expires_at TIMESTAMP",
        "ALTER TABLE users ADD COLUMN updated_at TIMESTAMP",
    ]
    for statement in user_columns:
        _run_schema_statement(conn, statement)

    user_indexes = [
        "CREATE INDEX IF NOT EXISTS ix_users_contact_email ON users (contact_email)",
        "CREATE INDEX IF NOT EXISTS ix_users_pending_contact_email_token_hash ON users (pending_contact_email_token_hash)",
        "CREATE INDEX IF NOT EXISTS ix_users_password_reset_token_hash ON users (password_reset_token_hash)",
    ]
    for statement in user_indexes:
        _run_schema_statement(conn, statement)


def ensure_runtime_feature_tables(engine: Engine) -> None:
    AuthProvider.__table__.create(bind=engine, checkfirst=True)
    AppSetting.__table__.create(bind=engine, checkfirst=True)
    SystemNotice.__table__.create(bind=engine, checkfirst=True)
    UserSession.__table__.create(bind=engine, checkfirst=True)
    Badge.__table__.create(bind=engine, checkfirst=True)
    UserBadge.__table__.create(bind=engine, checkfirst=True)
    GroupChangeRequest.__table__.create(bind=engine, checkfirst=True)

    # Migrations for UserSettings
    with engine.connect() as conn:
        _ensure_user_auth_columns(conn)
        _run_schema_statement(
            conn,
            "ALTER TABLE user_settings ADD COLUMN schedule_cache_weeks INTEGER NOT NULL DEFAULT 2",
        )
        _run_schema_statement(
            conn,
            "ALTER TABLE user_settings ADD COLUMN live_activity_enabled BOOLEAN NOT NULL DEFAULT TRUE",
        )

    with Session(engine) as db:
        seed_system_badges(db)


def seed_system_badges(db: Session) -> None:
    system_badges = [
        {
            "code": "first_tester",
            "title": "Первый тестер",
            "description": "Выдан участникам первого закрытого тестирования MyMPSU",
            "icon_name": "badge_first_tester",
            "rarity": "epic",
        },
        {
            "code": "active_tester",
            "title": "Активный тестер",
            "description": "За активное участие в поиске багов и улучшении приложения",
            "icon_name": "badge_active_tester",
            "rarity": "rare",
        },
    ]

    for badge_data in system_badges:
        existing = db.query(Badge).filter(Badge.code == badge_data["code"]).first()
        if not existing:
            badge = Badge(**badge_data)
            db.add(badge)
    db.commit()

import os


def _parse_bool_env(var_name: str, default: bool) -> bool:
    raw_value = os.getenv(var_name)
    if raw_value is None:
        return default

    normalized = raw_value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False

    return default


def _parse_int_env(var_name: str, default: int) -> int:
    raw_value = os.getenv(var_name)
    if raw_value is None:
        return default

    try:
        return int(raw_value.strip())
    except (TypeError, ValueError):
        return default

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_AUDIENCES = [
    "MoonbayStudio.MyMPSU",
    "ru.moonbay.mympsu.web",
    "ru.moonbaystudio.mympsu.web"
]
if os.getenv("APPLE_CLIENT_ID"):
    APPLE_AUDIENCES.append(os.getenv("APPLE_CLIENT_ID"))

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is not set")

JWT_SECRET = os.getenv("JWT_SECRET")
if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET is not configured")

MPGU_SCHEDULE_API_BASE_URL = os.getenv(
    "MPGU_SCHEDULE_API_BASE_URL",
    ""
).rstrip("/")

MPGU_SCHEDULE_API_PATH = os.getenv(
    "MPGU_SCHEDULE_API_PATH",
    "/schedule/v1/schedule"
)

FRONTEND_BASE_URL = os.getenv(
    "FRONTEND_BASE_URL",
    "https://mympsu.moonbaystudio.ru"
).rstrip("/")

CORS_ORIGINS = [
    origin.strip().rstrip("/")
    for origin in os.getenv(
        "CORS_ORIGINS",
        "https://mympsu.moonbaystudio.ru",
    ).split(",")
    if origin.strip()
]

MPGU_SCHEDULE_API_TIMEOUT_SECONDS = 15

ADMIN_EMAILS = os.getenv("ADMIN_EMAILS", "")
ADMIN_EMAIL_SET = {
    email.strip().lower()
    for email in ADMIN_EMAILS.split(",")
    if email.strip()
}

OWNER_EMAILS = os.getenv("OWNER_EMAILS", "")
OWNER_EMAILS_SET = {
    email.strip().lower()
    for email in OWNER_EMAILS.split(",")
    if email.strip()
}

PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 128
INVALID_PASSWORD_LOGIN_DETAIL = "Invalid email or password"
APPLE_RELAY_EMAIL_DOMAIN = "privaterelay.appleid.com"
EMAIL_VERIFICATION_EXPIRES_HOURS = 24

SMTP_HOST = os.getenv("SMTP_HOST", "mail.hosting.reg.ru")
SMTP_PORT = _parse_int_env("SMTP_PORT", 465)
SMTP_USERNAME = os.getenv(
    "SMTP_USERNAME",
    "security@mympsu.moonbaystudio.ru",
)
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
SMTP_FROM_EMAIL = os.getenv(
    "SMTP_FROM_EMAIL",
    "security@mympsu.moonbaystudio.ru",
)
SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "Мой МПГУ")
SMTP_USE_TLS = _parse_bool_env("SMTP_USE_TLS", True)
SMTP_TIMEOUT_SECONDS = _parse_int_env("SMTP_TIMEOUT_SECONDS", 60)
SMTP_FALLBACK_PORTS = [
    int(port.strip())
    for port in os.getenv("SMTP_FALLBACK_PORTS", "587").split(",")
    if port.strip().isdigit()
]
EMAIL_LOGO_URL = os.getenv(
    "EMAIL_LOGO_URL",
    f"{FRONTEND_BASE_URL}/img/logo.png",
)

GOOGLE_CLIENT_IDS = [
    cid.strip()
    for cid in os.getenv("GOOGLE_CLIENT_IDS", "").split(",")
    if cid.strip()
]
if os.getenv("GOOGLE_WEB_CLIENT_ID"):
    GOOGLE_CLIENT_IDS.append(os.getenv("GOOGLE_WEB_CLIENT_ID"))
if os.getenv("GOOGLE_ANDROID_CLIENT_ID"):
    GOOGLE_CLIENT_IDS.append(os.getenv("GOOGLE_ANDROID_CLIENT_ID"))
if os.getenv("GOOGLE_IOS_CLIENT_ID"):
    GOOGLE_CLIENT_IDS.append(os.getenv("GOOGLE_IOS_CLIENT_ID"))

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "").strip()
AI_PROVIDER = os.getenv(
    "AI_PROVIDER",
    "openrouter" if OPENROUTER_API_KEY else "ollama",
).strip().lower()
if AI_PROVIDER not in {"ollama", "openrouter"}:
    raise RuntimeError("AI_PROVIDER must be 'ollama' or 'openrouter'")

OPENROUTER_BASE_URL = os.getenv(
    "OPENROUTER_BASE_URL",
    "https://openrouter.ai/api/v1",
).rstrip("/")
OPENROUTER_MODEL = os.getenv(
    "OPENROUTER_MODEL",
    "openrouter/free",
).strip()
OPENROUTER_SITE_URL = os.getenv(
    "OPENROUTER_SITE_URL",
    FRONTEND_BASE_URL,
).strip()
OPENROUTER_APP_NAME = os.getenv(
    "OPENROUTER_APP_NAME",
    "MyMPSU",
).strip()

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "").rstrip("/")
ENABLE_AI_AGENT = _parse_bool_env("ENABLE_AI_AGENT", True)
if ENABLE_AI_AGENT:
    if AI_PROVIDER == "openrouter" and not OPENROUTER_API_KEY:
        raise RuntimeError("OPENROUTER_API_KEY is not configured")
    if AI_PROVIDER == "ollama" and not OLLAMA_BASE_URL:
        raise RuntimeError("OLLAMA_BASE_URL is not configured")

PELIKASHA_MODEL = os.getenv(
    "PELIKASHA_MODEL",
    "pelikasha:latest"
)
PERSONA_THEME = os.getenv("PERSONA_THEME", "default")
ENABLE_HOMEWORK_MODULE = _parse_bool_env("ENABLE_HOMEWORK_MODULE", True)
ENABLE_ROLE_REQUESTS_MODULE = _parse_bool_env(
    "ENABLE_ROLE_REQUESTS_MODULE",
    True,
)
ENABLE_ADMIN_ROLE_MANAGEMENT_MODULE = _parse_bool_env(
    "ENABLE_ADMIN_ROLE_MANAGEMENT_MODULE",
    True,
)

ROLE_PERMISSIONS = {
    "admin": {
        "manage_roles",
        "unlimited_ai",
    },
    "moderator": {
        "manage_roles",
    },
    "tester": {
        "unlimited_ai",
    },
}

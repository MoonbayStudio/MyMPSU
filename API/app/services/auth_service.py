import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from email.utils import formataddr
from html import escape
from typing import Any, Optional

import requests
from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import (
    APPLE_KEYS_URL,
    EMAIL_LOGO_URL,
    EMAIL_VERIFICATION_EXPIRES_HOURS,
    FRONTEND_BASE_URL,
    SMTP_FROM_EMAIL,
    SMTP_FROM_NAME,
    SMTP_FALLBACK_PORTS,
    SMTP_HOST,
    SMTP_PASSWORD,
    SMTP_PORT,
    SMTP_TIMEOUT_SECONDS,
    SMTP_USERNAME,
    SMTP_USE_TLS,
)
from app.db.models import User
from app.services.user_profile_service import is_apple_relay_email, normalize_email
from app.utils.common import normalize_optional_string
from app.utils.email import EMAIL_VERIFICATION_PATTERN


apple_keys_cache = None
EMAIL_DELIVERY_ERROR_DETAIL = "Failed to send verification email"


def get_apple_keys():
    global apple_keys_cache

    if apple_keys_cache is None:
        response = requests.get(APPLE_KEYS_URL, timeout=30)
        response.raise_for_status()
        apple_keys_cache = response.json()["keys"]

    return apple_keys_cache


def validate_contact_email(value: Any) -> str:
    normalized = normalize_email(value)

    if (
        normalized is None
        or len(normalized) > 254
        or EMAIL_VERIFICATION_PATTERN.fullmatch(normalized) is None
    ):
        raise HTTPException(status_code=400, detail="Invalid email")

    if is_apple_relay_email(normalized):
        raise HTTPException(
            status_code=400,
            detail="Apple relay email cannot be used as contact email",
        )

    return normalized


def hash_contact_email_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def ensure_contact_email_available(
    db: Session,
    email: str,
    user_id: int,
) -> None:
    existing_user = db.query(User).filter(
        func.lower(User.contact_email) == email,
        User.id != user_id,
    ).first()

    if existing_user is not None:
        raise HTTPException(status_code=400, detail="Email is already in use")


def create_pending_contact_email_token(user: User, email: str) -> str:
    token = secrets.token_urlsafe(32)
    now = datetime.now(timezone.utc)

    user.pending_contact_email = email
    user.pending_contact_email_token_hash = hash_contact_email_token(token)
    user.pending_contact_email_expires_at = now + timedelta(hours=EMAIL_VERIFICATION_EXPIRES_HOURS)
    user.updated_at = now

    return token


def apply_apple_email_to_user(
    user: User,
    apple_sub: str,
    apple_email: Optional[str],
) -> None:
    normalized_apple_email = normalize_email(apple_email)

    user.apple_sub = apple_sub

    if normalized_apple_email is None:
        return

    user.apple_email = normalized_apple_email

    if normalize_email(user.email) is None:
        user.email = normalized_apple_email

    if normalize_email(user.contact_email) is None and not is_apple_relay_email(normalized_apple_email):
        user.contact_email = normalized_apple_email
        user.contact_email_verified = False
        user.contact_email_verified_at = None


def apply_google_email_to_user(
    user: User,
    google_email: Optional[str],
) -> None:
    normalized_google_email = normalize_email(google_email)

    if normalized_google_email is None:
        return

    if normalize_email(user.email) is None:
        user.email = normalized_google_email

    if normalize_email(user.contact_email) is None:
        user.contact_email = normalized_google_email
        user.contact_email_verified = True  # Google emails are verified
        user.contact_email_verified_at = datetime.now(timezone.utc)
    elif normalize_email(user.contact_email) == normalized_google_email:
        user.contact_email_verified = True
        user.contact_email_verified_at = datetime.now(timezone.utc)


def clear_pending_contact_email(user: User) -> None:
    user.pending_contact_email = None
    user.pending_contact_email_token_hash = None
    user.pending_contact_email_expires_at = None


def create_pending_email_verification_code(user: User, email: str) -> str:
    code = f"{secrets.randbelow(1000000):06d}"
    now = datetime.now(timezone.utc)

    user.pending_contact_email = email
    user.pending_contact_email_token_hash = hash_contact_email_token(code)
    user.pending_contact_email_expires_at = now + timedelta(minutes=15)
    user.updated_at = now

    return code


def create_password_reset_code(user: User) -> str:
    code = f"{secrets.randbelow(1000000):06d}"
    now = datetime.now(timezone.utc)

    user.password_reset_token_hash = hash_contact_email_token(code)
    user.password_reset_expires_at = now + timedelta(minutes=15)
    user.updated_at = now

    return code


def _raise_email_delivery_error(
    *,
    action: str,
    email: str,
    error: Optional[Exception] = None,
) -> None:
    if error is not None:
        print(
            "Email delivery failed: "
            f"action={action}, email={email}, error={error}",
            flush=True,
        )

    raise HTTPException(status_code=502, detail=EMAIL_DELIVERY_ERROR_DETAIL)


def _build_email_layout(
    *,
    title: str,
    body_html: str,
    logo_url: Optional[str],
) -> str:
    support_url = f"{FRONTEND_BASE_URL}/support/"
    safe_logo_url = escape(logo_url, quote=True) if logo_url else None
    logo_html = (
        f'<img src="{safe_logo_url}" width="40" height="40" alt="Мой МПГУ" '
        'style="display:block;border:0;border-radius:10px;">'
        if safe_logo_url
        else (
            '<div style="width:40px;height:40px;border-radius:10px;'
            'background:#3358ff;"></div>'
        )
    )

    return f"""<!doctype html>
<html lang="ru">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{escape(title)}</title>
  </head>
  <body style="margin:0;padding:0;background:#ffffff;color:#34446c;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;background:#ffffff;">
      <tr>
        <td align="center" style="padding:24px 16px 10px;">
          <table role="presentation" width="580" cellspacing="0" cellpadding="0" style="width:580px;max-width:100%;border-collapse:collapse;">
            <tr>
              <td style="padding:0 24px 28px;">
                <table role="presentation" cellspacing="0" cellpadding="0" style="border-collapse:collapse;">
                  <tr>
                    <td style="vertical-align:middle;padding-right:10px;">{logo_html}</td>
                    <td style="vertical-align:middle;font-family:Arial,Helvetica,sans-serif;font-size:28px;line-height:34px;font-weight:700;color:#151a2f;">
                      Мой МПГУ
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="border:12px solid #dfe6ef;background:#ffffff;padding:36px 34px;font-family:Arial,Helvetica,sans-serif;font-size:17px;line-height:1.58;color:#34446c;">
                {body_html}
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:6px 18px 0;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#728096;">
                Если у вас есть вопросы, вы можете обратиться в наш раздел
                <a href="{escape(support_url)}" style="color:#0969ff;text-decoration:underline;">«Помощь»</a><br>
                Спасибо за то, что вы с нами! Искренне ваш, Мой МПГУ.
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:28px 18px 0;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#728096;">
                Это письмо содержит важную информацию.<br>
                Оно обязательное и не требует подписки.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>"""


async def _send_template_email(
    *,
    action: str,
    email: str,
    subject: str,
    text: str,
    body_html: str,
    require_configured: bool = False,
    raise_on_failure: bool = True,
) -> None:
    password = normalize_optional_string(SMTP_PASSWORD)

    if password is None:
        if require_configured:
            raise HTTPException(status_code=500, detail="Email service is not configured")
        print(f"DEV MODE: Email action={action}, to={email}, subject={subject}", flush=True)
        print(text, flush=True)
        return

    try:
        import aiosmtplib
    except ImportError as error:
        if raise_on_failure:
            _raise_email_delivery_error(action=action, email=email, error=error)
        print(
            f"Email delivery skipped: action={action}, email={email}, error={error}",
            flush=True,
        )
        return

    message = EmailMessage()
    message["From"] = formataddr((SMTP_FROM_NAME, SMTP_FROM_EMAIL))
    message["To"] = email
    message["Subject"] = subject
    message.set_content(text)
    message.add_alternative(
        _build_email_layout(
            title=subject,
            body_html=body_html,
            logo_url=normalize_optional_string(EMAIL_LOGO_URL),
        ),
        subtype="html",
    )

    last_error: Optional[Exception] = None
    attempted_ports = []
    for port in [SMTP_PORT, *SMTP_FALLBACK_PORTS]:
        if port in attempted_ports:
            continue
        attempted_ports.append(port)

        use_tls = SMTP_USE_TLS if port == SMTP_PORT else port == 465
        start_tls = None if use_tls else port in {25, 587}

        try:
            await aiosmtplib.send(
                message,
                hostname=SMTP_HOST,
                port=port,
                username=SMTP_USERNAME,
                password=password,
                use_tls=use_tls,
                start_tls=start_tls,
                timeout=SMTP_TIMEOUT_SECONDS,
            )
            return
        except Exception as error:
            last_error = error
            print(
                "Email delivery attempt failed: "
                f"action={action}, email={email}, host={SMTP_HOST}, port={port}, "
                f"use_tls={use_tls}, start_tls={start_tls}, error={error}",
                flush=True,
            )

    if raise_on_failure:
        _raise_email_delivery_error(action=action, email=email, error=last_error)
    print(
        f"Email delivery failed without blocking: action={action}, email={email}, error={last_error}",
        flush=True,
    )


def _code_html(code: str) -> str:
    return (
        '<div style="margin:20px 0 22px;padding:18px 20px;border:1px solid #dfe6ef;'
        'background:#f7f9fc;text-align:center;">'
        f'<span style="font-family:Arial,Helvetica,sans-serif;font-size:34px;'
        f'letter-spacing:7px;font-weight:700;color:#17213d;">{escape(code)}</span>'
        "</div>"
    )


async def send_password_reset_code(email: str, code: str) -> None:
    body_html = (
        "<p style=\"margin:0 0 16px;\"><strong>Вы запросили сброс пароля в Мой МПГУ.</strong></p>"
        "<p style=\"margin:0 0 12px;\">Введите этот код в приложении:</p>"
        f"{_code_html(code)}"
        "<p style=\"margin:0;\">Код действует 15 минут. "
        "Если вы не запрашивали сброс пароля, просто проигнорируйте письмо.</p>"
    )
    text = (
        "Вы запросили сброс пароля в Мой МПГУ.\n"
        f"Код для сброса пароля: {code}\n"
        "Код действует 15 минут."
    )
    await _send_template_email(
        action="password_reset_code",
        email=email,
        subject="Сброс пароля в Мой МПГУ",
        text=text,
        body_html=body_html,
    )


async def send_email_verification_code(email: str, code: str) -> None:
    body_html = (
        "<p style=\"margin:0 0 16px;\"><strong>Подтвердите email для аккаунта Мой МПГУ.</strong></p>"
        "<p style=\"margin:0 0 12px;\">Введите этот код в приложении:</p>"
        f"{_code_html(code)}"
        "<p style=\"margin:0;\">Код действует 15 минут. Никому не передавайте его.</p>"
    )
    text = (
        "Подтвердите email для аккаунта Мой МПГУ.\n"
        f"Ваш код подтверждения: {code}\n"
        "Код действует 15 минут. Никому не передавайте его."
    )
    await _send_template_email(
        action="signup_code",
        email=email,
        subject="Код подтверждения Мой МПГУ",
        text=text,
        body_html=body_html,
    )


async def send_contact_email_verification(email: str, token: str) -> None:
    verification_link = f"{FRONTEND_BASE_URL}/verify-email?token={token}"
    safe_link = escape(verification_link)
    body_html = (
        "<p style=\"margin:0 0 16px;\"><strong>Подтвердите контактную почту Мой МПГУ.</strong></p>"
        "<p style=\"margin:0 0 16px;\">Откройте эту ссылку, чтобы завершить подтверждение email:</p>"
        f'<p style="margin:0 0 16px;word-break:break-all;"><a href="{safe_link}" '
        f'style="color:#0969ff;text-decoration:underline;">{safe_link}</a></p>'
        "<p style=\"margin:0;\">Ссылка действует 24 часа.</p>"
    )
    text = (
        "Подтвердите контактную почту Мой МПГУ:\n"
        f"{verification_link}\n\n"
        "Ссылка действует 24 часа."
    )
    await _send_template_email(
        action="contact_email_link",
        email=email,
        subject="Подтвердите email в Мой МПГУ",
        text=text,
        body_html=body_html,
        require_configured=True,
    )


def _format_security_datetime(value: Optional[datetime]) -> str:
    normalized = normalize_datetime(value) or datetime.now(timezone.utc)
    try:
        from zoneinfo import ZoneInfo

        normalized = normalized.astimezone(ZoneInfo("Europe/Moscow"))
    except Exception:
        normalized = normalized.astimezone(timezone.utc)

    return normalized.strftime("%Y-%m-%d %H:%M:%S")


async def send_new_device_login_notification(
    *,
    email: str,
    occurred_at: datetime,
    ip_address: Optional[str] = None,
    device_name: Optional[str] = None,
    platform: Optional[str] = None,
    app_version: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> None:
    timestamp = _format_security_datetime(occurred_at)
    ip_label = ip_address or "неизвестного IP"
    device_parts = [
        part
        for part in [
            normalize_optional_string(device_name),
            normalize_optional_string(platform),
            f"версия {app_version}" if normalize_optional_string(app_version) else None,
        ]
        if part
    ]
    device_label = ", ".join(device_parts)
    user_agent_label = normalize_optional_string(user_agent)

    device_html = (
        f'<p style="margin:0 0 16px;">Устройство: <strong>{escape(device_label)}</strong>.</p>'
        if device_label
        else ""
    )
    user_agent_html = (
        f'<p style="margin:0 0 16px;">User-Agent: '
        f'<span style="word-break:break-all;">{escape(user_agent_label)}</span></p>'
        if user_agent_label and not device_label
        else ""
    )
    body_html = (
        f'<p style="margin:0 0 16px;"><strong>{escape(timestamp)} зафиксирован вход '
        f'в ваш аккаунт с использованием IP {escape(ip_label)}.</strong></p>'
        f"{device_html}"
        f"{user_agent_html}"
        "<p style=\"margin:0 0 16px;\">Вы получили данное уведомление, потому что "
        "вход выполнен с устройства, которое ранее не использовалось для этого аккаунта.</p>"
        "<p style=\"margin:0;\">Если вы не входили в аккаунт, пожалуйста, немедленно "
        "свяжитесь с технической поддержкой Мой МПГУ.</p>"
    )
    text_lines = [
        f"{timestamp} зафиксирован вход в ваш аккаунт с использованием IP {ip_label}.",
    ]
    if device_label:
        text_lines.append(f"Устройство: {device_label}.")
    elif user_agent_label:
        text_lines.append(f"User-Agent: {user_agent_label}")
    text_lines.extend(
        [
            "Вы получили данное уведомление, потому что вход выполнен с нового устройства.",
            "Если это были не вы, свяжитесь с технической поддержкой Мой МПГУ.",
        ]
    )

    await _send_template_email(
        action="new_device_login",
        email=email,
        subject="Новый вход в аккаунт Мой МПГУ",
        text="\n".join(text_lines),
        body_html=body_html,
        raise_on_failure=False,
    )


async def send_password_security_notification(
    *,
    email: str,
    action: str,
    occurred_at: datetime,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> None:
    timestamp = _format_security_datetime(occurred_at)
    action_label = "создан" if action == "created" else "изменен"
    subject = (
        "Пароль создан в Мой МПГУ"
        if action == "created"
        else "Пароль изменен в Мой МПГУ"
    )
    ip_label = ip_address or "неизвестного IP"
    user_agent_label = normalize_optional_string(user_agent)
    user_agent_html = (
        f'<p style="margin:0 0 16px;">User-Agent: '
        f'<span style="word-break:break-all;">{escape(user_agent_label)}</span></p>'
        if user_agent_label
        else ""
    )
    body_html = (
        f'<p style="margin:0 0 16px;"><strong>{escape(timestamp)} пароль вашего '
        f'аккаунта был {escape(action_label)} с использованием IP {escape(ip_label)}.</strong></p>'
        f"{user_agent_html}"
        "<p style=\"margin:0 0 16px;\">Вы получили это уведомление, потому что "
        "изменились настройки входа в ваш аккаунт.</p>"
        "<p style=\"margin:0;\">Если вы не выполняли это действие, пожалуйста, "
        "немедленно свяжитесь с технической поддержкой Мой МПГУ.</p>"
    )
    text_lines = [
        f"{timestamp} пароль вашего аккаунта был {action_label} с использованием IP {ip_label}.",
    ]
    if user_agent_label:
        text_lines.append(f"User-Agent: {user_agent_label}")
    text_lines.extend(
        [
            "Вы получили это уведомление, потому что изменились настройки входа в ваш аккаунт.",
            "Если это были не вы, свяжитесь с технической поддержкой Мой МПГУ.",
        ]
    )

    await _send_template_email(
        action=f"password_{action}",
        email=email,
        subject=subject,
        text="\n".join(text_lines),
        body_html=body_html,
        raise_on_failure=False,
    )


def normalize_datetime(value: Optional[datetime]) -> Optional[datetime]:
    if value is None:
        return None

    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)

    return value.astimezone(timezone.utc)

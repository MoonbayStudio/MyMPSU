import hashlib
import inspect
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Form
from fastapi.responses import RedirectResponse
from jose import jwt
from sqlalchemy import func
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.core.config import APPLE_AUDIENCES, INVALID_PASSWORD_LOGIN_DETAIL
from app.core.deps import get_current_user
from app.core.rate_limit import limiter
from app.core.security import (
    create_session_token,
    hash_password,
    validate_password_strength,
    verify_password,
)
from app.db.models import AuthProvider, User
from app.db.session import get_db
from app.schemas.user import (
    AppleLoginRequest,
    AppleLoginResponse,
    AppleUserResponse,
    ContactEmailRequest,
    EmailChangeRequest,
    EmailConfirmRequest,
    GoogleLoginRequest,
    PasswordChangeRequest,
    PasswordLoginRequest,
    PasswordSetupRequest,
    ResetPasswordConfirmRequest,
    ResetPasswordRequest,
    SuccessResponse,
    SignupRequest,
    SignupVerifyRequest,
)
from app.services.auth_service import (
    apply_apple_email_to_user,
    apply_google_email_to_user,
    clear_pending_contact_email,
    create_password_reset_code,
    create_pending_contact_email_token,
    create_pending_email_verification_code,
    ensure_contact_email_available,
    get_apple_keys,
    hash_contact_email_token,
    normalize_datetime,
    send_new_device_login_notification,
    send_password_security_notification,
    send_contact_email_verification,
    send_email_verification_code,
    send_password_reset_code,
    validate_contact_email,
)
from app.services.user_profile_service import build_user_response, normalize_email, user_has_password
from app.services.user_sessions_service import (
    SessionTrackingInput,
    should_notify_new_login_device,
    track_login_session,
)
from app.utils.common import normalize_optional_string
from app.utils.google_auth import verify_google_token


router = APIRouter()


def _email_signup_sub(email: str) -> str:
    email_hash = hashlib.sha256(email.encode("utf-8")).hexdigest()[:20]
    return f"email:{email_hash}"


def _mask_login_email(email: str) -> str:
    local_part, separator, domain = email.partition("@")
    if not separator:
        return "***"
    if not local_part:
        masked_local_part = "***"
    elif len(local_part) <= 2:
        masked_local_part = f"{local_part[:1]}***"
    else:
        masked_local_part = f"{local_part[:2]}***"
    return f"{masked_local_part}@{domain}"


async def _maybe_await_delivery(result) -> None:
    if inspect.isawaitable(result):
        await result


def _verified_notification_email(user: User) -> str | None:
    notification_email = normalize_email(user.contact_email) or normalize_email(user.email)
    if notification_email is None or not user.contact_email_verified:
        return None
    return notification_email


async def _track_login_session_and_notify(
    *,
    request: Request,
    db: Session,
    user: User,
    session_token: str,
    device_id: str | None,
    device_name: str | None,
    platform: str | None,
    app_version: str | None,
) -> None:
    payload = SessionTrackingInput(
        session_token=session_token,
        device_id=device_id,
        device_name=device_name,
        platform=platform,
        app_version=app_version,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    should_notify = should_notify_new_login_device(
        db=db,
        user_id=user.id,
        payload=payload,
    )
    session = track_login_session(
        db=db,
        user_id=user.id,
        payload=payload,
    )

    if not should_notify:
        return

    notification_email = _verified_notification_email(user)
    if notification_email is None:
        return

    await _maybe_await_delivery(
        send_new_device_login_notification(
            email=notification_email,
            occurred_at=session.last_seen_at,
            ip_address=session.ip_address,
            device_name=session.device_name,
            platform=session.platform,
            app_version=session.app_version,
            user_agent=session.user_agent,
        )
    )


@limiter.limit("10/minute")
@router.post("/auth/google", response_model=AppleLoginResponse)
async def google_login(
    request: Request,
    data: GoogleLoginRequest,
    db: Session = Depends(get_db),
):
    payload = verify_google_token(data.idToken)
    google_sub = payload["sub"]
    google_email = normalize_email(payload.get("email"))

    # Try to find user by existing Google provider or sub
    provider = db.query(AuthProvider).filter(
        AuthProvider.provider == "google",
        AuthProvider.provider_user_id == google_sub,
    ).first()

    user = None
    if provider:
        user = db.query(User).filter(User.id == provider.user_id).first()

    if user is None and google_email:
        # Fallback: find by verified contact email for account linking
        user = db.query(User).filter(
            func.lower(User.contact_email) == google_email,
            User.contact_email_verified == True
        ).first()

    if user is None:
        # Create new user
        # Note: apple_sub is mandatory in current schema.
        # Using "google:{sub}" as a placeholder if no apple_sub exists to satisfy uniqueness/nullability
        user = User(
            apple_sub=f"google:{google_sub}",
            email=google_email,
            display_name=payload.get("name"),
        )
        db.add(user)
        db.flush()
    else:
        # Update existing user info if missing
        if not user.display_name and payload.get("name"):
            user.display_name = payload.get("name")

    apply_google_email_to_user(
        user=user,
        google_email=google_email,
    )
    user.updated_at = datetime.now(timezone.utc)

    if provider is None:
        provider = AuthProvider(
            user_id=user.id,
            provider="google",
            provider_user_id=google_sub,
            email=google_email,
        )
        db.add(provider)
    else:
        if google_email:
            provider.email = google_email

    db.commit()
    db.refresh(user)

    session_token = create_session_token(user.id)
    await _track_login_session_and_notify(
        request=request,
        db=db,
        user=user,
        session_token=session_token,
        device_id=data.deviceId,
        device_name=data.deviceName,
        platform=data.platform,
        app_version=data.appVersion,
    )

    return {
        "token": session_token,
        "user": build_user_response(db=db, user=user),
    }


@limiter.limit("10/minute")
@router.post("/me/providers/google", response_model=AppleUserResponse)
async def link_google_provider(
    request: Request,
    data: GoogleLoginRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    print(f"Google provider link started: user_id={current_user.id}")
    payload = verify_google_token(data.idToken)
    google_sub = payload["sub"]
    google_email = normalize_email(payload.get("email"))

    provider = db.query(AuthProvider).filter(
        AuthProvider.provider == "google",
        AuthProvider.provider_user_id == google_sub,
    ).first()

    if provider is not None and provider.user_id != current_user.id:
        raise HTTPException(
            status_code=409,
            detail="Google account is already linked to another user",
        )

    apply_google_email_to_user(
        user=current_user,
        google_email=google_email,
    )
    current_user.updated_at = datetime.now(timezone.utc)

    if provider is None:
        provider = AuthProvider(
            user_id=current_user.id,
            provider="google",
            provider_user_id=google_sub,
            email=google_email,
        )
        db.add(provider)
    else:
        provider.user_id = current_user.id
        if google_email is not None:
            provider.email = google_email

    db.commit()
    db.refresh(current_user)

    return build_user_response(db=db, user=current_user)


@limiter.limit("3/15minute")
@router.post("/me/email/change-request")
async def email_change_request(
    request: Request,
    data: EmailChangeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    normalized_email = validate_contact_email(data.email)
    ensure_contact_email_available(
        db=db,
        email=normalized_email,
        user_id=current_user.id,
    )

    code = create_pending_email_verification_code(
        user=current_user,
        email=normalized_email,
    )

    db.commit()
    await _maybe_await_delivery(
        send_email_verification_code(email=normalized_email, code=code)
    )

    return {"status": "verification_required"}


@router.post("/me/email/confirm", response_model=AppleUserResponse)
async def email_confirm(
    data: EmailConfirmRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    normalized_code = normalize_optional_string(data.code)

    if normalized_code is None:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    code_hash = hash_contact_email_token(normalized_code)

    if current_user.pending_contact_email_token_hash != code_hash:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    expires_at = normalize_datetime(current_user.pending_contact_email_expires_at)
    now = datetime.now(timezone.utc)

    if expires_at is None or expires_at <= now:
        clear_pending_contact_email(current_user)
        current_user.updated_at = now
        db.commit()
        raise HTTPException(status_code=400, detail="Verification code expired")

    pending_email = validate_contact_email(current_user.pending_contact_email)
    ensure_contact_email_available(
        db=db,
        email=pending_email,
        user_id=current_user.id,
    )

    current_user.contact_email = pending_email
    current_user.contact_email_verified = True
    current_user.contact_email_verified_at = now
    current_user.email = pending_email
    clear_pending_contact_email(current_user)
    current_user.updated_at = now

    db.commit()
    db.refresh(current_user)

    return build_user_response(db=db, user=current_user)


@limiter.limit("10/minute")
@router.post("/auth/contact-email/request", response_model=SuccessResponse)
async def request_contact_email(
    request: Request,
    data: ContactEmailRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    normalized_email = validate_contact_email(data.email)
    ensure_contact_email_available(
        db=db,
        email=normalized_email,
        user_id=current_user.id,
    )

    token = create_pending_contact_email_token(
        user=current_user,
        email=normalized_email,
    )

    db.commit()
    await _maybe_await_delivery(
        send_contact_email_verification(email=normalized_email, token=token)
    )

    return {"success": True}


@limiter.limit("30/minute")
@router.get("/auth/contact-email/verify", response_model=SuccessResponse)
async def verify_contact_email(
    request: Request,
    token: str,
    db: Session = Depends(get_db),
):
    normalized_token = normalize_optional_string(token)

    if normalized_token is None:
        raise HTTPException(status_code=400, detail="Invalid verification token")

    token_hash = hash_contact_email_token(normalized_token)
    user = db.query(User).filter(User.pending_contact_email_token_hash == token_hash).first()

    if user is None:
        raise HTTPException(status_code=400, detail="Invalid verification token")

    expires_at = normalize_datetime(user.pending_contact_email_expires_at)
    now = datetime.now(timezone.utc)

    if expires_at is None or expires_at <= now:
        clear_pending_contact_email(user)
        user.updated_at = now
        db.commit()
        raise HTTPException(status_code=400, detail="Verification token expired")

    pending_email = validate_contact_email(user.pending_contact_email)
    ensure_contact_email_available(
        db=db,
        email=pending_email,
        user_id=user.id,
    )

    user.contact_email = pending_email
    user.contact_email_verified = True
    user.contact_email_verified_at = now
    user.email = pending_email
    clear_pending_contact_email(user)
    user.updated_at = now

    db.commit()

    return {"success": True}


@limiter.limit("10/minute")
@router.post(
    "/auth/contact-email/resend-verification",
    response_model=SuccessResponse,
)
async def resend_contact_email_verification(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    pending_email = normalize_email(current_user.pending_contact_email)
    contact_email = normalize_email(current_user.contact_email)

    if pending_email is not None:
        target_email = pending_email
    elif contact_email is not None and not current_user.contact_email_verified:
        target_email = contact_email
    else:
        raise HTTPException(status_code=400, detail="No email verification pending")

    target_email = validate_contact_email(target_email)
    ensure_contact_email_available(
        db=db,
        email=target_email,
        user_id=current_user.id,
    )

    token = create_pending_contact_email_token(
        user=current_user,
        email=target_email,
    )

    db.commit()
    await _maybe_await_delivery(
        send_contact_email_verification(email=target_email, token=token)
    )

    return {"success": True}


@limiter.limit("10/minute")
@router.post("/me/password/create")
async def password_create(
    request: Request,
    data: PasswordSetupRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    normalized_email = normalize_email(current_user.contact_email)

    if normalized_email is None:
        raise HTTPException(
            status_code=400,
            detail="Verified contact email is required to set password",
        )

    if not current_user.contact_email_verified:
        raise HTTPException(
            status_code=400,
            detail="Verified contact email is required to set password",
        )

    if user_has_password(current_user):
        raise HTTPException(status_code=400, detail="Password already set")

    validate_password_strength(data.password)

    now = datetime.now(timezone.utc)
    current_user.email = normalized_email
    current_user.password_hash = hash_password(data.password)
    current_user.password_created_at = now
    current_user.password_updated_at = now
    current_user.updated_at = now

    db.commit()

    await _maybe_await_delivery(
        send_password_security_notification(
            email=normalized_email,
            action="created",
            occurred_at=now,
            ip_address=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
        )
    )

    return {"status": "password_created"}


@router.post("/auth/signup")
async def signup(
    request: Request,
    data: SignupRequest,
    db: Session = Depends(get_db),
):
    normalized_email = validate_contact_email(data.email)
    validate_password_strength(data.password)
    display_name = normalize_optional_string(data.displayName)
    if display_name is None:
        raise HTTPException(status_code=400, detail="Display name is required")

    signup_sub = _email_signup_sub(normalized_email)
    user = db.query(User).filter(User.apple_sub == signup_sub).first()
    now = datetime.now(timezone.utc)

    if user is not None:
        if user.contact_email_verified:
            raise HTTPException(status_code=400, detail="Email is already in use")

        ensure_contact_email_available(db, normalized_email, user.id)
        user.display_name = display_name
        user.password_hash = hash_password(data.password)
        if user.password_created_at is None:
            user.password_created_at = now
        user.password_updated_at = now
        user.updated_at = now
    else:
        ensure_contact_email_available(db, normalized_email, None)
        user = User(
            apple_sub=signup_sub,
            display_name=display_name,
            password_hash=hash_password(data.password),
            password_created_at=now,
            password_updated_at=now,
        )
        db.add(user)
        db.flush()

    code = create_pending_email_verification_code(
        user=user,
        email=normalized_email,
    )

    db.commit()
    await _maybe_await_delivery(
        send_email_verification_code(email=normalized_email, code=code)
    )

    return {"status": "verification_required", "email": normalized_email}


@router.post("/auth/signup/verify", response_model=AppleLoginResponse)
async def signup_verify(
    request: Request,
    data: SignupVerifyRequest,
    db: Session = Depends(get_db),
):
    normalized_email = normalize_email(data.email)
    if not normalized_email:
        raise HTTPException(status_code=400, detail="Invalid email")

    code_hash = hash_contact_email_token(data.code)

    user = db.query(User).filter(
        User.apple_sub == _email_signup_sub(normalized_email),
        User.pending_contact_email == normalized_email,
        User.pending_contact_email_token_hash == code_hash
    ).first()

    if not user:
        raise HTTPException(status_code=400, detail="Invalid verification code or email")

    expires_at = normalize_datetime(user.pending_contact_email_expires_at)
    if expires_at is None or expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Verification code expired")

    ensure_contact_email_available(db, normalized_email, user.id)

    # Verify and activate
    user.contact_email = normalized_email
    user.contact_email_verified = True
    user.contact_email_verified_at = datetime.now(timezone.utc)
    user.email = normalized_email
    clear_pending_contact_email(user)
    user.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(user)

    session_token = create_session_token(user.id)
    await _track_login_session_and_notify(
        request=request,
        db=db,
        user=user,
        session_token=session_token,
        device_id=data.deviceId,
        device_name=data.deviceName,
        platform=data.platform,
        app_version=data.appVersion,
    )

    return {
        "token": session_token,
        "user": build_user_response(db=db, user=user),
    }


@limiter.limit("10/minute")
@router.post("/auth/login", response_model=AppleLoginResponse)
async def password_login(
    request: Request,
    data: PasswordLoginRequest,
    db: Session = Depends(get_db),
):
    normalized_email = normalize_email(data.email)

    if normalized_email is None:
        print("Password login rejected: reason=invalid_email")
        raise HTTPException(status_code=401, detail=INVALID_PASSWORD_LOGIN_DETAIL)

    masked_email = _mask_login_email(normalized_email)
    user = db.query(User).filter(
        func.lower(User.contact_email) == normalized_email,
        User.contact_email_verified == True,
    ).first()

    if user is None:
        print(f"Password login rejected: reason=verified_contact_not_found, email={masked_email}")
        raise HTTPException(status_code=401, detail=INVALID_PASSWORD_LOGIN_DETAIL)

    if not user_has_password(user):
        print(f"Password login rejected: reason=password_not_set, email={masked_email}")
        raise HTTPException(status_code=401, detail=INVALID_PASSWORD_LOGIN_DETAIL)

    password_hash = user.password_hash or ""

    if not verify_password(data.password, password_hash):
        print(f"Password login rejected: reason=password_mismatch, email={masked_email}")
        raise HTTPException(status_code=401, detail=INVALID_PASSWORD_LOGIN_DETAIL)

    print(f"Password login accepted: user_id={user.id}")

    session_token = create_session_token(user.id)
    await _track_login_session_and_notify(
        request=request,
        db=db,
        user=user,
        session_token=session_token,
        device_id=data.deviceId,
        device_name=data.deviceName,
        platform=data.platform,
        app_version=data.appVersion,
    )

    return {
        "token": session_token,
        "user": build_user_response(db=db, user=user),
    }


@limiter.limit("10/minute")
@router.post("/me/password/change", response_model=SuccessResponse)
async def password_change(
    request: Request,
    data: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_password_hash = normalize_optional_string(current_user.password_hash)

    if current_password_hash is None:
        raise HTTPException(status_code=400, detail="Password is not set")

    if not verify_password(data.currentPassword, current_password_hash):
        raise HTTPException(status_code=401, detail="Current password is incorrect")

    validate_password_strength(data.newPassword)

    now = datetime.now(timezone.utc)
    current_user.password_hash = hash_password(data.newPassword)
    current_user.password_updated_at = now
    current_user.updated_at = now

    db.commit()

    notification_email = _verified_notification_email(current_user)
    if notification_email is not None:
        await _maybe_await_delivery(
            send_password_security_notification(
                email=notification_email,
                action="changed",
                occurred_at=now,
                ip_address=request.client.host if request.client else None,
                user_agent=request.headers.get("user-agent"),
            )
        )

    return {"success": True}


@limiter.limit("5/15minute")
@router.post("/auth/password/reset-request")
async def password_reset_request(
    request: Request,
    data: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    normalized_email = normalize_email(data.email)

    if normalized_email is not None:
        user = db.query(User).filter(
            func.lower(User.contact_email) == normalized_email,
            User.contact_email_verified == True,
        ).first()

        if user is not None:
            code = create_password_reset_code(user)
            db.commit()
            await _maybe_await_delivery(
                send_password_reset_code(normalized_email, code)
            )

    return {"status": "ok"}


@limiter.limit("5/15minute")
@router.post("/auth/password/reset-confirm")
async def password_reset_confirm(
    request: Request,
    data: ResetPasswordConfirmRequest,
    db: Session = Depends(get_db),
):
    normalized_code = normalize_optional_string(data.code)

    if normalized_code is None:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    code_hash = hash_contact_email_token(normalized_code)
    user = db.query(User).filter(User.password_reset_token_hash == code_hash).first()

    if user is None:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    expires_at = normalize_datetime(user.password_reset_expires_at)
    now = datetime.now(timezone.utc)

    if expires_at is None or expires_at <= now:
        user.password_reset_token_hash = None
        user.password_reset_expires_at = None
        user.updated_at = now
        db.commit()
        raise HTTPException(status_code=400, detail="Verification code expired")

    validate_password_strength(data.newPassword)

    user.password_hash = hash_password(data.newPassword)
    user.last_password_reset_at = now
    user.password_updated_at = now
    user.password_reset_token_hash = None
    user.password_reset_expires_at = None
    user.updated_at = now

    db.commit()

    return {"success": True}


@limiter.limit("10/minute")
@router.post("/auth/apple", response_model=AppleLoginResponse)
async def apple_login(
    request: Request,
    data: AppleLoginRequest,
    db: Session = Depends(get_db),
):
    try:
        headers = jwt.get_unverified_header(data.identityToken)
        kid = headers["kid"]

        matching_key = None

        for key in get_apple_keys():
            if key["kid"] == kid:
                matching_key = key
                break

        if not matching_key:
            raise HTTPException(status_code=401, detail="Apple public key not found")

        payload = jwt.decode(
            data.identityToken,
            matching_key,
            algorithms=["RS256"],
            options={"verify_aud": False},
            issuer="https://appleid.apple.com",
        )

        token_audience = payload.get("aud")
        is_valid_audience = False

        if isinstance(token_audience, str):
            is_valid_audience = token_audience in APPLE_AUDIENCES
        elif isinstance(token_audience, list):
            is_valid_audience = any(
                isinstance(aud, str) and aud in APPLE_AUDIENCES for aud in token_audience
            )

        if not is_valid_audience:
            raise HTTPException(status_code=401, detail="Invalid Apple token audience")

        apple_sub = payload["sub"]
        token_email = payload.get("email")

        # Determine email provided in this request
        provided_email = normalize_email(token_email or data.email)

        provider = db.query(AuthProvider).filter(
            AuthProvider.provider == "apple",
            AuthProvider.provider_user_id == apple_sub,
        ).first()

        user = None

        if provider:
            user = db.query(User).filter(User.id == provider.user_id).first()

        if user is None:
            user = db.query(User).filter(User.apple_sub == apple_sub).first()

        if user is None:
            # New user registration
            user = User(
                apple_sub=apple_sub,
                email=provided_email,
                apple_email=provided_email,
                display_name=data.fullName,
            )

            db.add(user)
            db.flush()
            apple_email = provided_email
        else:
            # Existing user login
            if not user.display_name and data.fullName:
                user.display_name = data.fullName

            # If email is missing, use the one from database
            apple_email = provided_email or user.apple_email or user.email

        apply_apple_email_to_user(
            user=user,
            apple_sub=apple_sub,
            apple_email=apple_email,
        )
        user.updated_at = datetime.now(timezone.utc)

        if provider is None:
            provider = AuthProvider(
                user_id=user.id,
                provider="apple",
                provider_user_id=apple_sub,
                email=apple_email,
            )

            db.add(provider)
        else:
            provider.user_id = user.id

            if apple_email is not None:
                provider.email = apple_email

        db.commit()
        db.refresh(user)

        session_token = create_session_token(user.id)
        await _track_login_session_and_notify(
            request=request,
            db=db,
            user=user,
            session_token=session_token,
            device_id=data.deviceId,
            device_name=data.deviceName,
            platform=data.platform,
            app_version=data.appVersion,
        )

        return {
            "token": session_token,
            "user": build_user_response(db=db, user=user),
        }

    except HTTPException:
        raise
    except jwt.ExpiredSignatureError:
        print("Apple auth error: expired token")
        raise HTTPException(status_code=401, detail="Apple auth failed: expired token")
    except jwt.JWTClaimsError as error:
        print(f"Apple auth error: invalid claims (audience/issuer): {error}")
        raise HTTPException(status_code=401, detail="Apple auth failed: invalid claims")
    except jwt.JWTError as error:
        print(f"Apple auth error: invalid signature or parsing failed: {error}")
        raise HTTPException(status_code=401, detail="Apple auth failed: invalid token")
    except Exception as error:
        print(f"Apple auth error: {type(error).__name__} - {error}")
        raise HTTPException(status_code=401, detail="Apple auth failed")


@router.post("/auth/apple/callback")
async def apple_callback(
    request: Request,
    id_token: str = Form(...),
    code: str = Form(None),
    user: str = Form(None),  # Apple присылает JSON со сведениями о пользователе только при первой авторизации
    db: Session = Depends(get_db),
):
    """
    Обработчик для Sign in with Apple (Web/Android).
    Apple отправляет id_token методом POST (form_post).
    """
    import json

    # 1. Парсим данные пользователя, если они есть
    full_name = None
    if user:
        try:
            user_data = json.loads(user)
            name_info = user_data.get("name", {})
            first_name = name_info.get("firstName", "")
            last_name = name_info.get("lastName", "")
            full_name = f"{first_name} {last_name}".strip() or None
        except:
            pass

    # 2. Подготавливаем данные для существующей функции apple_login
    login_data = AppleLoginRequest(
        identityToken=id_token,
        fullName=full_name,
        # Для Android/Web Flow параметры устройства пустые или стандартные
        deviceId="android-web-flow",
        deviceName="Android Browser",
        platform="android",
        appVersion="1.0"
    )

    # 3. Вызываем авторизацию
    try:
        result = await apple_login(request, login_data, db)
        token = result["token"]
        # 4. Редиректим обратно в мобильное приложение через Deep Link
        return RedirectResponse(url=f"mympsu://auth?token={token}", status_code=303)
    except Exception as e:
        print(f"Apple callback error: {e}")
        # В случае ошибки возвращаем в приложение с ошибкой
        return RedirectResponse(url=f"mympsu://auth?error=auth_failed", status_code=303)

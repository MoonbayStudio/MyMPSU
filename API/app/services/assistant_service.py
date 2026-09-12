import re
import zoneinfo
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.db.models import UsageLimit, User
from app.schemas.assistant import AssistantChatRequest, AssistantChatResponse
from app.services.assistant_policy_service import (
    PLAN_LIMITS,
    get_plan_message_length_limit,
    get_user_plan,
)
from app.services.ai_provider_service import (
    AIProviderResponseError,
    generate_assistant_reply,
)
from app.services.persona_service import load_persona_prompt
from app.services.runtime_settings_service import get_runtime_setting_value
from app.utils.dates import parse_schedule_date
from app.utils.schedule_context import (
    SCHEDULE_SESSION_CACHE_TTL,
    build_schedule_context_rules,
    build_schedule_instructions,
    resolve_ai_schedule_context,
)


async def run_assistant_chat(
    request: Request,
    data: AssistantChatRequest,
    db: Session,
    current_user: Optional[User],
):
    user_id = current_user.id if current_user else None
    plan = get_user_plan(user_id, db)

    ai_enabled_setting = get_runtime_setting_value(
        db=db,
        key="AI_ENABLED",
    )
    if not bool(ai_enabled_setting):
        return JSONResponse(
            status_code=503,
            content={
                "detail": "AI assistant is temporarily disabled",
                "remaining": 0,
                "plan": plan,
            },
        )

    max_length = get_plan_message_length_limit(plan)
    if len(data.message) > max_length:
        raise HTTPException(
            status_code=400,
            detail=f"Сообщение слишком длинное. Лимит для вашего тарифа: {max_length} символов.",
        )

    limit = PLAN_LIMITS.get(plan, 3)
    runtime_daily_limit = get_runtime_setting_value(
        db=db,
        key="AI_DAILY_LIMIT",
    )
    if (
        isinstance(runtime_daily_limit, int)
        and runtime_daily_limit > 0
        and limit != -1
    ):
        limit = min(limit, runtime_daily_limit)

    runtime_schedule_ttl = get_runtime_setting_value(
        db=db,
        key="SCHEDULE_CACHE_TTL_SECONDS",
    )
    if isinstance(runtime_schedule_ttl, int) and runtime_schedule_ttl > 0:
        schedule_cache_ttl_seconds = runtime_schedule_ttl
    else:
        schedule_cache_ttl_seconds = int(SCHEDULE_SESSION_CACHE_TTL.total_seconds())

    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    if user_id is not None:
        usage_record = db.query(UsageLimit).filter(
            UsageLimit.user_id == user_id,
            UsageLimit.date == today_str,
            UsageLimit.feature == "assistant_chat",
        ).first()
    else:
        client_ip = request.client.host if request.client else "unknown"
        usage_record = db.query(UsageLimit).filter(
            UsageLimit.client_ip == client_ip,
            UsageLimit.date == today_str,
            UsageLimit.feature == "assistant_chat",
        ).first()

    used_count = usage_record.used_count if usage_record else 0

    if limit != -1 and used_count >= limit:
        return JSONResponse(
            status_code=429,
            content={
                "detail": "Лимит сообщений на сегодня исчерпан",
                "remaining": 0,
                "plan": plan,
            },
        )

    try:
        system_prompt = load_persona_prompt(data.persona)
    except RuntimeError as error:
        error_message = str(error)
        if "not found" in error_message:
            raise HTTPException(
                status_code=400,
                detail="Unknown persona",
            ) from error
        raise HTTPException(
            status_code=500,
            detail=error_message,
        ) from error

    group_id = data.groupId
    selected_date = data.targetDate
    date_source = None
    original_phrase = None
    schedule_intent = False

    if data.context:
        if group_id is None:
            group_id = data.context.selectedGroupId
        if selected_date is None:
            selected_date = data.context.selectedDate

    tz = zoneinfo.ZoneInfo("Europe/Moscow")
    now = datetime.now(tz)
    parsed_date_info = parse_schedule_date(data.message, now)
    if parsed_date_info:
        schedule_intent = True
        selected_date, date_source, original_phrase = parsed_date_info

    user_key = (
        str(user_id)
        if user_id is not None
        else f"anon:{request.client.host if request.client else 'unknown'}"
    )

    (
        schedule_text,
        lessons_count,
        _schedule_source,
        _saved_session_cache,
        _session_cache_hit,
        has_schedule_context,
        _cache_fresh,
        group_id,
        selected_date,
    ) = resolve_ai_schedule_context(
        user_key=user_key,
        conversation_id=data.conversationId,
        group_id=group_id,
        target_date=selected_date,
        cached_schedule=data.cachedSchedule,
        schedule_intent=schedule_intent,
        date_source=date_source,
        original_phrase=original_phrase,
        message=data.message,
        now=now,
        session_cache_ttl_seconds=schedule_cache_ttl_seconds,
    )

    schedule_rules = build_schedule_instructions(
        schedule_intent=schedule_intent,
        target_date=selected_date,
        date_source=date_source,
        lessons_count=lessons_count,
        original_phrase=original_phrase,
    )
    schedule_context_rules = build_schedule_context_rules(
        has_schedule_context=has_schedule_context,
        lessons_count=lessons_count,
        target_date=selected_date,
    )

    prompt_parts = [system_prompt]
    if schedule_rules:
        prompt_parts.append(schedule_rules)
    if schedule_context_rules:
        prompt_parts.append(schedule_context_rules)
    if schedule_text:
        prompt_parts.append(f"Контекст расписания:\n{schedule_text}")
    full_system_prompt = "\n\n".join(prompt_parts)
    full_prompt_preview = full_system_prompt.replace("\n", "\\n")[:100]
    print(
        f"[AI Persona] full_system_prompt_preview={full_prompt_preview}",
        flush=True,
    )

    messages = [
        {"role": "system", "content": full_system_prompt},
        {"role": "user", "content": data.message},
    ]

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            reply = await generate_assistant_reply(client, messages)

            if re.search(r"[\u4e00-\u9fff]", reply):
                print("[AI Language Guard] chinese_detected=true", flush=True)
                print("[AI Language Guard] retry_generation=true", flush=True)

                messages.append({"role": "assistant", "content": reply})
                messages.append(
                    {"role": "user", "content": "Повтори ответ только на русском языке."}
                )

                reply = await generate_assistant_reply(client, messages)

    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="AI assistant timeout")
    except httpx.HTTPStatusError as error:
        if error.response.status_code == 401:
            detail = "OpenRouter API key is invalid"
        elif error.response.status_code == 429:
            detail = "AI provider rate limit reached"
        else:
            detail = "AI provider rejected the request"
        raise HTTPException(status_code=502, detail=detail) from error
    except httpx.RequestError as error:
        raise HTTPException(status_code=502, detail="AI assistant is unavailable") from error
    except AIProviderResponseError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    except HTTPException:
        raise
    except Exception as error:
        print(f"[AI Provider] unexpected_error={type(error).__name__}", flush=True)
        raise HTTPException(status_code=500, detail="Internal AI error") from error

    if usage_record:
        usage_record.used_count += 1
        usage_record.updated_at = datetime.now(timezone.utc)
    else:
        new_record = UsageLimit(
            user_id=user_id,
            client_ip=None if user_id else (request.client.host if request.client else "unknown"),
            date=today_str,
            feature="assistant_chat",
            used_count=1,
        )
        db.add(new_record)
    db.commit()

    remaining = max(0, limit - (used_count + 1)) if limit != -1 else -1

    print(
        f"Assistant Chat: user_id={user_id}, persona={data.persona}, len={len(data.message)}, status=success",
        flush=True,
    )

    return AssistantChatResponse(
        reply=reply,
        remaining=remaining,
        plan=plan,
    )

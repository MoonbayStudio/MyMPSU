import json
import re
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

from app.schemas.assistant import CachedSchedulePayload
from app.services.schedule_service import (
    get_schedule_entries_for_group,
    normalize_optional_string,
    normalize_schedule_lesson,
    parse_schedule_lessons,
)
from app.utils.dates import parse_iso_datetime

SCHEDULE_SESSION_CACHE_TTL = timedelta(minutes=30)
DEVICE_SCHEDULE_CACHE_MAX_AGE = timedelta(hours=6)

_session_schedule_cache: Dict[str, Tuple[Dict[str, Any], datetime]] = {}
_conversation_schedule_index: Dict[str, str] = {}

SCHEDULE_QUESTION_TERMS = (
    "во сколько",
    "после чего",
    "что после",
    "откуда",
    "сколько",
    "следующая",
    "предыдущая",
    "какие",
    "какая",
    "какое",
    "какой",
    "когда",
    "куда",
    "где",
    "кто",
    "дальше",
)

SCHEDULE_KEYWORD_TERMS = (
    "class_url",
    "преподаватель",
    "расписание",
    "занятия",
    "занятие",
    "аудитория",
    "практика",
    "семинар",
    "экзамен",
    "кабинет",
    "лекция",
    "moodle",
    "корпус",
    "препод",
    "ссылка",
    "пары",
    "пара",
    "мудл",
)

EMOTIONAL_REACTION_TERMS = (
    "не хочу",
    "ненавижу",
    "понятно",
    "жесткая",
    "жестко",
    "спасибо",
    "хаха",
    "ахах",
    "окей",
    "ясно",
    "капец",
    "жесть",
    "ужас",
    "боль",
)

EMOTIONAL_STANDALONE_TERMS = (
    "да",
    "нет",
)

LESSON_NAME_ALIASES = {
    "физическая культура и спорт": "физра",
    "физическая культура": "физра",
}


def build_schedule_instructions(
    schedule_intent: bool,
    target_date: Optional[str],
    date_source: Optional[str],
    lessons_count: int,
    original_phrase: Optional[str] = None,
) -> str:
    if not (
        schedule_intent
        and target_date
        and date_source
        and date_source != "unknown"
    ):
        return ""

    day_label = original_phrase or target_date
    empty_schedule_examples = (
        f'"На {day_label} пар нет 🙂" или '
        f'"Похоже, {day_label} занятий нет."'
    )

    return f"""ПРАВИЛА РАСПИСАНИЯ (ОБЯЗАТЕЛЬНО):

Backend уже определил дату запроса. SCHEDULE_CONTEXT — единственный источник правды.

scheduleIntent=true, targetDate={target_date}, dateSource={date_source}.

Если backend передал targetDate в schedule context, считай дату уже определённой.
Никогда не уточняй её повторно и не спорь с ней.

ЗАПРЕЩЕНО:
- уточнять дату у пользователя
- спорить с targetDate или говорить, что пользователь указал дату неверно
- объяснять, что «завтра может значить...» или пересчитывать дату самостоятельно
- игнорировать targetDate из SCHEDULE_CONTEXT

Если lessonsCount > 0:
- сразу покажи расписание на targetDate ({target_date})

Если lessonsCount == 0:
- НЕ говори «у меня нет информации», «не вижу данных» или подобное
- сразу ответь, что пар нет, например: {empty_schedule_examples}"""


def is_device_schedule_cache_fresh(generated_at: datetime, now: datetime) -> bool:
    if generated_at.tzinfo is None:
        generated_at = generated_at.replace(tzinfo=timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    return now - generated_at <= DEVICE_SCHEDULE_CACHE_MAX_AGE


def schedule_session_cache_key(
    user_key: str,
    conversation_id: str,
    group_id: int,
    target_date: str,
) -> str:
    return (
        f"ai_schedule_context:{user_key}:{conversation_id}:"
        f"{group_id}:{target_date}"
    )


def purge_expired_session_schedule_cache(now: Optional[datetime] = None) -> None:
    now = now or datetime.now(timezone.utc)
    expired_keys = [
        cache_key
        for cache_key, (_, expires_at) in _session_schedule_cache.items()
        if now > expires_at
    ]

    for cache_key in expired_keys:
        _session_schedule_cache.pop(cache_key, None)

    stale_index_keys = [
        index_key
        for index_key, cache_key in _conversation_schedule_index.items()
        if cache_key not in _session_schedule_cache
    ]
    for index_key in stale_index_keys:
        _conversation_schedule_index.pop(index_key, None)


def get_session_schedule_cache(
    user_key: str,
    conversation_id: str,
) -> Optional[Dict[str, Any]]:
    purge_expired_session_schedule_cache()
    index_key = f"{user_key}:{conversation_id}"
    cache_key = _conversation_schedule_index.get(index_key)
    if not cache_key:
        return None

    entry = _session_schedule_cache.get(cache_key)
    if not entry:
        _conversation_schedule_index.pop(index_key, None)
        return None

    payload, expires_at = entry
    if datetime.now(timezone.utc) > expires_at:
        _session_schedule_cache.pop(cache_key, None)
        _conversation_schedule_index.pop(index_key, None)
        return None

    return payload


def save_session_schedule_cache(
    user_key: str,
    conversation_id: str,
    group_id: int,
    target_date: str,
    lessons: List[Dict[str, Any]],
    source: str,
    generated_at: str,
    ttl_seconds: int = 1800,
) -> None:
    if not conversation_id:
        return

    effective_ttl_seconds = max(1, int(ttl_seconds))
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=effective_ttl_seconds)
    payload = {
        "groupId": group_id,
        "targetDate": target_date,
        "lessons": lessons,
        "source": source,
        "generatedAt": generated_at,
    }
    cache_key = schedule_session_cache_key(
        user_key,
        conversation_id,
        group_id,
        target_date,
    )
    _session_schedule_cache[cache_key] = (payload, expires_at)
    _conversation_schedule_index[f"{user_key}:{conversation_id}"] = cache_key


def normalize_cached_schedule_lessons(
    lessons: List[Any],
    target_date: str,
) -> List[Dict[str, Any]]:
    normalized: List[Dict[str, Any]] = []

    for lesson in lessons:
        lesson_dict = lesson.model_dump() if hasattr(lesson, "model_dump") else lesson
        if not isinstance(lesson_dict, dict):
            continue

        lesson_date = lesson_dict.get("date")
        if lesson_date and lesson_date != target_date:
            continue

        parsed = normalize_schedule_lesson(lesson_dict)
        if parsed is None:
            continue

        if not parsed.get("date"):
            parsed["date"] = target_date
        normalized.append(parsed)

    normalized.sort(key=lambda lesson: lesson.get("startTime") or "")
    return normalized


def validate_device_cached_schedule(
    cached_schedule: CachedSchedulePayload,
    group_id: Optional[int],
    target_date: Optional[str],
    now: datetime,
) -> Tuple[bool, bool, List[Dict[str, Any]]]:
    if group_id is None or not target_date:
        return False, False, []

    generated_at = parse_iso_datetime(cached_schedule.generatedAt)
    if generated_at is None:
        return False, False, []

    is_fresh = is_device_schedule_cache_fresh(generated_at, now)
    lessons = normalize_cached_schedule_lessons(cached_schedule.lessons, target_date)
    return True, is_fresh, lessons


def build_lesson_reference_terms(
    session_context: Optional[Dict[str, Any]],
) -> Set[str]:
    terms: Set[str] = set()
    if not session_context:
        return terms

    for lesson in session_context.get("lessons") or []:
        if not isinstance(lesson, dict):
            continue

        name = normalize_optional_string(lesson.get("name"))
        if not name:
            continue

        name_lower = name.lower()
        terms.add(name_lower)

        for alias_source, alias_target in LESSON_NAME_ALIASES.items():
            if name_lower.startswith(alias_source) or alias_source in name_lower:
                terms.add(alias_target)

        if "физическ" in name_lower:
            terms.add("физра")

        for word in re.findall(r"[\wё]+", name_lower):
            if len(word) >= 4:
                terms.add(word)

    return terms


def _message_contains_term(message_lower: str, term: str) -> bool:
    if len(term) >= 4:
        return term in message_lower

    return re.search(rf"\b{re.escape(term)}\b", message_lower) is not None


def _match_schedule_question_signal(message_lower: str) -> bool:
    if any(
        _message_contains_term(message_lower, term)
        for term in SCHEDULE_QUESTION_TERMS
    ):
        return True

    return "после" in message_lower and "что" in message_lower


def _match_schedule_keyword_signal(message_lower: str) -> bool:
    return any(
        _message_contains_term(message_lower, term)
        for term in SCHEDULE_KEYWORD_TERMS
    )


def _match_lesson_reference_signal(
    message_lower: str,
    session_context: Optional[Dict[str, Any]],
) -> bool:
    terms = build_lesson_reference_terms(session_context)
    if not terms:
        return False

    for term in terms:
        if len(term) >= 4 and term in message_lower:
            return True

    message_words = re.findall(r"[\wё]+", message_lower)
    for word in message_words:
        if len(word) < 4:
            continue
        word_prefix = word[:4]
        for term in terms:
            if len(term) >= 4 and (
                term.startswith(word_prefix) or word.startswith(term[:4])
            ):
                return True

    return False


def _match_casual_reaction_signal(
    message_lower: str,
    has_question_signal: bool,
    has_schedule_keyword: bool,
) -> bool:
    if has_question_signal or has_schedule_keyword:
        return False

    if message_lower in EMOTIONAL_STANDALONE_TERMS:
        return True

    return any(
        _message_contains_term(message_lower, term)
        for term in EMOTIONAL_REACTION_TERMS
    )


def score_schedule_follow_up(
    message: str,
    session_context: Optional[Dict[str, Any]] = None,
) -> int:
    message_lower = message.lower().strip()
    if not message_lower:
        return 0

    score = 0
    matched_question_signal = _match_schedule_question_signal(message_lower)
    matched_schedule_keyword = _match_schedule_keyword_signal(message_lower)
    matched_lesson_reference = _match_lesson_reference_signal(
        message_lower,
        session_context,
    )

    if matched_question_signal:
        score += 2
    if matched_schedule_keyword:
        score += 2
    if matched_lesson_reference:
        score += 2
    if "?" in message:
        score += 1

    word_count = len(re.findall(r"[\wё]+", message_lower))
    if matched_lesson_reference and word_count <= 6:
        score += 1

    if _match_casual_reaction_signal(
        message_lower,
        matched_question_signal,
        matched_schedule_keyword,
    ):
        score -= 3

    return score


def is_schedule_follow_up(
    message: str,
    session_context: Optional[Dict[str, Any]] = None,
) -> bool:
    message_lower = message.lower().strip()
    matched_question_signal = _match_schedule_question_signal(message_lower)
    matched_schedule_keyword = _match_schedule_keyword_signal(message_lower)
    matched_lesson_reference = _match_lesson_reference_signal(
        message_lower,
        session_context,
    )
    casual_reaction = _match_casual_reaction_signal(
        message_lower,
        matched_question_signal,
        matched_schedule_keyword,
    )
    score = score_schedule_follow_up(message, session_context)
    threshold = 2 if session_context else 3
    result = score >= threshold

    print(f"[AI Schedule FollowUp] score={score}", flush=True)
    print(
        "[AI Schedule FollowUp] matched_lesson_reference="
        f"{str(matched_lesson_reference).lower()}",
        flush=True,
    )
    print(
        "[AI Schedule FollowUp] matched_question_signal="
        f"{str(matched_question_signal).lower()}",
        flush=True,
    )
    print(
        f"[AI Schedule FollowUp] casual_reaction={str(casual_reaction).lower()}",
        flush=True,
    )
    print(f"[AI Schedule FollowUp] result={str(result).lower()}", flush=True)

    return result


def should_use_schedule_context(
    message: str,
    schedule_intent: bool,
    cached_schedule: Optional[CachedSchedulePayload],
    session_context: Optional[Dict[str, Any]] = None,
) -> bool:
    if schedule_intent:
        return True
    if cached_schedule is not None:
        return True
    return is_schedule_follow_up(message, session_context)


def fetch_schedule_lessons_from_api(
    group_id: int,
    target_date: str,
) -> List[Dict[str, Any]]:
    try:
        raw_items = get_schedule_entries_for_group(
            group_id=group_id,
            start_date_str=target_date,
            end_date_str=target_date,
        )
    except Exception as error:
        print(f"[AI Schedule] fetch_error={error}", flush=True)
        raw_items = []

    raw_count = len(raw_items)
    print(f"[AI Schedule] raw_api_items_count={raw_count}", flush=True)
    if raw_items:
        print(
            f"[AI Schedule] first_raw_item_keys={list(raw_items[0].keys())}",
            flush=True,
        )

    lessons = parse_schedule_lessons(raw_items)
    print(f"[AI Schedule] parsed_lessons_count={len(lessons)}", flush=True)
    if lessons:
        print(
            f"[AI Schedule] first_lesson_name={lessons[0].get('name')}",
            flush=True,
        )
    print(f"[AI Schedule] filtered_lessons_count={len(lessons)}", flush=True)
    return lessons


def format_schedule_context_payload(
    group_id: Optional[int],
    target_date: Optional[str],
    lessons: List[Dict[str, Any]],
    schedule_intent: bool,
    date_source: Optional[str],
    original_phrase: Optional[str],
    context_source: Optional[str] = None,
) -> Tuple[str, int]:
    if not group_id:
        return "Нет данных о расписании (не выбрана группа).", 0

    resolved_target_date = (
        target_date if target_date else datetime.now(timezone.utc).date().isoformat()
    )
    lessons_count = len(lessons)
    print(f"[AI Schedule] schedule_lessons_count={lessons_count}", flush=True)

    schedule_context_dict: Dict[str, Any] = {
        "scheduleIntent": schedule_intent,
        "targetDate": resolved_target_date,
        "dateSource": date_source or "unknown",
        "originalPhrase": original_phrase or "",
        "lessonsCount": lessons_count,
        "schedule": lessons,
    }
    if context_source:
        schedule_context_dict["contextSource"] = context_source

    return (
        json.dumps(
            {"SCHEDULE_CONTEXT": schedule_context_dict},
            ensure_ascii=False,
            indent=2,
        ),
        lessons_count,
    )


def build_schedule_context_rules(
    has_schedule_context: bool,
    lessons_count: int,
    target_date: Optional[str],
) -> str:
    if not has_schedule_context or not target_date:
        return ""

    empty_examples = (
        f'"На {target_date} пар нет 🙂" или '
        f'"Похоже, {target_date} занятий нет."'
    )

    return f"""ПРАВИЛА SCHEDULE CONTEXT (ОБЯЗАТЕЛЬНО):

Backend передал готовый schedule context для targetDate={target_date}.
Используй ТОЛЬКО lessons из SCHEDULE_CONTEXT.
Не выдумывай пары, время, аудитории, преподавателей и ссылки.

Если lessonsCount > 0:
- отвечай только на основе переданных lessons

Если lessonsCount == 0:
- НЕ говори «у меня нет информации» или «не вижу данных»
- сразу скажи, что пар нет, например: {empty_examples}"""


def resolve_ai_schedule_context(
    user_key: str,
    conversation_id: Optional[str],
    group_id: Optional[int],
    target_date: Optional[str],
    cached_schedule: Optional[CachedSchedulePayload],
    schedule_intent: bool,
    date_source: Optional[str],
    original_phrase: Optional[str],
    message: str,
    now: datetime,
    session_cache_ttl_seconds: int = 1800,
) -> Tuple[
    str,
    int,
    Optional[str],
    bool,
    bool,
    bool,
    Optional[bool],
    Optional[int],
    Optional[str],
]:
    conversation_id = conversation_id or ""
    session_payload = None
    if conversation_id:
        session_payload = get_session_schedule_cache(user_key, conversation_id)

    schedule_follow_up = False
    if not schedule_intent and cached_schedule is None:
        schedule_follow_up = is_schedule_follow_up(message, session_payload)

    schedule_relevant = schedule_intent or cached_schedule is not None or schedule_follow_up
    source: Optional[str] = None
    cache_fresh: Optional[bool] = None
    session_cache_hit = False
    saved_session_cache = False
    lessons: List[Dict[str, Any]] = []

    print(
        f"[AI Schedule Context] schedule_relevant={str(schedule_relevant).lower()}",
        flush=True,
    )

    if not schedule_relevant:
        print(
            f"[AI Schedule Context] conversation_id={conversation_id or 'none'}",
            flush=True,
        )
        print("[AI Schedule Context] source=none", flush=True)
        print("[AI Schedule Context] cache_fresh=n/a", flush=True)
        print("[AI Schedule Context] saved_session_cache=false", flush=True)
        print("[AI Schedule Context] session_cache_hit=false", flush=True)
        print("[AI Schedule Context] lessons_count=0", flush=True)
        return "", 0, None, False, False, False, None, group_id, target_date

    if schedule_follow_up and session_payload:
        session_cache_hit = True
        if group_id is None:
            group_id = session_payload.get("groupId")
        if target_date is None:
            target_date = session_payload.get("targetDate")

    if cached_schedule is not None:
        is_valid, is_fresh, device_lessons = validate_device_cached_schedule(
            cached_schedule,
            group_id,
            target_date,
            now,
        )
        cache_fresh = is_fresh
        if is_valid and is_fresh:
            source = "device_cache"
            lessons = device_lessons

    if source is None and conversation_id and session_payload:
        session_group_id = session_payload.get("groupId")
        session_target_date = session_payload.get("targetDate")
        session_matches = (group_id is None or session_group_id == group_id) and (
            target_date is None or session_target_date == target_date
        )
        if session_matches and schedule_follow_up:
            source = "session_cache"
            session_cache_hit = True
            lessons = session_payload.get("lessons", [])
            group_id = session_group_id
            target_date = session_target_date

    if source is None and group_id and target_date:
        print(f"[AI Schedule] USING_TARGET_DATE={target_date}", flush=True)
        print(f"[AI Schedule] FETCHING_SCHEDULE_FOR={target_date}", flush=True)
        print(f"[AI Schedule] group_id={group_id}", flush=True)
        source = "mympsu_schedule_api"
        lessons = fetch_schedule_lessons_from_api(group_id, target_date)

    generated_at_value = datetime.now(timezone.utc).isoformat()
    if source and conversation_id and group_id and target_date:
        if source == "device_cache" and cached_schedule is not None:
            generated_at_value = cached_schedule.generatedAt

        save_session_schedule_cache(
            user_key=user_key,
            conversation_id=conversation_id,
            group_id=group_id,
            target_date=target_date,
            lessons=lessons,
            source=source,
            generated_at=generated_at_value,
            ttl_seconds=session_cache_ttl_seconds,
        )
        saved_session_cache = True

    has_schedule_context = source is not None
    schedule_text, lessons_count = format_schedule_context_payload(
        group_id=group_id,
        target_date=target_date,
        lessons=lessons,
        schedule_intent=schedule_intent or schedule_follow_up,
        date_source=date_source,
        original_phrase=original_phrase,
        context_source=source,
    )

    print(f"[AI Schedule Context] conversation_id={conversation_id or 'none'}", flush=True)
    print(f"[AI Schedule Context] source={source or 'none'}", flush=True)
    if cache_fresh is None:
        print("[AI Schedule Context] cache_fresh=n/a", flush=True)
    else:
        print(
            f"[AI Schedule Context] cache_fresh={str(cache_fresh).lower()}",
            flush=True,
        )
    print(
        f"[AI Schedule Context] saved_session_cache={str(saved_session_cache).lower()}",
        flush=True,
    )
    print(
        f"[AI Schedule Context] session_cache_hit={str(session_cache_hit).lower()}",
        flush=True,
    )
    print(f"[AI Schedule Context] lessons_count={lessons_count}", flush=True)

    return (
        schedule_text,
        lessons_count,
        source,
        saved_session_cache,
        session_cache_hit,
        has_schedule_context,
        cache_fresh,
        group_id,
        target_date,
    )


def build_schedule_context(
    group_id: int,
    target_date: Optional[str] = None,
    date_source: str = "context_selected",
    original_phrase: Optional[str] = None,
    schedule_intent: bool = False,
) -> Tuple[str, int]:
    if target_date is None:
        target_date = datetime.now(timezone.utc).date().isoformat()

    lessons = fetch_schedule_lessons_from_api(group_id, target_date)
    return format_schedule_context_payload(
        group_id=group_id,
        target_date=target_date,
        lessons=lessons,
        schedule_intent=schedule_intent,
        date_source=date_source,
        original_phrase=original_phrase,
    )

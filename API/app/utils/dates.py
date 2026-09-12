import re
from datetime import datetime, timedelta
from typing import Optional, Tuple


def parse_schedule_date(
    message: str,
    now: datetime,
    timezone_str: str = "Europe/Moscow",
) -> Optional[Tuple[str, str, str]]:
    _ = timezone_str
    message_lower = message.lower()

    schedule_keywords = [
        "пар", "расписание", "занятия", "занятие", "урок",
        "что сегодня", "что завтра", "что в", "что на",
        "какие сегодня", "какие завтра", "что послезавтра"
    ]

    intent_matched = any(kw in message_lower for kw in schedule_keywords)
    if not intent_matched:
        return None

    target_date = None
    original_phrase = None

    if re.search(r'\bсегодня\b', message_lower):
        target_date = now
        original_phrase = "сегодня"
    elif re.search(r'\bпослезавтра\b', message_lower):
        target_date = now + timedelta(days=2)
        original_phrase = "послезавтра"
    elif re.search(r'\bзавтра\b', message_lower):
        target_date = now + timedelta(days=1)
        original_phrase = "завтра"
    elif re.search(r'\bвчера\b', message_lower):
        target_date = now - timedelta(days=1)
        original_phrase = "вчера"

    weekdays = {
        "понедельник": 0, "вторник": 1, "сред": 2, "четверг": 3,
        "пятниц": 4, "суббот": 5, "воскресень": 6
    }

    if not target_date:
        for wd_name, wd_idx in weekdays.items():
            if re.search(rf'\bследующ(?:ий|ая|ее|ую)\s+{wd_name}', message_lower) or re.search(rf'\bв\s+следующ(?:ий|ую)\s+{wd_name}', message_lower):
                target_date = now + timedelta(days=(7 - now.weekday()) + wd_idx)
                original_phrase = f"следующий {wd_name}"
                break

            if re.search(rf'\bв\s+{wd_name}', message_lower) or re.search(rf'\bво\s+{wd_name}', message_lower):
                if now.weekday() == wd_idx:
                    target_date = now
                else:
                    days_ahead = wd_idx - now.weekday()
                    if days_ahead < 0:
                        days_ahead += 7
                    target_date = now + timedelta(days=days_ahead)
                original_phrase = f"в {wd_name}"
                break

    if not target_date:
        if re.search(r'\bна этой неделе\b', message_lower):
            target_date = now
            original_phrase = "на этой неделе"
        elif re.search(r'\bна следующей неделе\b', message_lower):
            target_date = now + timedelta(days=(7 - now.weekday()))
            original_phrase = "на следующей неделе"
        elif match := re.search(r'\bчерез\s+(\d+)\s+дн(?:ей|я|ь)\b', message_lower):
            days = int(match.group(1))
            target_date = now + timedelta(days=days)
            original_phrase = f"через {days} дней"
        elif match := re.search(r'\b(\d{1,2})\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)\b', message_lower):
            months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
            day = int(match.group(1))
            month_idx = months.index(match.group(2)) + 1
            year = now.year
            if month_idx < now.month or (month_idx == now.month and day < now.day):
                year += 1
            try:
                target_date = now.replace(year=year, month=month_idx, day=day)
                original_phrase = match.group(0)
            except ValueError:
                pass
        elif match := re.search(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b', message_lower):
            year = int(match.group(1))
            month = int(match.group(2))
            day = int(match.group(3))
            try:
                target_date = now.replace(year=year, month=month, day=day)
                original_phrase = match.group(0)
            except ValueError:
                pass
        elif match := re.search(r'\b(\d{1,2})\.(\d{1,2})(?:\.(\d{4}))?\b', message_lower):
            day = int(match.group(1))
            month = int(match.group(2))
            year = int(match.group(3)) if match.group(3) else now.year
            if not match.group(3) and (month < now.month or (month == now.month and day < now.day)):
                year += 1
            try:
                target_date = now.replace(year=year, month=month, day=day)
                original_phrase = match.group(0)
            except ValueError:
                pass

    if target_date:
        parsed_target_date = target_date.strftime("%Y-%m-%d")
        print("[AI Schedule] schedule_intent=true", flush=True)
        print(f"[AI Schedule] original_message=\"{message}\"", flush=True)
        print(f"[AI Schedule] parsed_target_date={parsed_target_date}", flush=True)
        print("[AI Schedule] date_source=parsed_from_user", flush=True)
        return (parsed_target_date, "parsed_from_user", original_phrase)

    fallback_date = now.strftime("%Y-%m-%d")
    print("[AI Schedule] schedule_intent=true", flush=True)
    print(f"[AI Schedule] original_message=\"{message}\"", flush=True)
    print(f"[AI Schedule] parsed_target_date={fallback_date}", flush=True)
    print("[AI Schedule] date_source=fallback_today", flush=True)
    return (fallback_date, "fallback_today", "fallback_today")


def parse_iso_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None

    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None

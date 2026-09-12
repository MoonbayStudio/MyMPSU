from datetime import datetime, timezone, timedelta
import zoneinfo
from app.utils.dates import parse_schedule_date

def test_parse_schedule_date():
    tz = zoneinfo.ZoneInfo("Europe/Moscow")
    now = datetime(2026, 5, 23, 12, 0, 0, tzinfo=tz) # Saturday

    cases = [
        ("какие пары сегодня", "2026-05-23", "сегодня", "parsed_from_user"),
        ("что завтра", "2026-05-24", "завтра", "parsed_from_user"),
        ("какие пары в понедельник", "2026-05-25", "в понедельник", "parsed_from_user"),
        ("что в следующий понедельник", "2026-05-25", "следующий понедельник", "parsed_from_user"),
        ("расписание 25 мая", "2026-05-25", "25 мая", "parsed_from_user"),
        ("пары 25.05", "2026-05-25", "25.05", "parsed_from_user"),
        ("что на следующей неделе", "2026-05-25", "на следующей неделе", "parsed_from_user"),
    ]

    for msg, expected_date, expected_phrase, expected_source in cases:
        res = parse_schedule_date(msg, now)
        assert res is not None
        target_date, source, phrase = res
        assert target_date == expected_date
        assert source == expected_source
        if expected_phrase:
            assert phrase == expected_phrase

    # Fallback case
    res = parse_schedule_date("какое-то расписание", now)
    assert res is not None
    assert res[0] == "2026-05-23"
    assert res[1] == "fallback_today"
    assert res[2] == "fallback_today"

if __name__ == "__main__":
    test_parse_schedule_date()
    print("All tests passed!")

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

import requests
from fastapi import HTTPException

from app.core.config import (
    MPGU_SCHEDULE_API_BASE_URL,
    MPGU_SCHEDULE_API_TIMEOUT_SECONDS,
    MPGU_SCHEDULE_API_PATH,
)
from app.utils.common import normalize_optional_string, parse_int


def extract_items(payload: Any) -> List[Dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]

    if isinstance(payload, dict):
        for key in (
            "items",
            "data",
            "results",
            "schedule",
            "lessons",
            "teachers",
        ):
            value = payload.get(key)
            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]

    return []


def parse_schedule_datetime_field(value: Any) -> Tuple[Optional[str], Optional[str]]:
    if value is None:
        return None, None

    if isinstance(value, datetime):
        dt = value
    elif isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None, None
    else:
        return None, None

    return dt.date().isoformat(), dt.strftime("%H:%M")


def extract_subject_name(lesson: Dict[str, Any]) -> Optional[str]:
    subject_name = (
        lesson.get("name")
        or lesson.get("subject_name")
        or lesson.get("subjectName")
    )

    subject = lesson.get("subject")

    if subject_name is None and isinstance(subject, dict):
        subject_name = (
            subject.get("name")
            or subject.get("subject_name")
            or subject.get("subjectName")
        )

    return normalize_optional_string(subject_name)


def extract_teacher_id(lesson: Dict[str, Any]) -> Optional[int]:
    teacher_id = lesson.get("teacher_id")

    if teacher_id is None:
        teacher_id = lesson.get("teacherId")

    teacher = lesson.get("teacher")

    if teacher_id is None and isinstance(teacher, dict):
        teacher_id = (
            teacher.get("id")
            or teacher.get("teacher_id")
            or teacher.get("teacherId")
        )

    return parse_int(teacher_id)


def extract_teacher_name(lesson: Dict[str, Any]) -> Optional[str]:
    teacher_name = lesson.get("teacher_name") or lesson.get("teacherName")

    teacher = lesson.get("teacher")

    if teacher_name is None and isinstance(teacher, dict):
        teacher_name = (
            teacher.get("name")
            or teacher.get("full_name")
            or teacher.get("fio")
            or teacher.get("teacher_name")
            or teacher.get("teacherName")
        )

    return normalize_optional_string(teacher_name)


def extract_lesson_type(lesson: Dict[str, Any]) -> Optional[str]:
    lesson_type = (
        lesson.get("type")
        or lesson.get("lesson_type")
        or lesson.get("lessonType")
    )

    return normalize_optional_string(lesson_type)


def normalize_schedule_lesson(item: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    name = normalize_optional_string(item.get("name")) or extract_subject_name(item)
    if not name:
        return None

    date_str = normalize_optional_string(item.get("date"))
    start_time = item.get("startTime")
    end_time = item.get("endTime")

    if isinstance(start_time, str) and "T" in start_time:
        parsed_date, start_time = parse_schedule_datetime_field(start_time)
        if not date_str:
            date_str = parsed_date
    elif not start_time:
        parsed_date, start_time = parse_schedule_datetime_field(
            item.get("start_time") or item.get("startTime")
        )
        if not date_str:
            date_str = parsed_date

    if isinstance(end_time, str) and "T" in end_time:
        _, end_time = parse_schedule_datetime_field(end_time)
    elif not end_time:
        _, end_time = parse_schedule_datetime_field(
            item.get("end_time") or item.get("endTime")
        )

    lesson_type = extract_lesson_type(item)
    class_url = item.get("class_url")
    if class_url is None:
        class_url = item.get("classUrl")

    is_exam = item.get("is_exam")
    if is_exam is None:
        is_exam = item.get("isExam")

    lesson: Dict[str, Any] = {
        "name": name,
        "type": lesson_type,
        "startTime": start_time,
        "endTime": end_time,
        "date": date_str,
        "roomId": parse_int(item.get("room_id") or item.get("roomId")),
        "teacherId": parse_int(item.get("teacher_id") or item.get("teacherId")),
        "classUrl": class_url,
        "note": item.get("note"),
        "isExam": is_exam,
    }

    room = normalize_optional_string(item.get("room"))
    teacher = normalize_optional_string(item.get("teacher"))
    if room:
        lesson["room"] = room
    if teacher:
        lesson["teacher"] = teacher

    return lesson


def parse_schedule_lessons(raw_items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    lessons: List[Dict[str, Any]] = []

    for item in raw_items:
        lesson = normalize_schedule_lesson(item)
        if lesson is not None:
            lessons.append(lesson)

    lessons.sort(key=lambda lesson: lesson.get("startTime") or "")
    return lessons


def request_mpgu_api(path: str, params: Optional[Dict[str, Any]] = None) -> Tuple[int, Any]:
    if not MPGU_SCHEDULE_API_BASE_URL:
        raise HTTPException(status_code=503, detail="Расписание МПГУ ещё не подключено")
    url = f"{MPGU_SCHEDULE_API_BASE_URL}{path}"

    try:
        response = requests.get(url, params=params, timeout=MPGU_SCHEDULE_API_TIMEOUT_SECONDS)
    except requests.RequestException as error:
        raise HTTPException(status_code=502, detail="MyMPSU schedule API is unavailable") from error

    if response.status_code >= 500:
        raise HTTPException(status_code=502, detail="MyMPSU schedule API server error")

    try:
        payload = response.json()
    except ValueError as error:
        raise HTTPException(status_code=502, detail="MyMPSU schedule API returned invalid JSON") from error

    return response.status_code, payload


def get_schedule_entries_for_group(
    group_id: int,
    start_date_str: Optional[str] = None,
    end_date_str: Optional[str] = None,
) -> List[Dict[str, Any]]:
    now = datetime.now(timezone.utc).date()
    start_date = start_date_str if start_date_str else now.isoformat()
    end_date = end_date_str if end_date_str else (now + timedelta(days=120)).isoformat()

    params_variants = [
        {
            "group_id": group_id,
            "start_date": start_date,
            "end_date": end_date,
        },
        {
            "groupId": group_id,
            "startDate": start_date,
            "endDate": end_date,
        },
    ]

    for params in params_variants:
        status_code, payload = request_mpgu_api(
            path=MPGU_SCHEDULE_API_PATH,
            params=params,
        )

        if status_code == 200:
            return extract_items(payload)

        if status_code in (400, 404, 422):
            continue

        raise HTTPException(
            status_code=502,
            detail="Failed to fetch schedule from MyMPSU schedule API",
        )

    raise HTTPException(
        status_code=502,
        detail="Failed to fetch schedule from MyMPSU schedule API",
    )


def get_teacher_names(teacher_ids: Set[int]) -> Dict[int, str]:
    if not teacher_ids:
        return {}

    ids_csv = ",".join(str(teacher_id) for teacher_id in sorted(teacher_ids))
    params_variants = [
        {"ids": ids_csv},
        {"teacher_ids": ids_csv},
        None,
    ]

    teacher_names: Dict[int, str] = {}

    for params in params_variants:
        status_code, payload = request_mpgu_api(path="/teachers", params=params)

        if status_code == 200:
            for teacher in extract_items(payload):
                teacher_id = parse_int(
                    teacher.get("id")
                    or teacher.get("teacher_id")
                    or teacher.get("teacherId")
                )

                if teacher_id is None or teacher_id not in teacher_ids:
                    continue

                teacher_name = normalize_optional_string(
                    teacher.get("name")
                    or teacher.get("full_name")
                    or teacher.get("fio")
                    or teacher.get("teacher_name")
                    or teacher.get("teacherName")
                )

                if teacher_name:
                    teacher_names[teacher_id] = teacher_name

            if teacher_names:
                return teacher_names

            continue

        if status_code in (400, 404, 422):
            continue

        raise HTTPException(status_code=502, detail="Failed to fetch teachers from MyMPSU schedule API")

    return teacher_names

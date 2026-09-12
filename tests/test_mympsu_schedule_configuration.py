from unittest.mock import patch

import pytest
from fastapi import HTTPException
from app.services import schedule_service


def test_unconfigured_mpgu_schedule_does_not_contact_another_university(monkeypatch):
    monkeypatch.setattr(schedule_service, "MPGU_SCHEDULE_API_BASE_URL", "")
    with patch.object(schedule_service.requests, "get") as request:
        with pytest.raises(HTTPException) as error:
            schedule_service.request_mpgu_api("/schedule/v1/schedule")
    assert error.value.status_code == 503
    assert error.value.detail == "Расписание МПГУ ещё не подключено"
    request.assert_not_called()

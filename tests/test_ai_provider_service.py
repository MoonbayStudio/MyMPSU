import asyncio
import json

import httpx

from app.services import ai_provider_service


def test_openrouter_provider_sends_key_model_and_messages(monkeypatch):
    captured = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["url"] = str(request.url)
        captured["authorization"] = request.headers.get("Authorization")
        captured["referer"] = request.headers.get("HTTP-Referer")
        captured["title"] = request.headers.get("X-OpenRouter-Title")
        captured["body"] = json.loads(request.content)
        return httpx.Response(
            200,
            json={"choices": [{"message": {"content": "  Готово!  "}}]},
        )

    monkeypatch.setattr(ai_provider_service, "AI_PROVIDER", "openrouter")
    monkeypatch.setattr(ai_provider_service, "OPENROUTER_API_KEY", "test-key")
    monkeypatch.setattr(ai_provider_service, "OPENROUTER_MODEL", "openrouter/free")
    monkeypatch.setattr(ai_provider_service, "OPENROUTER_BASE_URL", "https://openrouter.test/api/v1")
    monkeypatch.setattr(ai_provider_service, "OPENROUTER_SITE_URL", "https://mympsu.test")
    monkeypatch.setattr(ai_provider_service, "OPENROUTER_APP_NAME", "MyMPSU")

    async def run_request():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            return await ai_provider_service.generate_assistant_reply(
                client,
                [{"role": "user", "content": "Привет"}],
            )

    reply = asyncio.run(run_request())

    assert reply == "Готово!"
    assert captured == {
        "url": "https://openrouter.test/api/v1/chat/completions",
        "authorization": "Bearer test-key",
        "referer": "https://mympsu.test",
        "title": "MyMPSU",
        "body": {
            "model": "openrouter/free",
            "messages": [{"role": "user", "content": "Привет"}],
            "stream": False,
        },
    }


def test_openrouter_provider_rejects_empty_choices(monkeypatch):
    monkeypatch.setattr(ai_provider_service, "AI_PROVIDER", "openrouter")

    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"choices": []})

    async def run_request():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            return await ai_provider_service.generate_assistant_reply(
                client,
                [{"role": "user", "content": "Привет"}],
            )

    try:
        asyncio.run(run_request())
        assert False, "Expected an empty response error"
    except ai_provider_service.AIProviderResponseError as error:
        assert str(error) == "OpenRouter returned no choices"

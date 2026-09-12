from typing import Dict, List

import httpx

from app.core.config import (
    AI_PROVIDER,
    OLLAMA_BASE_URL,
    OPENROUTER_API_KEY,
    OPENROUTER_APP_NAME,
    OPENROUTER_BASE_URL,
    OPENROUTER_MODEL,
    OPENROUTER_SITE_URL,
    PELIKASHA_MODEL,
)


ChatMessage = Dict[str, str]


class AIProviderResponseError(RuntimeError):
    pass


async def generate_assistant_reply(
    client: httpx.AsyncClient,
    messages: List[ChatMessage],
) -> str:
    if AI_PROVIDER == "openrouter":
        reply = await _generate_openrouter_reply(client, messages)
    else:
        reply = await _generate_ollama_reply(client, messages)

    normalized_reply = reply.strip()
    if not normalized_reply:
        raise AIProviderResponseError("AI provider returned an empty response")
    return normalized_reply


async def _generate_openrouter_reply(
    client: httpx.AsyncClient,
    messages: List[ChatMessage],
) -> str:
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }
    if OPENROUTER_SITE_URL:
        headers["HTTP-Referer"] = OPENROUTER_SITE_URL
    if OPENROUTER_APP_NAME:
        headers["X-OpenRouter-Title"] = OPENROUTER_APP_NAME

    response = await client.post(
        f"{OPENROUTER_BASE_URL}/chat/completions",
        headers=headers,
        json={
            "model": OPENROUTER_MODEL,
            "messages": messages,
            "stream": False,
        },
    )
    response.raise_for_status()
    payload = response.json()
    choices = payload.get("choices") or []
    if not choices:
        raise AIProviderResponseError("OpenRouter returned no choices")
    return choices[0].get("message", {}).get("content") or ""


async def _generate_ollama_reply(
    client: httpx.AsyncClient,
    messages: List[ChatMessage],
) -> str:
    response = await client.post(
        f"{OLLAMA_BASE_URL}/api/chat",
        json={
            "model": PELIKASHA_MODEL,
            "messages": messages,
            "stream": False,
            "keep_alive": -1,
        },
    )
    response.raise_for_status()
    payload = response.json()
    return payload.get("message", {}).get("content") or ""

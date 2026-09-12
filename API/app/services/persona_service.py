import os
from datetime import datetime
from typing import Dict, Optional, Tuple

import zoneinfo

from persona_theme import resolve_persona_theme
from app.services.runtime_settings_service import get_runtime_persona_theme


PERSONAS_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "personas"
)

_PERSONA_PLACEHOLDER_SNIPPETS = (
    "todo: customize seasonal persona.",
    "праздничный вариант персоны — placeholder.",
)

_persona_cache: Dict[str, Tuple[str, str]] = {}


def _resolve_active_persona_theme() -> Tuple[str, Optional[str]]:
    active_persona_theme = get_runtime_persona_theme()
    if active_persona_theme != "auto":
        return active_persona_theme, None

    now = datetime.now(zoneinfo.ZoneInfo("Europe/Moscow"))
    resolved = resolve_persona_theme(now)
    theme_dir = os.path.join(PERSONAS_DIR, resolved)
    if not os.path.isdir(theme_dir):
        return "default", resolved
    return resolved, resolved


def _is_placeholder_persona_prompt(content: str) -> bool:
    normalized = content.strip().lower()
    if not normalized:
        return True
    return any(snippet in normalized for snippet in _PERSONA_PLACEHOLDER_SNIPPETS)


def _log_persona_selection(
    persona_name: str,
    theme: str,
    resolved_theme: Optional[str],
    loaded_from: str,
    system_prompt: str,
    cache_hit: bool,
) -> None:
    active_persona_theme = get_runtime_persona_theme()
    if active_persona_theme == "auto":
        print("[AI Persona] mode=auto", flush=True)
        print(f"[AI Persona] resolved_theme={resolved_theme}", flush=True)
    else:
        print(f"[AI Persona] theme={active_persona_theme}", flush=True)
    print(f"[AI Persona] selected_persona={persona_name}", flush=True)
    print(f"[AI Persona] selected_theme={theme}", flush=True)
    print(f"[AI Persona] loaded_md_file={loaded_from}", flush=True)
    print(f"[AI Persona] cache_hit={cache_hit}", flush=True)
    prompt_preview = system_prompt.replace("\n", "\\n")[:100]
    print(f"[AI Persona] system_prompt_preview={prompt_preview}", flush=True)


def load_persona_prompt(persona_name: str) -> str:
    theme, resolved_theme = _resolve_active_persona_theme()
    cache_key = f"{theme}:{persona_name}"

    if cache_key in _persona_cache:
        cached_content, loaded_from = _persona_cache[cache_key]
        _log_persona_selection(
            persona_name=persona_name,
            theme=theme,
            resolved_theme=resolved_theme,
            loaded_from=loaded_from,
            system_prompt=cached_content,
            cache_hit=True,
        )
        return cached_content

    primary_persona_file = os.path.join(PERSONAS_DIR, theme, f"{persona_name}.md")
    persona_file = primary_persona_file
    loaded_from = persona_file

    if not os.path.isfile(persona_file):
        if theme != "default":
            persona_file = os.path.join(
                PERSONAS_DIR,
                "default",
                f"{persona_name}.md"
            )
            loaded_from = persona_file

        if not os.path.isfile(persona_file):
            raise RuntimeError(
                f"Persona file not found: {persona_name} "
                f"(theme={theme})"
            )

    with open(persona_file, "r", encoding="utf-8") as persona_handle:
        content = persona_handle.read().strip()

    if theme != "default" and persona_file == primary_persona_file and _is_placeholder_persona_prompt(content):
        fallback_file = os.path.join(PERSONAS_DIR, "default", f"{persona_name}.md")
        if not os.path.isfile(fallback_file):
            raise RuntimeError(
                f"Persona fallback file not found: {persona_name} "
                f"(theme=default)"
            )
        print(
            f"[AI Persona] placeholder_detected=true fallback_to_default=true source={primary_persona_file}",
            flush=True
        )
        with open(fallback_file, "r", encoding="utf-8") as fallback_handle:
            content = fallback_handle.read().strip()
        loaded_from = fallback_file

    if not content:
        raise RuntimeError(
            f"Persona file is empty: {persona_name} "
            f"(loaded_from={loaded_from})"
        )

    _log_persona_selection(
        persona_name=persona_name,
        theme=theme,
        resolved_theme=resolved_theme,
        loaded_from=loaded_from,
        system_prompt=content,
        cache_hit=False,
    )

    _persona_cache[cache_key] = (content, loaded_from)
    return content

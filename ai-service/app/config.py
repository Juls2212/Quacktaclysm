"""Settings read from environment variables. Values are never logged."""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass, replace
from pathlib import Path

MODE_MOCK = "mock"
MODE_OPENAI = "openai"
_DEFAULT_TIMEOUT_SECONDS = 8.0


@dataclass(frozen=True)
class Settings:
    mode: str = MODE_MOCK
    openai_api_key: str = ""
    openai_model: str = ""
    openai_timeout_seconds: float = _DEFAULT_TIMEOUT_SECONDS
    host: str = "127.0.0.1"
    port: int = 8000

    @property
    def openai_configured(self) -> bool:
        return bool(self.openai_api_key and self.openai_model)


ENV_FILE_VAR = "AI_SERVICE_ENV_FILE"
_notice_printed = False


def env_file_path() -> Path:
    """ai-service/.env, resolved from this file (never from the working directory).

    AI_SERVICE_ENV_FILE can point somewhere else; the tests use it so they never read the real file.
    """
    override = os.environ.get(ENV_FILE_VAR, "").strip()
    if override:
        return Path(override)
    return Path(__file__).resolve().parent.parent / ".env"


def load_dotenv_if_available() -> bool:
    """Loads the .env file; its values WIN over leftover shell variables (override=True).

    Returns True when a file was found and read. Never raises when the file or python-dotenv
    is missing.
    """
    path = env_file_path()
    try:
        from dotenv import load_dotenv
    except ImportError:
        return False
    if not path.is_file():
        return False
    return bool(load_dotenv(path, override=True))


def _float_env(name: str, default: float) -> float:
    try:
        value = float(os.environ.get(name, "").strip())
    except ValueError:
        return default
    return value if value > 0 else default


def _int_env(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, "").strip())
    except ValueError:
        return default


def load_settings() -> Settings:
    mode = os.environ.get("AI_SERVICE_MODE", MODE_MOCK).strip().lower()
    if mode not in (MODE_MOCK, MODE_OPENAI):
        mode = MODE_MOCK
    return Settings(
        mode=mode,
        openai_api_key=os.environ.get("OPENAI_API_KEY", "").strip(),
        openai_model=os.environ.get("OPENAI_MODEL", "").strip(),
        openai_timeout_seconds=_float_env("OPENAI_TIMEOUT_SECONDS", _DEFAULT_TIMEOUT_SECONDS),
        host=os.environ.get("AI_SERVICE_HOST", "127.0.0.1").strip() or "127.0.0.1",
        port=_int_env("AI_SERVICE_PORT", 8000),
    )


def prepare_settings() -> Settings:
    """Startup entry point: load .env, read the settings and degrade to mock mode if needed.

    A missing .env, or openai mode without key/model, never crashes: the service starts in mock
    mode and prints ONE key-free hint (once per process).
    """
    loaded = load_dotenv_if_available()
    settings = load_settings()
    degraded = settings.mode == MODE_OPENAI and not settings.openai_configured
    if degraded:
        settings = replace(settings, mode=MODE_MOCK)
    if (not loaded or degraded) and not _notice_printed:
        _print_notice(loaded, degraded)
    return settings


def _print_notice(env_loaded: bool, degraded: bool) -> None:
    global _notice_printed
    _notice_printed = True
    reasons = []
    if not env_loaded:
        reasons.append("ai-service/.env was not found")
    if degraded:
        reasons.append("AI_SERVICE_MODE=openai but OPENAI_API_KEY or OPENAI_MODEL is empty")
    print("AI service: " + " and ".join(reasons) + ". Running in MOCK mode (no network, no OpenAI). "
          "To use OpenAI, copy ai-service/.env.example to ai-service/.env and fill it in.",
          file=sys.stderr, flush=True)

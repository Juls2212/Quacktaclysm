"""Settings read from environment variables. Values are never logged."""
from __future__ import annotations

import os
from dataclasses import dataclass
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


def load_dotenv_if_available() -> None:
    """Loads ai-service/.env when python-dotenv is installed. Never fails if it is not."""
    try:
        from dotenv import load_dotenv
    except ImportError:
        return
    load_dotenv(Path(__file__).resolve().parent.parent / ".env", override=False)


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

"""FastAPI app: GET /health and POST /v1/adaptive/profile.

NOTE: there is no authentication or rate limiting in this phase. Before hosting the
service publicly add both (and HTTPS); see README.md ("Servicio de IA").
"""
from __future__ import annotations

import logging
import time
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from . import rules
from .config import MODE_MOCK, Settings, load_dotenv_if_available, load_settings
from .openai_client import OpenAIProfileClient, ProfileModelClient, UpstreamError, UpstreamTimeout
from .schemas import ProfileRequest, ProfileResponse

logger = logging.getLogger("ai_service")

MAX_BODY_BYTES = 16 * 1024


class _BodyTooLarge(Exception):
    pass


async def _send_plain(send: Any, status: int, text: str) -> None:
    body = ('{"detail":"%s"}' % text).encode()
    await send({"type": "http.response.start", "status": status,
                "headers": [(b"content-type", b"application/json"), (b"content-length", str(len(body)).encode())]})
    await send({"type": "http.response.body", "body": body})


class BodyLimitMiddleware:
    """Rejects request bodies larger than max_bytes (by header and while streaming)."""

    def __init__(self, app: Any, max_bytes: int) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Any, receive: Any, send: Any) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        length = dict(scope["headers"]).get(b"content-length", b"")
        if length.isdigit() and int(length) > self.max_bytes:
            await _send_plain(send, 413, "request too large")
            return
        received = 0
        started = False

        async def limited_receive() -> Any:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_bytes:
                    raise _BodyTooLarge
            return message

        async def tracking_send(message: Any) -> None:
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, tracking_send)
        except _BodyTooLarge:
            if not started:
                await _send_plain(send, 413, "request too large")


class AccessLogMiddleware:
    """Logs method, path, status and duration only. Never bodies or headers."""

    def __init__(self, app: Any) -> None:
        self.app = app

    async def __call__(self, scope: Any, receive: Any, send: Any) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        start = time.perf_counter()
        status = 500

        async def logging_send(message: Any) -> None:
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, logging_send)
        finally:
            logger.info("%s %s -> %d (%.1f ms)", scope["method"], scope["path"], status,
                        (time.perf_counter() - start) * 1000)


def create_app(settings: Settings | None = None, model_client: ProfileModelClient | None = None) -> FastAPI:
    """`model_client` lets tests inject a fake OpenAI client (no network)."""
    if settings is None:
        load_dotenv_if_available()
        settings = load_settings()
    app = FastAPI(title="Quacktaclysm AI service")
    app.add_middleware(BodyLimitMiddleware, max_bytes=MAX_BODY_BYTES)
    app.add_middleware(AccessLogMiddleware)
    state: dict[str, ProfileModelClient | None] = {"client": model_client}

    @app.exception_handler(RequestValidationError)
    async def invalid_request(_request: Request, exc: RequestValidationError) -> JSONResponse:
        # Field paths only: the default handler would echo the offending input back.
        fields = [".".join(str(part) for part in error["loc"][1:]) for error in exc.errors()]
        return JSONResponse(status_code=422, content={"detail": "invalid request", "fields": fields})

    def get_client() -> ProfileModelClient:
        if state["client"] is None:
            if not settings.openai_configured:
                raise HTTPException(503, "AI service not configured")
            state["client"] = OpenAIProfileClient(settings.openai_api_key, settings.openai_model,
                                                  settings.openai_timeout_seconds)
        return state["client"]

    @app.get("/health")
    def health() -> dict[str, Any]:
        return {"status": "ok", "mode": settings.mode, "openai_configured": settings.openai_configured}

    @app.post("/v1/adaptive/profile", response_model=ProfileResponse)
    def adaptive_profile(request: ProfileRequest) -> ProfileResponse:
        if settings.mode == MODE_MOCK:
            profile = rules.classify([d.model_dump() for d in request.decisions])
            return ProfileResponse(profile=profile, narrative_variant=rules.default_variant(profile), source="mock")
        client = get_client()
        try:
            text = client.classify(request.model_dump())
        except UpstreamTimeout:
            raise HTTPException(504, "AI provider timeout") from None
        except UpstreamError:
            raise HTTPException(502, "AI provider error") from None
        except Exception as exc:  # noqa: BLE001 - never leak SDK/exception text
            logger.warning("unexpected model client failure (%s)", type(exc).__name__)
            raise HTTPException(502, "AI provider error") from None
        try:
            profile, variant = rules.parse_model_output(text)
        except rules.UnusableModelOutput:
            raise HTTPException(502, "AI provider returned an unusable answer") from None
        return ProfileResponse(profile=profile, narrative_variant=variant, source="openai")

    return app


app = create_app()

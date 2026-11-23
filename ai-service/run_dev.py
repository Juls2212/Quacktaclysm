"""Starts the service bound to AI_SERVICE_HOST:AI_SERVICE_PORT (default 127.0.0.1:8000)."""
import uvicorn

from app.config import prepare_settings

if __name__ == "__main__":
    settings = prepare_settings()
    uvicorn.run("app.main:app", host=settings.host, port=settings.port, log_level="info")

"""Starts the service bound to AI_SERVICE_HOST:AI_SERVICE_PORT (default 127.0.0.1:8000)."""
import uvicorn

from app.config import load_dotenv_if_available, load_settings

if __name__ == "__main__":
    load_dotenv_if_available()
    settings = load_settings()
    uvicorn.run("app.main:app", host=settings.host, port=settings.port, log_level="info")

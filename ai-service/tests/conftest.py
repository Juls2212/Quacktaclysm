"""Test isolation: the tests must never read the real ai-service/.env (it may hold a real key).

This runs before any test module imports `app.main` (which builds the app at import time), so the
loader is pointed at a file that does not exist.
"""
import os
import tempfile
from pathlib import Path

os.environ["AI_SERVICE_ENV_FILE"] = str(Path(tempfile.gettempdir()) / "quacktaclysm_no_such_dir" / ".env")

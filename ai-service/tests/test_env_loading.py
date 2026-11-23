"""The .env loader, the startup fallback and /health. Only temporary files; never the real .env."""
import pytest
from fastapi.testclient import TestClient

from app import config
from app.config import ENV_FILE_VAR, env_file_path, load_dotenv_if_available, prepare_settings
from app.main import create_app

FAKE_KEY = "fakekey-unit-test-0123456789"
MANAGED = ("OPENAI_API_KEY", "OPENAI_MODEL", "AI_SERVICE_MODE", "AI_SERVICE_HOST", "AI_SERVICE_PORT",
           "OPENAI_TIMEOUT_SECONDS", ENV_FILE_VAR)


@pytest.fixture
def clean_env(monkeypatch):
    """Registers every variable with monkeypatch so whatever the loader sets is undone afterwards."""
    for name in MANAGED:
        monkeypatch.setenv(name, "placeholder")
        monkeypatch.delenv(name)
    monkeypatch.setattr(config, "_notice_printed", False)
    return monkeypatch


def _env_file(tmp_path, text):
    path = tmp_path / ".env"
    path.write_text(text, encoding="utf-8")
    return path


def test_default_path_is_next_to_the_package_not_the_cwd(clean_env, tmp_path):
    clean_env.chdir(tmp_path)
    path = env_file_path()
    assert path.name == ".env" and path.parent.name == "ai-service"
    assert path.is_absolute()


def test_loader_reads_a_temporary_env_file(clean_env, tmp_path):
    path = _env_file(tmp_path, "AI_SERVICE_MODE=openai\nOPENAI_API_KEY=%s\nOPENAI_MODEL=test-model\nAI_SERVICE_PORT=9123\n" % FAKE_KEY)
    clean_env.setenv(ENV_FILE_VAR, str(path))
    assert load_dotenv_if_available() is True
    settings = config.load_settings()
    assert settings.mode == "openai" and settings.openai_configured and settings.port == 9123


def test_env_file_beats_a_conflicting_shell_variable(clean_env, tmp_path):
    path = _env_file(tmp_path, "AI_SERVICE_MODE=mock\nOPENAI_MODEL=from-file\n")
    clean_env.setenv(ENV_FILE_VAR, str(path))
    clean_env.setenv("AI_SERVICE_MODE", "openai")
    clean_env.setenv("OPENAI_MODEL", "stale-shell-value")
    load_dotenv_if_available()
    settings = config.load_settings()
    assert settings.mode == "mock" and settings.openai_model == "from-file"


def test_missing_env_file_starts_in_mock_without_exception(clean_env, tmp_path, capsys):
    clean_env.setenv(ENV_FILE_VAR, str(tmp_path / "nope" / ".env"))
    settings = prepare_settings()
    assert settings.mode == "mock"
    err = capsys.readouterr().err
    assert err.count("AI service:") == 1 and ".env.example" in err and "MOCK" in err
    prepare_settings()  # a second start in the same process does not repeat the hint
    assert capsys.readouterr().err == ""


def test_openai_mode_with_empty_key_or_model_falls_back_to_mock(clean_env, tmp_path, capsys):
    path = _env_file(tmp_path, "AI_SERVICE_MODE=openai\nOPENAI_API_KEY=\nOPENAI_MODEL=\n")
    clean_env.setenv(ENV_FILE_VAR, str(path))
    settings = prepare_settings()
    assert settings.mode == "mock" and not settings.openai_configured
    err = capsys.readouterr().err
    assert err.count("AI service:") == 1 and ".env.example" in err
    health = TestClient(create_app()).get("/health").json()
    assert health == {"status": "ok", "mode": "mock", "openai_configured": False}


def test_properly_configured_openai_mode_stays_openai_and_is_silent(clean_env, tmp_path, capsys):
    path = _env_file(tmp_path, "AI_SERVICE_MODE=openai\nOPENAI_API_KEY=%s\nOPENAI_MODEL=test-model\n" % FAKE_KEY)
    clean_env.setenv(ENV_FILE_VAR, str(path))
    assert prepare_settings().mode == "openai"
    assert capsys.readouterr().err == ""


def test_health_and_startup_output_contain_no_key_material(clean_env, tmp_path, capsys):
    path = _env_file(tmp_path, "AI_SERVICE_MODE=openai\nOPENAI_API_KEY=%s\nOPENAI_MODEL=test-model\n" % FAKE_KEY)
    clean_env.setenv(ENV_FILE_VAR, str(path))
    client = TestClient(create_app())
    response = client.get("/health")
    assert response.json() == {"status": "ok", "mode": "openai", "openai_configured": True}
    shown = response.text + capsys.readouterr().err + capsys.readouterr().out
    for fragment in (FAKE_KEY, FAKE_KEY[:6], FAKE_KEY[-6:], str(len(FAKE_KEY))):
        assert fragment not in shown

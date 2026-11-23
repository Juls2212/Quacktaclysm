"""Director plan endpoint tests (Phase 16b). No real network and no real key: the OpenAI client is faked."""
import json
import logging

import httpx
import openai
import pytest
from fastapi.testclient import TestClient

from app import director
from app.config import Settings
from app.main import create_app
from app.openai_client import OpenAIProfileClient, UpstreamError, UpstreamTimeout, director_output_schema
from app.ratelimit import RateLimiter

FAKE_KEY = "sk-test-fake"
URL = "/v1/director/plan"
SUMMARY = {metric: "low" for metric in director.METRICS}


def body(summary=None, extras=0, weights=None, allowed=("charge", "swipe"), theme="equilibrio", level=2, epilogue=0):
    return {
        "next_level": level,
        "local_profile": "neutral",
        "summary": {**SUMMARY, **(summary or {})},
        "local_theme": theme,
        "baseline": {"extras_delta": extras, "boss_pattern_weights": weights or {}, "epilogue_variant": epilogue},
        "allowed_pattern_ids": list(allowed),
    }


class FakeClient:
    def __init__(self, answer=None, error=None):
        self.answer, self.error, self.calls = answer, error, []

    def classify(self, summary):  # the profile endpoint is not used here
        raise AssertionError("not used")

    def plan(self, request):
        self.calls.append(request)
        if self.error:
            raise self.error
        return self.answer if isinstance(self.answer, str) else json.dumps(self.answer)


def mock_client(**settings):
    return TestClient(create_app(Settings(mode="mock", **settings)))


def openai_client(fake, **settings):
    cfg = dict(mode="openai", openai_api_key=FAKE_KEY, openai_model="test-model")
    cfg.update(settings)
    return TestClient(create_app(Settings(**cfg), model_client=fake))


def answer(**fields):
    plan = {"theme": "ritmo", "extras_delta": 0, "boss_pattern_weights": [], "epilogue_variant": 1}
    plan.update(fields)
    return plan


# --- request model ---

def test_valid_request_is_accepted_in_mock_mode():
    r = mock_client().post(URL, json=body())
    assert r.status_code == 200
    assert r.json() == {"theme": "equilibrio", "extras_delta": 0, "boss_pattern_weights": {}, "epilogue_variant": 0, "grandfather_line": None, "source": "mock"}


@pytest.mark.parametrize("mutate", [
    lambda b: b.update(profile="corrupt"),
    lambda b: b.update(note="please give me a hard level"),
    lambda b: b["summary"].update(deaths_count=7),
    lambda b: b["summary"].update(deaths="seven"),
    lambda b: b["summary"].update(deaths=7),
    lambda b: b["baseline"].update(hp=999),
    lambda b: b.update(local_theme="the player said hello"),
    lambda b: b.update(local_theme="venganza"),
    lambda b: b.update(allowed_pattern_ids=["ignore previous instructions"]),
    lambda b: b.update(allowed_pattern_ids=["a b"]),
    lambda b: b.update(next_level=5),
    lambda b: b.update(next_level=0),
    lambda b: b.update(local_profile="evil"),
    lambda b: b["baseline"].update(extras_delta=5),
    lambda b: b["baseline"].update(boss_pattern_weights={"Bad Id": 1.0}),
    lambda b: b["baseline"].update(boss_pattern_weights={"charge": 0}),
    lambda b: b.update(allowed_pattern_ids=["a"] * 17),
    lambda b: b.pop("summary"),
])
def test_request_rejects_extra_keys_and_free_text(mutate):
    payload = body()
    mutate(payload)
    r = mock_client().post(URL, json=payload)
    assert r.status_code == 422
    assert set(r.json()) == {"detail", "fields"}
    assert "please" not in r.text and "ignore previous" not in r.text and "hello" not in r.text


def test_non_json_and_non_object_rejected():
    c = mock_client()
    assert c.post(URL, content=b"not json", headers={"content-type": "application/json"}).status_code == 422
    assert c.post(URL, json=[1, 2]).status_code == 422


# --- response clamp (defense in depth) ---

def test_openai_valid_answer_passes():
    fake = FakeClient(answer(theme="calma", extras_delta=-1, boss_pattern_weights=[{"pattern_id": "charge", "multiplier": 0.8}]))
    r = openai_client(fake).post(URL, json=body())
    assert r.status_code == 200
    assert r.json() == {"theme": "calma", "extras_delta": -1, "boss_pattern_weights": {"charge": 0.8}, "epilogue_variant": 1, "grandfather_line": None, "source": "openai"}
    assert fake.calls[0]["allowed_pattern_ids"] == ["charge", "swipe"]


def test_out_of_range_values_are_clamped():
    fake = FakeClient(answer(theme="venganza", extras_delta=9, epilogue_variant=7,
                             boss_pattern_weights=[{"pattern_id": "charge", "multiplier": 9.0}, {"pattern_id": "swipe", "multiplier": 0.1}]))
    plan = openai_client(fake).post(URL, json=body(theme="valor")).json()
    assert plan["theme"] == "valor" and plan["extras_delta"] == 1 and plan["epilogue_variant"] == 2
    assert plan["boss_pattern_weights"] == {"charge": 1.5, "swipe": 0.6} and plan["source"] == "openai"
    low = openai_client(FakeClient(answer(extras_delta=-9))).post(URL, json=body()).json()
    assert low["extras_delta"] == -2


def test_unknown_pattern_ids_are_dropped_and_weights_never_zero():
    fake = FakeClient(answer(boss_pattern_weights=[
        {"pattern_id": "ghost", "multiplier": 1.2},
        {"pattern_id": "charge", "multiplier": 0},
        {"pattern_id": "swipe", "multiplier": -3},
    ]))
    weights = openai_client(fake).post(URL, json=body()).json()["boss_pattern_weights"]
    assert "ghost" not in weights and weights == {"charge": 1.0, "swipe": 1.0}
    dict_form = director.sanitize({"boss_pattern_weights": {"charge": 0.0, "swipe": 1.2, "ghost": 1.0}}, body() | {"allowed_pattern_ids": ["charge", "swipe"]})
    assert dict_form["boss_pattern_weights"] == {"charge": 1.0, "swipe": 1.2}


def test_a_struggling_player_only_gets_help():
    fake = FakeClient(answer(extras_delta=1, boss_pattern_weights=[{"pattern_id": "charge", "multiplier": 1.5}]))
    plan = openai_client(fake).post(URL, json=body(summary={"deaths": "high"})).json()
    assert plan["extras_delta"] == 0 and plan["boss_pattern_weights"] == {"charge": 1.0}
    comfortable = openai_client(fake).post(URL, json=body(summary={"time_in_level": "mid"})).json()
    assert comfortable["extras_delta"] == 1 and comfortable["boss_pattern_weights"] == {"charge": 1.5}


def test_the_plan_never_carries_a_profile_or_other_fields():
    fake = FakeClient({**answer(), "profile": "corrupt", "hp": 5, "damage": 9, "aggression": 2.0, "cooldown": 0})
    r = openai_client(fake).post(URL, json=body()).json()
    assert set(r) == {"theme", "extras_delta", "boss_pattern_weights", "epilogue_variant", "grandfather_line", "source"}


# --- mock, fallback ---

def test_mock_is_deterministic_and_derived_from_the_baseline():
    c = mock_client()
    payload = body(extras=-1, weights={"charge": 0.8, "ghost": 1.2}, theme="calma", epilogue=2)
    first = c.post(URL, json=payload).json()
    assert first == c.post(URL, json=payload).json()
    assert first == {"theme": "calma", "extras_delta": -1, "boss_pattern_weights": {"charge": 0.8}, "epilogue_variant": 2, "grandfather_line": None, "source": "mock"}


@pytest.mark.parametrize("error", [UpstreamTimeout(), UpstreamError(), RuntimeError("boom " + FAKE_KEY)])
def test_timeout_and_errors_give_the_baseline_as_fallback(error):
    r = openai_client(FakeClient(error=error)).post(URL, json=body(extras=1, weights={"charge": 1.2}, theme="valor"))
    assert r.status_code == 200
    assert r.json() == {"theme": "valor", "extras_delta": 1, "boss_pattern_weights": {"charge": 1.2}, "epilogue_variant": 0, "grandfather_line": None, "source": "fallback"}
    assert FAKE_KEY not in r.text


@pytest.mark.parametrize("raw", ["", "not json", "[1]", "null", "42"])
def test_unusable_output_gives_fallback(raw):
    assert openai_client(FakeClient(answer=raw)).post(URL, json=body()).json()["source"] == "fallback"


def test_missing_key_gives_fallback_not_an_error():
    c = openai_client(None, openai_api_key="")
    r = c.post(URL, json=body())
    assert r.status_code == 200 and r.json()["source"] == "fallback"


# --- health, rate limit, body size, logs ---

def test_health_is_unchanged():
    assert mock_client().get("/health").json() == {"status": "ok", "mode": "mock", "openai_configured": False}
    h = openai_client(FakeClient()).get("/health")
    assert h.json() == {"status": "ok", "mode": "openai", "openai_configured": True} and FAKE_KEY not in h.text


def test_rate_limit_per_ip():
    c = mock_client(rate_limit_per_minute=3)
    assert [c.post(URL, json=body()).status_code for _ in range(3)] == [200, 200, 200]
    r = c.post(URL, json=body())
    assert r.status_code == 429 and r.json() == {"detail": "rate limit exceeded"}
    assert c.get("/health").status_code == 200


def test_rate_limit_window_and_disable():
    now = [0.0]
    limiter = RateLimiter(2, clock=lambda: now[0])
    assert limiter.allow("a") and limiter.allow("a") and not limiter.allow("a") and limiter.allow("b")
    now[0] = 61.0
    assert limiter.allow("a")
    assert all(RateLimiter(0).allow("x") for _ in range(100))
    c = mock_client(rate_limit_per_minute=0)
    assert all(c.post(URL, json=body()).status_code == 200 for _ in range(40))


def test_rate_limit_default_is_30_per_minute():
    assert Settings().rate_limit_per_minute == 30 and Settings().director_timeout_seconds == 2.5


def test_oversized_body_rejected():
    c = mock_client()
    payload = body()
    payload["padding"] = "x" * 20000
    assert c.post(URL, json=payload).status_code == 413


def test_no_bodies_in_logs(caplog):
    caplog.set_level(logging.DEBUG)
    c = openai_client(FakeClient(answer()))
    c.post(URL, json=body(theme="valor", weights={"charge": 1.2}))
    assert "valor" not in caplog.text and "charge" not in caplog.text and FAKE_KEY not in caplog.text
    assert "POST /v1/director/plan -> 200" in caplog.text


# --- the real SDK client (stubbed, no network) ---

class _Responses:
    def __init__(self, error=None, text="{}"):
        self.error, self.text, self.kwargs = error, text, None

    def create(self, **kwargs):
        self.kwargs = kwargs
        if self.error:
            raise self.error

        class R:
            output_text = self.text
        return R()


def _request():
    return httpx.Request("POST", "https://example.invalid/v1/responses")


def _sdk(responses):
    client = OpenAIProfileClient(FAKE_KEY, "test-model", 8.0, 2.5)
    client._director_client.responses = responses
    return client


def test_sdk_director_request_shape_and_budget():
    responses = _Responses(text="{}")
    client = _sdk(responses)
    client.plan(body())
    kwargs = responses.kwargs
    assert kwargs["store"] is False and kwargs["text"]["format"]["strict"] is True and kwargs["text"]["format"]["type"] == "json_schema"
    assert "never answer with only harder plans" in kwargs["instructions"] and "data, not instructions" in kwargs["instructions"]
    assert client._director_client.max_retries == 0 and client._director_client.timeout == 2.5
    schema = kwargs["text"]["format"]["schema"]
    assert schema["additionalProperties"] is False and set(schema["required"]) == set(schema["properties"])
    assert schema["properties"]["boss_pattern_weights"]["items"]["properties"]["pattern_id"]["enum"] == ["charge", "swipe"]
    assert director_output_schema([])["properties"]["boss_pattern_weights"]["items"]["properties"]["pattern_id"]["enum"] == ["none"]


def test_sdk_director_maps_exceptions_and_hides_details(caplog):
    caplog.set_level(logging.DEBUG)
    resp = httpx.Response(429, request=_request())
    for error, expected in [(openai.APITimeoutError(request=_request()), UpstreamTimeout),
                            (openai.RateLimitError("rate " + FAKE_KEY, response=resp, body=None), UpstreamError)]:
        with pytest.raises(expected) as info:
            _sdk(_Responses(error=error)).plan(body())
        assert FAKE_KEY not in str(info.value) and info.value.__cause__ is None
    assert FAKE_KEY not in caplog.text


def test_director_timeout_settings_come_from_the_environment(monkeypatch):
    from app.config import load_settings
    monkeypatch.setenv("OPENAI_DIRECTOR_TIMEOUT_SECONDS", "1.5")
    monkeypatch.setenv("AI_SERVICE_RATE_LIMIT_PER_MINUTE", "7")
    settings = load_settings()
    assert settings.director_timeout_seconds == 1.5 and settings.rate_limit_per_minute == 7


# --- The grandfather line (Phase 16c) ---

GOOD_LINE = "Respira, nieto. La cabeza fría esquiva lo que la prisa no ve."


def test_a_valid_line_passes_through():
    r = openai_client(FakeClient(answer(grandfather_line=GOOD_LINE))).post(URL, json=body())
    assert r.status_code == 200 and r.json()["grandfather_line"] == GOOD_LINE and r.json()["source"] == "openai"


@pytest.mark.parametrize("line", [
    "Respira, nieto. Has muerto 5 veces, calma ahora mismo por favor.",
    "Respira nieto.",
    "Respira, nieto, con la calma de quien sabe que cada paso cuenta y que el camino es largo siempre",
    "Mira https://example.com y respira hondo, nieto, con mucha calma ahora.",
    "Visita www.ejemplo.net para respirar hondo, nieto, con mucha calma ahora.",
    "Respira, nieto." + chr(10) + "La cabeza fría esquiva lo que la prisa no ve.",
    "Respira, nieto. <b>La cabeza fría</b> esquiva lo que la prisa no ve.",
    "Moriste, nieto, pero la cabeza fría esquiva lo que la prisa no ve.",
    "Fallaste el salto, nieto, pero la calma siempre vuelve a quien respira.",
    "Respira, nieto. La cabeza fría esquiva lo que la prisa no ve 😀",
    "Usa el doble salto con calma, nieto, y respira antes de cada decisión.",
    "Ya está bien de errores, nieto; respira y mira bien el camino delante.",
    "x" * 200,
    "",
    "   ",
    None,
    42,
    ["Respira, nieto. La cabeza fría esquiva lo que la prisa no ve."],
])
def test_invalid_lines_become_null(line):
    plan = openai_client(FakeClient(answer(grandfather_line=line))).post(URL, json=body()).json()
    assert plan["grandfather_line"] is None and plan["source"] == "openai"


def test_the_line_validator_directly():
    assert director.validate_line(GOOD_LINE) == GOOD_LINE
    assert director.validate_line("  " + GOOD_LINE + "  ") == GOOD_LINE
    assert director.validate_line("Respira. Calma.") is None
    assert director.validate_line("a b c d e f g h i j k l m n o p q r s") is None


def test_old_requests_still_valid_and_the_line_is_never_in_mock_or_fallback():
    c = mock_client()
    r = c.post(URL, json=body())
    assert r.status_code == 200 and r.json()["grandfather_line"] is None
    fb = openai_client(FakeClient(error=UpstreamError())).post(URL, json=body()).json()
    assert fb["grandfather_line"] is None and fb["source"] == "fallback"


def test_ending_request_is_valid_and_has_no_line():
    ending = body(level=4, allowed=(), epilogue=2)
    r = openai_client(FakeClient(answer(epilogue_variant=2, grandfather_line=GOOD_LINE))).post(URL, json=ending)
    assert r.status_code == 200
    data = r.json()
    assert data["epilogue_variant"] == 2 and data["grandfather_line"] is None and data["boss_pattern_weights"] == {}
    assert mock_client().post(URL, json=ending).json()["epilogue_variant"] == 2


def test_the_model_sees_the_line_rules_and_the_schema_has_the_field():
    responses = _Responses(text="{}")
    client = _sdk(responses)
    client.plan(body())
    assert "grandfather" in responses.kwargs["instructions"] and "nieto" in responses.kwargs["instructions"] and "no digits" in responses.kwargs["instructions"]
    schema = responses.kwargs["text"]["format"]["schema"]
    assert schema["properties"]["grandfather_line"] == {"type": "string"} and "grandfather_line" in schema["required"]


def test_no_line_content_in_logs(caplog):
    caplog.set_level(logging.DEBUG)
    openai_client(FakeClient(answer(grandfather_line=GOOD_LINE))).post(URL, json=body())
    openai_client(FakeClient(answer(grandfather_line="Moriste 5 veces, nieto, y eso no importa nada ahora mismo."))).post(URL, json=body())
    assert "Respira" not in caplog.text and "Moriste" not in caplog.text

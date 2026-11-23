"""Rules of the AI Director plan (Phase 16b): the caps, the defense-in-depth clamp of whatever the model (or a client) proposes,
the mock plan and the fallback. Mirrors game/backend/ai/director/default_telemetry_config.tres; the game validates again.

A plan never carries the corruption profile, HP, damage, telegraph times, aggression or cooldowns: it has exactly four
fields. Phase 16c may add ONE optional free-text line; nothing else is free text.
"""
from __future__ import annotations

import json
import re
import unicodedata
from typing import Any

THEMES = ("calma", "paciencia", "distancia", "ritmo", "recursos", "valor", "equilibrio")
BUCKETS = ("low", "mid", "high")
# Same names as RunTelemetry.METRICS in game/backend/ai/director/run_telemetry.gd.
METRICS = (
    "deaths", "damage_taken", "melee_damage", "ranged_damage", "boss_damage", "hazard_damage", "fall_deaths",
    "light_use", "heavy_use", "dash_slash_use", "wave_use", "dash_use", "double_jump_use", "heals", "kills",
    "low_health_time", "time_in_level", "time_in_boss",
)
EXTRAS_MIN = -2
EXTRAS_MAX = 1
WEIGHT_MIN = 0.6
WEIGHT_MAX = 1.5
NEUTRAL_WEIGHT = 1.0
EPILOGUE_MIN = 0
EPILOGUE_MAX = 2
# A player is struggling when one of these is high: then a plan can only make the level easier.
STRUGGLE_METRICS = ("deaths", "damage_taken")
HIGH = "high"
MAX_PATTERN_IDS = 16
# next_level 4 means "the ending": only the epilogue variant matters and no allowed pattern ids are sent.
ENDING_LEVEL = 4

# --- The grandfather line (Phase 16c). Mirrors GrandfatherLineValidator and default_grandfather_lines.tres in the game. ---
LINE_MIN_WORDS = 8
LINE_MAX_WORDS = 18
LINE_MAX_CHARS = 110
_LINE_ALLOWED = re.compile(r"^[A-Za-z\u00c1\u00c9\u00cd\u00d3\u00da\u00dc\u00d1\u00e1\u00e9\u00ed\u00f3\u00fa\u00fc\u00f1\u00bf\u00a1 .,;:!?\-\u2014\u2013\u00ab\u00bb\"'\u2026()]+$")
# Reproach, statistics and game mechanics (compared without accents, as whole words or phrases).
LINE_BANNED = (
    "moriste", "murio", "fallaste", "fallo", "fallos", "errores", "fracaso", "fracasos", "culpas", "fracasaste", "culpa", "error", "torpe", "debil", "debilidad", "inutil",
    "perdiste", "derrota", "esquivaste", "incapaz", "estupido", "game over", "otra vez", "dash", "salto", "tajo", "guardia", "jefe",
    "nivel", "checkpoint", "vidas", "corazones", "golpe pesado", "onda de espada", "doble salto", "estadistica", "porcentaje", "muertes",
)
_URL_MARKS = ("http", "www", ".com", ".net", ".org", "://")


def _plain(text: str) -> str:
    decomposed = unicodedata.normalize("NFD", text)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).lower()


def validate_line(value: Any) -> str | None:
    """The line when it follows the rules of the grandfather's voice, else None. Never raises."""
    if not isinstance(value, str):
        return None
    text = value.strip()
    if not text or len(text) > LINE_MAX_CHARS or any(ch.isdigit() for ch in text):
        return None
    if "\n" in text or "\r" in text or "\t" in text or _LINE_ALLOWED.match(text) is None:
        return None
    words = text.split()
    if not LINE_MIN_WORDS <= len(words) <= LINE_MAX_WORDS:
        return None
    plain = _plain(text)
    if any(mark in plain for mark in _URL_MARKS):
        return None
    padded = " " + re.sub(r"[^a-z ]", " ", plain) + " "
    padded = re.sub(r" +", " ", padded)
    if any((" " + word + " ") in padded for word in LINE_BANNED):
        return None
    return text


class UnusableModelOutput(ValueError):
    """The model answer cannot be trusted or parsed."""


def is_struggling(summary: dict[str, Any]) -> bool:
    return any(summary.get(metric) == HIGH for metric in STRUGGLE_METRICS)


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value == value and abs(value) != float("inf")


def _weights_from(raw: Any) -> dict[str, Any]:
    """Accepts {id: weight} or the list [{"pattern_id": id, "multiplier": weight}] the strict model schema uses."""
    if isinstance(raw, dict):
        return dict(raw)
    result: dict[str, Any] = {}
    if isinstance(raw, list):
        for entry in raw:
            if isinstance(entry, dict) and isinstance(entry.get("pattern_id"), str):
                result[entry["pattern_id"]] = entry.get("multiplier")
    return result


def sanitize(raw: Any, request: dict[str, Any]) -> dict[str, Any]:
    """Clamps a proposed plan to the caps. `request` is the validated request (dict). Never raises on bad content."""
    data = raw if isinstance(raw, dict) else {}
    baseline = request["baseline"]
    theme = data.get("theme")
    if not isinstance(theme, str) or theme not in THEMES:
        theme = request["local_theme"]
    extras = data.get("extras_delta")
    extras = round(extras) if _is_number(extras) else baseline["extras_delta"]
    extras = max(EXTRAS_MIN, min(EXTRAS_MAX, extras))
    allowed = set(request["allowed_pattern_ids"])
    weights: dict[str, float] = {}
    for pattern_id, value in _weights_from(data.get("boss_pattern_weights", {})).items():
        if pattern_id not in allowed:
            continue
        if not _is_number(value) or value <= 0:
            weights[pattern_id] = NEUTRAL_WEIGHT
            continue
        weights[pattern_id] = max(WEIGHT_MIN, min(WEIGHT_MAX, float(value)))
    epilogue = data.get("epilogue_variant")
    epilogue = round(epilogue) if _is_number(epilogue) else baseline.get("epilogue_variant", EPILOGUE_MIN)
    epilogue = max(EPILOGUE_MIN, min(EPILOGUE_MAX, epilogue))
    if is_struggling(request["summary"]):
        # Help, never only harder: a struggling player gets no extra enemy and no heavier pattern.
        extras = min(extras, 0)
        weights = {pattern_id: min(weight, NEUTRAL_WEIGHT) for pattern_id, weight in weights.items()}
    line = None if request["next_level"] == ENDING_LEVEL else validate_line(data.get("grandfather_line"))
    return {"theme": theme, "extras_delta": int(extras), "boss_pattern_weights": weights, "epilogue_variant": int(epilogue), "grandfather_line": line}


def baseline_plan(request: dict[str, Any]) -> dict[str, Any]:
    """The local plan sent as baseline, clamped. Used for mock mode and as the fallback."""
    return sanitize({"theme": request["local_theme"], **request["baseline"]}, request)


def parse_model_output(text: str | None, request: dict[str, Any]) -> dict[str, Any]:
    """Treats model output as untrusted: returns a clamped plan or raises UnusableModelOutput."""
    if not isinstance(text, str) or not text.strip():
        raise UnusableModelOutput("empty answer")
    try:
        data = json.loads(text)
    except ValueError as exc:
        raise UnusableModelOutput("not JSON") from exc
    if not isinstance(data, dict):
        raise UnusableModelOutput("not an object")
    return sanitize(data, request)

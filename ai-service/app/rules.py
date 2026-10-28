"""Profile rules shared by mock mode and by the validation of model output."""
from __future__ import annotations

import json
from typing import Any

PROFILE_COMPASSIONATE = "compassionate"
PROFILE_NEUTRAL = "neutral"
PROFILE_CORRUPT = "corrupt"
PROFILES = (PROFILE_COMPASSIONATE, PROFILE_NEUTRAL, PROFILE_CORRUPT)

# Mirrors game/backend/ai/default_adaptive_config.tres (first entry = profile default).
ALLOWED_VARIANTS: dict[str, tuple[str, ...]] = {
    PROFILE_COMPASSIONATE: ("mercy", "mercy_hopeful"),
    PROFILE_NEUTRAL: ("balanced",),
    PROFILE_CORRUPT: ("burden", "burden_bitter"),
}
ALL_VARIANTS = tuple(v for variants in ALLOWED_VARIANTS.values() for v in variants)

# Mirrors AdaptiveConfig.decision_margin_threshold (mock mode only).
MOCK_THRESHOLD = 2.0


def default_variant(profile: str) -> str:
    return ALLOWED_VARIANTS[profile][0]


def score(decisions: list[dict[str, Any]]) -> float:
    """released = +1, kept = -1 (level weights are 1.0 in the default Godot config)."""
    return float(sum(1 if d["choice"] == "released" else -1 for d in decisions))


def classify(decisions: list[dict[str, Any]]) -> str:
    value = score(decisions)
    if value >= MOCK_THRESHOLD:
        return PROFILE_COMPASSIONATE
    if value <= -MOCK_THRESHOLD:
        return PROFILE_CORRUPT
    return PROFILE_NEUTRAL


class UnusableModelOutput(ValueError):
    """The model answer cannot be trusted or parsed."""


def parse_model_output(text: str | None) -> tuple[str, str]:
    """Treats model output as untrusted: returns (profile, variant) or raises UnusableModelOutput."""
    if not isinstance(text, str) or not text.strip():
        raise UnusableModelOutput("empty answer")
    try:
        data = json.loads(text)
    except ValueError as exc:
        raise UnusableModelOutput("not JSON") from exc
    if not isinstance(data, dict):
        raise UnusableModelOutput("not an object")
    profile = data.get("profile")
    if not isinstance(profile, str) or profile not in PROFILES:
        raise UnusableModelOutput("unknown profile")
    variant = data.get("narrative_variant")
    if not isinstance(variant, str) or variant not in ALLOWED_VARIANTS[profile]:
        variant = default_variant(profile)
    return profile, variant

"""Request/response schemas. Strict, with extra fields forbidden."""
from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

from .director import MAX_PATTERN_IDS

# Same string ids as AdaptiveInput.POINT_* in game/backend/ai/adaptive_input.gd.
EvaluationPoint = Literal["after_decision", "level_start", "ending"]
Profile = Literal["compassionate", "neutral", "corrupt"]
ID_PATTERN = r"^[a-z0-9_]{1,64}$"


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class Decision(_Strict):
    fragment_id: str = Field(pattern=ID_PATTERN)
    boss_id: str = Field(pattern=ID_PATTERN)
    level: int = Field(ge=1, le=3)
    choice: Literal["released", "kept"]


class ProfileRequest(_Strict):
    released: int = Field(ge=0, le=10)
    kept: int = Field(ge=0, le=10)
    current_level: int = Field(ge=1, le=3)
    evaluation_point: EvaluationPoint
    local_profile: Profile
    decisions: list[Decision] = Field(max_length=10)


class ProfileResponse(_Strict):
    profile: Profile
    narrative_variant: str
    source: Literal["openai", "mock"]


# --- AI Director plan (Phase 16b). Only enums, bounded numbers and ids: never free text from the player. ---
Theme = Literal["calma", "paciencia", "distancia", "ritmo", "recursos", "valor", "equilibrio"]
Bucket = Literal["low", "mid", "high"]
PatternId = Annotated[str, StringConstraints(pattern=ID_PATTERN)]


class TelemetrySummary(_Strict):
    """The categorical summary of Phase 16a (RunTelemetry.summarize): low / mid / high, never counts."""

    deaths: Bucket
    damage_taken: Bucket
    melee_damage: Bucket
    ranged_damage: Bucket
    boss_damage: Bucket
    hazard_damage: Bucket
    fall_deaths: Bucket
    light_use: Bucket
    heavy_use: Bucket
    dash_slash_use: Bucket
    wave_use: Bucket
    dash_use: Bucket
    double_jump_use: Bucket
    heals: Bucket
    kills: Bucket
    low_health_time: Bucket
    time_in_level: Bucket
    time_in_boss: Bucket


class BaselinePlan(_Strict):
    """The local plan, sent as the baseline the model may keep or adjust."""

    extras_delta: int = Field(ge=-2, le=1)
    boss_pattern_weights: dict[PatternId, float] = Field(default_factory=dict, max_length=MAX_PATTERN_IDS)
    epilogue_variant: int = Field(default=0, ge=0, le=2)

    @field_validator("boss_pattern_weights")
    @classmethod
    def _positive(cls, value: dict[str, float]) -> dict[str, float]:
        if any(not 0 < weight <= 3 for weight in value.values()):
            raise ValueError("weight out of range")
        return value


class DirectorRequest(_Strict):
    # 1 to 3: the level about to load; 4: the ending (only the epilogue variant matters, allowed_pattern_ids is empty).
    next_level: int = Field(ge=1, le=4)
    local_profile: Profile
    summary: TelemetrySummary
    local_theme: Theme
    baseline: BaselinePlan
    allowed_pattern_ids: list[PatternId] = Field(default_factory=list, max_length=MAX_PATTERN_IDS)


class DirectorResponse(_Strict):
    """`grandfather_line` is the ONE optional free-text field (Phase 16c): a validated line in the grandfather voice, or null."""

    theme: Theme
    extras_delta: int = Field(ge=-2, le=1)
    boss_pattern_weights: dict[PatternId, float] = Field(default_factory=dict, max_length=MAX_PATTERN_IDS)
    epilogue_variant: int = Field(ge=0, le=2)
    grandfather_line: str | None = None
    source: Literal["openai", "mock", "fallback"]

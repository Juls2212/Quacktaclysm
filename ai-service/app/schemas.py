"""Request/response schemas. Strict, with extra fields forbidden."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

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

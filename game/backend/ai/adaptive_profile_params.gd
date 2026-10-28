class_name AdaptiveProfileParams
extends Resource
## Controlled output values of one adaptive profile. The remote service can only pick a
## profile (and a variant from `allowed_narrative_variants`); every value here comes from data.

@export var profile_id: String = ""
## Default narrative variant of the profile; must be contained in `allowed_narrative_variants`.
@export var narrative_variant: String = ""
@export var allowed_narrative_variants: PackedStringArray = PackedStringArray()
@export var encounter_variant: String = ""
@export var ending_variant: String = ""
## Multiplier consumed by a later phase (bosses).
@export_range(0.5, 2.0, 0.01) var boss_aggression: float = 1.0

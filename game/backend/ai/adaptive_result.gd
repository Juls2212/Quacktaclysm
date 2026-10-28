class_name AdaptiveResult
extends RefCounted
## Output of the adaptive system. Every field is data from AdaptiveConfig, never free text.

var profile: String = AdaptiveIds.PROFILE_NEUTRAL
var narrative_variant: String = ""
var encounter_variant: String = ""
var ending_variant: String = ""
var boss_aggression: float = 1.0
## AdaptiveIds.SOURCE_DEFAULT, SOURCE_LOCAL or SOURCE_REMOTE.
var source: String = AdaptiveIds.SOURCE_DEFAULT
var warnings: Array[String] = []


static func from_params(params: AdaptiveProfileParams, source_id: String) -> AdaptiveResult:
	var result := AdaptiveResult.new()
	result.profile = params.profile_id
	result.narrative_variant = params.narrative_variant
	result.encounter_variant = params.encounter_variant
	result.ending_variant = params.ending_variant
	result.boss_aggression = params.boss_aggression
	result.source = source_id
	return result


## JSON-safe snapshot for logs and tests.
func to_dict() -> Dictionary:
	return {
		"profile": profile,
		"narrative_variant": narrative_variant,
		"encounter_variant": encounter_variant,
		"ending_variant": ending_variant,
		"boss_aggression": boss_aggression,
		"source": source,
		"warnings": warnings.duplicate(),
	}

class_name AdaptiveConfig
extends Resource
## Tunable data of the adaptive system: classifier thresholds/weights, remote tolerance and
## the per-profile output table. Default instance: res://backend/ai/default_adaptive_config.tres.

const DEFAULT_LEVEL_WEIGHT: float = 1.0

## |weighted score| needed to leave the neutral profile.
@export_range(0.5, 10.0, 0.1) var decision_margin_threshold: float = 2.0
## Indexed by level - 1; a missing index counts as 1.0.
@export var level_weights: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0])
## Largest allowed distance between a remote profile and the local one (compassionate=0, neutral=1, corrupt=2).
@export_range(0, 2) var max_profile_distance: int = 1
@export var params_compassionate: AdaptiveProfileParams
@export var params_neutral: AdaptiveProfileParams
@export var params_corrupt: AdaptiveProfileParams


func is_known_profile(profile: String) -> bool:
	return AdaptiveIds.is_known_profile(profile)


func get_level_weight(level: int) -> float:
	var index: int = level - 1
	if index < 0 or index >= level_weights.size():
		return DEFAULT_LEVEL_WEIGHT
	return level_weights[index]


## Unknown profile falls back to neutral. If the table itself is incomplete an empty params
## object carrying the profile id is returned, so callers never get null.
func get_params(profile: String) -> AdaptiveProfileParams:
	var params: AdaptiveProfileParams = null
	match profile:
		AdaptiveIds.PROFILE_COMPASSIONATE:
			params = params_compassionate
		AdaptiveIds.PROFILE_CORRUPT:
			params = params_corrupt
		_:
			profile = AdaptiveIds.PROFILE_NEUTRAL
			params = params_neutral
	if params == null:
		params = AdaptiveProfileParams.new()
		params.profile_id = profile
	return params


## Distance on the ordered scale; an unknown profile is farther than any allowed distance.
func profile_distance(a: String, b: String) -> int:
	var index_a: int = AdaptiveIds.PROFILE_ORDER.find(a)
	var index_b: int = AdaptiveIds.PROFILE_ORDER.find(b)
	if index_a < 0 or index_b < 0:
		return AdaptiveIds.PROFILE_ORDER.size()
	return absi(index_a - index_b)

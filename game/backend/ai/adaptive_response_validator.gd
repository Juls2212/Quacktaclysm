class_name AdaptiveResponseValidator
extends RefCounted
## Contract for the future remote service. Pure and static; never throws on bad input.
##
## Expected remote JSON: { "profile": "compassionate|neutral|corrupt", "narrative_variant": "<optional string>" }
## The remote side can only choose a known profile and (optionally) one of its allowed
## narrative variants. Every other key is ignored: encounter/ending variants and boss
## aggression always come from the config table of the validated profile.

const MAX_TEXT_LENGTH: int = 64


## Returns { "ok": bool, "result": AdaptiveResult or null, "reason": String }.
static func validate(raw: Variant, local_result: AdaptiveResult, config: AdaptiveConfig) -> Dictionary:
	var cfg: AdaptiveConfig = config if config != null else AdaptiveConfig.new()
	if not raw is Dictionary:
		return _fail("response is not a dictionary")
	var data: Dictionary = raw
	var raw_profile: Variant = data.get("profile")
	if not raw_profile is String:
		return _fail("profile missing or not a string")
	var profile_text: String = raw_profile
	if profile_text.length() > MAX_TEXT_LENGTH:
		return _fail("profile longer than %d characters" % MAX_TEXT_LENGTH)
	var profile: String = profile_text.strip_edges().to_lower()
	if not cfg.is_known_profile(profile):
		return _fail("unknown profile")

	var local_profile: String = local_result.profile if local_result != null else AdaptiveIds.PROFILE_NEUTRAL
	var distance: int = cfg.profile_distance(profile, local_profile)
	if distance > cfg.max_profile_distance:
		return _fail("profile '%s' is %d steps from local '%s' (max %d)" % [profile, distance, local_profile, cfg.max_profile_distance])

	var params: AdaptiveProfileParams = cfg.get_params(profile)
	var result: AdaptiveResult = AdaptiveResult.from_params(params, AdaptiveIds.SOURCE_REMOTE)
	result.profile = profile
	if data.has("narrative_variant"):
		var variant: Variant = data["narrative_variant"]
		if variant is String and (variant as String).length() <= MAX_TEXT_LENGTH \
				and params.allowed_narrative_variants.has(variant):
			result.narrative_variant = variant
		else:
			result.warnings.append("narrative_variant not allowed for '%s', using default" % profile)
	return {"ok": true, "result": result, "reason": ""}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "result": null, "reason": reason}

class_name DirectorPlanValidator
extends RefCounted
## The ONLY door for plans (Phase 16a; the remote AI of Phase 16b uses it too). Pure and static; never throws on bad input.
##   - not a dictionary, or any key of TelemetryConfig.forbidden_keys (profile, hp, damage, aggression, cooldown...): REJECTED.
##   - any other key outside the four plan fields is DROPPED (with a warning).
##   - theme not in the list: replaced by the local theme. extras_delta: clamped to the caps (not a number: 0).
##   - boss_pattern_weights: ids that are not known patterns are dropped; a value that is zero, negative or not a number is
##     replaced by 1.0 (neutral); the rest is clamped to 0.6..1.5, so a weight is never 0.
##   - epilogue_variant: clamped to 0..2. Missing fields take the neutral value.

const _ID_PATTERN: String = "^[a-z0-9_]{1,64}$"


## Returns {"ok": bool, "plan": DirectorPlan or null, "warnings": Array[String], "reason": String}.
## `known_pattern_ids` = the rotation patterns of the level boss; empty means "any well-formed id".
static func validate(raw: Variant, local_theme: String, config: TelemetryConfig = null, known_pattern_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	var cfg: TelemetryConfig = config if config != null else TelemetryConfig.get_default()
	var warnings: Array[String] = []
	if not raw is Dictionary:
		return _fail("plan is not a dictionary", warnings)
	var data: Dictionary = raw
	for key: Variant in data.keys():
		if cfg.forbidden_keys.has(String(key).strip_edges().to_lower()):
			return _fail("forbidden key '%s'" % String(key), warnings)
	for key: Variant in data.keys():
		if not DirectorPlan.KEYS.has(String(key)):
			warnings.append("unknown key '%s' dropped" % String(key))

	var fallback_theme: String = local_theme if cfg.themes.has(local_theme) else cfg.default_theme
	var plan := DirectorPlan.new()
	var raw_theme: Variant = data.get("theme", fallback_theme)
	if raw_theme is String and cfg.themes.has((raw_theme as String).strip_edges().to_lower()):
		plan.theme = (raw_theme as String).strip_edges().to_lower()
	else:
		plan.theme = fallback_theme
		if data.has("theme"):
			warnings.append("theme not in the list, using the local one")

	var raw_delta: Variant = data.get("extras_delta", 0)
	if _is_number(raw_delta):
		plan.extras_delta = clampi(roundi(float(raw_delta)), cfg.extras_delta_min, cfg.extras_delta_max)
	else:
		plan.extras_delta = 0
		warnings.append("extras_delta is not a number, using 0")

	var raw_weights: Variant = data.get("boss_pattern_weights", {})
	if raw_weights is Dictionary:
		var regex: RegEx = RegEx.create_from_string(_ID_PATTERN)
		for id: Variant in (raw_weights as Dictionary).keys():
			var id_text: String = String(id)
			if regex.search(id_text) == null or (not known_pattern_ids.is_empty() and not known_pattern_ids.has(id_text)):
				warnings.append("unknown pattern '%s' dropped" % id_text)
				continue
			var value: Variant = (raw_weights as Dictionary)[id]
			if not _is_number(value) or float(value) <= 0.0:
				plan.boss_pattern_weights[id_text] = 1.0
				warnings.append("weight of '%s' replaced by 1.0" % id_text)
				continue
			plan.boss_pattern_weights[id_text] = clampf(float(value), cfg.weight_min, cfg.weight_max)
	elif data.has("boss_pattern_weights"):
		warnings.append("boss_pattern_weights is not a dictionary, ignored")

	var raw_epilogue: Variant = data.get("epilogue_variant", 0)
	plan.epilogue_variant = clampi(roundi(float(raw_epilogue)), 0, cfg.epilogue_max) if _is_number(raw_epilogue) else 0
	return {"ok": true, "plan": plan, "warnings": warnings, "reason": ""}


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _fail(reason: String, warnings: Array[String]) -> Dictionary:
	return {"ok": false, "plan": null, "warnings": warnings, "reason": reason}

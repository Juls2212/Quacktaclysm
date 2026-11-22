class_name DirectorPlan
extends RefCounted
## What the AI Director decides for ONE level (Phase 16a). Exactly four fields, nothing else: it never carries the corruption
## profile, boss HP, damage, telegraph times, aggression or cooldowns. Built by the local planner (and, in Phase 16b, by the
## remote AI) and only ever accepted through DirectorPlanValidator.

const KEYS: PackedStringArray = ["theme", "extras_delta", "boss_pattern_weights", "epilogue_variant"]

## One of TelemetryConfig.themes.
var theme: String = "equilibrio"
## Added to the profile extra enemies of the level (final count clamped to 0..3).
var extras_delta: int = 0
## Boss rotation pattern id -> multiplier of its weight (0.6 to 1.5, never 0).
var boss_pattern_weights: Dictionary = {}
## 0 to 2; used by the epilogue of Phase 16c.
var epilogue_variant: int = 0


static func neutral(p_theme: String = "equilibrio") -> DirectorPlan:
	var plan := DirectorPlan.new()
	plan.theme = p_theme
	return plan


## True when applying the plan changes nothing.
func is_neutral() -> bool:
	if extras_delta != 0:
		return false
	for id: Variant in boss_pattern_weights.keys():
		if not is_equal_approx(float(boss_pattern_weights[id]), 1.0):
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"theme": theme,
		"extras_delta": extras_delta,
		"boss_pattern_weights": boss_pattern_weights.duplicate(),
		"epilogue_variant": epilogue_variant,
	}


## One short line for the debug log.
func describe() -> String:
	return "theme=%s extras_delta=%d weights=%s epilogue=%d" % [theme, extras_delta, str(boss_pattern_weights), epilogue_variant]

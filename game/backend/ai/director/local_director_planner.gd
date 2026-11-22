class_name LocalDirectorPlanner
extends RefCounted
## Deterministic planner (Phase 16a): categorical summary -> DirectorPlan. Same input, same plan.
##   - STRUGGLING (deaths high, or damage taken high): fewer extra enemies (-1; -2 when BOTH are high) and the boss pattern that
##     hurt the most is weighted down (0.8; 0.6 when both are high).
##   - COMFORTABLE (deaths low, damage low and the level was really played: time not low): one more extra enemy and the pattern
##     that hurt the most (the one the player handles worst) is weighted up.
##   - otherwise the neutral plan (delta 0, no weights). The theme is always the local one.
## All numbers come from the TelemetryConfig; the plan is validated before it is returned.


## `worst_pattern` is the boss pattern id that hurt the player most ("" when none).
static func plan(summary: Dictionary, worst_pattern: String, config: TelemetryConfig = null, known_pattern_ids: PackedStringArray = PackedStringArray()) -> DirectorPlan:
	var cfg: TelemetryConfig = config if config != null else TelemetryConfig.get_default()
	var theme: String = DirectorThemes.select(summary, cfg)
	var raw: Dictionary = {"theme": theme, "extras_delta": 0, "boss_pattern_weights": {}, "epilogue_variant": cfg.epilogue_neutral}
	var deaths: String = String(summary.get("deaths", TelemetryConfig.LOW))
	var damage: String = String(summary.get("damage_taken", TelemetryConfig.LOW))
	var time_played: String = String(summary.get("time_in_level", TelemetryConfig.LOW))
	var struggling: bool = deaths == TelemetryConfig.HIGH or damage == TelemetryConfig.HIGH
	var severe: bool = deaths == TelemetryConfig.HIGH and damage == TelemetryConfig.HIGH
	var comfortable: bool = deaths == TelemetryConfig.LOW and damage == TelemetryConfig.LOW and time_played != TelemetryConfig.LOW
	if struggling:
		raw["extras_delta"] = cfg.struggle_delta_high if severe else cfg.struggle_delta_mid
		raw["epilogue_variant"] = cfg.epilogue_struggle
		if not worst_pattern.is_empty():
			raw["boss_pattern_weights"] = {worst_pattern: cfg.struggle_weight_high if severe else cfg.struggle_weight_mid}
	elif comfortable:
		raw["extras_delta"] = cfg.comfort_delta
		raw["epilogue_variant"] = cfg.epilogue_comfortable
		if not worst_pattern.is_empty():
			raw["boss_pattern_weights"] = {worst_pattern: cfg.comfort_weight}
	var verdict: Dictionary = DirectorPlanValidator.validate(raw, theme, cfg, known_pattern_ids)
	return verdict["plan"] if verdict["ok"] else DirectorPlan.neutral(cfg.default_theme)

class_name Director
extends RefCounted
## The local AI Director (Phase 16a). A plain object owned by GameState as a field: not an autoload, never saved. It holds the
## in-memory telemetry, one plan per level (cached, so a retry in the same session reuses it) and the debug override.
## `plan_for_level()` is called once per level load (LevelBase._apply_adaptive). The plan of level N comes from the telemetry of
## level N - 1; level 1, a level with no telemetry behind it (for example after continuing from disk) and any error give the
## NEUTRAL plan. Every plan, local or forced, goes through DirectorPlanValidator.
##
## Debug-only override (never in a release export): `set_forced_plan(dict)`, `set_force_neutral(true)` or the environment
## variables QUACKTACLYSM_DIRECTOR_PLAN (a JSON plan) and QUACKTACLYSM_DIRECTOR_NEUTRAL (any value) make every level load use
## that plan, so QA and the tests are reproducible.

## next_level 4 is the ending: only its epilogue variant is asked for and used.
const ENDING_LEVEL: int = 4
const ENV_PLAN: String = "QUACKTACLYSM_DIRECTOR_PLAN"
const ENV_NEUTRAL: String = "QUACKTACLYSM_DIRECTOR_NEUTRAL"

var telemetry := RunTelemetry.new()
var config: TelemetryConfig = null
## Tests set this to behave as a release build (the overrides are then refused).
var simulate_release: bool = false

## Bumped by every reset: an answer that arrives after a new game or a loaded save belongs to another run and is discarded.
var run_id: int = 0
## Where the plan of the last plan_for_level() call came from: forced, forced_neutral, remote, local, neutral or cached.
var last_source: String = ""

## Lines of the grandfather shown in this session (never repeated while others of the set remain) and the levels already voiced.
var shown_lines: Array[String] = []
var lines: GrandfatherLines = null

var _voiced_levels: Dictionary = {}
var _remote_lines: Dictionary = {}
var _plans: Dictionary = {}
var _sources: Dictionary = {}
var _remote: Dictionary = {}
var _forced: Dictionary = {}
var _force_neutral: bool = false
var _env_read: bool = false


func get_config() -> TelemetryConfig:
	if config == null:
		config = TelemetryConfig.get_default()
	return config


## New game or loaded save: telemetry and cached plans are forgotten (the debug override stays).
func reset() -> void:
	telemetry.reset()
	_plans.clear()
	_sources.clear()
	_remote.clear()
	_remote_lines.clear()
	run_id += 1


func overrides_allowed() -> bool:
	return OS.is_debug_build() and not simulate_release


## Forces a plan for every level (debug builds only). Returns false when refused (release build or an invalid plan).
func set_forced_plan(raw: Dictionary) -> bool:
	if not overrides_allowed():
		return false
	var verdict: Dictionary = DirectorPlanValidator.validate(raw, get_config().default_theme, get_config())
	if not verdict["ok"]:
		return false
	_forced = (verdict["plan"] as DirectorPlan).to_dict()
	_force_neutral = false
	_plans.clear()
	return true


func set_force_neutral(value: bool) -> bool:
	if not overrides_allowed():
		return false
	_force_neutral = value
	_forced = {}
	_plans.clear()
	return true


func clear_overrides() -> void:
	_forced = {}
	_force_neutral = false
	_plans.clear()


func has_override() -> bool:
	_read_environment()
	return overrides_allowed() and (_force_neutral or not _forced.is_empty())


func get_cached_plan(level: int) -> DirectorPlan:
	return _plans.get(level)


## The source (remote, local, neutral) the cached plan of a level came from; "" before the level loaded.
func get_plan_source(level: int) -> String:
	return String(_sources.get(level, ""))


## Stores a validated remote plan for `level` (Phase 16b). Refused (false) when that level already loaded: a late answer is
## discarded, the level keeps the plan it started with. The caller validated it with DirectorPlanValidator.
func set_remote_plan(level: int, plan: DirectorPlan, line: String = "") -> bool:
	if plan == null or _plans.has(level):
		return false
	_remote[level] = plan
	if not line.is_empty():
		_remote_lines[level] = line
	return true


func has_remote_plan(level: int) -> bool:
	return _remote.has(level)


func get_lines() -> GrandfatherLines:
	if lines == null:
		lines = GrandfatherLines.get_default()
	return lines


## Whether the grandfather already spoke at the start of `level` in this session (a retry does not repeat it).
func has_voiced(level: int) -> bool:
	return _voiced_levels.has(level)


func mark_voiced(level: int) -> void:
	_voiced_levels[level] = true


## Forgets the lines shown and the levels voiced (a new session; the tests).
func clear_voice_memory() -> void:
	shown_lines.clear()
	_voiced_levels.clear()


## The line for the start of `level`: level 1 a remembered saying; levels 2 and 3 a valid REMOTE line when the plan of that level is
## the remote one, else a deterministic bank line of the plan theme. Never a line already shown in the session while others of
## the set remain. Returns {"text": String, "source": "remote" | "bank" | "memory"}; the text is "" only if the bank is empty.
func choose_line(level: int, theme: String, decisions: Array) -> Dictionary:
	var bank: GrandfatherLines = get_lines()
	var text: String = ""
	var source: String = "bank"
	if level <= 1:
		source = "memory"
		text = _pick_unshown(bank.memory_lines, GrandfatherLineSelector.seed_for(bank.memory_theme, level, decisions))
	else:
		var remote: String = String(_remote_lines.get(level, ""))
		if not remote.is_empty() and get_plan_source(level) == "remote" and not shown_lines.has(remote) and GrandfatherLineValidator.validate(remote, bank)["ok"]:
			text = remote
			source = "remote"
		else:
			var set_theme: String = theme if get_config().themes.has(theme) else get_config().default_theme
			text = _pick_unshown(bank.lines_for(set_theme), GrandfatherLineSelector.seed_for(set_theme, level, decisions))
	if not text.is_empty():
		shown_lines.append(text)
	return {"text": text, "source": source}


func _pick_unshown(candidates: Array, seed_value: int) -> String:
	var any_left: bool = false
	for candidate in candidates:
		any_left = any_left or not shown_lines.has(String(candidate))
	if not any_left:
		for candidate in candidates:
			shown_lines.erase(String(candidate))
	return GrandfatherLineSelector.pick(candidates, seed_value, shown_lines)


## The epilogue variant (0 to 2) of the ending: the plan of the ending level (remote if it arrived and is valid, else local;
## 0 without telemetry, for example after continuing from disk).
func epilogue_variant() -> int:
	return clampi(plan_for_level(ENDING_LEVEL).epilogue_variant, 0, get_config().epilogue_max)


## The plan to apply when `level` loads. `known_pattern_ids` = the rotation patterns of that level boss (may be empty).
func plan_for_level(level: int, known_pattern_ids: PackedStringArray = PackedStringArray()) -> DirectorPlan:
	var cfg: TelemetryConfig = get_config()
	_read_environment()
	if overrides_allowed():
		if _force_neutral:
			last_source = "forced_neutral"
			return DirectorPlan.neutral(cfg.default_theme)
		if not _forced.is_empty():
			var verdict: Dictionary = DirectorPlanValidator.validate(_forced, cfg.default_theme, cfg, known_pattern_ids)
			last_source = "forced"
			return verdict["plan"] if verdict["ok"] else DirectorPlan.neutral(cfg.default_theme)
	if _plans.has(level):
		last_source = "cached"
		return _plans[level]
	var plan: DirectorPlan = null
	var source: String = "local"
	if _remote.has(level) and level >= cfg.active_from_level:
		# Validated once more here, with the pattern ids of the boss that really loaded.
		var remote: Dictionary = DirectorPlanValidator.validate((_remote[level] as DirectorPlan).to_dict(), cfg.default_theme, cfg, known_pattern_ids)
		if remote["ok"]:
			plan = remote["plan"]
			source = "remote"
	if plan == null:
		plan = _compute(level, known_pattern_ids)
		source = "neutral" if plan.is_neutral() else "local"
	_remote.erase(level)
	_plans[level] = plan
	_sources[level] = source
	last_source = source
	return plan


func _compute(level: int, known_pattern_ids: PackedStringArray) -> DirectorPlan:
	var cfg: TelemetryConfig = get_config()
	var behind: int = level - 1
	if level < cfg.active_from_level or not telemetry.has_level(behind):
		return DirectorPlan.neutral(cfg.default_theme)
	return LocalDirectorPlanner.plan(telemetry.summarize(behind, cfg), telemetry.worst_pattern(behind), cfg, known_pattern_ids)


func _read_environment() -> void:
	if _env_read:
		return
	_env_read = true
	if not overrides_allowed():
		return
	if not OS.get_environment(ENV_NEUTRAL).is_empty():
		_force_neutral = true
		return
	var text: String = OS.get_environment(ENV_PLAN).strip_edges()
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var verdict: Dictionary = DirectorPlanValidator.validate(parsed, get_config().default_theme, get_config())
		if verdict["ok"]:
			_forced = (verdict["plan"] as DirectorPlan).to_dict()

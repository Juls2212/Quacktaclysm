class_name DirectorClient
extends Node
## Asks the AI service for the Director plan of the NEXT level (Phase 16b). Not an autoload: GameState (an existing autoload)
## owns it as a child, so a request survives the scene change. It is started at the same moment as the existing narrative call
## (after the player decides a fragment) and only PREFETCHES: the level never waits for the network. The answer goes through
## DirectorPlanValidator (the same door as the local plan) and is kept in memory in GameState.director, keyed by the next level.
## At level load LevelBase uses it if it is there; a late answer (the level already loaded), a failure, a timeout, an invalid
## plan, the option "Adaptación con IA" off, a forced debug plan or a service in mock / fallback mode all end with the local plan
## and no visible error. Nothing here is saved and no key is ever involved: the service holds the OpenAI key.

signal request_started(level: int)
signal request_finished(level: int, status: String)

const STATUS_APPLIED: String = "applied"
const STATUS_LATE: String = "late"
const STATUS_STALE: String = "stale"
const STATUS_REJECTED: String = "rejected"
const STATUS_SERVICE_LOCAL: String = "service_local"
const STATUS_SKIPPED: String = "skipped"
const STATUS_OPTION_OFF: String = "option_off"
const STATUS_OVERRIDE: String = "override"
const STATUS_NO_TELEMETRY: String = "no_telemetry"

## The AiClient that talks to the service (tests assign its `transport`).
var ai: AiClient = null
var in_flight: bool = false
## Status of the last attempt: an AiClient.STATUS_* or one of the STATUS_* above.
var last_status: String = "idle"
## Requests that really left the client (the tests read it).
var requests_sent: int = 0

var _level: int = 0
var _request_id: int = 0
var _run_id: int = 0
var _known_ids: PackedStringArray = PackedStringArray()


func _ready() -> void:
	if ai == null:
		ai = AiClient.new()
		ai.name = "AiClient"
		add_child(ai)
	ai.completed.connect(_on_completed)


func _exit_tree() -> void:
	in_flight = false
	_request_id = 0


## Starts the request for the level after `completed_level`. Returns false when nothing was sent (and why: `last_status`).
func request_plan(completed_level: int) -> bool:
	var director: Director = GameState.director
	var cfg: TelemetryConfig = director.get_config()
	var next_level: int = completed_level + 1
	if next_level > Director.ENDING_LEVEL or next_level < cfg.active_from_level:
		return _skip(STATUS_SKIPPED)
	if not GameSettings.is_ai_adaptation_enabled():
		return _skip(STATUS_OPTION_OFF)
	if director.has_override():
		return _skip(STATUS_OVERRIDE)
	if not director.telemetry.has_level(completed_level):
		return _skip(STATUS_NO_TELEMETRY)
	_known_ids = rotation_ids_for(next_level, cfg)
	_level = next_level
	_run_id = director.run_id
	in_flight = true
	last_status = "in_flight"
	requests_sent += 1
	request_started.emit(next_level)
	_request_id = ai.request_director(build_payload(completed_level, next_level, _known_ids))
	return true


## Exactly the fields of the service request schema: categories, the local theme, the local plan as the baseline and the ids of
## the next boss rotation patterns. No counts, no free text.
func build_payload(completed_level: int, next_level: int, known_ids: PackedStringArray) -> Dictionary:
	var director: Director = GameState.director
	var cfg: TelemetryConfig = director.get_config()
	var summary: Dictionary = director.telemetry.summarize(completed_level, cfg)
	var local: DirectorPlan = LocalDirectorPlanner.plan(summary, director.telemetry.worst_pattern(completed_level), cfg, known_ids)
	return {
		"next_level": clampi(next_level, 1, Director.ENDING_LEVEL),
		"local_profile": GameState.adaptive_profile,
		"summary": summary,
		"local_theme": local.theme,
		"baseline": {
			"extras_delta": local.extras_delta,
			"boss_pattern_weights": local.boss_pattern_weights,
			"epilogue_variant": local.epilogue_variant,
		},
		"allowed_pattern_ids": Array(known_ids),
	}


## Rotation pattern ids of the boss of `level` (read from its scene, which is not added to the tree).
func rotation_ids_for(level: int, cfg: TelemetryConfig) -> PackedStringArray:
	var ids := PackedStringArray()
	var path: String = String(cfg.boss_scenes.get(level, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return ids
	var boss := (load(path) as PackedScene).instantiate()
	var patterns: Node = boss.get_node_or_null(^"Patterns")
	if patterns != null:
		for child in patterns.get_children():
			if child is BossPattern and (child as BossPattern).fallback_priority == 0 and (child as BossPattern).weight > 0.0:
				ids.append(String((child as BossPattern).pattern_id))
	boss.free()
	return ids


func _on_completed(request_id: int, outcome: Dictionary) -> void:
	if request_id != _request_id or not in_flight:
		return
	in_flight = false
	_request_id = 0
	var level: int = _level
	if not outcome.get("ok", false):
		_finish(level, String(outcome.get("status", "unknown")))
		return
	var director: Director = GameState.director
	if director.run_id != _run_id:
		_finish(level, STATUS_STALE)  # a new game or a loaded save happened meanwhile
		return
	var data: Variant = outcome.get("data")
	if not data is Dictionary:
		_finish(level, STATUS_REJECTED)
		return
	var cfg: TelemetryConfig = director.get_config()
	var verdict: Dictionary = DirectorPlanValidator.validate(data, cfg.default_theme, cfg, _known_ids)
	if not verdict["ok"]:
		_finish(level, STATUS_REJECTED)
		return
	# Only a plan the model made is a remote plan: a service in mock or fallback mode just echoes the local baseline.
	if String((data as Dictionary).get("source", "")) != "openai":
		_finish(level, STATUS_SERVICE_LOCAL)
		return
	var line: String = ""
	if level != Director.ENDING_LEVEL:
		var checked: Dictionary = GrandfatherLineValidator.validate((data as Dictionary).get("grandfather_line"), director.get_lines())
		if checked["ok"]:
			line = checked["line"]
	if director.set_remote_plan(level, verdict["plan"], line):
		_finish(level, STATUS_APPLIED)
	else:
		_finish(level, STATUS_LATE)


func _finish(level: int, status: String) -> void:
	last_status = status
	request_finished.emit(level, status)


func _skip(status: String) -> bool:
	last_status = status
	return false

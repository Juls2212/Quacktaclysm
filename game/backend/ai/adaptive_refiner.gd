class_name AdaptiveRefiner
extends Node
## Orchestrator: asks the AI service to refine the profile AFTER the local result is already
## applied. Never blocks, never shows errors to the player; any failure keeps the local state.
## Placed in scenes (like DecisionFlow); not an autoload.

signal refinement_started
signal refinement_applied(result: AdaptiveResult)
signal refinement_skipped(reason: String)

const DEFAULT_CONFIG_PATH: String = "res://backend/ai/default_ai_service_config.tres"
## Limits of the service request schema (ai-service/app/schemas.py).
const MAX_PAYLOAD_DECISIONS: int = 10
const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 3
const _ID_PATTERN: String = "^[a-z0-9_]{1,64}$"

@export var config: AiServiceConfig
@export var client: AiClient

var in_flight: bool = false
## Status of the last attempt: AiClient.STATUS_*, or "applied", "rejected", "stale", "skipped".
var last_status: String = "idle"
var last_message: String = ""

var _sequence: int = 0
var _current_sequence: int = 0
var _current_request_id: int = 0
var _snapshot_decision_count: int = 0
var _id_regex: RegEx = null


func _ready() -> void:
	if config == null:
		config = load(DEFAULT_CONFIG_PATH) as AiServiceConfig
		if config == null:
			config = AiServiceConfig.new()
	if client == null:
		client = AiClient.new()
		add_child(client)
	if client.config == null:
		client.config = config
	client.completed.connect(_on_client_completed)


func _exit_tree() -> void:
	_current_sequence = 0
	_current_request_id = 0
	in_flight = false
	if client != null and is_instance_valid(client) and client.completed.is_connected(_on_client_completed):
		client.completed.disconnect(_on_client_completed)


## Sends the current run summary to the service. Returns false if no request was started.
func request_refinement(point: String = AdaptiveInput.POINT_AFTER_DECISION) -> bool:
	if client == null or config == null:
		_skip("not_ready", "refiner is not in the scene tree yet")
		return false
	if not config.enabled:
		_skip(AiClient.STATUS_DISABLED, "AI service disabled in config")
		return false
	_sequence += 1
	_current_sequence = _sequence
	_current_request_id = 0  # the cancelled request's completion must be seen as stale
	_snapshot_decision_count = GameState.decisions.size()
	in_flight = true
	last_status = "in_flight"
	last_message = ""
	refinement_started.emit()
	var request_id: int = client.request_profile(build_payload(point))
	# A synchronous callback cannot have happened (client defers every completion).
	_current_request_id = request_id
	return true


## Exactly the fields of the service request schema, nothing else.
func build_payload(point: String) -> Dictionary:
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(_ID_PATTERN)
	var input: AdaptiveInput = AdaptiveInput.from_state_dict(GameState.to_dict(), point)
	var decisions: Array = []
	var released: int = 0
	var kept: int = 0
	for entry: Dictionary in input.decisions:
		if decisions.size() >= MAX_PAYLOAD_DECISIONS:
			break
		if _id_regex.search(entry["fragment_id"]) == null or _id_regex.search(entry["boss_id"]) == null:
			continue
		decisions.append({
			"fragment_id": entry["fragment_id"],
			"boss_id": entry["boss_id"],
			"level": clampi(entry["level"], MIN_LEVEL, MAX_LEVEL),
			"choice": entry["choice"],
		})
		if entry["choice"] == AdaptiveIds.CHOICE_RELEASED:
			released += 1
		else:
			kept += 1
	return {
		"released": released,
		"kept": kept,
		"current_level": clampi(input.current_level, MIN_LEVEL, MAX_LEVEL),
		"evaluation_point": point,
		"local_profile": GameState.adaptive_profile,
		"decisions": decisions,
	}


func _on_client_completed(request_id: int, outcome: Dictionary) -> void:
	if _current_sequence == 0 or request_id != _current_request_id:
		return  # stale: belongs to a cancelled or replaced request
	in_flight = false
	_current_sequence = 0
	_current_request_id = 0
	last_status = outcome.get("status", "unknown")
	last_message = outcome.get("message", "")
	if not outcome.get("ok", false):
		refinement_skipped.emit(last_status)
		return
	if GameState.decisions.size() != _snapshot_decision_count:
		_skip("stale", "decisions changed while the request was in flight")
		return
	var verdict: Dictionary = AdaptiveResponseValidator.validate(
		outcome.get("data"), GameState.get_adaptive_result(), GameState.get_adaptive_config())
	if not verdict["ok"]:
		_skip("rejected", verdict["reason"])
		return
	var result: AdaptiveResult = verdict["result"]
	var changed: bool = result.profile != GameState.adaptive_profile
	if not GameState.set_adaptive_profile(result.profile):
		_skip("rejected", "profile could not be applied")
		return
	GameState.set_adaptive_narrative_variant(result.narrative_variant)
	if changed:
		GameState.autosave()
	last_status = "applied"
	last_message = "profile %s, variant %s" % [result.profile, result.narrative_variant]
	refinement_applied.emit(result)


func _skip(status: String, message: String) -> void:
	last_status = status
	last_message = message
	refinement_skipped.emit(status)

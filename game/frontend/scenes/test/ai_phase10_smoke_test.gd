extends Node
## Headless smoke test for Phase 10: AiServiceConfig, AiClient, AdaptiveRefiner, DecisionFlow integration.
## Development only. NO server and NO network: the transport is faked (except one localhost
## connection-refused check). Save work happens on a redirected user:// test path only.
## Run: <godot> --headless --path game res://frontend/scenes/test/ai_phase10_smoke_test.tscn
## Expect GameState warnings in the output: rejected decisions / profiles are exercised on purpose.

const FRAGMENT_SCENE: PackedScene = preload("res://backend/decisions/soul_fragment.tscn")
const PANEL_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const DATA_1: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_1.tres")
const DATA_2: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_2.tres")
const DEFAULT_SERVICE_CONFIG: AiServiceConfig = preload("res://backend/ai/default_ai_service_config.tres")
const TEST_PATH: String = "user://test_save_phase10.json"
const TEST_ENV_NAME: String = "QUACKTACLYSM_TEST_URL_PHASE10"
const REL: String = AdaptiveIds.CHOICE_RELEASED
const KEP: String = AdaptiveIds.CHOICE_KEPT
const COMP: String = AdaptiveIds.PROFILE_COMPASSIONATE
const NEUT: String = AdaptiveIds.PROFILE_NEUTRAL
const CORR: String = AdaptiveIds.PROFILE_CORRUPT
const PAYLOAD_KEYS: Array[String] = ["released", "kept", "current_level", "evaluation_point", "local_profile", "decisions"]
const DECISION_KEYS: Array[String] = ["fragment_id", "boss_id", "level", "choice"]
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]

var failures: int = 0
var real_file_existed: bool = false
var real_file_time: int = 0
var real_file_size: int = 0
## Requests captured by the fake transport: {id, url, headers, body (String), on_done}
var sent: Array[Dictionary] = []
var applied_count: int = 0
var skipped: Array[String] = []


func _ready() -> void:
	SaveSystem.set_save_path(TEST_PATH)
	real_file_existed = FileAccess.file_exists(SaveSystem.DEFAULT_PATH)
	if real_file_existed:
		real_file_time = FileAccess.get_modified_time(SaveSystem.DEFAULT_PATH)
		real_file_size = _file_size(SaveSystem.DEFAULT_PATH)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


func _saved() -> Dictionary:
	if not FileAccess.file_exists(TEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	return parsed if parsed is Dictionary else {}


func _fake_transport(request_id: int, url: String, headers: PackedStringArray, body: String, on_done: Callable) -> void:
	sent.append({"id": request_id, "url": url, "headers": headers, "body": body, "on_done": on_done})


## Answers a captured request. Skips the callback if its client is gone (a real HTTPRequest would be gone too).
func _respond(index: int, result: int, code: int, body: PackedByteArray) -> void:
	var on_done: Callable = sent[index]["on_done"]
	if on_done.is_valid():
		on_done.call({"result": result, "code": code, "body": body})
	await _frames(2)


func _ok_response(index: int, data: Variant) -> void:
	await _respond(index, HTTPRequest.RESULT_SUCCESS, 200, JSON.stringify(data).to_utf8_buffer())


func _fresh_state(pairs: Array = []) -> void:
	SaveSystem.purge()
	GameState.autosave_enabled = true
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	for i in pairs.size():
		GameState.record_decision("p10_f%d" % i, "boss_a", pairs[i][0], pairs[i][1])
	GameState.refresh_adaptive_profile()
	SaveSystem.purge()
	sent.clear()
	skipped.clear()
	applied_count = 0


func _make_refiner(config: AiServiceConfig = null) -> AdaptiveRefiner:
	var refiner := AdaptiveRefiner.new()
	if config != null:
		refiner.config = config
	add_child(refiner)
	refiner.client.transport = _fake_transport
	refiner.refinement_applied.connect(func(_r: AdaptiveResult) -> void: applied_count += 1)
	refiner.refinement_skipped.connect(func(reason: String) -> void: skipped.append(reason))
	return refiner


func _run() -> void:
	_test_config()
	await _test_client()
	await _test_payload()
	await _test_success()
	await _test_failures()
	await _test_staleness()
	await _test_variant()
	await _test_flow()
	_test_isolation()
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- Config ---

func _test_config() -> void:
	var config := AiServiceConfig.new()
	_check("config: defaults", config.enabled and config.max_response_bytes == 4096 and is_equal_approx(config.request_timeout_seconds, 10.0)
		and config.env_url_override_name == "QUACKTACLYSM_AI_URL")
	config.env_url_override_name = TEST_ENV_NAME
	OS.unset_environment(TEST_ENV_NAME)
	_check("config: default resource values", DEFAULT_SERVICE_CONFIG.base_url == "http://127.0.0.1:8000"
		and DEFAULT_SERVICE_CONFIG.profile_path == "/v1/adaptive/profile" and DEFAULT_SERVICE_CONFIG.enabled)
	_check("config: default base url", config.resolve_base_url() == "http://127.0.0.1:8000")
	config.base_url = "http://example.test:9000///"
	_check("config: trailing slashes stripped", config.resolve_base_url() == "http://example.test:9000")
	_check("config: profile url", config.resolve_profile_url() == "http://example.test:9000/v1/adaptive/profile")
	config.base_url = "HTTPS://example.test/"
	_check("config: https and scheme case", config.resolve_base_url() == "HTTPS://example.test")
	OS.set_environment(TEST_ENV_NAME, "http://127.0.0.1:8765/")
	_check("config: env override wins and is trimmed", config.resolve_base_url() == "http://127.0.0.1:8765")
	OS.set_environment(TEST_ENV_NAME, "file:///etc/passwd")
	_check("config: env override with bad scheme -> empty", config.resolve_base_url().is_empty())
	OS.unset_environment(TEST_ENV_NAME)
	for bad: String in ["file:///tmp/x", "ftp://host", "", "   ", "http://", "https://", "localhost:8000", "javascript:alert(1)"]:
		config.base_url = bad
		_check("config: rejects '%s'" % bad, config.resolve_base_url().is_empty() and config.resolve_profile_url().is_empty())
	config.base_url = "http://h"
	config.profile_path = "v1/x"
	_check("config: profile path gets a leading slash", config.resolve_profile_url() == "http://h/v1/x")


# --- AiClient ---

func _test_client() -> void:
	var results: Array = []
	var client := AiClient.new()
	var config := AiServiceConfig.new()
	config.env_url_override_name = TEST_ENV_NAME
	client.config = config
	client.transport = _fake_transport
	add_child(client)
	client.completed.connect(func(id: int, outcome: Dictionary) -> void: results.append([id, outcome]))
	sent.clear()

	config.enabled = false
	var id_disabled: int = client.request_profile({})
	_check("client: disabled returns an id and is not sent", id_disabled > 0 and sent.is_empty() and results.is_empty())
	await _frames(2)
	_check("client: disabled reports 'disabled' once", results.size() == 1 and results[0][1]["status"] == "disabled" and not results[0][1]["ok"])
	results.clear()
	config.enabled = true
	config.base_url = "file:///x"
	client.request_profile({})
	await _frames(2)
	_check("client: invalid url status", results.size() == 1 and results[0][1]["status"] == "invalid_url" and sent.is_empty())
	results.clear()
	config.base_url = "http://127.0.0.1:8765"

	var id_a: int = client.request_profile({"a": 1})
	_check("client: request is in flight right after the call", client.in_flight and sent.size() == 1 and results.is_empty())
	_check("client: JSON body and headers", int(JSON.parse_string(sent[0]["body"])["a"]) == 1
		and (sent[0]["headers"] as PackedStringArray).has("Content-Type: application/json")
		and sent[0]["url"] == "http://127.0.0.1:8765/v1/adaptive/profile")
	var id_b: int = client.request_profile({"b": 1})
	_check("client: new request cancels the previous (old id reported 'cancelled' once)", id_b != id_a and results.size() == 1
		and results[0][0] == id_a and results[0][1]["status"] == "cancelled")
	await _ok_response(0, {"late": true})
	_check("client: response of the cancelled request is dropped", results.size() == 1 and client.in_flight)
	await _ok_response(1, {"profile": "neutral"})
	_check("client: response of the active request delivered", results.size() == 2 and results[1][0] == id_b
		and results[1][1]["ok"] and results[1][1]["status"] == "ok" and results[1][1]["data"] == {"profile": "neutral"} and not client.in_flight)
	results.clear()
	sent.clear()
	var id_c: int = client.request_profile({})
	client.cancel()
	_check("client: cancel() reports cancelled", results.size() == 1 and results[0][0] == id_c and results[0][1]["status"] == "cancelled" and not client.in_flight)
	client.cancel()
	_check("client: cancel when idle is a no-op", results.size() == 1)
	results.clear()
	sent.clear()

	var cases: Array = [
		["connection failed", HTTPRequest.RESULT_CANT_CONNECT, 0, "", "connection_failed"],
		["timeout", HTTPRequest.RESULT_TIMEOUT, 0, "", "timeout"],
		["body too large (http limit)", HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, 200, "", "http_error"],
		["http 500", HTTPRequest.RESULT_SUCCESS, 500, "{}", "http_error"],
		["http 422", HTTPRequest.RESULT_SUCCESS, 422, "{}", "http_error"],
		["http 301", HTTPRequest.RESULT_SUCCESS, 301, "{}", "http_error"],
		["empty body", HTTPRequest.RESULT_SUCCESS, 200, "", "invalid_json"],
		["not json", HTTPRequest.RESULT_SUCCESS, 200, "<html>nope", "invalid_json"],
		["oversized body", HTTPRequest.RESULT_SUCCESS, 200, "x".repeat(5000), "http_error"],
	]
	for row: Array in cases:
		results.clear()
		sent.clear()
		client.request_profile({})
		await _respond(0, row[1], row[2], (row[3] as String).to_utf8_buffer())
		_check("client: " + row[0], results.size() == 1 and results[0][1]["status"] == row[4] and not results[0][1]["ok"],
			str(results[0][1]["status"] if results.size() > 0 else "none"))
	results.clear()
	sent.clear()
	client.request_profile({})
	# Godot prints an 'Unicode parsing error' warning for these bytes; that is expected.
	await _respond(0, HTTPRequest.RESULT_SUCCESS, 200, PackedByteArray([255, 254, 0, 1]))
	_check("client: binary garbage handled", results.size() == 1 and not results[0][1]["ok"])
	results.clear()
	sent.clear()
	client.request_profile({})
	await _ok_response(0, [1, 2])
	_check("client: non-dictionary root is delivered as data", results.size() == 1 and results[0][1]["ok"] and results[0][1]["data"] is Array)

	client.free()
	# Real HTTPRequest against a closed localhost port: graceful failure, then free while in flight.
	var real := AiClient.new()
	var real_config := AiServiceConfig.new()
	real_config.env_url_override_name = TEST_ENV_NAME
	real_config.base_url = "http://127.0.0.1:1"
	real_config.request_timeout_seconds = 3.0
	real.config = real_config
	add_child(real)
	var real_results: Array = []
	real.completed.connect(func(_id: int, outcome: Dictionary) -> void: real_results.append(outcome))
	real.request_profile({"x": 1})
	_check("client(real): returns immediately in flight", real.in_flight and real_results.is_empty())
	await _wait_until(func() -> bool: return not real_results.is_empty(), 600)
	_check("client(real): closed port -> connection_failed or timeout", real_results.size() == 1
		and real_results[0]["status"] in ["connection_failed", "timeout"] and not real_results[0]["ok"], str(real_results))
	real.request_profile({"x": 2})
	real.free()
	await _frames(3)
	_check("client(real): freeing while in flight is safe", true)


# --- Payload ---

func _test_payload() -> void:
	_fresh_state([[1, REL], [2, KEP]])
	var refiner := _make_refiner()
	var payload: Dictionary = refiner.build_payload(AdaptiveInput.POINT_LEVEL_START)
	_check("payload: exactly the schema keys", _same_keys(payload.keys(), PAYLOAD_KEYS), str(payload.keys()))
	_check("payload: scalar values", payload["released"] == 1 and payload["kept"] == 1 and payload["current_level"] == 1
		and payload["evaluation_point"] == "level_start" and payload["local_profile"] == NEUT)
	var decisions: Array = payload["decisions"]
	_check("payload: decisions keys and values", decisions.size() == 2 and _same_keys(decisions[0].keys(), DECISION_KEYS)
		and decisions[0] == {"fragment_id": "p10_f0", "boss_id": "boss_a", "level": 1, "choice": REL}
		and decisions[1]["level"] == 2 and decisions[1]["choice"] == KEP)
	GameState.checkpoint = "secret_checkpoint"
	_check("payload: no extra GameState data", not JSON.stringify(refiner.build_payload(AdaptiveInput.POINT_ENDING)).contains("secret_checkpoint"))
	GameState.checkpoint = GameState.DEFAULT_CHECKPOINT
	_check("payload: evaluation point ids match AdaptiveInput", refiner.build_payload(AdaptiveInput.POINT_AFTER_DECISION)["evaluation_point"] == "after_decision"
		and refiner.build_payload(AdaptiveInput.POINT_ENDING)["evaluation_point"] == "ending")
	GameState.record_decision("Bad Id!", "boss_a", 1, REL)
	GameState.record_decision("ok_but_level_9", "boss_a", 9, REL)
	var cleaned: Dictionary = refiner.build_payload(AdaptiveInput.POINT_AFTER_DECISION)
	_check("payload: ids outside the pattern are dropped, levels clamped, counters consistent",
		(cleaned["decisions"] as Array).size() == 3 and cleaned["released"] == 2 and cleaned["kept"] == 1
		and cleaned["decisions"][2]["level"] == 3)
	_fresh_state()
	for i in 14:
		GameState.record_decision("many_%d" % i, "boss_a", 1, REL)
	var many: Dictionary = refiner.build_payload(AdaptiveInput.POINT_AFTER_DECISION)
	_check("payload: capped at the schema limit", (many["decisions"] as Array).size() == 10 and many["released"] == 10 and many["kept"] == 0)
	var parsed: Variant = JSON.parse_string(JSON.stringify(many))
	_check("payload: JSON round trip", parsed is Dictionary)
	var disabled := AiServiceConfig.new()
	disabled.enabled = false
	var off := _make_refiner(disabled)
	var started: bool = off.request_refinement()
	_check("refiner: disabled -> no request, status disabled", not started and off.last_status == "disabled" and sent.is_empty()
		and not off.in_flight and skipped == ["disabled"])
	off.free()
	refiner.free()


func _same_keys(keys: Array, expected: Array[String]) -> bool:
	var a: Array = keys.duplicate()
	var b: Array = expected.duplicate()
	a.sort()
	b.sort()
	return a == b


# --- Success path ---

func _test_success() -> void:
	_fresh_state([[1, REL]])
	var refiner := _make_refiner()
	var started: bool = refiner.request_refinement()
	_check("non-blocking: returns at once with the request in flight", started and refiner.in_flight and sent.size() == 1
		and applied_count == 0 and GameState.adaptive_profile == NEUT)
	_check("refiner: request sent to the default endpoint", (sent[0]["url"] as String).ends_with("/v1/adaptive/profile"))
	var applied: Array[AdaptiveResult] = []
	refiner.refinement_applied.connect(func(r: AdaptiveResult) -> void: applied.append(r))
	await _ok_response(0, {"profile": COMP, "narrative_variant": "mercy_hopeful", "source": "openai"})
	_check("success: profile applied", GameState.adaptive_profile == COMP)
	_check("success: variant stored in memory", GameState.adaptive_narrative_variant == "mercy_hopeful"
		and GameState.get_adaptive_result().narrative_variant == "mercy_hopeful"
		and GameState.get_adaptive_result().source == AdaptiveIds.SOURCE_REMOTE)
	_check("success: encounter/ending/aggression still come from the table", GameState.get_adaptive_result().encounter_variant == "calm"
		and is_equal_approx(GameState.get_adaptive_result().boss_aggression, 0.9))
	_check("success: refinement_applied emitted once", applied_count == 1 and applied.size() == 1 and skipped.is_empty() and applied[0].source == AdaptiveIds.SOURCE_REMOTE)
	_check("success: autosave happened because the profile changed", _saved().get("adaptive_profile") == COMP, str(_saved()))
	_check("success: status and flags", refiner.last_status == "applied" and not refiner.in_flight)
	_check("success: saved file has only the seven keys", _same_keys(_saved().keys(), SAVE_KEYS), str(_saved().keys()))
	# Same profile again: variant updates, but no autosave.
	SaveSystem.purge()
	refiner.request_refinement()
	await _ok_response(1, {"profile": COMP, "narrative_variant": "mercy"})
	_check("success: unchanged profile does not autosave", not FileAccess.file_exists(TEST_PATH) and applied_count == 2)
	_check("success: variant replaced", GameState.adaptive_narrative_variant == "mercy")
	refiner.free()


# --- Failures ---

func _test_failures() -> void:
	var cases: Array = [
		["connection failed", HTTPRequest.RESULT_CANT_CONNECT, 0, "", "connection_failed"],
		["timeout", HTTPRequest.RESULT_TIMEOUT, 0, "", "timeout"],
		["http 500", HTTPRequest.RESULT_SUCCESS, 500, "{}", "http_error"],
		["http 503", HTTPRequest.RESULT_SUCCESS, 503, "{}", "http_error"],
		["http 422", HTTPRequest.RESULT_SUCCESS, 422, "{}", "http_error"],
		["invalid json", HTTPRequest.RESULT_SUCCESS, 200, "not json {", "invalid_json"],
		["empty body", HTTPRequest.RESULT_SUCCESS, 200, "", "invalid_json"],
		["oversized body", HTTPRequest.RESULT_SUCCESS, 200, "x".repeat(6000), "http_error"],
		["profile out of the list", HTTPRequest.RESULT_SUCCESS, 200, '{"profile":"evil"}', "rejected"],
		["profile with text", HTTPRequest.RESULT_SUCCESS, 200, '{"profile":"I think corrupt"}', "rejected"],
		["non-dictionary root", HTTPRequest.RESULT_SUCCESS, 200, '["corrupt"]', "rejected"],
		["json null", HTTPRequest.RESULT_SUCCESS, 200, "null", "rejected"],
		["profile at distance 2", HTTPRequest.RESULT_SUCCESS, 200, '{"profile":"corrupt","narrative_variant":"burden"}', "rejected"],
	]
	for row: Array in cases:
		# Local profile compassionate so that "corrupt" is at distance 2 for the last case.
		_fresh_state([[1, REL], [2, REL]])
		var refiner := _make_refiner()
		refiner.request_refinement()
		await _respond(0, row[1], row[2], (row[3] as String).to_utf8_buffer())
		_check("failure [%s]: local state untouched" % row[0], GameState.adaptive_profile == COMP
			and GameState.adaptive_narrative_variant.is_empty() and GameState.decisions.size() == 2)
		_check("failure [%s]: status '%s', not in flight, skipped once, nothing applied or saved" % [row[0], row[4]],
			refiner.last_status == row[4] and not refiner.in_flight and skipped.size() == 1 and applied_count == 0
			and not FileAccess.file_exists(TEST_PATH), "%s %s" % [refiner.last_status, refiner.last_message])
		_check("failure [%s]: game still responsive (a new request can start)" % row[0], refiner.request_refinement() and refiner.in_flight)
		refiner.free()
		await _frames(1)


# --- Staleness ---

func _test_staleness() -> void:
	_fresh_state()
	var refiner := _make_refiner()
	refiner.request_refinement()
	refiner.request_refinement()
	_check("stale: second request replaces the first", sent.size() == 2 and refiner.in_flight and skipped.is_empty())
	await _ok_response(0, {"profile": CORR})
	_check("stale: first response is discarded", GameState.adaptive_profile == NEUT and applied_count == 0 and refiner.in_flight)
	await _ok_response(1, {"profile": COMP, "narrative_variant": "mercy"})
	_check("stale: second response applied", GameState.adaptive_profile == COMP and applied_count == 1)
	refiner.free()

	# Decision count changed while in flight.
	_fresh_state([[1, REL]])
	refiner = _make_refiner()
	refiner.request_refinement()
	GameState.record_decision("p10_late", "boss_a", 2, REL)
	await _ok_response(0, {"profile": COMP})
	_check("stale: response discarded when decisions changed", GameState.adaptive_profile == NEUT and applied_count == 0
		and refiner.last_status == "stale" and not refiner.in_flight and skipped == ["stale"])
	refiner.free()

	# Freed while in flight, then the response arrives.
	_fresh_state()
	refiner = _make_refiner()
	refiner.request_refinement()
	var late: Callable = sent[0]["on_done"]
	refiner.free()
	await _frames(2)
	_check("stale: freeing the refiner in flight is safe and nothing is applied", applied_count == 0 and GameState.adaptive_profile == NEUT)
	_check("stale: callback of a freed client is no longer valid (nothing to call)", not late.is_valid())

	# Client replaced/freed alone, refiner kept: late response ignored, refiner stays usable.
	_fresh_state()
	refiner = _make_refiner()
	refiner.request_refinement()
	refiner.client.cancel()
	await _ok_response(0, {"profile": COMP})
	_check("stale: cancelled request response ignored", GameState.adaptive_profile == NEUT and applied_count == 0 and not refiner.in_flight)
	refiner.free()
	await _frames(1)


# --- Variant handling ---

func _test_variant() -> void:
	_fresh_state([[1, REL]])
	var refiner := _make_refiner()
	refiner.request_refinement()
	await _ok_response(0, {"profile": COMP, "narrative_variant": "burden"})
	_check("variant: out-of-list variant replaced by the profile default", GameState.adaptive_profile == COMP
		and GameState.adaptive_narrative_variant == "mercy" and GameState.get_adaptive_result().narrative_variant == "mercy")
	refiner.free()
	_fresh_state()
	GameState.set_adaptive_narrative_variant("burden")
	_check("variant: not allowed for the current profile -> default", GameState.get_adaptive_result().narrative_variant == "balanced"
		and GameState.get_adaptive_result().source == AdaptiveIds.SOURCE_DEFAULT)
	GameState.set_adaptive_profile(CORR)
	_check("variant: cleared when the profile changes (set_adaptive_profile)", GameState.adaptive_narrative_variant.is_empty())
	GameState.set_adaptive_narrative_variant("burden_bitter")
	GameState.set_adaptive_profile(CORR)
	_check("variant: kept when the profile does not change", GameState.adaptive_narrative_variant == "burden_bitter"
		and GameState.get_adaptive_result().narrative_variant == "burden_bitter")
	GameState.record_decision("v1", "b", 1, REL)
	GameState.record_decision("v2", "b", 1, REL)
	GameState.refresh_adaptive_profile()
	_check("variant: cleared when refresh changes the profile", GameState.adaptive_profile == COMP and GameState.adaptive_narrative_variant.is_empty())
	GameState.set_adaptive_narrative_variant("mercy_hopeful")
	GameState.reset_run()
	_check("variant: cleared by reset_run", GameState.adaptive_narrative_variant.is_empty())
	GameState.set_adaptive_narrative_variant("mercy")
	GameState.start_new_game()
	_check("variant: cleared by start_new_game", GameState.adaptive_narrative_variant.is_empty())
	GameState.set_adaptive_profile(COMP)
	GameState.set_adaptive_narrative_variant("mercy_hopeful")
	GameState.save_to_disk()
	GameState.load_from_disk()
	_check("variant: cleared by load; profile kept", GameState.adaptive_narrative_variant.is_empty() and GameState.adaptive_profile == COMP)
	GameState.set_adaptive_narrative_variant("mercy_hopeful")
	GameState.load_from_dict(GameState.to_dict())
	_check("variant: cleared by load_from_dict", GameState.adaptive_narrative_variant.is_empty())
	GameState.set_adaptive_narrative_variant("mercy_hopeful")
	_check("variant: not part of to_dict (seven keys)", _same_keys(GameState.to_dict().keys(), SAVE_KEYS)
		and not JSON.stringify(GameState.to_dict()).contains("mercy_hopeful"))
	GameState.save_to_disk()
	_check("variant: not written to disk", _same_keys(_saved().keys(), SAVE_KEYS) and not FileAccess.get_file_as_string(TEST_PATH).contains("mercy_hopeful"))
	SaveSystem.purge()


# --- DecisionFlow ---

func _test_flow() -> void:
	_fresh_state()
	var refiner := _make_refiner()
	var panel := PANEL_SCENE.instantiate() as DecisionPanel
	add_child(panel)
	var flow := DecisionFlow.new()
	flow.panel = panel
	flow.refiner = refiner
	add_child(flow)
	var fragments: Array[SoulFragment] = []
	var step: Callable = func(target: DecisionFlow, data: SoulFragmentData, release: bool) -> void:
		var fragment := FRAGMENT_SCENE.instantiate() as SoulFragment
		fragment.data = data
		add_child(fragment)
		fragments.append(fragment)
		target._on_fragment_collected(fragment)
		(panel.release_button if release else panel.keep_button).pressed.emit()

	step.call(flow, DATA_1, true)
	_check("flow: accepted decision triggers exactly one request", sent.size() == 1 and refiner.in_flight)
	_check("flow: request carries the decision and local profile", JSON.parse_string(sent[0]["body"])["decisions"].size() == 1
		and JSON.parse_string(sent[0]["body"])["local_profile"] == NEUT)
	step.call(flow, DATA_1, false)
	_check("flow: rejected decision triggers no request", sent.size() == 1 and GameState.decisions.size() == 1)
	_check("flow: panel closed and unpaused", not panel.is_open() and not get_tree().paused)
	step.call(flow, DATA_2, true)
	_check("flow: next accepted decision triggers a new request (previous is replaced)", sent.size() == 2)
	_check("flow: local result already applied before any response", GameState.adaptive_profile == COMP)
	await _ok_response(0, {"profile": NEUT})
	_check("flow: first response is stale", GameState.adaptive_profile == COMP and applied_count == 0)
	await _ok_response(1, {"profile": COMP, "narrative_variant": "mercy_hopeful"})
	_check("flow: latest response applied after the local result and autosave", GameState.adaptive_profile == COMP and applied_count == 1
		and GameState.adaptive_narrative_variant == "mercy_hopeful" and _saved().get("adaptive_profile") == COMP)

	var plain := DecisionFlow.new()
	plain.panel = panel
	add_child(plain)
	GameState.reset_run()
	sent.clear()
	step.call(plain, DATA_1, true)
	_check("flow: without a refiner nothing is requested and local behavior is intact", sent.is_empty() and GameState.has_decision(DATA_1.fragment_id)
		and GameState.adaptive_profile == NEUT and _saved().get("adaptive_profile") == NEUT)

	await _frames(2)
	for fragment in fragments:
		if is_instance_valid(fragment):
			fragment.free()
	plain.free()
	flow.free()
	panel.free()
	refiner.free()
	get_tree().paused = false
	await _frames(2)


func _test_isolation() -> void:
	_check("isolation: save path is the redirected test path", SaveSystem.get_save_path() == TEST_PATH)
	var untouched: bool
	if real_file_existed:
		untouched = FileAccess.file_exists(SaveSystem.DEFAULT_PATH) \
			and FileAccess.get_modified_time(SaveSystem.DEFAULT_PATH) == real_file_time \
			and _file_size(SaveSystem.DEFAULT_PATH) == real_file_size
	else:
		untouched = not FileAccess.file_exists(SaveSystem.DEFAULT_PATH)
	_check("isolation: real save file not created or modified", untouched)

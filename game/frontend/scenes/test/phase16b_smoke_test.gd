extends Node
## Smoke test for Phase 16b: the remote AI Director plan. NO server and NO network: the transport of the DirectorClient is faked.
## A valid remote plan is applied through the validator; a forbidden key is rejected; offline, timeout and bad answers fall back
## with no error and no waiting at level load; a late answer is discarded; the option OFF sends nothing; the request survives the
## scene change; the forced debug plan wins; the guards (seven save keys, three autoloads, real save and settings untouched).
## Development only. Run (alone, a minute or two): <godot> --headless --path game res://frontend/scenes/test/phase16b_smoke_test.tscn
## Uses a redirected save path and a throwaway settings file. Times are real game time.

const TEST_SAVE: String = "user://test_save_phase16b.json"
const TEST_SETTINGS: String = "user://test_settings_phase16b.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const LEVEL_TWO: String = "res://frontend/levels/level_2.tscn"
const LEVEL_ONE: String = "res://frontend/levels/level_1.tscn"
const PANEL_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const FRAGMENT_SCENE: PackedScene = preload("res://backend/decisions/soul_fragment.tscn")
const DATA_1: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_1.tres")
const DATA_3: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_3.tres")
const REQUEST_KEYS: Array[String] = ["allowed_pattern_ids", "baseline", "local_profile", "local_theme", "next_level", "summary"]

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var config: TelemetryConfig = TelemetryConfig.get_default()

## The fake network: what the transport saw and what it answers.
var sent: Array[Dictionary] = []
var mode: String = "ok"
var reply: Variant = {}
var delay: float = 0.3


func _ready() -> void:
	ai_config.enabled = true
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
	real_controls_before = _read_file(ControlsConfig.DEFAULT_PATH)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _transport(_request_id: int, url: String, _headers: PackedStringArray, body: String, on_done: Callable) -> void:
	sent.append({"url": url, "body": body})
	match mode:
		"ok":
			on_done.call({"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify(reply).to_utf8_buffer()})
		"delayed":
			get_tree().create_timer(delay).timeout.connect(func() -> void:
				if on_done.is_valid():
					on_done.call({"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify(reply).to_utf8_buffer()}))
		"timeout":
			on_done.call({"result": HTTPRequest.RESULT_TIMEOUT, "code": 0, "body": PackedByteArray()})
		"offline":
			on_done.call({"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": PackedByteArray()})
		"http500":
			on_done.call({"result": HTTPRequest.RESULT_SUCCESS, "code": 500, "body": PackedByteArray()})
		"bad_json":
			on_done.call({"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": "not json at all".to_utf8_buffer()})


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.director.clear_overrides()
	GameState.director.simulate_release = false
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	sent.clear()
	mode = "ok"
	delay = 0.3
	var client: DirectorClient = GameState.get_director_client()
	client.ai.cancel()
	client.ai.transport = _transport
	client.in_flight = false
	client.last_status = "idle"
	client.requests_sent = 0


func _run() -> void:
	_clean_state()
	_test_guards()
	_test_payload()
	await _test_valid_plan_applied()
	await _test_forbidden_keys_rejected()
	await _test_failures_fall_back()
	await _test_no_waiting_and_late_answer()
	await _test_option_off()
	await _test_survives_scene_change()
	await _test_forced_plan_wins()
	await _test_service_mock_and_stale()
	await _test_decision_flow_hook()
	await _test_no_leaks()
	_clean_state()
	SaveSystem.purge()
	ai_config.enabled = false
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path_override = ""
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	_check("the real controls file was not touched", _read_file(ControlsConfig.DEFAULT_PATH) == real_controls_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

func _rotation_ids(boss_scene: String) -> PackedStringArray:
	return GameState.get_director_client().rotation_ids_for(2 if boss_scene.contains("two") else 3, config)


func _seed_level_one(metrics: Dictionary = {"time_in_level": 150, "kills": 6}) -> void:
	for metric: Variant in metrics.keys():
		GameState.director.telemetry.add(1, String(metric), float(metrics[metric]))


func _remote_reply(extras: int, weights: Dictionary, theme: String = "ritmo", source: String = "openai", extra: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = {"theme": theme, "extras_delta": extras, "boss_pattern_weights": weights, "epilogue_variant": 1, "source": source}
	plan.merge(extra, true)
	return plan


func _load_level(path: String, profile: String = "neutral") -> LevelBase:
	GameState.set_adaptive_profile(profile)
	var level := (load(path) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await _frames(3)
	return level


func _free_level(level: LevelBase) -> void:
	level.free()
	await _frames(2)


func _boss_weights(boss: BossBase) -> Dictionary:
	var weights: Dictionary = {}
	for pattern in boss.patterns:
		weights[String(pattern.pattern_id)] = pattern.weight
	return weights


func _scene_weights() -> Dictionary:
	var boss := (load("res://backend/bosses/boss_two.tscn") as PackedScene).instantiate() as BossBase
	var weights: Dictionary = {}
	for child in boss.get_node("Patterns").get_children():
		if child is BossPattern:
			weights[String((child as BossPattern).pattern_id)] = (child as BossPattern).weight
	boss.free()
	return weights


## Asks for the plan of level 2 and waits until the client finished (or a short real time).
func _request_and_wait() -> String:
	var client: DirectorClient = GameState.get_director_client()
	var started: bool = client.request_plan(1)
	var waited: float = 0.0
	while started and client.in_flight and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return client.last_status


# ---------------------------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------------------------

func _test_guards() -> void:
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: still exactly the seven keys", keys == expected, str(keys))
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: exactly GameState, SceneManager and AudioDirector", autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	var client: DirectorClient = GameState.get_director_client()
	_check("client: the DirectorClient is a child of GameState (not an autoload) and is created once", client.get_parent() == GameState and client == GameState.get_director_client())
	_check("config: the Director endpoint and a 3 s budget are in the AI service config", ai_config.resolve_director_url().ends_with("/v1/director/plan") and is_equal_approx(ai_config.director_timeout_seconds, 3.0))
	_check("settings: the option 'Adaptación con IA' exists and is ON by default, in the settings file (not in the save)", bool(GameSettings.DEFAULTS["ai_adaptation"]) and GameSettings.is_ai_adaptation_enabled()
		and not GameState.to_dict().has("ai_adaptation"))
	_check("settings: its Spanish text is «Adaptación con IA»", (load(OptionsBoard.PRESENTATION_PATH) as ProfilePresentation).ai_toggle_text == "Adaptación con IA")


func _test_payload() -> void:
	_clean_state()
	_seed_level_one({"deaths": 6, "damage_taken": 20, "time_in_level": 200})
	var client: DirectorClient = GameState.get_director_client()
	var ids: PackedStringArray = client.rotation_ids_for(2, config)
	var worst_id: String = ids[0]
	GameState.director.telemetry.add_pattern_damage(1, worst_id, 5.0)
	var payload: Dictionary = client.build_payload(1, 2, ids)
	var keys: Array = payload.keys()
	keys.sort()
	_check("payload: exactly the fields of the service schema (%s)" % str(keys), keys == REQUEST_KEYS)
	var categorical: bool = payload["summary"].size() == RunTelemetry.METRICS.size()
	for metric in RunTelemetry.METRICS:
		categorical = categorical and ["low", "mid", "high"].has(payload["summary"].get(metric, ""))
	_check("payload: the summary is only low / mid / high (never counts) and has every metric", categorical)
	_check("payload: the next level, the local profile and the local theme are enums, the baseline is the local plan inside the caps",
		payload["next_level"] == 2 and payload["local_profile"] == "neutral" and config.themes.has(payload["local_theme"]) and int(payload["baseline"]["extras_delta"]) == -2
		and is_equal_approx(float(payload["baseline"]["boss_pattern_weights"].get(worst_id, 0.0)), 0.6) and payload["baseline"].keys().size() == 3)
	_check("payload: the allowed ids are the rotation patterns of the next boss, no fallbacks", ids.size() > 0 and Array(ids) == payload["allowed_pattern_ids"] and not ids.has("stomp"))
	var text: String = JSON.stringify(payload)
	_check("payload: no free text and no key: the only strings are enums and pattern ids", not text.contains("sk-") and not text.contains("\"profile\""))


# ---------------------------------------------------------------------------------------------
# Remote plan applied / rejected
# ---------------------------------------------------------------------------------------------

func _test_valid_plan_applied() -> void:
	_clean_state()
	_seed_level_one()
	var ids: PackedStringArray = _rotation_ids("two")
	var worst: String = ids[0]
	var base: float = float(_scene_weights()[worst])
	reply = _remote_reply(-1, {worst: 0.8, "ghost": 1.2, "stomp": 1.5})
	var status: String = await _request_and_wait()
	_check("remote: a valid answer is applied (status %s) after exactly one request to the Director endpoint" % status, status == "applied" and sent.size() == 1 and String(sent[0]["url"]).ends_with("/v1/director/plan")
		and GameState.director.has_remote_plan(2))
	var level: LevelBase = await _load_level(LEVEL_TWO, "corrupt")
	var plan: DirectorPlan = level.get_applied_plan()
	_check("remote: level 2 uses it (source %s): delta %d, theme %s" % [GameState.director.get_plan_source(2), plan.extras_delta, plan.theme], GameState.director.get_plan_source(2) == "remote" and plan.extras_delta == -1 and plan.theme == "ritmo")
	_check("remote: a corrupt level 2 (2 extras) with -1 keeps 1 extra", _extras_left(level).size() == 1)
	_check("remote: the weight reached the boss (x0.8) and unknown or fallback ids were dropped by the validator", is_equal_approx(float(_boss_weights(level.boss)[worst]), base * 0.8) and not plan.boss_pattern_weights.has("ghost") and not plan.boss_pattern_weights.has("stomp"))
	var first_plan: Dictionary = plan.to_dict()
	await _free_level(level)
	var retry: LevelBase = await _load_level(LEVEL_TWO, "corrupt")
	_check("remote: a retry of the level reuses the cached plan", retry.get_applied_plan().to_dict() == first_plan and GameState.director.get_plan_source(2) == "remote")
	await _free_level(retry)
	# Out-of-range values are clamped by the same door.
	_clean_state()
	_seed_level_one()
	reply = _remote_reply(9, {worst: 9.0}, "venganza")
	await _request_and_wait()
	var clamped_level: LevelBase = await _load_level(LEVEL_TWO)
	var clamped: DirectorPlan = clamped_level.get_applied_plan()
	_check("remote: out-of-range values are clamped (delta 9 -> %d, weight 9 -> %.1f) and a bad theme becomes the local one (%s)" % [clamped.extras_delta, float(clamped.boss_pattern_weights.get(worst, 0.0)), clamped.theme],
		clamped.extras_delta == 1 and is_equal_approx(float(clamped.boss_pattern_weights.get(worst, 0.0)), 1.5) and config.themes.has(clamped.theme) and clamped.theme != "venganza")
	_check("remote: the extras stay within 0 and 3", _extras_left(clamped_level).size() <= 3)
	await _free_level(clamped_level)


func _extras_left(level: LevelBase) -> Array[NodePath]:
	var left: Array[NodePath] = []
	for group_id: Variant in level.variant_groups.keys():
		for raw_path: Variant in level.variant_groups[group_id] as Array:
			if level.get_node_or_null(NodePath(raw_path)) != null:
				left.append(NodePath(raw_path))
	return left


func _test_forbidden_keys_rejected() -> void:
	var worst: String = _rotation_ids("two")[0]
	for key in ["profile", "adaptive_profile", "hp", "max_health", "damage", "aggression", "boss_aggression", "cooldown", "telegraph_time"]:
		_clean_state()
		_seed_level_one()
		GameState.set_adaptive_profile("compassionate")
		reply = _remote_reply(1, {worst: 1.4}, "ritmo", "openai", {key: "corrupt" if key == "profile" else 5})
		var status: String = await _request_and_wait()
		var level: LevelBase = await _load_level(LEVEL_TWO, "compassionate")
		var ok: bool = status == "rejected" and not GameState.director.has_remote_plan(2) and GameState.director.get_plan_source(2) != "remote" and GameState.adaptive_profile == "compassionate"
		_check("rejected: a plan with the key '%s' is rejected, the local plan is used and the profile is untouched (%s)" % [key, status], ok)
		await _free_level(level)


func _test_failures_fall_back() -> void:
	for failure in ["offline", "timeout", "http500", "bad_json"]:
		_clean_state()
		_seed_level_one({"deaths": 6, "damage_taken": 20, "time_in_level": 200})
		mode = failure
		var status: String = await _request_and_wait()
		var level: LevelBase = await _load_level(LEVEL_TWO, "corrupt")
		_check("fallback (%s): status '%s', no remote plan, level 2 loads with the local plan (delta %d, source %s)" % [failure, status, level.get_applied_plan().extras_delta, GameState.director.get_plan_source(2)],
			status != "applied" and not GameState.director.has_remote_plan(2) and level.get_applied_plan().extras_delta == -2 and GameState.director.get_plan_source(2) == "local")
		await _free_level(level)
	# An unreachable service and a disabled config.
	_clean_state()
	_seed_level_one()
	ai_config.enabled = false
	var disabled_status: String = await _request_and_wait()
	ai_config.enabled = true
	_check("fallback: a disabled AI config sends nothing and falls back quietly (%s)" % disabled_status, disabled_status == "disabled" and sent.is_empty())


func _test_no_waiting_and_late_answer() -> void:
	_clean_state()
	_seed_level_one()
	var worst: String = _rotation_ids("two")[0]
	mode = "delayed"
	delay = 0.5
	reply = _remote_reply(1, {worst: 1.4})
	var client: DirectorClient = GameState.get_director_client()
	client.request_plan(1)
	var started_at: int = Time.get_ticks_msec()
	var level: LevelBase = await _load_level(LEVEL_TWO)
	var elapsed_ms: int = Time.get_ticks_msec() - started_at
	_check("no waiting: the level loaded with the answer still in flight (%d ms, the answer takes 500 ms)" % elapsed_ms, client.in_flight and level.get_applied_plan() != null and elapsed_ms < 450)
	var loaded_plan: Dictionary = level.get_applied_plan().to_dict()
	_check("no waiting: the level started with the local plan (source %s)" % GameState.director.get_plan_source(2), GameState.director.get_plan_source(2) != "remote")
	await _wait(0.8)
	_check("late answer: it is discarded for that level (status %s) and the plan does not change" % client.last_status, client.last_status == "late" and not GameState.director.has_remote_plan(2) and level.get_applied_plan().to_dict() == loaded_plan)
	await _free_level(level)
	var again: LevelBase = await _load_level(LEVEL_TWO)
	_check("late answer: a retry of the level still has the plan it started with", again.get_applied_plan().to_dict() == loaded_plan)
	await _free_level(again)


func _test_option_off() -> void:
	_clean_state()
	_seed_level_one()
	var values: Dictionary = GameSettings.DEFAULTS.duplicate()
	values["ai_adaptation"] = false
	GameSettings.save_settings(values)
	var client: DirectorClient = GameState.get_director_client()
	_check("option off: the setting is stored in the settings file and read back", not GameSettings.is_ai_adaptation_enabled() and not bool(GameSettings.load_settings()["ai_adaptation"]))
	var started: bool = client.request_plan(1)
	await _frames(3)
	_check("option off: no request leaves the game (status %s, %d sent)" % [client.last_status, sent.size()], not started and client.last_status == "option_off" and sent.is_empty() and client.requests_sent == 0 and not client.in_flight)
	var level: LevelBase = await _load_level(LEVEL_TWO)
	_check("option off: only the local plan is used", GameState.director.get_plan_source(2) != "remote" and not GameState.director.has_remote_plan(2))
	await _free_level(level)
	values["ai_adaptation"] = true
	GameSettings.save_settings(values)
	_check("option on again: requests flow again", GameSettings.is_ai_adaptation_enabled() and client.request_plan(1))
	await _wait(0.2)
	_check("option on again: the request was sent (%d)" % sent.size(), sent.size() == 1)
	# The tutorial-level, the last level and an unplayed level send nothing.
	_clean_state()
	_check("skips: no telemetry behind the level, or no next level, sends nothing", not client.request_plan(1) and client.last_status == "no_telemetry" and not client.request_plan(3) and client.last_status == "no_telemetry" and not client.request_plan(4) and client.last_status == "skipped" and not client.request_plan(0) and client.last_status == "skipped" and sent.is_empty())


func _test_survives_scene_change() -> void:
	_clean_state()
	var worst: String = _rotation_ids("two")[0]
	var level_one: LevelBase = await _load_level(LEVEL_ONE)
	GameState.director.telemetry.add(1, "time_in_level", 150.0)
	mode = "delayed"
	delay = 0.4
	reply = _remote_reply(1, {worst: 1.4})
	var client: DirectorClient = GameState.get_director_client()
	var started: bool = client.request_plan(1)
	await _free_level(level_one)
	_check("scene change: the request is still in flight after the level is gone (client in GameState)", started and client.in_flight and is_instance_valid(client) and client.get_parent() == GameState)
	await _wait(0.7)
	_check("scene change: the answer arrived after the level was freed and is stored for the next level (status %s)" % client.last_status, client.last_status == "applied" and GameState.director.has_remote_plan(2))
	var level_two: LevelBase = await _load_level(LEVEL_TWO)
	_check("scene change: the next level uses it (source %s, delta %d)" % [GameState.director.get_plan_source(2), level_two.get_applied_plan().extras_delta], GameState.director.get_plan_source(2) == "remote" and level_two.get_applied_plan().extras_delta == 1)
	await _free_level(level_two)


func _test_forced_plan_wins() -> void:
	_clean_state()
	_seed_level_one()
	var worst: String = _rotation_ids("two")[0]
	reply = _remote_reply(1, {worst: 1.4}, "ritmo")
	await _request_and_wait()
	_check("forced: a remote plan is waiting for level 2", GameState.director.has_remote_plan(2))
	GameState.director.set_forced_plan({"theme": "valor", "extras_delta": -2})
	var level: LevelBase = await _load_level(LEVEL_TWO)
	_check("forced: the debug plan beats the remote one (theme %s, delta %d, source %s)" % [level.get_applied_plan().theme, level.get_applied_plan().extras_delta, GameState.director.last_source],
		level.get_applied_plan().theme == "valor" and level.get_applied_plan().extras_delta == -2 and GameState.director.last_source == "forced")
	await _free_level(level)
	sent.clear()
	var started: bool = GameState.get_director_client().request_plan(1)
	_check("forced: while a plan is forced no request is sent", not started and GameState.get_director_client().last_status == "override" and sent.is_empty())
	GameState.director.clear_overrides()
	GameState.director.set_force_neutral(true)
	var neutral: LevelBase = await _load_level(LEVEL_TWO)
	_check("forced: 'always neutral' also wins over the remote plan", neutral.get_applied_plan().is_neutral() and GameState.director.last_source == "forced_neutral")
	await _free_level(neutral)


func _test_service_mock_and_stale() -> void:
	# A service in mock or fallback mode only echoes the local baseline: it is not a remote plan.
	for source in ["mock", "fallback"]:
		_clean_state()
		_seed_level_one()
		reply = _remote_reply(1, {}, "calma", source)
		var status: String = await _request_and_wait()
		var level: LevelBase = await _load_level(LEVEL_TWO)
		_check("service %s: no remote plan is stored (%s) and the local plan runs" % [source, status], status == "service_local" and not GameState.director.has_remote_plan(2) and GameState.director.get_plan_source(2) != "remote")
		await _free_level(level)
	# A new game while the request is in flight: the answer belongs to another run.
	_clean_state()
	_seed_level_one()
	mode = "delayed"
	delay = 0.3
	reply = _remote_reply(1, {})
	var client: DirectorClient = GameState.get_director_client()
	client.request_plan(1)
	GameState.start_new_game()
	await _wait(0.6)
	_check("stale: an answer that arrives after a new game is discarded (%s)" % client.last_status, client.last_status == "stale" and not GameState.director.has_remote_plan(2))


func _test_decision_flow_hook() -> void:
	_clean_state()
	_seed_level_one()
	var panel := PANEL_SCENE.instantiate() as DecisionPanel
	add_child(panel)
	var flow := DecisionFlow.new()
	flow.panel = panel
	add_child(flow)
	reply = _remote_reply(0, {}, "calma", "mock")
	var step: Callable = func(data: SoulFragmentData, release: bool) -> void:
		var fragment := FRAGMENT_SCENE.instantiate() as SoulFragment
		fragment.data = data
		add_child(fragment)
		flow._on_fragment_collected(fragment)
		(panel.release_button if release else panel.keep_button).pressed.emit()
	step.call(DATA_1, true)
	await _frames(2)
	_check("flow: the decision of a level fragment asks for the plan of the NEXT level once (%d sent)" % sent.size(), sent.size() == 1 and JSON.parse_string(sent[0]["body"])["next_level"] == 2)
	step.call(DATA_1, false)
	await _frames(2)
	_check("flow: a rejected (duplicate) decision sends nothing", sent.size() == 1)
	GameState.director.telemetry.add(3, "time_in_level", 100.0)
	step.call(DATA_3, true)
	await _frames(2)
	_check("flow: the decision of the last level asks for the epilogue of the ending (next_level 4, no pattern ids) (Phase 16c)", sent.size() == 2 and JSON.parse_string(sent[1]["body"])["next_level"] == 4
		and JSON.parse_string(sent[1]["body"])["allowed_pattern_ids"].is_empty())
	panel.free()
	flow.free()
	await _frames(2)


func _test_no_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	var worst: String = _rotation_ids("two")[0]
	for round in 5:
		_clean_state()
		_seed_level_one()
		reply = _remote_reply(1, {worst: 1.2})
		await _request_and_wait()
		var level: LevelBase = await _load_level(LEVEL_TWO)
		await _free_level(level)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated remote plan requests and level loads|%s" % str(counts))
	_check("leaks: no nodes are left behind (%s) and nothing is paused" % str(counts), counts[4] <= counts[1] + 4 and not get_tree().paused)

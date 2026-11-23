extends Node
## Phase 14g: the game does not depend on the AI service. Through the REAL level flow (boss killed,
## fragment collected, decision panel, DecisionFlow, AdaptiveRefiner, LevelBase advance) it checks that
## with the service unreachable (a closed local port with the real HTTP client), silent, answering
## garbage, answering an invalid profile or answering an HTTP error, the decision completes, the level
## advances within refine_wait_timeout, the LOCAL rule decides the profile, nothing is left paused and
## nothing hangs or crashes. No real remote service is ever called (the only real request goes to a
## closed port on this machine). Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/ai_down_phase14g_smoke_test.tscn
## Uses a redirected save path and SceneManager.dry_run; the real save is never touched.

const TEST_SAVE: String = "user://test_save_ai_down_14g.json"
const LEVEL_1_SCENE: PackedScene = preload("res://frontend/levels/level_1.tscn")
const ADVANCE_DELAY: float = 0.2
const REFINE_WAIT: float = 1.5
## How long past refine_wait_timeout the level may take to advance before the test calls it a hang.
const HANG_MARGIN: float = 1.2
const CLOSED_PORT_URL: String = "http://127.0.0.1:9"

var failures: int = 0
var real_save_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var original_url: String = ""
var started_signals: Array[String] = []
var _requests: Array[Dictionary] = []


func _ready() -> void:
	original_url = ai_config.base_url
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = FileAccess.get_file_as_string(SaveSystem.DEFAULT_PATH) if FileAccess.file_exists(SaveSystem.DEFAULT_PATH) else "<missing>"
	SceneManager.transition_started.connect(func(scene_id: String) -> void: started_signals.append(scene_id))
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


func _clean_state() -> void:
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = true
	SceneManager.last_requested_scene_id = ""
	started_signals.clear()
	_requests.clear()


func _find_fragment() -> SoulFragment:
	for child in get_children():
		if child is SoulFragment:
			return child as SoulFragment
	return null


## A transport that captures the request; the scenario decides what (if anything) comes back.
func _capture(request_id: int, url: String, headers: PackedStringArray, body: String, on_done: Callable) -> void:
	_requests.append({"id": request_id, "url": url, "on_done": on_done})


func _answer(code: int, text: String) -> void:
	for request: Dictionary in _requests:
		var on_done: Callable = request["on_done"]
		if on_done.is_valid():
			on_done.call({"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": text.to_utf8_buffer()})


func _run() -> void:
	# [name, mode, code, body]. "real" uses the real HTTP client against a closed local port.
	var scenarios: Array = [
		["service unreachable (closed port, real client)", "real", 0, ""],
		["service silent (never answers)", "silent", 0, ""],
		["service returns garbage", "answer", 200, "not json {{{"],
		["service returns an invalid profile", "answer", 200, "{\"profile\":\"evil\",\"narrative_variant\":\"x\"}"],
		["service returns HTTP 500", "answer", 500, "{}"],
	]
	for scenario: Array in scenarios:
		await _run_scenario(scenario[0], scenario[1], scenario[2], scenario[3])
	ai_config.enabled = false
	ai_config.base_url = original_url
	_clean_state()
	SaveSystem.purge()
	SceneManager.dry_run = false
	var real_save_after: String = FileAccess.get_file_as_string(SaveSystem.DEFAULT_PATH) if FileAccess.file_exists(SaveSystem.DEFAULT_PATH) else "<missing>"
	_check("the real save file was not touched", real_save_after == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _run_scenario(title: String, mode: String, code: int, body: String) -> void:
	_clean_state()
	SceneManager.dry_run = true
	ai_config.enabled = true
	ai_config.base_url = CLOSED_PORT_URL if mode == "real" else original_url
	var level := LEVEL_1_SCENE.instantiate() as LevelBase
	add_child(level)
	await _frames(3)
	level.advance_delay = ADVANCE_DELAY
	level.refine_wait_timeout = REFINE_WAIT
	if mode != "real":
		level.refiner.client.transport = _capture
	var completed: Array[int] = []
	level.level_completed.connect(func(number: int) -> void: completed.append(number))
	level.boss.hurtbox.receive_hit(DamageInfo.create(999, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	var waited: float = 0.0
	while _find_fragment() == null and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		# Phase 15q: since Phase 15n the guardian's last words come first (the fragment waits for them); no key is pressed here, so they are skipped.
		for node in level.find_children("*", "BossDialogue", true, false):
			if (node as BossDialogue).is_speaking():
				(node as BossDialogue).skip()
	_check("[%s] the boss fell and its fragment appeared" % title, _find_fragment() != null)
	if _find_fragment() == null:
		level.free()
		return
	level.player.global_position = _find_fragment().global_position
	var panel := level.get_node("DecisionPanel") as DecisionPanel
	waited = 0.0
	while not panel.is_open() and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check("[%s] the decision panel opened" % title, panel.is_open())
	panel.release_button.pressed.emit()
	var started_at: int = Time.get_ticks_msec()
	_check("[%s] the decision was recorded at once" % title, GameState.has_decision("fragment_level_1") and GameState.souls_released == 1)
	_check("[%s] the LOCAL rule already decided the profile (compassionate)" % title, GameState.adaptive_profile == AdaptiveIds.PROFILE_COMPASSIONATE)
	# A request is in flight (or was refused); the answer, if any, is a bad one.
	await _frames(3)
	if mode == "answer":
		_check("[%s] the game asked the service" % title, _requests.size() >= 1)
		_answer(code, body)
	var limit: float = REFINE_WAIT + HANG_MARGIN
	waited = 0.0
	while completed.is_empty() and waited < limit + 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var elapsed: float = float(Time.get_ticks_msec() - started_at) / 1000.0
	_check("[%s] the level advanced (%.2f s, at most refine_wait_timeout %.1f s + margin)" % [title, elapsed, REFINE_WAIT],
		completed == [1] and elapsed <= REFINE_WAIT + HANG_MARGIN)
	_check("[%s] it asked for the next level" % title, SceneManager.last_requested_scene_id == "level_2" and started_signals == ["level_2"])
	_check("[%s] the profile is still the local one and nothing remote was applied" % title,
		GameState.adaptive_profile == AdaptiveIds.PROFILE_COMPASSIONATE and GameState.adaptive_narrative_variant != "x" and GameState.adaptive_narrative_variant != "evil")
	_check("[%s] the tree is not paused and no pause lock is held" % title, not get_tree().paused and not PauseLock.is_locked())
	_check("[%s] the refiner is not stuck (idle, or reported a failure status)" % title,
		not level.refiner.in_flight or mode == "silent" or mode == "real")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)) if FileAccess.file_exists(TEST_SAVE) else null
	_check("[%s] the save is valid with exactly the seven keys" % title, saved is Dictionary and (saved as Dictionary).size() == 7)
	level.free()
	for child in get_children():
		if child is SoulFragment:
			child.free()
	await _frames(3)

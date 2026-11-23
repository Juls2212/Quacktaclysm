extends Node
## Headless smoke test for Phase 15m (the tutorial rebuilt): no softlock by design. A seeded fuzz test throws random sequences of actions at
## the tutorial (any order, killing the dummy, dying, falling, pausing, spamming inputs) and asserts that the gate is always reachable and
## opens (by completing the steps or by the skip hold) and that the dummy always comes back; plus the independent steps, early credit, the
## remapped keys in the prompts, the skip hold, the checklist, the stations, the flow into level 1, the reduced mode and the usual guards.
## Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15m_smoke_test.tscn
## Uses a redirected save path and a temporary settings file; the AI service stays disabled; the real files are never touched.

const TEST_SAVE: String = "user://test_save_phase15m.json"
const TEST_SETTINGS: String = "user://test_settings_phase15m.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const TUTORIAL: PackedScene = preload("res://frontend/levels/tutorial.tscn")
const DEFAULT_REGISTRY: SceneRegistry = preload("res://backend/progression/default_scene_registry.tres")
## The fuzz stops after this many seconds of wall time and reports how many sequences ran.
const FUZZ_BUDGET_SECONDS: float = 150.0
const FUZZ_MIN_SEQUENCES: int = 12
const CLOCK: float = 8.0

var failures: int = 0
var real_save_before: String = ""
var real_settings_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	GameSettings.path_override = TEST_SETTINGS
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_settings_before = _read_file(GameSettings.PATH)
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


## Waits `seconds` of game time (the clock may be accelerated).
func _wait(seconds: float) -> void:
	var waited: float = 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	InputMap.load_from_project_settings()
	Input.action_release(&"ui_accept")
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())
	SceneManager.dry_run = true
	var registry := SceneRegistry.new()
	registry.scenes = DEFAULT_REGISTRY.scenes.duplicate()
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	SceneManager.set_registry(registry)
	SceneManager.last_requested_scene_id = ""


func _level() -> LevelBase:
	var level := TUTORIAL.instantiate() as LevelBase
	add_child(level)
	await _frames(3)
	return level


func _free_level(level: LevelBase) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	level.free()
	await _frames(2)
	while SceneManager.is_transitioning():
		await get_tree().process_frame


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_steps_and_credit()
	await _test_dummy_and_skip()
	await _test_prompts_and_checklist()
	await _test_flow()
	await _test_reduced()
	await _test_fuzz()
	await _test_leaks()
	SceneManager.dry_run = false
	_clean_state()
	SaveSystem.purge()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path_override = ""
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real settings file was not touched", _read_file(GameSettings.PATH) == real_settings_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


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
	var config: TutorialConfig = TutorialConfig.get_default()
	_check("numbers: the dummy comes back after about 1 s and the skip hold is exported (%.1f s / %.1f s)" % [config.respawn_seconds, config.skip_hold_seconds], is_equal_approx(config.respawn_seconds, 1.0) and config.skip_hold_seconds > 0.5)
	var texts: TutorialTexts = TutorialTexts.get_default()
	var required: int = 0
	for step in texts.steps:
		required += 1 if bool(step.get("required", true)) else 0
	_check("texts: the steps and the dummy lines are in the resource (%d steps, %d required, %d dummy events)" % [texts.steps.size(), required, texts.dummy_lines.size()], texts.steps.size() == 8 and required == 7 and texts.dummy_lines.size() >= 8)
	var wave_free: bool = true
	for step in texts.steps:
		wave_free = wave_free and String(step["kind"]) != "wave"
	_check("texts: the tutorial does not teach the sword wave or the double jump (they come with the fragments) and says so", wave_free and texts.abilities_note.contains("fragmentos"))


func _test_steps_and_credit() -> void:
	_clean_state()
	var level: LevelBase = await _level()
	var controller: TutorialController = level.get_node("TutorialController")
	var player: Player = level.player
	var early: Array[String] = []
	controller.step_credited_early.connect(func(step_id: String) -> void: early.append(step_id))
	_check("steps: the first one on screen is move and nothing is done", controller.get_current_step_id() == "move" and controller.done.is_empty() and not controller.is_completed)
	# Out of order: heavy, then the soul, then the dash, before the move.
	player.heavy_attack_started.emit()
	player.soul.add_soul(11)
	player.dash_started.emit()
	_check("steps: actions done out of order and before they are asked are all credited (%s)" % str(early), controller.is_step_done("heavy") and controller.is_step_done("soul") and controller.is_step_done("dash") and early.size() == 3)
	_check("steps: what is on screen is recomputed from what is done (still the move)", controller.get_current_step_id() == "move" and controller.current_index == 0)
	# The same action twice does nothing new.
	var count: int = controller.done.size()
	for i in 20:
		player.dash_started.emit()
		player.heavy_attack_started.emit()
	_check("steps: spamming an action changes nothing (%d done)" % controller.done.size(), controller.done.size() == count)
	# A respawn or a fall is not walking.
	player.global_position = Vector2(1500.0, 570.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("steps: a teleport (a respawn) does not count as moving", not controller.is_step_done("move"))
	for kind in ["move", "jump", "attack"]:
		controller._on_action(kind)
	_check("steps: with everything done but the heal the gate is closed", not controller.is_completed and controller.get_current_step_id() == "heal")
	controller.exit_area.body_entered.emit(player)
	_check("steps: the closed gate says what is missing and does not go anywhere", SceneManager.last_requested_scene_id == "" and controller.prompt_label.text.contains("Curarte"), controller.prompt_label.text)
	player.focus_completed.emit(0)
	_check("steps: the last required step opens the gate (the optional pause is not needed)", controller.is_completed and not controller.is_step_done("pause"))
	# The pause step is credited when the pause action is pressed.
	var pause := InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	controller._input(pause)
	_check("steps: pressing pause credits the optional pause step", controller.is_step_done("pause"))
	var stations: Array[Node] = get_tree().get_nodes_in_group(&"tutorial_station")
	var lit: int = 0
	for station in stations:
		lit += 1 if station.get(&"done") else 0
	_check("stations: eight practice stations stand in the level and they light up when their step is done (%d of %d)" % [lit, stations.size()], stations.size() == 8 and lit == 8)
	await _free_level(level)


func _test_dummy_and_skip() -> void:
	_clean_state()
	var level: LevelBase = await _level()
	var controller: TutorialController = level.get_node("TutorialController")
	var player: Player = level.player
	var dummy: TrainingDummy = controller.dummy
	var config: TutorialConfig = controller.config
	# Kill the dummy before it has said or asked anything.
	dummy.health.kill(player)
	await _frames(2)
	_check("dummy: it died (the old tutorial stayed blocked here)", dummy.health.is_dead and not dummy.hurtbox.monitorable)
	Engine.time_scale = 4.0
	var waited: float = 0.0
	while dummy.health.is_dead and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	Engine.time_scale = 1.0
	_check("dummy: it respawned by itself after about %.1f s (%.2f s) and can be hit again" % [config.respawn_seconds, waited], not dummy.health.is_dead and dummy.hurtbox.monitorable and controller.respawns == 1 and waited >= config.respawn_seconds - 0.3 and waited <= config.respawn_seconds + 1.5)
	var hit: bool = dummy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER, &"light"))
	_check("dummy: a hit after the respawn lands and speaks (%s)" % str(controller.dummy_label.text), hit)
	for i in 3:
		dummy.health.kill(player)
		await _frames(2)
		Engine.time_scale = 8.0
		await _wait(config.respawn_seconds + 1.0)
		Engine.time_scale = 1.0
	_check("dummy: it keeps coming back however many times it is killed (%d respawns)" % controller.respawns, controller.respawns >= 4 and not dummy.health.is_dead)
	# The skip hold: a short press does nothing, a long hold opens the gate.
	Input.action_press(&"ui_accept")
	Engine.time_scale = 4.0
	await _wait(config.skip_hold_seconds * 0.4)
	Input.action_release(&"ui_accept")
	Engine.time_scale = 1.0
	_check("skip: a short press does not open the gate (held %.2f of %.1f s)" % [controller.skip_held, config.skip_hold_seconds], not controller.is_completed, str(controller.done.keys()))
	var opened: Array[bool] = [false]
	controller.tutorial_completed.connect(func() -> void: opened[0] = true)
	Input.action_press(&"ui_accept")
	Engine.time_scale = 4.0
	await _wait(config.skip_hold_seconds + 1.0)
	Input.action_release(&"ui_accept")
	Engine.time_scale = 1.0
	_check("skip: holding the confirm action opens the gate at any time and the tutorial is marked skipped", controller.is_completed and controller.skipped and opened[0])
	controller.exit_area.body_entered.emit(player)
	_check("skip: the open gate goes to level 1", SceneManager.last_requested_scene_id == "level_1" and GameState.current_level == 1)
	await _free_level(level)


func _test_prompts_and_checklist() -> void:
	_clean_state()
	var level: LevelBase = await _level()
	var controller: TutorialController = level.get_node("TutorialController")
	var hud: TutorialHud = level.get_node("PromptLayer/Hud") as TutorialHud
	# Remap the jump key: the prompt and the hint follow it.
	InputMap.action_erase_events(&"jump")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.keycode = KEY_B
	InputMap.action_add_event(&"jump", key)
	for kind in ["move", "dash", "attack", "heavy"]:
		controller._on_action(kind)
	_check("prompts: the step on screen is the jump", controller.get_current_step_id() == "jump")
	controller._hint_check_left = 0.0
	controller._feedback_left = 0.0
	controller._refresh_hints()
	controller._show_current_prompt()
	_check("prompts: the prompt shows the REMAPPED jump key (%s)" % controller.prompt_label.text, controller.prompt_label.text.contains("B") and not controller.prompt_label.text.contains("{"))
	_check("prompts: every step prompt resolves all its keys from the controls catalog", _all_prompts_resolve(controller))
	_check("checklist: the panel has one row per step and mirrors what is done (%d of %d)" % [hud.done_count(), hud.rows.size()], hud != null and hud.rows.size() == 8 and hud.done_count() == controller.done.size())
	controller._on_action("jump")
	_check("checklist: a step done is ticked at once", hud.done_count() == controller.done.size() and hud.done_count() == 5)
	_check("checklist: the skip hint shows the current confirm key (%s)" % hud.resolve("{ui_accept}"), not hud.resolve(TutorialTexts.get_default().skip_hint).contains("{"))
	InputMap.load_from_project_settings()
	await _free_level(level)


func _all_prompts_resolve(controller: TutorialController) -> bool:
	for step in controller.steps:
		if controller.build_text(String(step["text"])).contains("{") or controller.build_text(String(step["short"])).contains("{"):
			return false
	return true


func _test_flow() -> void:
	_clean_state()
	var registry_scene: String = String(DEFAULT_REGISTRY.scenes.get(DEFAULT_REGISTRY.new_game_scene_id, ""))
	_check("flow: a new game starts in the tutorial (%s)" % DEFAULT_REGISTRY.new_game_scene_id, DEFAULT_REGISTRY.new_game_scene_id == "tutorial" and registry_scene.ends_with("tutorial.tscn"))
	var level: LevelBase = await _level()
	var controller: TutorialController = level.get_node("TutorialController")
	for step in controller.steps:
		if bool(step.get("required", true)):
			controller._on_action(String(step["kind"]))
	controller.exit_area.body_entered.emit(level.player)
	_check("flow: finishing the steps and entering the gate requests level 1 once and sets the checkpoint", SceneManager.last_requested_scene_id == "level_1" and GameState.current_level == 1 and GameState.checkpoint == "level_1_start")
	var loads: bool = true
	for id in ["level_1", "level_2", "level_3"]:
		loads = loads and DEFAULT_REGISTRY.scenes.has(id) and ResourceLoader.exists(String(DEFAULT_REGISTRY.scenes[id]))
	_check("flow: levels 1, 2 and 3 are in the registry and load", loads)
	await _free_level(level)


func _test_reduced() -> void:
	_clean_state()
	GameSettings.save_settings({"corruption_effects": false})
	var level: LevelBase = await _level()
	var hud: TutorialHud = level.get_node("PromptLayer/Hud") as TutorialHud
	var controller: TutorialController = level.get_node("TutorialController")
	var ages_before: float = float(hud.rows[0]["age"])
	await _frames(20)
	var station: Node = get_tree().get_nodes_in_group(&"tutorial_station")[0]
	_check("reduced: the checklist and the stations are static (no animation clock)", hud.reduced and station.get(&"_reduced") == true and float(hud.rows[0]["age"]) == ages_before)
	for step in controller.steps:
		controller._on_action(String(step["kind"]))
	_check("reduced: the tutorial works the same", controller.is_completed)
	await _free_level(level)
	GameSettings.save_settings(GameSettings.DEFAULTS.duplicate())


# ---------------------------------------------------------------------------------------------
# The fuzz: random sequences cannot block the gate
# ---------------------------------------------------------------------------------------------

func _apply(level: LevelBase, controller: TutorialController, rng: RandomNumberGenerator) -> void:
	var player: Player = level.player
	match rng.randi_range(0, 13):
		0:
			player.dash_started.emit()
		1:
			player.attack_started.emit()
		2:
			player.heavy_attack_started.emit()
		3:
			player.state_changed.emit(Player.State.IDLE, Player.State.JUMP)
		4:
			player.focus_completed.emit(0)
		5:
			player.soul.add_soul(rng.randi_range(1, 40))
		6:
			if is_instance_valid(controller.dummy) and not controller.dummy.health.is_dead:
				controller.dummy.health.kill(player)
		7:
			player.health.kill(player)
		8:
			player.global_position = Vector2(rng.randf_range(100.0, 2400.0), 1300.0)
		9:
			var pause := InputEventAction.new()
			pause.action = &"pause"
			pause.pressed = true
			controller._input(pause)
			get_tree().paused = true
			await _wait(0.2)
			get_tree().paused = false
		10:
			for i in rng.randi_range(5, 30):
				player.dash_started.emit()
				player.attack_started.emit()
				player.heavy_attack_started.emit()
		11:
			Input.action_press(&"ui_accept")
			await _wait(controller.config.skip_hold_seconds * 0.3)
			Input.action_release(&"ui_accept")
		12:
			if is_instance_valid(controller.dummy):
				controller.dummy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER, [&"light", &"heavy", &""][rng.randi_range(0, 2)]))
		_:
			await _wait(rng.randf_range(0.0, 1.5))


func _test_fuzz() -> void:
	var started: int = Time.get_ticks_msec()
	var sequences: int = 0
	var by_steps: int = 0
	var by_skip: int = 0
	var bad: PackedStringArray = PackedStringArray()
	var dummy_back: int = 0
	var kills: int = 0
	var seed_value: int = 15013
	while (Time.get_ticks_msec() - started) / 1000.0 < FUZZ_BUDGET_SECONDS and sequences < 400:
		seed_value += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_clean_state()
		var level: LevelBase = await _level()
		var controller: TutorialController = level.get_node("TutorialController")
		Engine.time_scale = CLOCK
		var actions: int = rng.randi_range(4, 24)
		for i in actions:
			await _apply(level, controller, rng)
			await _frames(1)
		Engine.time_scale = 1.0
		get_tree().paused = false
		Input.action_release(&"ui_accept")
		# Whatever happened, the dummy is alive again after its time and the gate can be opened.
		Engine.time_scale = CLOCK
		await _wait(controller.config.respawn_seconds + 1.0)
		Engine.time_scale = 1.0
		var dummy_ok: bool = is_instance_valid(controller.dummy) and not controller.dummy.health.is_dead and controller.dummy.hurtbox.monitorable
		dummy_back += 1 if dummy_ok else 0
		if controller.respawns > 0:
			kills += 1
		var route: int = rng.randi_range(0, 1)
		if route == 0:
			# By doing the missing steps (as the player would, in any order).
			var missing: Array[Dictionary] = []
			for step in controller.steps:
				if bool(step.get("required", true)) and not controller.is_step_done(String(step["id"])):
					missing.append(step)
			missing.shuffle()
			for step in missing:
				controller._on_action(String(step["kind"]))
			by_steps += 1
		else:
			Input.action_press(&"ui_accept")
			Engine.time_scale = CLOCK
			await _wait(controller.config.skip_hold_seconds + 1.0)
			Engine.time_scale = 1.0
			Input.action_release(&"ui_accept")
			by_skip += 1
		SceneManager.last_requested_scene_id = ""
		controller.exit_area.body_entered.emit(level.player)
		var gate_ok: bool = controller.is_completed and SceneManager.last_requested_scene_id == "level_1"
		if not (gate_ok and dummy_ok):
			bad.append("seed %d route %d gate %s dummy %s done %s" % [seed_value, route, str(gate_ok), str(dummy_ok), str(controller.done.keys())])
		sequences += 1
		await _free_level(level)
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	print("MEASURE|fuzz: %d sequences in %.1f s (%d opened by the steps, %d by the skip hold, %d with a dummy respawn), %d failures" % [sequences, seconds, by_steps, by_skip, kills, bad.size()])
	_check("fuzz: %d random sequences ran (at least %d) in %.0f s; the gate always opened and the dummy always came back (%d failures) %s" % [sequences, FUZZ_MIN_SEQUENCES, seconds, bad.size(), str(bad.slice(0, 3))], sequences >= FUZZ_MIN_SEQUENCES and bad.is_empty())
	_check("fuzz: both routes were exercised (steps %d, skip hold %d) and the dummy respawned in %d sequences" % [by_steps, by_skip, kills], by_steps > 0 and by_skip > 0 and kills > 0)


func _test_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 4:
		var level: LevelBase = await _level()
		var controller: TutorialController = level.get_node("TutorialController")
		controller.dummy.health.kill(level.player)
		await _wait(0.5)
		for step in controller.steps:
			controller._on_action(String(step["kind"]))
		await _free_level(level)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeating the tutorial four times|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeating the tutorial four times (%s)" % str(counts), counts[3] <= counts[1] + 4 and not get_tree().paused)
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: after all of it still the seven keys", keys == expected)

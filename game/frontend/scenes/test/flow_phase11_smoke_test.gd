extends Node
## Headless smoke test for Phase 11: PauseLock, SceneRegistry/SceneManager, main menu, pause menu,
## Game Over and one REAL scene transition (to flow_target_scene, which quits with the exit code).
## Run: <godot> --headless --path game res://frontend/scenes/test/flow_phase11_smoke_test.tscn
## Uses a redirected save path and SceneManager.dry_run; the real save is never touched.

const TEST_SAVE: String = "user://test_save_phase11.json"
const DEFAULT_REGISTRY: SceneRegistry = preload("res://backend/progression/default_scene_registry.tres")
const MAIN_MENU_SCENE: PackedScene = preload("res://frontend/ui/main_menu.tscn")
const PAUSE_SCENE: PackedScene = preload("res://frontend/ui/pause_menu.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://frontend/ui/game_over_panel.tscn")
const DECISION_SCENE: PackedScene = preload("res://frontend/ui/decision_panel.tscn")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const BOSS_TEST_SCENE: PackedScene = preload("res://frontend/scenes/test/boss_test.tscn")
const FRAGMENT_DATA: SoulFragmentData = preload("res://backend/decisions/data/fragment_level_1.tres")
const TARGET_PATH: String = "res://frontend/scenes/test/flow_target_scene.tscn"
const FLOOR_Y: float = 300.0

var failures: int = 0
var failed_signals: Array[String] = []
var finished_signals: Array[String] = []
var real_save_before: String = ""


func _ready() -> void:
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
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


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait_idle(max_frames: int = 60) -> void:
	var waited: int = 0
	while SceneManager.is_transitioning() and waited < max_frames:
		await get_tree().process_frame
		waited += 1


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "<missing>"
	return FileAccess.get_file_as_string(path)


func _write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_registry() -> SceneRegistry:
	var registry := SceneRegistry.new()
	registry.scenes = DEFAULT_REGISTRY.scenes.duplicate()
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	return registry


func _clean_state() -> void:
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.start_new_game()
	SceneManager.last_requested_scene_id = ""
	SceneManager.last_requested_path = ""
	SceneManager.quit_requested = false


func _press_pause() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "pause"
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _run() -> void:
	SceneManager.dry_run = true
	SceneManager.set_registry(_test_registry())
	SceneManager.scene_change_failed.connect(func(_id: String, reason: String) -> void: failed_signals.append(reason))
	SceneManager.transition_finished.connect(func(id: String) -> void: finished_signals.append(id))
	await _test_pause_lock()
	await _test_registry_and_manager()
	await _test_main_menu()
	await _test_pause_menu()
	await _test_game_over()
	await _test_boss_test_integration()
	_clean_state()
	SceneManager.dry_run = false
	SaveSystem.purge()
	_check("real save file untouched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT (before real transition): %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	if failures > 0:
		get_tree().quit(1)
		return
	_start_real_transition()


# --- PauseLock ---

func _test_pause_lock() -> void:
	var tree := get_tree()
	PauseLock.reset(tree)
	_check("lock starts free", not PauseLock.is_locked() and PauseLock.holder_count() == 0 and not tree.paused)
	var a := RefCounted.new()
	var b := RefCounted.new()
	PauseLock.request(a, tree)
	_check("one holder pauses", tree.paused and PauseLock.is_locked() and PauseLock.holder_count() == 1)
	PauseLock.request(a, tree)
	_check("same holder twice counts once", PauseLock.holder_count() == 1)
	PauseLock.release(a, tree)
	_check("releasing the only holder unpauses", not tree.paused and not PauseLock.is_locked())
	PauseLock.request(a, tree)
	PauseLock.request(b, tree)
	PauseLock.release(a, tree)
	_check("two holders: stays paused after the first release", tree.paused and PauseLock.holder_count() == 1)
	PauseLock.release(b, tree)
	_check("two holders: unpaused after both release", not tree.paused and PauseLock.holder_count() == 0)
	PauseLock.request(a, tree)
	PauseLock.release(b, tree)
	_check("releasing an unknown holder is a no-op", tree.paused and PauseLock.holder_count() == 1)
	PauseLock.release(null, tree)
	_check("releasing null is a no-op", tree.paused and PauseLock.holder_count() == 1)
	PauseLock.reset(tree)
	var lone := RefCounted.new()
	PauseLock.release(lone, tree)
	_check("unknown release while free is safe", not tree.paused and PauseLock.holder_count() == 0)
	var freed_1 := Node.new()
	var freed_2 := Node.new()
	PauseLock.request(freed_1, tree)
	PauseLock.request(freed_2, tree)
	freed_1.free()
	_check("freed holder is purged", PauseLock.holder_count() == 1)
	freed_2.free()
	_check("all freed holders purged: not locked", not PauseLock.is_locked() and PauseLock.holder_count() == 0)
	var freed_3 := Node.new()
	PauseLock.request(freed_3, tree)
	freed_3.free()
	var live := RefCounted.new()
	PauseLock.request(live, tree)
	PauseLock.release(live, tree)
	_check("a freed holder cannot keep the tree paused", not tree.paused)
	PauseLock.request(a, tree)
	PauseLock.request(b, tree)
	PauseLock.reset(tree)
	_check("reset clears everything and unpauses", not tree.paused and PauseLock.holder_count() == 0)
	var panel := DECISION_SCENE.instantiate() as DecisionPanel
	add_child(panel)
	panel.open(FRAGMENT_DATA)
	_check("DecisionPanel pauses through PauseLock", tree.paused and PauseLock.holder_count() == 1)
	panel.close()
	_check("DecisionPanel unpauses through PauseLock", not tree.paused and PauseLock.holder_count() == 0)
	panel.open(FRAGMENT_DATA)
	panel.free()
	_check("freeing an open DecisionPanel unpauses", not tree.paused and PauseLock.holder_count() == 0)
	PauseLock.reset(tree)


# --- SceneRegistry / SceneManager ---

func _test_registry_and_manager() -> void:
	_clean_state()
	failed_signals.clear()
	finished_signals.clear()
	_check("unknown id returns false", not SceneManager.go_to("does_not_exist"))
	_check("unknown id emits scene_change_failed", failed_signals.size() == 1)
	_check("failed request starts no transition", not SceneManager.is_transitioning())
	var registry := _test_registry()
	registry.scenes["ghost"] = "res://frontend/nope/missing.tscn"
	SceneManager.set_registry(registry)
	failed_signals.clear()
	_check("missing file returns false", not SceneManager.go_to("ghost"))
	_check("missing file emits scene_change_failed", failed_signals.size() == 1)
	_check("has_scene false for missing file and unknown id", not registry.has_scene("ghost") and not registry.has_scene("zzz"))
	_check("get_path_for unknown is empty", registry.get_path_for("zzz") == "")
	_check("valid id is known", registry.has_scene("level_1") and registry.has_scene("main_menu"))
	_check("ending is registered (Phase 12b)", registry.get_path_for("ending") == "res://frontend/ui/ending.tscn")
	_check("default registry ids", DEFAULT_REGISTRY.new_game_scene_id == "tutorial" and DEFAULT_REGISTRY.main_menu_scene_id == "main_menu"
		and DEFAULT_REGISTRY.level_scene_ids == PackedStringArray(["level_1", "level_2", "level_3"]))
	_check("tutorial and levels 1-3 are real scenes (Phase 12b registry)",
		DEFAULT_REGISTRY.get_path_for("tutorial") == "res://frontend/levels/tutorial.tscn"
		and DEFAULT_REGISTRY.get_path_for("level_1") == "res://frontend/levels/level_1.tscn"
		and DEFAULT_REGISTRY.get_path_for("level_2") == "res://frontend/levels/level_2.tscn"
		and DEFAULT_REGISTRY.get_path_for("level_3") == "res://frontend/levels/level_3.tscn")
	_check("scene_id_for_level maps and clamps", registry.scene_id_for_level(1) == "level_1" and registry.scene_id_for_level(2) == "level_2"
		and registry.scene_id_for_level(3) == "level_3" and registry.scene_id_for_level(0) == "level_1"
		and registry.scene_id_for_level(-5) == "level_1" and registry.scene_id_for_level(99) == "level_3")
	_check("dry-run go_to starts a transition", SceneManager.go_to("level_2") and SceneManager.is_transitioning())
	_check("dry-run records id and path", SceneManager.last_requested_scene_id == "level_2"
		and SceneManager.last_requested_path == "res://frontend/levels/level_2.tscn")
	failed_signals.clear()
	_check("second request during a transition is rejected", not SceneManager.go_to("level_1") and failed_signals.size() == 1)
	_check("rejected request keeps the first target", SceneManager.last_requested_scene_id == "level_2")
	await _wait_idle()
	_check("transition finishes and emits transition_finished", not SceneManager.is_transitioning() and finished_signals == ["level_2"])
	for level: int in [1, 2, 3, 0, 7]:
		SceneManager.last_requested_scene_id = ""
		_check("go_to_level(%d)" % level, SceneManager.go_to_level(level))
		var expected: String = "level_%d" % clampi(level, 1, 3)
		_check("go_to_level(%d) requests %s" % [level, expected], SceneManager.last_requested_scene_id == expected)
		await _wait_idle()
	_check("go_to_main_menu", SceneManager.go_to_main_menu() and SceneManager.last_requested_scene_id == "main_menu")
	await _wait_idle()
	var autoloads: PackedStringArray = _autoload_names()
	_check("autoloads are exactly GameState and SceneManager", autoloads == PackedStringArray(["GameState", "SceneManager"]), str(autoloads))
	SceneManager.set_registry(_test_registry())


func _autoload_names() -> PackedStringArray:
	var names := PackedStringArray()
	var in_section: bool = false
	for line in FileAccess.get_file_as_string("res://project.godot").split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("["):
			in_section = trimmed == "[autoload]"
		elif in_section and "=" in trimmed:
			names.append(trimmed.get_slice("=", 0))
	return names


# --- Main menu ---

func _make_menu() -> MainMenu:
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	return menu


func _seed_progress() -> void:
	GameState.start_new_game()
	GameState.record_decision("flow_fragment_1", "boss_a", 1, GameState.CHOICE_RELEASED)
	GameState.set_current_level(2)
	GameState.set_checkpoint("flow_checkpoint")


func _test_main_menu() -> void:
	_clean_state()
	var menu := _make_menu()
	await _frames(1)
	_check("menu: Continuar disabled without a save", menu.continue_button.disabled and not menu.new_game_button.disabled)
	_check("menu: focus on the first enabled button", menu.new_game_button.has_focus())
	_seed_progress()
	menu.new_game_button.pressed.emit()
	_check("menu: new game without a save starts directly", not menu.confirm_panel.visible
		and SceneManager.last_requested_scene_id == "tutorial")
	_check("menu: new game reset the state", GameState.decisions.is_empty() and GameState.current_level == 1
		and GameState.checkpoint == GameState.DEFAULT_CHECKPOINT)
	await _wait_idle()
	menu.free()

	_clean_state()
	_seed_progress()
	_check("menu: seed save written", GameState.save_to_disk())
	var saved_bytes: String = _read_file(TEST_SAVE)
	menu = _make_menu()
	await _frames(1)
	_check("menu: Continuar enabled with a save", not menu.continue_button.disabled)
	menu.new_game_button.pressed.emit()
	_check("menu: new game with a save asks for confirmation", menu.confirm_panel.visible and SceneManager.last_requested_scene_id == "")
	_check("menu: confirmation focuses cancel", menu.confirm_cancel_button.has_focus())
	menu.confirm_cancel_button.pressed.emit()
	_check("menu: cancel changes nothing", not menu.confirm_panel.visible and GameState.current_level == 2
		and GameState.decisions.size() == 1 and SceneManager.last_requested_scene_id == "" and not menu.new_game_button.disabled)
	menu.new_game_button.pressed.emit()
	menu.confirm_yes_button.pressed.emit()
	_check("menu: confirm resets the state and requests the new game scene", GameState.decisions.is_empty()
		and GameState.current_level == 1 and SceneManager.last_requested_scene_id == "tutorial")
	_check("menu: save file not deleted or changed", SaveSystem.has_save() and _read_file(TEST_SAVE) == saved_bytes)
	await _wait_idle()
	menu.free()

	_clean_state()
	_seed_progress()
	GameState.save_to_disk()
	GameState.start_new_game()
	SceneManager.last_requested_scene_id = ""
	menu = _make_menu()
	await _frames(1)
	menu.continue_button.pressed.emit()
	_check("menu: continue restores the saved state", GameState.current_level == 2 and GameState.decisions.size() == 1
		and GameState.checkpoint == "flow_checkpoint")
	_check("menu: continue requests the level scene", SceneManager.last_requested_scene_id == "level_2")
	await _wait_idle()
	menu.free()

	# Failure statuses: message shown, no scene requested.
	_clean_state()
	_write_file(TEST_SAVE, "this is not json {{{")
	menu = _make_menu()
	await _frames(1)
	menu.continue_button.pressed.emit()
	_check("menu: corrupt save shows a message and requests no scene", menu.message_label.text == menu.message_corrupt
		and SceneManager.last_requested_scene_id == "" and not SceneManager.is_transitioning())
	_check("menu: still usable after a corrupt save", not menu.new_game_button.disabled and not menu.quit_button.disabled)
	menu.free()

	_clean_state()
	var newer: String = JSON.stringify({"save_version": 999, "current_level": 2, "checkpoint": "x", "souls_released": 0,
		"souls_kept": 0, "decisions": [], "adaptive_profile": "neutral"})
	_write_file(TEST_SAVE, newer)
	var newer_bytes: String = _read_file(TEST_SAVE)
	menu = _make_menu()
	await _frames(1)
	menu.continue_button.pressed.emit()
	_check("menu: newer-version save shows a message and requests no scene", menu.message_label.text == menu.message_unsupported
		and SceneManager.last_requested_scene_id == "")
	_check("menu: newer-version file bytes unchanged", _read_file(TEST_SAVE) == newer_bytes)
	_check("menu: newer-version save blocks saving", not GameState.save_blocked_reason.is_empty())
	menu.new_game_button.pressed.emit()
	_check("menu: new game over a blocked save asks for confirmation", menu.confirm_panel.visible)
	menu.free()

	_clean_state()
	menu = _make_menu()
	await _frames(1)
	menu.continue_button.pressed.emit()
	_check("menu: no save shows a message and requests no scene", menu.message_label.text == menu.message_no_save
		and SceneManager.last_requested_scene_id == "")
	menu.quit_button.pressed.emit()
	_check("menu: quit calls quit in dry-run", SceneManager.quit_requested)
	SceneManager.quit_requested = false

	SceneManager.go_to("level_1")
	var requested_before: String = SceneManager.last_requested_scene_id
	SceneManager.last_requested_scene_id = "marker"
	menu.new_game_button.pressed.emit()
	menu.continue_button.pressed.emit()
	menu.quit_button.pressed.emit()
	_check("menu: buttons ignored during a transition", SceneManager.last_requested_scene_id == "marker"
		and not SceneManager.quit_requested and requested_before == "level_1")
	await _wait_idle()
	menu.free()
	_clean_state()


# --- Pause menu ---

func _make_pause(player: Player = null) -> PauseMenu:
	var pause := PAUSE_SCENE.instantiate() as PauseMenu
	pause.player = player
	add_child(pause)
	return pause


func _test_pause_menu() -> void:
	_clean_state()
	var tree := get_tree()
	var pause := _make_pause()
	await _frames(1)
	_check("pause: closed at start", not pause.is_open() and not tree.paused)
	await _press_pause()
	_check("pause: action opens it and pauses", pause.is_open() and tree.paused and PauseLock.holder_count() == 1)
	_check("pause: focus on Continuar", pause.resume_button.has_focus())
	await _press_pause()
	_check("pause: action again closes it and unpauses", not pause.is_open() and not tree.paused and PauseLock.holder_count() == 0)
	pause.open_menu()
	pause.resume_button.pressed.emit()
	_check("pause: Continuar closes it", not pause.is_open() and not tree.paused)

	var decision := DECISION_SCENE.instantiate() as DecisionPanel
	add_child(decision)
	decision.open(FRAGMENT_DATA)
	await _press_pause()
	_check("pause: does not open while the decision panel holds the lock", not pause.is_open() and PauseLock.holder_count() == 1)
	decision.close()
	_check("pause: decision panel released the lock", not tree.paused)
	decision.free()

	var dead_player := PLAYER_SCENE.instantiate() as Player
	dead_player.is_dead = true
	pause.player = dead_player
	await _press_pause()
	_check("pause: does not open while the player is dead", not pause.is_open() and not tree.paused)
	pause.player = null
	dead_player.free()

	SceneManager.go_to("level_1")
	_check("pause: does not open while transitioning", not pause.can_open() and not pause.open_menu() and not pause.is_open())
	await _wait_idle()

	pause.open_menu()
	pause.main_menu_button.pressed.emit()
	_check("pause: Menú principal releases the lock and requests the main menu", not pause.is_open() and not tree.paused
		and PauseLock.holder_count() == 0 and SceneManager.last_requested_scene_id == "main_menu")
	await _wait_idle()

	pause.open_menu()
	_check("pause: opened before freeing", tree.paused)
	pause.free()
	_check("pause: freeing it while open leaves the tree unpaused", not tree.paused and PauseLock.holder_count() == 0)
	_clean_state()


# --- Game Over ---

func _add_floor(parent: Node) -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.collision_mask = 0
	floor_body.position = Vector2(0.0, FLOOR_Y + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	parent.add_child(floor_body)


func _test_game_over() -> void:
	_clean_state()
	var tree := get_tree()
	var arena := Node2D.new()
	add_child(arena)
	_add_floor(arena)
	var untouched := PLAYER_SCENE.instantiate() as Player
	untouched.position = Vector2(-3000.0, FLOOR_Y - 30.0)
	arena.add_child(untouched)
	_check("player: without a controller auto respawn follows the stats", untouched.is_auto_respawn_enabled() == untouched.stats.auto_respawn)
	var stats_auto_respawn: bool = untouched.stats.auto_respawn
	untouched.set_auto_respawn(not stats_auto_respawn)
	_check("player: set_auto_respawn overrides at runtime", untouched.is_auto_respawn_enabled() == (not stats_auto_respawn))
	_check("player: set_auto_respawn does not mutate the shared stats", untouched.stats.auto_respawn == stats_auto_respawn
		and ResourceLoader.load("res://backend/player/default_player_stats.tres").auto_respawn == stats_auto_respawn)
	untouched.free()

	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - 30.0)
	arena.add_child(player)
	var panel := GAME_OVER_SCENE.instantiate() as GameOverPanel
	arena.add_child(panel)
	var controller := GameOverController.new()
	controller.player = player
	controller.panel = panel
	controller.open_delay = 0.1
	arena.add_child(controller)
	var counts: Dictionary = {"retry": 0, "menu": 0}
	panel.retry_requested.connect(func() -> void: counts["retry"] += 1)
	panel.menu_requested.connect(func() -> void: counts["menu"] += 1)
	await _physics(5)
	var checkpoint_pos := Vector2(120.0, FLOOR_Y - 30.0)
	player.set_respawn_point(checkpoint_pos)
	_check("game over: controller disables auto respawn", not player.is_auto_respawn_enabled())
	_check("game over: shared stats still unchanged", player.stats.auto_respawn == stats_auto_respawn)

	player.health.kill()
	_check("game over: player is dead", player.is_dead)
	_check("game over: panel waits for the delay", not panel.is_open() and not tree.paused)
	player.died.emit()
	await _physics(20)
	_check("game over: panel opens after the delay and pauses", panel.is_open() and tree.paused and PauseLock.holder_count() == 1)
	_check("game over: a second died while waiting did not duplicate", PauseLock.holder_count() == 1)
	_check("game over: focus on Reintentar", panel.retry_button.has_focus())
	panel.retry_button.pressed.emit()
	panel.retry_button.pressed.emit()
	panel.main_menu_button.pressed.emit()
	_check("game over: only one action per opening", counts["retry"] == 1 and counts["menu"] == 0
		and SceneManager.last_requested_scene_id != "main_menu")
	_check("game over: Reintentar closes and unpauses", not panel.is_open() and not tree.paused and PauseLock.holder_count() == 0)
	_check("game over: Reintentar respawns at the checkpoint with full health", not player.is_dead
		and player.health.current_health == player.health.max_health and player.global_position.is_equal_approx(checkpoint_pos))
	await _physics(3)

	player.health.kill()
	await _physics(20)
	_check("game over: reopens on a second death", panel.is_open() and tree.paused)
	panel.main_menu_button.pressed.emit()
	panel.retry_button.pressed.emit()
	_check("game over: Menú principal requests the main menu and unpauses", SceneManager.last_requested_scene_id == "main_menu"
		and not panel.is_open() and not tree.paused and counts["menu"] == 1 and counts["retry"] == 1)
	await _wait_idle()
	player.respawn()

	# show_game_over = false behaves like the automatic respawn.
	var auto_player := PLAYER_SCENE.instantiate() as Player
	auto_player.position = Vector2(-1500.0, FLOOR_Y - 30.0)
	arena.add_child(auto_player)
	var auto_panel := GAME_OVER_SCENE.instantiate() as GameOverPanel
	arena.add_child(auto_panel)
	var auto_controller := GameOverController.new()
	auto_controller.player = auto_player
	auto_controller.panel = auto_panel
	auto_controller.show_game_over = false
	arena.add_child(auto_controller)
	await _physics(5)
	_check("game over: show_game_over=false keeps auto respawn", auto_player.is_auto_respawn_enabled())
	auto_player.health.kill()
	await _physics(int((auto_player.stats.respawn_delay + 0.5) * Engine.physics_ticks_per_second))
	_check("game over: show_game_over=false respawns automatically without a panel", not auto_player.is_dead
		and not auto_panel.is_open() and not tree.paused)

	# Freeing the panel while open leaves the tree unpaused.
	var lone_panel := GAME_OVER_SCENE.instantiate() as GameOverPanel
	arena.add_child(lone_panel)
	lone_panel.open()
	_check("game over: lone panel pauses", tree.paused)
	lone_panel.free()
	_check("game over: freeing it while open unpauses", not tree.paused and PauseLock.holder_count() == 0)
	arena.free()
	_clean_state()


# --- boss_test integration: pause menu + game over controller wired in the sandbox ---

func _test_boss_test_integration() -> void:
	_clean_state()
	GameState.autosave_enabled = false
	var tree := get_tree()
	var scene := BOSS_TEST_SCENE.instantiate()
	add_child(scene)
	await _physics(5)
	var player := scene.get_node("Player") as Player
	var boss := scene.get_node("Boss") as BossBase
	var encounter := scene.get_node("Encounter") as BossEncounter
	var panel := scene.get_node("GameOverPanel") as GameOverPanel
	var pause := scene.get_node("PauseMenu") as PauseMenu
	_check("sandbox: nodes wired", player != null and boss != null and panel != null and pause != null
		and pause.player == player and not player.is_auto_respawn_enabled())
	player.global_position = encounter.global_position
	var started: bool = false
	for i in 120:
		await _physics(1)
		if boss.state != BossBase.State.INACTIVE:
			started = true
			break
	_check("sandbox: encounter started", started)
	player.health.kill()
	_check("sandbox: boss resets when the player dies", player.is_dead and boss.state == BossBase.State.INACTIVE)
	await _press_pause()
	_check("sandbox: pause does not open while dead", not pause.is_open() and not tree.paused)
	await _physics(int((panel_delay(scene) + 0.4) * Engine.physics_ticks_per_second))
	_check("sandbox: game over panel opened", panel.is_open() and tree.paused)
	panel.retry_button.pressed.emit()
	_check("sandbox: retry respawns and unpauses", not player.is_dead and not tree.paused)
	await _press_pause()
	_check("sandbox: pause opens when alive", pause.is_open() and tree.paused)
	await _press_pause()
	_check("sandbox: pause closes", not pause.is_open() and not tree.paused)
	scene.free()
	_check("sandbox: freeing the scene leaves the tree unpaused", not tree.paused and PauseLock.holder_count() == 0)
	GameState.autosave_enabled = true
	_clean_state()


func panel_delay(scene: Node) -> float:
	return (scene.get_node("GameOverController") as GameOverController).open_delay


# --- Real transition ---

func _start_real_transition() -> void:
	var registry := SceneRegistry.new()
	registry.scenes = {"flow_target": TARGET_PATH}
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	SceneManager.set_registry(registry)
	SceneManager.dry_run = false
	var holder := RefCounted.new()
	SceneManager.set_meta("flow_test_holder", holder)
	PauseLock.request(holder, get_tree())
	print("starting REAL transition with the pause lock held (paused=%s, holders=%d)" % [get_tree().paused, PauseLock.holder_count()])
	if not SceneManager.go_to("flow_target"):
		print("FAIL: real go_to returned false")
		get_tree().quit(1)

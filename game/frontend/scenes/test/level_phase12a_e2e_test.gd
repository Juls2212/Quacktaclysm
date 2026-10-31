extends Node
## End-to-end headless check for Phase 12a with REAL scene changes (no dry_run, fades 0):
## go_to("level_1") -> kill the boss -> collect the fragment -> choose through the real DecisionPanel
## -> the level advances to the registry's level_2 scene. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/level_phase12a_e2e_test.tscn
## The entry scene is replaced by the first transition, so a copy of this script is parented to
## the root (it survives scene changes) and drives the checks. Uses a redirected save path.

const TEST_SAVE: String = "user://test_save_phase12a_e2e.json"
const LEVEL_1_PATH: String = "res://frontend/levels/level_1.tscn"
const LEVEL_2_PATH: String = "res://frontend/levels/level_2.tscn"
const STEP_TIMEOUT_SECONDS: float = 30.0
const DRIVER_NAME: String = "E2EDriver"

var failures: int = 0


func _ready() -> void:
	if name == DRIVER_NAME:
		_drive.call_deferred()
		return
	SaveSystem.set_save_path(TEST_SAVE)
	SaveSystem.purge()
	GameState.start_new_game()
	GameState.autosave_enabled = true
	var registry := SceneRegistry.new()
	registry.scenes = SceneManager.get_registry().scenes.duplicate()
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	SceneManager.set_registry(registry)
	SceneManager.dry_run = false
	var driver := Node.new()
	driver.set_script(get_script())
	driver.name = DRIVER_NAME
	get_tree().root.add_child.call_deferred(driver)


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _wait_for(condition: Callable) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(STEP_TIMEOUT_SECONDS * 1000.0):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _scene_is(path: String) -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path == path and not SceneManager.is_transitioning()


func _find_fragment() -> SoulFragment:
	for child in get_tree().current_scene.get_children():
		if child is SoulFragment:
			return child as SoulFragment
	return null


func _drive() -> void:
	SaveSystem.set_save_path(TEST_SAVE)
	_check("start: go_to level_1 accepted", SceneManager.go_to("level_1"))
	var arrived: bool = await _wait_for(func() -> bool: return _scene_is(LEVEL_1_PATH))
	_check("level_1 loaded through the real SceneManager", arrived)
	if not arrived:
		_finish()
		return
	var level := get_tree().current_scene as LevelBase
	_check("level_1: fresh arrival state", GameState.current_level == 1 and GameState.checkpoint == "level_1_start" and not level.player.is_input_locked())
	level.advance_delay = 0.3
	level.refine_wait_timeout = 1.0
	level.boss.hurtbox.receive_hit(DamageInfo.create(999, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
	_check("boss killed with a lethal DamageInfo", level.boss.state == BossBase.State.DEAD)
	var spawned: bool = await _wait_for(func() -> bool: return _find_fragment() != null)
	_check("fragment spawned", spawned)
	level.player.global_position = _find_fragment().global_position
	var panel := level.get_node("DecisionPanel") as DecisionPanel
	var opened: bool = await _wait_for(func() -> bool: return panel.is_open())
	_check("decision panel opened and paused the tree", opened and get_tree().paused)
	panel.release_button.pressed.emit()
	_check("decision recorded through the real panel", GameState.has_decision("fragment_level_1") and GameState.souls_released == 1)
	var advanced: bool = await _wait_for(func() -> bool: return _scene_is(LEVEL_2_PATH))
	_check("transitioned to the registry's level_2 scene", advanced)
	_check("tree unpaused after the transition", not get_tree().paused and not PauseLock.is_locked())
	_check("GameState advanced", GameState.current_level == 2 and GameState.checkpoint == "level_2_start" and GameState.has_decision("fragment_level_1"))
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)) if FileAccess.file_exists(TEST_SAVE) else null
	_check("save file holds level 2", saved is Dictionary and int(saved.get("current_level", 0)) == 2 and saved.get("checkpoint", "") == "level_2_start")
	_finish()


func _finish() -> void:
	SaveSystem.purge()
	GameState.start_new_game()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)

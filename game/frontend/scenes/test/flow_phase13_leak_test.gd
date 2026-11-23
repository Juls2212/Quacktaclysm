extends Node
## Phase 13a scene-transition leak check with REAL scene changes (no dry_run, fades 0):
## 20 loops menu -> tutorial -> level 1 -> menu, then 10 loops menu -> level 1 -> 2 -> 3 -> ending ->
## menu. After each loop it records the node / orphan / object counts and asserts that they stop
## growing after a warm-up. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/flow_phase13_leak_test.tscn
## The entry scene is replaced by the first transition, so a copy of this script parented to the
## root drives the checks (same pattern as the Phase 12b playthrough test).

const TEST_SAVE: String = "user://test_save_phase13_leak.json"
const DRIVER_NAME: String = "LeakDriver"
const STEP_TIMEOUT_SECONDS: float = 30.0
const SETTLE_FRAMES: int = 12
const WARMUP_LOOPS: int = 3
const SHORT_LOOPS: int = 20
const FULL_LOOPS: int = 10
const COMPARE_WINDOW: int = 5
const NODE_TOLERANCE: int = 10
const ORPHAN_TOLERANCE: int = 2
const OBJECT_TOLERANCE: int = 60
const PATHS: Dictionary = {
	"main_menu": "res://frontend/ui/main_menu.tscn",
	"tutorial": "res://frontend/levels/tutorial.tscn",
	"level_1": "res://frontend/levels/level_1.tscn",
	"level_2": "res://frontend/levels/level_2.tscn",
	"level_3": "res://frontend/levels/level_3.tscn",
	"ending": "res://frontend/ui/ending.tscn",
}

var failures: int = 0
var real_save_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	if name == DRIVER_NAME:
		_drive.call_deferred()
		return
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	var registry := SceneRegistry.new()
	registry.scenes = SceneManager.get_registry().scenes.duplicate()
	registry.level_scene_ids = SceneManager.get_registry().level_scene_ids
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


func _scene_is(scene_id: String) -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path == String(PATHS[scene_id]) and not SceneManager.is_transitioning()


func _go(scene_id: String) -> bool:
	if not SceneManager.go_to(scene_id):
		return false
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(STEP_TIMEOUT_SECONDS * 1000.0):
		await get_tree().physics_frame
		if _scene_is(scene_id):
			return true
	return false


func _snapshot() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}


func _settle() -> Dictionary:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	return _snapshot()


func _healthy() -> bool:
	return not get_tree().paused and not SceneManager.is_transitioning() and PauseLock.holder_count() == 0


func _average(rows: Array[Dictionary], key: String, from: int, count: int) -> float:
	var total: float = 0.0
	for i in count:
		total += float(rows[from + i][key])
	return total / float(count)


func _verdict(title: String, rows: Array[Dictionary]) -> void:
	print("LEAK TABLE %s (loop: nodes / orphans / objects)" % title)
	for index in rows.size():
		print("  loop %2d: %5d / %3d / %5d" % [index + 1, rows[index]["nodes"], rows[index]["orphans"], rows[index]["objects"]])
	var early_from: int = WARMUP_LOOPS
	var late_from: int = rows.size() - COMPARE_WINDOW
	var node_growth: float = _average(rows, "nodes", late_from, COMPARE_WINDOW) - _average(rows, "nodes", early_from, COMPARE_WINDOW)
	var orphan_growth: float = _average(rows, "orphans", late_from, COMPARE_WINDOW) - _average(rows, "orphans", early_from, COMPARE_WINDOW)
	var object_growth: float = _average(rows, "objects", late_from, COMPARE_WINDOW) - _average(rows, "objects", early_from, COMPARE_WINDOW)
	print("  growth after warm-up (last %d loops vs loops %d-%d): nodes %+.1f, orphans %+.1f, objects %+.1f" % [COMPARE_WINDOW, early_from + 1, early_from + COMPARE_WINDOW, node_growth, orphan_growth, object_growth])
	_check("%s: node count stops growing after the warm-up" % title, node_growth <= NODE_TOLERANCE)
	_check("%s: orphan node count stops growing" % title, orphan_growth <= ORPHAN_TOLERANCE)
	_check("%s: object count stops growing" % title, object_growth <= OBJECT_TOLERANCE)


func _drive() -> void:
	real_save_before = FileAccess.get_file_as_string(SaveSystem.DEFAULT_PATH) if FileAccess.file_exists(SaveSystem.DEFAULT_PATH) else "<missing>"
	SaveSystem.set_save_path(TEST_SAVE)
	SaveSystem.purge()
	GameState.start_new_game()
	GameState.autosave_enabled = true
	var short_rows: Array[Dictionary] = []
	var all_ok: bool = true
	for loop in SHORT_LOOPS:
		all_ok = all_ok and await _go("main_menu") and _healthy()
		GameState.start_new_game()
		all_ok = all_ok and await _go("tutorial") and _healthy()
		all_ok = all_ok and await _go("level_1") and _healthy()
		all_ok = all_ok and await _go("main_menu") and _healthy()
		short_rows.append(await _settle())
		all_ok = all_ok and _healthy()
	_check("short loops: every scene change finished, tree unpaused, manager idle, no pause holders", all_ok)
	_verdict("menu -> tutorial -> level 1 -> menu (x%d)" % SHORT_LOOPS, short_rows)
	var full_rows: Array[Dictionary] = []
	all_ok = true
	for loop in FULL_LOOPS:
		GameState.start_new_game()
		for scene_id in ["level_1", "level_2", "level_3", "ending", "main_menu"]:
			all_ok = all_ok and await _go(scene_id) and _healthy()
		full_rows.append(await _settle())
		all_ok = all_ok and _healthy()
	_check("full loops: every scene change finished, tree unpaused, manager idle, no pause holders", all_ok)
	_verdict("menu -> level 1 -> 2 -> 3 -> ending -> menu (x%d)" % FULL_LOOPS, full_rows)
	# Phase 14c: with the corrupt profile every level applies its music filter; leaving for the menu
	# or the ending must always give the bus and the pitch back.
	var fx_ok: bool = true
	var corrupt_rows: Array[Dictionary] = []
	var music_bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	var baseline_effects: int = AudioServer.get_bus_effect_count(music_bus)
	var baseline_buses: int = AudioServer.bus_count
	for loop in 8:
		GameState.start_new_game()
		GameState.adaptive_profile = AdaptiveIds.PROFILE_CORRUPT
		fx_ok = fx_ok and await _go("level_1") and _healthy()
		fx_ok = fx_ok and bool(AudioDirector.get_music_profile()["filter_on_bus"])
		# Phase 15a: leave the level in the middle of a focus heal, with soul wisps flying.
		var focus_level := get_tree().current_scene as LevelBase
		if focus_level != null:
			focus_level.player.soul.add_soul(60)
			focus_level.player.health.apply_damage(DamageInfo.create(2, Vector2.ZERO, null, CombatLayers.Team.ENEMY))
			SoulPickup.spawn(focus_level, focus_level.player.global_position + Vector2(200, 0), 11)
			for i in 240:
				if focus_level.player.is_on_floor() and not focus_level.player.health.is_invulnerable():
					break
				await get_tree().physics_frame
			Input.action_press(&"heal")
			await get_tree().physics_frame
			focus_level.player._try_start_focus()
			fx_ok = fx_ok and focus_level.player.state == Player.State.FOCUS
		Input.action_release(&"heal")
		# Phase 15b: leave the level in the middle of the boss intro (the guardian is talking, the player is locked)
		# with a presentation-queue step that never ends.
		var intro_level := get_tree().current_scene as LevelBase
		if intro_level != null and intro_level.encounter != null:
			var boss_intro := intro_level.get_node("BossIntro") as BossIntro
			boss_intro.play_when_headless = true
			BossDialogue.forget_all()
			intro_level.player.global_position = intro_level.encounter.global_position
			for i in 12:
				await get_tree().physics_frame
			fx_ok = fx_ok and boss_intro.active and intro_level.player.is_input_locked()
			var never := Node.new()
			never.add_user_signal("never")
			intro_level.add_child(never)
			(intro_level.get_node("PresentationQueue") as PresentationQueue).enqueue("never", func() -> Variant: return Signal(never, &"never"), 60.0)
		fx_ok = fx_ok and await _go("level_2") and _healthy()
		BossDialogue.forget_all()
		fx_ok = fx_ok and bool(AudioDirector.get_music_profile()["filter_on_bus"])
		# Phase 15c: leave level 2 in the middle of boss 2's phase 2 (floor spikes running, the guardian leaping).
		var swamp_level := get_tree().current_scene as LevelBase
		if swamp_level != null and swamp_level.boss != null and swamp_level.has_node("Content/FloorHazard"):
			swamp_level.player.story_invulnerable = true
			swamp_level.player.global_position = swamp_level.encounter.global_position
			for i in 12:
				await get_tree().physics_frame
			# Phase 15d: the possession sequence is played for real (it is cancelled or ends with the level).
			var possession := swamp_level.get_node("PossessionDirector") as PossessionDirector
			possession.play_when_headless = true
			swamp_level.boss.health.apply_damage(DamageInfo.create(30, Vector2.ZERO, swamp_level.player, CombatLayers.Team.PLAYER))
			for i in 90:
				await get_tree().physics_frame
			var swamp_hazard := swamp_level.get_node("Content/FloorHazard") as FloorHazard
			fx_ok = fx_ok and (possession.active or swamp_hazard.running or possession.persistent)
		fx_ok = fx_ok and await _go("main_menu") and _healthy()
		await _settle()
		var state: Dictionary = AudioDirector.get_music_profile()
		fx_ok = fx_ok and not bool(state["filter_on_bus"]) and is_equal_approx(float(state["pitch"]), 1.0)
		# Phase 14f: no effect, bus, boss track or duck is left behind either (15a: nor a soul wisp).
		var music_state: Dictionary = AudioDirector.get_music_state()
		fx_ok = fx_ok and get_tree().root.find_children("SoulPickup*", "Node2D", true, false).is_empty() and get_tree().root.find_children("SoulWisp*", "Node2D", true, false).is_empty()
		fx_ok = fx_ok and AudioServer.get_bus_effect_count(music_bus) == baseline_effects and AudioServer.bus_count == baseline_buses 				and music_state["boss_music"] == false and is_equal_approx(float(music_state["duck_db"]), 0.0)
		corrupt_rows.append(await _settle())
	_check("corrupt loops: music filter on in levels; in the menu it is gone, pitch 1.0, no extra bus effect or bus, no boss track, no duck, every time", fx_ok)
	_verdict("menu -> level 1 -> 2 -> menu with the corrupt profile (x8)", corrupt_rows)
	SaveSystem.purge()
	GameState.start_new_game()
	var real_save_after: String = FileAccess.get_file_as_string(SaveSystem.DEFAULT_PATH) if FileAccess.file_exists(SaveSystem.DEFAULT_PATH) else "<missing>"
	_check("real save file untouched", real_save_after == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)

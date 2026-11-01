extends Node
## Full simulated playthroughs for Phase 12b with REAL scene changes (no dry_run, fades 0, AI service
## disabled, redirected save path): level 1 -> boss -> fragment -> real DecisionPanel -> level 2 ->
## level 3 -> ending -> main menu "Continuar" -> ending again. Three runs: always released
## (compassionate), always kept (corrupt) and released/kept/released (neutral). Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/level_phase12b_playthrough_test.tscn
## The entry scene is replaced by the first transition, so a copy of this script parented to the
## root (it survives scene changes) drives the checks.

const TEST_SAVE: String = "user://test_save_phase12b_play.json"
const DRIVER_NAME: String = "PlaythroughDriver"
const STEP_TIMEOUT_SECONDS: float = 30.0
const ENDING_PATH: String = "res://frontend/ui/ending.tscn"
const MENU_PATH: String = "res://frontend/ui/main_menu.tscn"
const LEVEL_PATHS: Dictionary = {
	1: "res://frontend/levels/level_1.tscn",
	2: "res://frontend/levels/level_2.tscn",
	3: "res://frontend/levels/level_3.tscn",
}
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const AGGRESSION: Dictionary = {"compassionate": 0.9, "neutral": 1.0, "corrupt": 1.15}
const EXTRAS_IN_CORRUPT: Dictionary = {2: 2, 3: 3}
const BASELINE_ENEMIES: Dictionary = {1: 6, 2: 8, 3: 9}
const RUNS: Array[Dictionary] = [
	{"name": "(a) always released", "choices": ["released", "released", "released"], "tiers": [0, 0, 0], "after_second": "compassionate", "final": "compassionate", "ending": "ending_compassionate"},
	{"name": "(b) always kept", "choices": ["kept", "kept", "kept"], "tiers": [0, 1, 2], "after_second": "corrupt", "final": "corrupt", "ending": "ending_corrupt"},
	{"name": "(c) released, kept, released", "choices": ["released", "kept", "released"], "tiers": [0, 0, 1], "after_second": "neutral", "final": "neutral", "ending": "ending_neutral"},
]

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


func _saved() -> Dictionary:
	if not FileAccess.file_exists(TEST_SAVE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	return parsed if parsed is Dictionary else {}


## Checks the in-memory state, the save file and the "world is running" invariants after a step.
func _assert_state(step: String, level: int, checkpoint: String, released: int, kept: int, decisions: int) -> void:
	_check("%s: GameState level/checkpoint" % step, GameState.current_level == level and GameState.checkpoint == checkpoint,
		"level %d checkpoint %s" % [GameState.current_level, GameState.checkpoint])
	_check("%s: counters and decisions" % step, GameState.souls_released == released and GameState.souls_kept == kept and GameState.decisions.size() == decisions,
		"released %d kept %d decisions %d profile %s" % [GameState.souls_released, GameState.souls_kept, GameState.decisions.size(), GameState.adaptive_profile])
	var saved: Dictionary = _saved()
	var keys_ok: bool = saved.keys().size() == SAVE_KEYS.size() and SAVE_KEYS.all(func(key: String) -> bool: return saved.has(key))
	_check("%s: test save has the seven keys and matches" % step, keys_ok and int(saved.get("current_level", 0)) == level and saved.get("checkpoint", "") == checkpoint
		and int(saved.get("souls_released", -1)) == released and int(saved.get("souls_kept", -1)) == kept
		and (saved.get("decisions", []) as Array).size() == decisions and saved.get("adaptive_profile", "") == GameState.adaptive_profile)
	_check("%s: tree unpaused, no transition, no pause holders" % step, not get_tree().paused and not SceneManager.is_transitioning() and not PauseLock.is_locked())


func _drive() -> void:
	var real_save_path: String = SaveSystem.DEFAULT_PATH
	real_save_before = FileAccess.get_file_as_string(real_save_path) if FileAccess.file_exists(real_save_path) else "<missing>"
	SaveSystem.set_save_path(TEST_SAVE)
	for run in RUNS:
		await _play(run)
	SaveSystem.purge()
	GameState.start_new_game()
	var real_save_after: String = FileAccess.get_file_as_string(real_save_path) if FileAccess.file_exists(real_save_path) else "<missing>"
	_check("real save file untouched", real_save_after == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _play(run: Dictionary) -> void:
	var tag: String = String(run["name"])
	var choices: Array = run["choices"]
	print("=== RUN %s ===" % tag)
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = true
	_check("%s: new game state" % tag, GameState.current_level == 1 and GameState.decisions.is_empty() and not GameState.is_game_completed() and not ai_config.enabled)
	# The tutorial exit: level 1 / level_1_start, autosave, go_to("level_1").
	GameState.set_current_level(1)
	GameState.set_checkpoint("level_1_start")
	GameState.autosave()
	_check("%s: go_to level_1 accepted" % tag, SceneManager.go_to("level_1"))
	var profile_at_level_3: String = ""
	for number in [1, 2, 3]:
		var path: String = LEVEL_PATHS[number]
		var step: String = "%s / level %d" % [tag, number]
		var arrived: bool = await _wait_for(func() -> bool: return _scene_is(path))
		_check("%s: scene loaded through the real SceneManager" % step, arrived)
		if not arrived:
			return
		var level := get_tree().current_scene as LevelBase
		var done_before: int = number - 1
		var released_before: int = choices.slice(0, done_before).count("released")
		_assert_state("%s: arrival" % step, number, "level_%d_start" % number, released_before, done_before - released_before, done_before)
		_check("%s: player free and level running" % step, not level.player.is_input_locked() and not level.player.is_dead)
		var wave_tier: int = level.player.wave_caster.get_effective_tier()
		_check("%s: sword wave tier %d at the start of the level (Phase 12c)" % [step, run["tiers"][number - 1]], wave_tier == run["tiers"][number - 1], "tier %d" % wave_tier)
		_check("%s: AI service disabled in the level's refiner" % step, level.refiner.config != null and not level.refiner.config.enabled)
		var applied: AdaptiveResult = level.get_applied_adaptive_result()
		var expected_profile: String = GameState.adaptive_profile
		_check("%s: adaptive result applied at load matches GameState (%s)" % [step, expected_profile], applied.profile == expected_profile
			and is_equal_approx(level.boss.aggression_multiplier, AGGRESSION[expected_profile]))
		if number >= 2:
			var extras: int = EXTRAS_IN_CORRUPT[number]
			var enemies: int = _count_enemies(level)
			var wanted: int = BASELINE_ENEMIES[number] + (extras if expected_profile == "corrupt" else 0)
			_check("%s: variant group applied (%s -> %d enemies)" % [step, expected_profile, wanted], enemies == wanted, "found %d" % enemies)
		if number == 3:
			profile_at_level_3 = applied.profile
			_check("%s: parameters applied in level 3 correspond to the profile after the second decision (%s)" % [step, run["after_second"]],
				applied.profile == run["after_second"] and is_equal_approx(level.boss.aggression_multiplier, AGGRESSION[run["after_second"]]))
			_check("%s: decision flow evaluates at the ending" % step, level.decision_flow.refinement_point == AdaptiveInput.POINT_ENDING)
		level.advance_delay = 0.3
		level.refine_wait_timeout = 1.0
		level.boss.hurtbox.receive_hit(DamageInfo.create(9999, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
		_check("%s: boss killed with a lethal DamageInfo" % step, level.boss.state == BossBase.State.DEAD)
		var spawned: bool = await _wait_for(func() -> bool: return _find_fragment() != null)
		_check("%s: fragment spawned" % step, spawned)
		if not spawned:
			return
		level.player.global_position = _find_fragment().global_position
		var panel := level.get_node("DecisionPanel") as DecisionPanel
		var opened: bool = await _wait_for(func() -> bool: return panel.is_open())
		_check("%s: decision panel opened and paused the tree" % step, opened and get_tree().paused)
		var choice: String = choices[number - 1]
		if choice == "released":
			panel.release_button.pressed.emit()
		else:
			panel.keep_button.pressed.emit()
		var released_after: int = choices.slice(0, number).count("released")
		_check("%s: decision '%s' recorded through the real panel" % [step, choice], GameState.has_decision("fragment_level_%d" % number)
			and GameState.souls_released == released_after and GameState.souls_kept == number - released_after)
		if number == 2:
			_check("%s: profile after the second decision is %s" % [step, run["after_second"]], GameState.adaptive_profile == run["after_second"], GameState.adaptive_profile)
		if number < 3:
			var next_path: String = LEVEL_PATHS[number + 1]
			var advanced: bool = await _wait_for(func() -> bool: return _scene_is(next_path))
			_check("%s: transitioned to level %d" % [step, number + 1], advanced)
			if not advanced:
				return
			_assert_state("%s: after the scene change" % step, number + 1, "level_%d_start" % (number + 1), released_after, number - released_after, number)
	# Ending.
	var ending_step: String = "%s / ending" % tag
	var reached: bool = await _wait_for(func() -> bool: return _scene_is(ENDING_PATH))
	_check("%s: ending scene reached" % ending_step, reached)
	if not reached:
		return
	var final_released: int = choices.count("released")
	_assert_state(ending_step, 3, GameState.CHECKPOINT_ENDING, final_released, 3 - final_released, 3)
	_check("%s: game completed and final profile %s" % [ending_step, run["final"]], GameState.is_game_completed() and GameState.adaptive_profile == run["final"]
		and profile_at_level_3 == run["after_second"])
	var snapshot: Dictionary = GameState.to_dict()
	var ending := get_tree().current_scene as EndingController
	_check("%s: shows %s" % [ending_step, run["ending"]], ending != null and ending.shown_variant == run["ending"] and ending.ending_label.text == String(ending.ending_texts[run["ending"]]))
	_check("%s: soul counts shown" % ending_step, ending.released_label.text == ending.souls_released_format % final_released
		and ending.kept_label.text == ending.souls_kept_format % (3 - final_released))
	print("ENDING TEXT: %s | %s | %s | %s" % [ending.ending_label.text, ending.released_label.text, ending.kept_label.text, ending.narrative_label.text])
	# "Continuar": a fresh process would start with an empty GameState and load the save from disk.
	GameState.start_new_game()
	_check("%s: back to the main menu" % ending_step, SceneManager.go_to_main_menu())
	var in_menu: bool = await _wait_for(func() -> bool: return _scene_is(MENU_PATH))
	_check("%s: main menu loaded" % ending_step, in_menu)
	if not in_menu:
		return
	var menu := get_tree().current_scene as MainMenu
	_check("%s: Continuar enabled by the saved game" % ending_step, not menu.continue_button.disabled)
	menu.continue_button.pressed.emit()
	var reopened: bool = await _wait_for(func() -> bool: return _scene_is(ENDING_PATH))
	_check("%s: Continuar reopens the ending" % ending_step, reopened)
	if reopened:
		var again := get_tree().current_scene as EndingController
		_check("%s: same ending after Continuar and the state is intact" % ending_step, again.shown_variant == run["ending"]
			and GameState.to_dict() == snapshot and GameState.is_game_completed())
		_assert_state("%s: after Continuar" % ending_step, 3, GameState.CHECKPOINT_ENDING, final_released, 3 - final_released, 3)


func _count_enemies(level: LevelBase) -> int:
	var count: int = 0
	for child in level.get_node("Content").get_children():
		if child.scene_file_path.ends_with("_enemy.tscn"):
			count += 1
	return count

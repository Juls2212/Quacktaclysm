extends Node
## Headless smoke test for Phase 12a: player input lock, silent checkpoints, level blocks, LevelBase
## (Level 1), restore/continue, arena, completion/advance, tutorial, Level 1 sanity and gap
## measurements. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/level_phase12a_smoke_test.tscn
## Uses a redirected save path and SceneManager.dry_run; the real save is never touched.

const TEST_SAVE: String = "user://test_save_phase12a.json"
const DEFAULT_REGISTRY: SceneRegistry = preload("res://backend/progression/default_scene_registry.tres")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://backend/progression/checkpoint.tscn")
const PLATFORM_SCENE: PackedScene = preload("res://frontend/levels/blocks/placeholder_platform.tscn")
const GATE_SCENE: PackedScene = preload("res://frontend/levels/blocks/arena_gate.tscn")
const LEVEL_1_SCENE: PackedScene = preload("res://frontend/levels/level_1.tscn")
const TUTORIAL_SCENE: PackedScene = preload("res://frontend/levels/tutorial.tscn")
const FLOOR_Y: float = 300.0
const PLAYER_HALF_HEIGHT: float = 26.0
const PLAYER_HALF_WIDTH: float = 14.0
const ENEMY_HALF_SIZE: Vector2 = Vector2(14.0, 24.0)
const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash", "attack"]
const DASH_DELAY: float = 0.3
const EXPECTED_ADVANCE_DELAY: float = 0.3

var failures: int = 0
var started_signals: Array[String] = []
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


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait_idle(max_frames: int = 60) -> void:
	var waited: int = 0
	while SceneManager.is_transitioning() and waited < max_frames:
		await get_tree().process_frame
		waited += 1


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _saved_json() -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_file(TEST_SAVE))
	return parsed if parsed is Dictionary else {}


func _release_actions() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _clean_state() -> void:
	_release_actions()
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.start_new_game()
	GameState.autosave_enabled = true
	SceneManager.last_requested_scene_id = ""
	SceneManager.last_requested_path = ""
	started_signals.clear()


func _test_registry() -> SceneRegistry:
	var registry := SceneRegistry.new()
	registry.scenes = DEFAULT_REGISTRY.scenes.duplicate()
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	return registry


func _add_floor(parent: Node, left: float = -4000.0, right: float = 0.0) -> StaticBody2D:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.collision_mask = 0
	floor_body.position = Vector2((left + right) * 0.5, FLOOR_Y + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(right - left, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	parent.add_child(floor_body)
	return floor_body


func _make_level(scene: PackedScene) -> LevelBase:
	var level := scene.instantiate() as LevelBase
	add_child(level)
	return level


func _run() -> void:
	SceneManager.dry_run = true
	SceneManager.set_registry(_test_registry())
	SceneManager.transition_started.connect(func(id: String) -> void: started_signals.append(id))
	await _test_input_lock()
	await _test_checkpoint_silent()
	await _test_blocks()
	await _test_level_wiring()
	await _test_restore()
	await _test_arena()
	await _test_completion()
	await _test_tutorial()
	await _test_level_sanity()
	await _test_gap_measurement()
	_test_debug_helper()
	_clean_state()
	SceneManager.dry_run = false
	SaveSystem.purge()
	_check("real save file untouched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- Player input lock ---

func _test_input_lock() -> void:
	_clean_state()
	var arena := Node2D.new()
	add_child(arena)
	_add_floor(arena, -4000.0, 4000.0)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	arena.add_child(player)
	await _physics(30)
	_check("lock: starts unlocked", not player.is_input_locked() and player.can_act())
	player.set_input_locked(true)
	_check("lock: can_act false while locked", player.is_input_locked() and not player.can_act())
	var x0: float = player.global_position.x
	Input.action_press("move_right")
	await _physics(20)
	_check("lock: ignores movement", is_equal_approx(player.global_position.x, x0))
	Input.action_release("move_right")
	Input.action_press("jump")
	await _physics(10)
	Input.action_release("jump")
	_check("lock: ignores jump", player.is_on_floor())
	Input.action_press("dash")
	await _physics(3)
	Input.action_release("dash")
	_check("lock: ignores dash", player.state != Player.State.DASH)
	Input.action_press("attack")
	await _physics(3)
	Input.action_release("attack")
	_check("lock: ignores attack", player.state != Player.State.ATTACK)
	player.global_position = Vector2(0.0, FLOOR_Y - 150.0)
	player.velocity = Vector2.ZERO
	await _physics(2)
	var fell: bool = await _wait_until(func() -> bool: return player.is_on_floor(), 120)
	_check("lock: gravity still works and the player lands", fell and player.global_position.y > FLOOR_Y - 100.0,
		"fell=%s y=%.1f state=%s" % [fell, player.global_position.y, Player.State.keys()[player.state]])
	player.set_input_locked(false)
	Input.action_press("move_right")
	await _physics(20)
	Input.action_release("move_right")
	_check("lock: unlocking restores control", player.global_position.x > x0 + 20.0)
	await _physics(30)
	# Death, respawn and hurt while locked.
	player.set_input_locked(true)
	player.health.kill()
	_check("lock: death works while locked", player.is_dead and player.state == Player.State.DEAD)
	player.respawn()
	_check("lock: respawn does not clear the lock", player.is_input_locked() and not player.is_dead)
	player.set_input_locked(false)
	var hurt_player := PLAYER_SCENE.instantiate() as Player
	hurt_player.position = Vector2(500.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	arena.add_child(hurt_player)
	await _physics(20)
	hurt_player.set_input_locked(true)
	hurt_player.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, arena, CombatLayers.Team.ENEMY))
	_check("lock: hurt state works while locked", hurt_player.state == Player.State.HURT)
	await _physics(30)
	_check("lock: still locked after the hurt state", hurt_player.is_input_locked() and not hurt_player.can_act())
	arena.free()


# --- Checkpoint ---

func _test_checkpoint_silent() -> void:
	_clean_state()
	var arena := Node2D.new()
	add_child(arena)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, 0.0)
	arena.add_child(player)
	var checkpoint := CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.checkpoint_id = &"silent_cp"
	checkpoint.position = Vector2(900.0, 0.0)
	arena.add_child(checkpoint)
	var activations: Array[int] = [0]
	checkpoint.activated.connect(func(_id: StringName) -> void: activations[0] += 1)
	var respawn_before: Vector2 = player.get_respawn_point()
	var state_before: Dictionary = GameState.to_dict()
	checkpoint.mark_activated_silently()
	_check("checkpoint: silent mark sets is_activated", checkpoint.is_activated and checkpoint.visual.color == checkpoint.active_color)
	_check("checkpoint: silent mark emits nothing", activations[0] == 0)
	_check("checkpoint: silent mark does not autosave", not SaveSystem.has_save())
	_check("checkpoint: silent mark leaves GameState and the respawn point alone", GameState.to_dict() == state_before
		and player.get_respawn_point() == respawn_before)
	player.global_position = checkpoint.global_position
	await _physics(5)
	_check("checkpoint: a silently activated checkpoint does not re-trigger", activations[0] == 0 and GameState.checkpoint == GameState.DEFAULT_CHECKPOINT
		and player.get_respawn_point() == respawn_before and not SaveSystem.has_save())
	arena.free()


# --- Blocks ---

func _test_blocks() -> void:
	var a := PLATFORM_SCENE.instantiate() as PlaceholderPlatform
	var b := PLATFORM_SCENE.instantiate() as PlaceholderPlatform
	a.size = Vector2(300.0, 40.0)
	b.size = Vector2(100.0, 20.0)
	b.one_way = true
	add_child(a)
	add_child(b)
	await _physics(1)
	var shape_a := a.collision.shape as RectangleShape2D
	var shape_b := b.collision.shape as RectangleShape2D
	_check("platform: shape follows size", shape_a.size == Vector2(300.0, 40.0) and shape_b.size == Vector2(100.0, 20.0))
	_check("platform: instances do not share a shape", shape_a != shape_b)
	a.size = Vector2(500.0, 60.0)
	_check("platform: size setter updates the shape and visual", shape_a.size == Vector2(500.0, 60.0)
		and a.visual.polygon.size() == 4 and a.visual.polygon[2] == Vector2(250.0, 30.0))
	_check("platform: one_way and layer", b.collision.one_way_collision and not a.collision.one_way_collision
		and a.collision_layer == CombatLayers.layer_bit(CombatLayers.LAYER_WORLD))
	a.free()
	b.free()
	var gate := GATE_SCENE.instantiate() as ArenaGate
	add_child(gate)
	var changes: Array[int] = [0]
	gate.state_changed.connect(func(_closed: bool) -> void: changes[0] += 1)
	await _physics(2)
	_check("gate: starts open", not gate.is_closed and gate.collision.disabled and not gate.visual.visible)
	gate.close()
	gate.close()
	await _physics(2)
	_check("gate: close enables collision and shows the visual (idempotent)", gate.is_closed and not gate.collision.disabled
		and gate.visual.visible and changes[0] == 1)
	gate.open()
	gate.open()
	await _physics(2)
	_check("gate: open disables collision (idempotent)", not gate.is_closed and gate.collision.disabled and not gate.visual.visible
		and changes[0] == 2)
	gate.free()


# --- LevelBase on Level 1 ---

func _test_level_wiring() -> void:
	_clean_state()
	SceneManager.go_to("main_menu")
	_check("wiring: a transition is running", SceneManager.is_transitioning())
	var level := _make_level(LEVEL_1_SCENE)
	_check("wiring: player locked while transitioning", level.player.is_input_locked())
	await _wait_idle()
	await _physics(2)
	_check("wiring: player unlocked after transition_finished", not level.player.is_input_locked())
	_check("wiring: HUD bound to the player", level.hud.filled_pips() == level.player.health.max_health)
	_check("wiring: boss bar bound to the boss", level.boss_bar.displayed_name == level.boss.stats.display_name)
	_check("wiring: decision flow bound to the drop", level.decision_flow.drop == level.fragment_drop
		and level.fragment_drop.boss == level.boss and level.decision_flow.panel != null and level.decision_flow.refiner == level.refiner)
	_check("wiring: exports set", level.level_number == 1 and level.next_scene_id == "level_2" and level.boss != null
		and level.encounter != null and level.arena_gates.size() == 1)
	_check("wiring: camera limits applied", level.player.camera.limit_left == 0 and level.player.camera.limit_top == 0
		and level.player.camera.limit_right == level.camera_limits.end.x and level.player.camera.limit_bottom == level.camera_limits.end.y)
	_check("wiring: fresh arrival writes GameState", GameState.current_level == 1 and GameState.checkpoint == "level_1_start")
	var saved: Dictionary = _saved_json()
	_check("wiring: fresh arrival autosaves", int(saved.get("current_level", 0)) == 1 and saved.get("checkpoint", "") == "level_1_start")
	_check("wiring: player respawn point is the spawn point", level.player.get_respawn_point().is_equal_approx(level.spawn_point.global_position))
	_check("wiring: game over enabled in levels", level.game_over_controller.show_game_over and not level.player.is_auto_respawn_enabled())
	var lock_failures := SceneManager.go_to("main_menu")
	_check("wiring: transition_started locks the player", lock_failures and level.player.is_input_locked())
	await _wait_idle()
	await _physics(2)
	_check("wiring: safety unlock after the transition", not level.player.is_input_locked())
	level.free()
	_check("wiring: signals disconnected on exit", SceneManager.transition_started.get_connections().size() <= 1)


# --- Continue / restore ---

func _spawn_position_of(level: LevelBase) -> Vector2:
	return level.spawn_point.global_position


func _test_restore() -> void:
	_clean_state()
	GameState.set_current_level(1)
	GameState.set_checkpoint("level_1_arena")
	var level := _make_level(LEVEL_1_SCENE)
	var arena_cp: Checkpoint = Checkpoint.find_checkpoint(get_tree(), "level_1_arena")
	var start_cp: Checkpoint = Checkpoint.find_checkpoint(get_tree(), "level_1_start")
	_check("restore: player placed at the saved checkpoint", level.player.global_position.is_equal_approx(arena_cp.get_respawn_position()))
	_check("restore: respawn point set there", level.player.get_respawn_point().is_equal_approx(arena_cp.get_respawn_position()))
	_check("restore: checkpoints up to it are marked activated", arena_cp.is_activated and start_cp.is_activated)
	_check("restore: no autosave and GameState unchanged", not SaveSystem.has_save() and GameState.checkpoint == "level_1_arena")
	level.free()

	_clean_state()
	GameState.set_current_level(1)
	GameState.set_checkpoint("level_1_start")
	level = _make_level(LEVEL_1_SCENE)
	start_cp = Checkpoint.find_checkpoint(get_tree(), "level_1_start")
	_check("restore: start checkpoint restores to its position", level.player.global_position.is_equal_approx(start_cp.get_respawn_position()))
	level.free()

	_clean_state()
	GameState.set_current_level(1)
	GameState.set_checkpoint(GameState.DEFAULT_CHECKPOINT)
	level = _make_level(LEVEL_1_SCENE)
	_check("restore: unknown/default checkpoint uses the spawn point", level.player.global_position.is_equal_approx(_spawn_position_of(level)))
	_check("restore: unknown checkpoint becomes a fresh arrival", GameState.checkpoint == "level_1_start" and SaveSystem.has_save())
	level.free()

	_clean_state()
	GameState.set_current_level(2)
	GameState.set_checkpoint("level_1_arena")
	level = _make_level(LEVEL_1_SCENE)
	_check("restore: current_level 2 does not restore inside level 1", level.player.global_position.is_equal_approx(_spawn_position_of(level)))
	level.free()
	_clean_state()


# --- Arena ---

func _encounter_rect(encounter: BossEncounter) -> Rect2:
	var shape := encounter.get_node("CollisionShape2D") as CollisionShape2D
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	return Rect2(encounter.global_position + shape.position - size * 0.5, size)


func _test_arena() -> void:
	_clean_state()
	var level := _make_level(LEVEL_1_SCENE)
	await _wait_idle()
	var player: Player = level.player
	var gate: ArenaGate = level.arena_gates[0]
	var arena_cp: Checkpoint = Checkpoint.find_checkpoint(get_tree(), "level_1_arena")
	_check("arena: gate starts open", not gate.is_closed)
	player.global_position = arena_cp.global_position
	await _physics(8)
	_check("arena: touching the arena checkpoint sets the respawn point", player.get_respawn_point().is_equal_approx(arena_cp.get_respawn_position()))
	_check("arena: respawn point is outside the encounter trigger", not _encounter_rect(level.encounter).has_point(player.get_respawn_point())
		and not _encounter_rect(level.encounter).has_point(arena_cp.global_position))
	player.global_position = level.encounter.global_position + Vector2(10.0, 0.0)
	var started: bool = await _wait_until(func() -> bool: return level.boss.state != BossBase.State.INACTIVE, 120)
	_check("arena: encounter started", started)
	_check("arena: gate closes when the encounter starts", gate.is_closed)
	player.health.kill()
	_check("arena: boss resets when the player dies", level.boss.state == BossBase.State.INACTIVE)
	_check("arena: gate reopens on reset", not gate.is_closed)
	await _wait_until(func() -> bool: return level.game_over_controller.panel.is_open(), 120)
	level.game_over_controller.panel.retry_button.pressed.emit()
	await _physics(5)
	_check("arena: retry respawns at the arena checkpoint, boss stays inactive", absf(player.global_position.x - arena_cp.get_respawn_position().x) < 1.0
		and absf(player.global_position.y - arena_cp.get_respawn_position().y) < 8.0
		and level.boss.state == BossBase.State.INACTIVE and not get_tree().paused,
		"pos=%s want=%s boss=%s paused=%s dead=%s" % [player.global_position, arena_cp.get_respawn_position(), level.boss.state, get_tree().paused, player.is_dead])
	player.global_position = level.encounter.global_position + Vector2(10.0, 0.0)
	await _wait_until(func() -> bool: return level.boss.state != BossBase.State.INACTIVE, 120)
	_check("arena: gate closes again", gate.is_closed)
	level.boss.hurtbox.receive_hit(DamageInfo.create(999, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	_check("arena: boss defeat opens the gate", level.boss.state == BossBase.State.DEAD and not gate.is_closed)
	level.free()
	for fragment in get_children():
		if fragment is SoulFragment:
			fragment.free()
	_clean_state()


# --- Completion / advance ---

func _find_fragment() -> SoulFragment:
	for child in get_children():
		if child is SoulFragment:
			return child as SoulFragment
	return null


func _free_fragments() -> void:
	for child in get_children():
		if child is SoulFragment:
			child.free()


func _kill_boss(level: LevelBase) -> void:
	level.boss.hurtbox.receive_hit(DamageInfo.create(999, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))


func _test_completion() -> void:
	_clean_state()
	var level := _make_level(LEVEL_1_SCENE)
	await _wait_idle()
	level.advance_delay = EXPECTED_ADVANCE_DELAY
	level.refine_wait_timeout = 0.6
	var completed: Array[int] = []
	level.level_completed.connect(func(number: int) -> void: completed.append(number))
	_kill_boss(level)
	var spawned: bool = await _wait_until(func() -> bool: return _find_fragment() != null, 120)
	_check("complete: killing the boss spawns the fragment", spawned)
	var fragment: SoulFragment = _find_fragment()
	level.player.global_position = fragment.global_position
	var opened: bool = await _wait_until(func() -> bool: return level.get_node("DecisionPanel").is_open(), 60)
	_check("complete: collecting opens the decision panel", opened and get_tree().paused)
	_check("complete: no advance before the decision", completed.is_empty() and SceneManager.last_requested_scene_id == "")
	# Stall the refiner: the advance must wait for the timeout, not just advance_delay.
	level.get_node("DecisionPanel").release_button.pressed.emit()
	level.refiner.in_flight = true
	_check("complete: decision recorded", GameState.has_decision("fragment_level_1"))
	await _wait_until(func() -> bool: return get_tree().paused == false, 10)
	var started_at: int = Time.get_ticks_msec()
	await _physics(int((EXPECTED_ADVANCE_DELAY + 0.15) * Engine.physics_ticks_per_second))
	_check("complete: waits for a busy refiner past advance_delay", completed.is_empty() and SceneManager.last_requested_scene_id == "")
	await _wait_until(func() -> bool: return not completed.is_empty(), 180)
	var elapsed: float = float(Time.get_ticks_msec() - started_at) / 1000.0
	_check("complete: advances after refine_wait_timeout", completed == [1] and elapsed >= level.refine_wait_timeout - 0.2, "elapsed %.2f" % elapsed)
	_check("complete: requests the next scene", SceneManager.last_requested_scene_id == "level_2" and started_signals == ["level_2"])
	_check("complete: GameState advanced", GameState.current_level == 2 and GameState.checkpoint == "level_2_start")
	var saved: Dictionary = _saved_json()
	_check("complete: save file holds the next level", int(saved.get("current_level", 0)) == 2 and saved.get("checkpoint", "") == "level_2_start")
	await _physics(90)
	_check("complete: advances exactly once", completed.size() == 1 and started_signals.size() == 1)
	level.free()
	_free_fragments()
	await _wait_idle()

	# Idle refiner: advances after advance_delay only.
	_clean_state()
	level = _make_level(LEVEL_1_SCENE)
	await _wait_idle()
	level.advance_delay = EXPECTED_ADVANCE_DELAY
	level.refine_wait_timeout = 5.0
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	var done: Array[int] = []
	level.level_completed.connect(func(number: int) -> void: done.append(number))
	_kill_boss(level)
	await _physics(75)
	_check("complete: decided level spawns no fragment", _find_fragment() == null)
	await _wait_until(func() -> bool: return not done.is_empty(), 120)
	_check("complete: decided level advances directly", done == [1] and SceneManager.last_requested_scene_id == "level_2")
	level.free()
	await _wait_idle()

	# A rejected go_to keeps the player in control.
	_clean_state()
	var broken := _test_registry()
	broken.scenes.erase("level_2")
	SceneManager.set_registry(broken)
	level = _make_level(LEVEL_1_SCENE)
	await _wait_idle()
	level.advance_delay = 0.1
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
	_kill_boss(level)
	await _wait_until(func() -> bool: return level.is_completed, 120)
	await _physics(5)
	_check("complete: rejected go_to keeps the player in control", level.is_completed and not level.player.is_input_locked()
		and not SceneManager.is_transitioning() and SceneManager.last_requested_scene_id == "" and GameState.current_level == 1)
	level.free()
	SceneManager.set_registry(_test_registry())
	_free_fragments()
	_clean_state()


# --- Tutorial ---

func _test_tutorial() -> void:
	_clean_state()
	GameState.set_current_level(2)
	GameState.set_checkpoint("custom_checkpoint")
	var state_before: Dictionary = GameState.to_dict()
	var tutorial := _make_level(TUTORIAL_SCENE)
	await _wait_idle()
	var controller: TutorialController = tutorial.get_node("TutorialController")
	var player: Player = tutorial.player
	_check("tutorial: loading never changes GameState or saves", GameState.to_dict() == state_before and not SaveSystem.has_save())
	_check("tutorial: autosave suspended while it is alive", not GameState.autosave_enabled)
	_check("tutorial: no game over, auto respawn on", not tutorial.game_over_controller.show_game_over and player.is_auto_respawn_enabled())
	_check("tutorial: eight ordered steps (wave added in Phase 12c, heavy and dash slash in 13c)", controller.steps.size() == 8 and controller.get_current_step_id() == "move")
	_check("tutorial: key hints resolved from the input map", controller.build_text("{jump}") != "{jump}" and not controller.prompt_label.text.contains("{"),
		controller.prompt_label.text)
	player.dash_started.emit()
	player.attack_started.emit()
	player.wave_cast.emit(0)
	_check("tutorial: early actions do not count", controller.current_index == 0)
	Input.action_press("move_right")
	await _wait_until(func() -> bool: return controller.current_index >= 1, 120)
	Input.action_release("move_right")
	_check("tutorial: moving completes the move step", controller.current_index == 1 and controller.get_current_step_id() == "jump")
	player.dash_started.emit()
	_check("tutorial: a dash before its step does not count", controller.current_index == 1)
	player.state_changed.emit(Player.State.IDLE, Player.State.JUMP)
	_check("tutorial: jump completes", controller.get_current_step_id() == "dash")
	player.dash_started.emit()
	_check("tutorial: dash completes", controller.get_current_step_id() == "attack")
	player.attack_started.emit()
	_check("tutorial: attack completes", controller.get_current_step_id() == "hit_dummy")
	_check("tutorial: exit does nothing before completion", not controller.is_completed)
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: early exit does not request a scene", SceneManager.last_requested_scene_id == "" and GameState.to_dict() == state_before
		and controller.prompt_label.text == controller.exit_hint_text)
	var dummy: TrainingDummy = controller.dummy
	dummy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	_check("tutorial: hitting the dummy leaves the wave step", not controller.is_completed and controller.get_current_step_id() == "wave")
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: exit still blocked before the wave step", SceneManager.last_requested_scene_id == "" and not controller.is_completed)
	player.wave_cast.emit(0)
	_check("tutorial: the wave cast leaves the heavy step", not controller.is_completed and controller.get_current_step_id() == "heavy")
	player.heavy_attack_started.emit()
	player.dash_slash_started.emit()
	_check("tutorial: heavy and dash slash complete the tutorial", controller.is_completed and controller.current_index == 8)
	_check("tutorial: final line shown", controller.prompt_label.text == controller.final_text)
	controller.exit_area.body_entered.emit(player)
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: exit requests level_1 once", SceneManager.last_requested_scene_id == "level_1" and started_signals == ["level_1"])
	_check("tutorial: exit sets GameState and saves", GameState.current_level == 1 and GameState.checkpoint == "level_1_start"
		and int(_saved_json().get("current_level", 0)) == 1 and _saved_json().get("checkpoint", "") == "level_1_start")
	await _wait_idle()
	# Death in the tutorial: automatic respawn, no Game Over panel.
	player.health.kill()
	await _physics(30)
	_check("tutorial: death shows no game over panel and does not pause", not tutorial.get_node("GameOverPanel").is_open() and not get_tree().paused)
	await _physics(int((player.stats.respawn_delay + 0.4) * Engine.physics_ticks_per_second))
	_check("tutorial: the player respawns automatically", not player.is_dead)
	tutorial.free()
	_check("tutorial: autosave restored when it is freed", GameState.autosave_enabled)
	_clean_state()


# --- Level 1 sanity ---

func _rect_of(node: Node2D, size: Vector2) -> Rect2:
	return Rect2(node.global_position - size * 0.5, size)


func _test_level_sanity() -> void:
	_clean_state()
	var level := _make_level(LEVEL_1_SCENE)
	await _wait_idle()
	var counts: Dictionary = {"melee": 0, "fast": 0, "ranged": 0}
	var solids: Array[Rect2] = []
	var enemies: Array[EnemyBase] = []
	for node in level.get_node("Content").get_children():
		if node is MeleeEnemy:
			counts["melee"] += 1
			enemies.append(node)
		elif node is FastEnemy:
			counts["fast"] += 1
			enemies.append(node)
		elif node is RangedEnemy:
			counts["ranged"] += 1
			enemies.append(node)
		elif node is PlaceholderPlatform:
			solids.append(_rect_of(node, (node as PlaceholderPlatform).size))
		elif node is ArenaGate:
			solids.append(_rect_of(node, (node as ArenaGate).size))
	_check("level 1: enemy counts match the design (3 melee, 2 fast, 1 ranged)", counts == {"melee": 3, "fast": 2, "ranged": 1}, str(counts))
	var inside: int = 0
	for enemy in enemies:
		var rect := Rect2(enemy.global_position - ENEMY_HALF_SIZE, ENEMY_HALF_SIZE * 2.0).grow(-1.0)
		for solid in solids:
			if rect.intersects(solid):
				inside += 1
	_check("level 1: no enemy spawns inside a platform", inside == 0)
	var boss_rect := Rect2(level.boss.global_position - Vector2(28.0, 44.0), Vector2(56.0, 88.0)).grow(-1.0)
	var boss_inside: bool = false
	for solid in solids:
		boss_inside = boss_inside or boss_rect.intersects(solid)
	_check("level 1: the boss does not spawn inside a platform", not boss_inside)
	var arena_cp: Checkpoint = Checkpoint.find_checkpoint(get_tree(), "level_1_arena")
	var start_cp: Checkpoint = Checkpoint.find_checkpoint(get_tree(), "level_1_start")
	_check("level 1: checkpoint orders and ids", start_cp.order == 0 and arena_cp.order == 1)
	_check("level 1: arena checkpoint is before the gate and outside the trigger", arena_cp.global_position.x < level.arena_gates[0].global_position.x
		and not _encounter_rect(level.encounter).has_point(arena_cp.global_position))
	_check("level 1: the encounter trigger is inside the arena, past the gate", level.encounter.global_position.x > level.arena_gates[0].global_position.x
		and level.boss.global_position.x > level.encounter.global_position.x)
	level.free()
	# Load both levels for 300 frames: the scene must run without errors (checked in the log).
	_clean_state()
	var l1 := _make_level(LEVEL_1_SCENE)
	await _physics(300)
	_check("level 1: runs 300 frames", is_instance_valid(l1) and not l1.player.is_dead)
	l1.free()
	_clean_state()
	var tut := _make_level(TUTORIAL_SCENE)
	await _physics(300)
	_check("tutorial: runs 300 frames", is_instance_valid(tut) and not tut.player.is_dead)
	tut.free()
	_clean_state()


# --- Gap measurement (real Player simulation) ---

func _gap_of_level_1() -> float:
	var level := LEVEL_1_SCENE.instantiate() as LevelBase
	var content: Node = level.get_node("Content")
	var start_floor: PlaceholderPlatform = content.get_node("FloorStart")
	var end_floor: PlaceholderPlatform = content.get_node("FloorEnd")
	var gap: float = (end_floor.position.x - end_floor.size.x * 0.5) - (start_floor.position.x + start_floor.size.x * 0.5)
	level.free()
	return gap


## Runs at full speed off a floor that ends at x = 0 and jumps at the edge. Returns the horizontal
## distance travelled until the player is back at the take-off height (no far platform).
func _measure_distance(player: Player, use_dash: bool) -> float:
	_release_actions()
	player.global_position = Vector2(-300.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	player.velocity = Vector2.ZERO
	await _physics(30)
	Input.action_press("move_right")
	while player.global_position.x < -4.0:
		await get_tree().physics_frame
	var start_x: float = player.global_position.x
	Input.action_press("jump")
	var elapsed: float = 0.0
	var dashed: bool = false
	while elapsed < 3.0:
		await get_tree().physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
		if use_dash and not dashed and elapsed >= DASH_DELAY:
			Input.action_press("dash")
			dashed = true
		elif dashed:
			Input.action_release("dash")
		if elapsed > 0.1 and player.global_position.y >= FLOOR_Y - PLAYER_HALF_HEIGHT and player.velocity.y >= 0.0:
			break
	var travelled: float = player.global_position.x - start_x
	_release_actions()
	return travelled


func _test_gap_measurement() -> void:
	_clean_state()
	var gap: float = _gap_of_level_1()
	var arena := Node2D.new()
	add_child(arena)
	_add_floor(arena, -4000.0, 0.0)
	var player := PLAYER_SCENE.instantiate() as Player
	arena.add_child(player)
	await _physics(2)
	var jump_distance: float = await _measure_distance(player, false)
	var dash_distance: float = await _measure_distance(player, true)
	var coyote_reach: float = player.stats.coyote_time * player.stats.max_speed
	var jump_limit: float = jump_distance + PLAYER_HALF_WIDTH * 2.0 + coyote_reach
	print("gap %.0f px | jump alone %.0f px (generous limit %.0f) | jump+dash %.0f px" % [gap, jump_distance, jump_limit, dash_distance])
	_check("gap: wider than a jump alone, even edge-hugging with coyote time", gap > jump_limit, "%.0f > %.0f" % [gap, jump_limit])
	_check("gap: narrower than jump + dash", gap < dash_distance, "%.0f < %.0f" % [gap, dash_distance])
	arena.free()
	# Real crossing: floors separated by the level's gap.
	for use_dash in [false, true]:
		var world := Node2D.new()
		add_child(world)
		_add_floor(world, -4000.0, 0.0)
		_add_floor(world, gap, gap + 2000.0)
		var runner := PLAYER_SCENE.instantiate() as Player
		world.add_child(runner)
		await _physics(2)
		await _measure_distance(runner, use_dash)
		await _physics(60)
		var crossed: bool = runner.global_position.x > gap and runner.global_position.y < FLOOR_Y
		_check("gap: %s" % ("jump + dash crosses" if use_dash else "jump alone falls short"), crossed == use_dash,
			"x %.0f y %.0f" % [runner.global_position.x, runner.global_position.y])
		_release_actions()
		world.free()


# --- Debug helper ---

func _test_debug_helper() -> void:
	_check("debug: removed on non-debug builds", LevelDebug.should_remove(false))
	_check("debug: kept on debug builds", not LevelDebug.should_remove(true))
	var level := _make_level(LEVEL_1_SCENE)
	var debug_node: Node = level.get_node_or_null("LevelDebug")
	_check("debug: the node follows OS.is_debug_build()", (debug_node != null) == OS.is_debug_build())
	level.free()

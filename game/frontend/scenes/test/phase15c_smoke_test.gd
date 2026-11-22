extends Node
## Headless smoke test for Phase 15c: the lily pads, the platforms of arena 2, the floor spikes, the guardian's
## leap, the double jump and its card. It also MEASURES the reach with the real player (jump, double jump, dash) and
## the worst time to reach a refuge from the spikes; the lines starting with "MEASURE|" are copied into
## docs/BALANCE_REPORT.md. Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase15c_smoke_test.tscn
## Uses a redirected save path; the real save and the real controls are never touched.

const TEST_SAVE: String = "user://test_save_phase15c.json"
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const PAD_SCENE: PackedScene = preload("res://backend/arena/bounce_pad.tscn")
const HAZARD_SCENE: PackedScene = preload("res://backend/arena/floor_hazard.tscn")
const KILL_ZONE_SCENE: PackedScene = preload("res://backend/combat/kill_zone.tscn")
const EXORCISM_SCENE: PackedScene = preload("res://frontend/fx/exorcism_cutscene.tscn")
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const FLOOR_Y: float = 300.0
const MIN_CONTRAST: float = 2.5

var failures: int = 0
## Filled by the reach measurement: how far one jump carries the player (px) and how long it stays in the air (s).
var jump_reach: float = 200.0
var jump_airtime: float = 0.7
var real_save_before: String = ""
var real_controls_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
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


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _clean_state() -> void:
	Engine.time_scale = 1.0
	PauseLock.reset(get_tree())
	get_tree().paused = false
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = false
	AbilityCard.forget_all()
	BossDialogue.forget_all()
	for action in [&"dash", &"move_right", &"move_left", &"jump", &"attack", &"heal"]:
		Input.action_release(action)


func _unlock_double_jump(unlocked: bool) -> void:
	GameState.decisions.clear()
	if unlocked:
		GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
		GameState.record_decision("fragment_level_2", "boss_two", 2, GameState.CHOICE_RELEASED)


func _run() -> void:
	_clean_state()
	_test_guards()
	await _test_pads()
	await _test_double_jump()
	await _test_reach_measurement()
	await _test_level_two_geometry()
	await _test_hazard()
	await _test_hazard_stops()
	await _test_refuge_time()
	await _test_leap()
	_test_old_patterns()
	await _test_cards()
	await _test_texture_override()
	_test_contrast()
	await _test_leaks()
	_clean_state()
	SaveSystem.purge()
	GameState.autosave_enabled = true
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	_check("the real controls file was not touched", _read_file(ControlsConfig.DEFAULT_PATH) == real_controls_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

func _arena(width: float = 6000.0, center_x: float = 0.0) -> Node2D:
	var world := Node2D.new()
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(center_x, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(width, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	return world


func _player_at(world: Node2D, x: float = 0.0, settle: bool = true) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(x, FLOOR_Y - 26.0)
	world.add_child(player)
	if settle:
		await _physics(25)
	return player


func _enemy_hit(player: Player, amount: int = 1) -> bool:
	return player.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.ENEMY))


func _level(number: int) -> LevelBase:
	return (load("res://frontend/levels/level_%d.tscn" % number) as PackedScene).instantiate() as LevelBase


## A level 2 fight: the boss awake, the player in the arena (nothing hurts the player unless `vulnerable`).
func _boss_fight(vulnerable: bool = false) -> LevelBase:
	var level: LevelBase = _level(2)
	add_child(level)
	await _frames(8)
	level.player.story_invulnerable = not vulnerable
	level.player.global_position = level.encounter.global_position
	await _physics(10)
	return level


func _damage_boss_to_phase_two(level: LevelBase) -> void:
	var boss: BossBase = level.boss
	boss.health.apply_damage(DamageInfo.create(int(float(boss.health.max_health) * 0.5), Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))


func _contrast_of(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


# ---------------------------------------------------------------------------------------------
# Guards and numbers
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
	var bounce := BounceConfig.get_default()
	var hazard := FloorHazardConfig.get_default()
	var stats := PlayerStats.new()
	_check("numbers: pad launch -1030 px/s, cooldown 0.35 s", is_equal_approx(bounce.launch_velocity, -1030.0) and is_equal_approx(bounce.cooldown, 0.35))
	_check("numbers: spikes warning 1.2 s, active 3.0 s, rest 4.0 s, 1 heart", is_equal_approx(hazard.warning_time, 1.2) and is_equal_approx(hazard.active_time, 3.0)
		and is_equal_approx(hazard.rest_time, 4.0) and hazard.damage == 1)
	_check("numbers: the extra jump is 85% of the first (-527 vs -620), one per airtime, unlocked with 2 decisions",
		is_equal_approx(absf(stats.double_jump_velocity) / absf(stats.jump_velocity), 0.85) and stats.max_air_jumps == 1 and stats.double_jump_unlock_decisions == 2,
		"%.3f" % (absf(stats.double_jump_velocity) / absf(stats.jump_velocity)))
	_check("numbers: the first jump, gravity and dash did not change", is_equal_approx(stats.jump_velocity, -620.0) and is_equal_approx(stats.gravity, 1800.0)
		and is_equal_approx(stats.dash_speed, 700.0) and is_equal_approx(stats.dash_duration, 0.18))
	var rise: float = bounce.launch_velocity * bounce.launch_velocity / (2.0 * stats.gravity)
	_check("numbers: the pad rise is about 300 px (%.0f px) and clears the high tier (250 px)" % rise, rise >= 280.0 and rise <= 320.0)


# ---------------------------------------------------------------------------------------------
# 1. Lily pads
# ---------------------------------------------------------------------------------------------

func _test_pads() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var pad := PAD_SCENE.instantiate() as BouncePad
	pad.position = Vector2(0.0, FLOOR_Y - 22.0)
	world.add_child(pad)
	var launches: Array[int] = [0]
	pad.launched.connect(func(_player: Player) -> void: launches[0] += 1)
	# A player that falls onto the pad is launched with the configured velocity.
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - 200.0)
	world.add_child(player)
	var top: float = 0.0
	var start_y: float = FLOOR_Y - 26.0
	var guard: int = 0
	while launches[0] == 0 and guard < 120:
		guard += 1
		await get_tree().physics_frame
	var launch_speed: float = player.velocity.y
	_check("pad: a player that comes down onto it is launched", launches[0] == 1 and launch_speed <= -900.0, "vy %.0f" % launch_speed)
	var peak_y: float = player.global_position.y
	for i in 90:
		await get_tree().physics_frame
		peak_y = minf(peak_y, player.global_position.y)
	var rise: float = start_y - peak_y
	_check("pad: it rises about 300 px (%.0f px)" % rise, rise >= 260.0 and rise <= 340.0)
	top = rise
	print("MEASURE|pad rise|%.0f px" % top)
	# The jump cut (releasing jump while rising) does not cancel the launch.
	await _physics(120)
	launches[0] = 0
	player.global_position = Vector2(0.0, FLOOR_Y - 150.0)
	player.velocity = Vector2.ZERO
	pad.cooldown_left = 0.0
	Input.action_press(&"jump")
	await _physics(2)
	Input.action_release(&"jump")
	var release_guard: int = 0
	while launches[0] == 0 and release_guard < 120:
		release_guard += 1
		await get_tree().physics_frame
	Input.action_press(&"jump")
	await get_tree().physics_frame
	Input.action_release(&"jump")
	await get_tree().physics_frame
	_check("pad: releasing the jump key right after the launch does not cut it", launches[0] == 1 and player.velocity.y < -700.0, "vy %.0f" % player.velocity.y)
	await _physics(120)
	# Cooldown: a second contact right away does nothing, after the cooldown it launches again.
	launches[0] = 0
	pad.cooldown_left = 0.0
	player.global_position = Vector2(0.0, FLOOR_Y - 40.0)
	player.velocity = Vector2(0.0, 200.0)
	await _physics(4)
	var first_cooldown: float = pad.cooldown_left
	_check("pad: a launch starts the cooldown (%.2f s left a few frames later)" % first_cooldown, launches[0] == 1 and first_cooldown > 0.2)
	player.global_position = Vector2(0.0, FLOOR_Y - 40.0)
	player.velocity = Vector2(0.0, 200.0)
	await _physics(3)
	_check("pad: it does not launch again during the cooldown", launches[0] == 1)
	await get_tree().create_timer(0.5).timeout
	player.global_position = Vector2(0.0, FLOOR_Y - 40.0)
	player.velocity = Vector2(0.0, 200.0)
	await _physics(5)
	_check("pad: after the cooldown it launches again", launches[0] == 2)
	await _physics(100)
	# Walking onto it does nothing: it has to be landed on from above.
	await _physics(150)
	launches[0] = 0
	pad.cooldown_left = 0.0
	player.global_position = Vector2(-200.0, FLOOR_Y - 26.0)
	player.velocity = Vector2.ZERO
	await _physics(10)
	Input.action_press(&"move_right")
	await _physics(75)
	Input.action_release(&"move_right")
	_check("pad: walking onto it along the floor does not launch (it must be landed on from above)", launches[0] == 0 and player.is_on_floor())
	# Rising through it (from below) does not trigger it.
	launches[0] = 0
	pad.cooldown_left = 0.0
	player.global_position = Vector2(0.0, FLOOR_Y + 5.0)
	player.velocity = Vector2(0.0, -300.0)
	await _physics(2)
	_check("pad: a player rising through it is not launched", launches[0] == 0)
	await _physics(60)
	# Dead players and players in a dash are not launched.
	player.global_position = Vector2(0.0, FLOOR_Y - 150.0)
	player.velocity = Vector2.ZERO
	await _physics(80)
	world.free()
	await _frames(2)
	# Enemies and the boss ignore it.
	var enemy_world: Node2D = _arena()
	var enemy_pad := PAD_SCENE.instantiate() as BouncePad
	enemy_pad.position = Vector2(0.0, FLOOR_Y - 22.0)
	enemy_world.add_child(enemy_pad)
	var enemy_launches: Array[int] = [0]
	enemy_pad.launched.connect(func(_player: Player) -> void: enemy_launches[0] += 1)
	var enemy := (load("res://backend/enemies/melee_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	enemy.position = Vector2(0.0, FLOOR_Y - 150.0)
	enemy_world.add_child(enemy)
	var boss := (load("res://backend/bosses/boss_two.tscn") as PackedScene).instantiate() as BossBase
	boss.position = Vector2(0.0, FLOOR_Y - 300.0)
	enemy_world.add_child(boss)
	await _physics(120)
	_check("pad: enemies and the boss ignore it (no launch, they fell through its area)", enemy_launches[0] == 0 and enemy.global_position.y > FLOOR_Y - 60.0 and boss.global_position.y > FLOOR_Y - 60.0)
	enemy_world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 5. Double jump
# ---------------------------------------------------------------------------------------------

func _press(action: StringName, frames: int = 2) -> void:
	Input.action_press(action)
	await _physics(frames)
	Input.action_release(action)


func _test_double_jump() -> void:
	# Locked with 0 or 1 decisions.
	for count in [0, 1]:
		_clean_state()
		GameState.decisions.clear()
		if count == 1:
			GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
		var world: Node2D = _arena()
		var player: Player = await _player_at(world)
		_check("double jump: locked with %d decision(s)" % count, not player.has_double_jump())
		await _press(&"jump", 2)
		await _physics(14)
		var jumps: Array[int] = [0]
		player.double_jumped.connect(func() -> void: jumps[0] += 1)
		var vy_before: float = player.velocity.y
		await _press(&"jump", 2)
		await _physics(2)
		_check("double jump: the second press in the air does nothing while it is locked (%d)" % count, jumps[0] == 0 and player.velocity.y >= vy_before)
		world.free()
		await _frames(2)
	# Unlocked with 2 or more decisions.
	_clean_state()
	_unlock_double_jump(true)
	var world_two: Node2D = _arena()
	var p: Player = await _player_at(world_two)
	_check("double jump: unlocked with 2 decisions", p.has_double_jump())
	var jumps_two: Array[int] = [0]
	var at_signal: Array[float] = [0.0]
	p.double_jumped.connect(func() -> void:
		jumps_two[0] += 1
		at_signal[0] = p.velocity.y)
	await _press(&"jump", 2)
	await _physics(16)
	var vy_first: float = p.velocity.y
	await _press(&"jump", 2)
	await _physics(2)
	_check("double jump: one extra jump in the air with the existing jump action", jumps_two[0] == 1 and p.velocity.y < vy_first and p.air_jumps_left == 0, "vy %.0f -> %.0f" % [vy_first, p.velocity.y])
	_check("double jump: its velocity is about 85%% of the first jump (%.0f)" % at_signal[0], is_equal_approx(at_signal[0], -527.0))
	await _physics(4)
	await _press(&"jump", 2)
	await _physics(2)
	_check("double jump: only once per airtime (a third press does nothing)", jumps_two[0] == 1)
	for i in 160:
		await get_tree().physics_frame
		if p.is_on_floor():
			break
	await _physics(2)
	_check("double jump: it is available again after landing", p.air_jumps_left == 1 and p.is_on_floor())
	# A dash does not spend it.
	await _press(&"jump", 2)
	await _physics(10)
	await _press(&"dash", 2)
	await _physics(18)
	var dashed_left: int = p.air_jumps_left
	jumps_two[0] = 0
	await _press(&"jump", 2)
	await _physics(2)
	_check("double jump: a dash in the air does not consume it", dashed_left == 1 and jumps_two[0] == 1)
	for i in 200:
		await get_tree().physics_frame
		if p.is_on_floor():
			break
	await _physics(30)
	# Coyote time: a jump pressed just after leaving a ledge is the FIRST jump and keeps the extra one.
	p.global_position = Vector2(0.0, FLOOR_Y - 26.0)
	world_two.free()
	await _frames(2)
	var ledge_world := Node2D.new()
	add_child(ledge_world)
	var ledge := StaticBody2D.new()
	ledge.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	ledge.position = Vector2(-300.0, FLOOR_Y + 20.0)
	var ledge_shape := CollisionShape2D.new()
	var ledge_rect := RectangleShape2D.new()
	ledge_rect.size = Vector2(600.0, 40.0)
	ledge_shape.shape = ledge_rect
	ledge.add_child(ledge_shape)
	ledge_world.add_child(ledge)
	var runner := PLAYER_SCENE.instantiate() as Player
	runner.position = Vector2(-80.0, FLOOR_Y - 26.0)
	ledge_world.add_child(runner)
	await _physics(25)
	Input.action_press(&"move_right")
	var left_ground: int = 0
	for i in 120:
		await get_tree().physics_frame
		if not runner.is_on_floor():
			left_ground = i
			break
	await _physics(3)
	var airborne_jumps: Array[int] = [0]
	runner.double_jumped.connect(func() -> void: airborne_jumps[0] += 1)
	var strongest: float = 0.0
	Input.action_press(&"jump")
	for i in 4:
		await get_tree().physics_frame
		strongest = minf(strongest, runner.velocity.y)
	Input.action_release(&"jump")
	Input.action_release(&"move_right")
	_check("double jump: a jump pressed within coyote time after a ledge is the first jump (full -620) and the extra one stays", left_ground > 0 and airborne_jumps[0] == 0 and strongest < -560.0 and runner.air_jumps_left == 1,
		"vy %.0f left %d" % [strongest, runner.air_jumps_left])
	ledge_world.free()
	await _frames(2)
	# Still unlocked after reloading a save with 2 decisions (nothing extra is saved).
	_clean_state()
	_unlock_double_jump(true)
	GameState.save_to_disk()
	var saved_keys: Array = GameState.to_dict().keys()
	GameState.start_new_game()
	var locked_after_reset: bool = GameState.decisions.size() < 2
	var load_result: Dictionary = GameState.load_from_disk()
	var world_three: Node2D = _arena()
	var q: Player = await _player_at(world_three)
	_check("double jump: still unlocked after loading a save with 2 decisions (no new save key)", locked_after_reset and q.has_double_jump() and saved_keys.size() == SAVE_KEYS.size(), str(load_result.get("ok", load_result.keys())))
	world_three.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 7. Reach measured with the real player
# ---------------------------------------------------------------------------------------------

## One measured jump on a flat floor. Returns [rise in px, horizontal distance in px, airtime in s].
func _measure(use_double: bool, dash_after: float) -> Array[float]:
	var world: Node2D = _arena()
	var player: Player = await _player_at(world, -2000.0)
	Input.action_press(&"move_right")
	await _physics(40)
	var start_x: float = player.global_position.x
	var start_y: float = player.global_position.y
	var min_y: float = start_y
	Input.action_press(&"jump")
	var frames: int = 0
	var apex_reached: bool = false
	var dash_pressed: bool = dash_after < 0.0
	var apex_frame: int = -1
	var double_done: bool = not use_double
	var landed: bool = false
	while frames < 360 and not landed:
		await get_tree().physics_frame
		frames += 1
		min_y = minf(min_y, player.global_position.y)
		if not apex_reached and player.velocity.y >= 0.0 and not player.is_on_floor() and frames > 3:
			apex_reached = true
			apex_frame = frames
			Input.action_release(&"jump")
			if use_double:
				await get_tree().physics_frame
				frames += 1
				double_done = true
				apex_reached = false
				apex_frame = frames
				# One press, held through the whole second rise (releasing early would cut it).
				Input.action_press(&"jump")
				for i in 3:
					await get_tree().physics_frame
					frames += 1
				while player.velocity.y < 0.0 and frames < 360:
					await get_tree().physics_frame
					frames += 1
					min_y = minf(min_y, player.global_position.y)
				Input.action_release(&"jump")
				apex_reached = true
				apex_frame = frames
		if apex_reached and double_done and not dash_pressed and float(frames - apex_frame) / 60.0 >= dash_after:
			Input.action_press(&"dash")
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release(&"dash")
			frames += 2
			dash_pressed = true
		if frames > 10 and player.is_on_floor():
			landed = true
	var result: Array[float] = [start_y - min_y, player.global_position.x - start_x, float(frames) / 60.0]
	Input.action_release(&"move_right")
	world.free()
	await _frames(2)
	return result


func _test_reach_measurement() -> void:
	_clean_state()
	_unlock_double_jump(true)
	var jump_only: Array[float] = await _measure(false, -1.0)
	var jump_double: Array[float] = await _measure(true, -1.0)
	var best_dash: Array[float] = [0.0, 0.0, 0.0]
	for offset in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]:
		var run: Array[float] = await _measure(false, offset)
		if run[1] > best_dash[1]:
			best_dash = run
	var best_all: Array[float] = [0.0, 0.0, 0.0]
	for offset in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]:
		var run_all: Array[float] = await _measure(true, offset)
		if run_all[1] > best_all[1]:
			best_all = run_all
	jump_reach = jump_only[1]
	jump_airtime = jump_only[2]
	print("MEASURE|jump|rise %.0f px|reach %.0f px|air %.2f s" % [jump_only[0], jump_only[1], jump_only[2]])
	print("MEASURE|jump + double jump|rise %.0f px|reach %.0f px|air %.2f s" % [jump_double[0], jump_double[1], jump_double[2]])
	print("MEASURE|jump + dash|rise %.0f px|reach %.0f px|air %.2f s" % [best_dash[0], best_dash[1], best_dash[2]])
	print("MEASURE|jump + double jump + dash|rise %.0f px|reach %.0f px|air %.2f s" % [best_all[0], best_all[1], best_all[2]])
	_check("reach: the first jump still rises about 112 px and reaches about 220 px (%.0f / %.0f)" % [jump_only[0], jump_only[1]],
		jump_only[0] >= 100.0 and jump_only[0] <= 125.0 and jump_only[1] >= 190.0 and jump_only[1] <= 250.0)
	_check("reach: jump + dash reaches at least the 328 px measured before (%.0f)" % best_dash[1], best_dash[1] >= 320.0)
	_check("reach: the double jump only ADDS ability (%.0f px rise, %.0f px reach)" % [jump_double[0], jump_double[1]], jump_double[0] > jump_only[0] + 50.0 and jump_double[1] > jump_only[1])
	_check("reach: jump + double jump + dash reaches the farthest (%.0f px)" % best_all[1], best_all[1] > best_dash[1])


# ---------------------------------------------------------------------------------------------
# 2. Platforms and pads of arena 2
# ---------------------------------------------------------------------------------------------

func _platform_rects(level: LevelBase) -> Dictionary:
	var result: Dictionary = {}
	for node in level.find_children("Arena*", "StaticBody2D", true, false):
		var shape_node := node.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var size: Vector2 = (shape_node.shape as RectangleShape2D).size
			result[String(node.name)] = Rect2(node.global_position - size / 2.0, size)
	return result


## Walks the player from `from_x` (on the floor or a platform, standing at `stand_y`) holding right and jumping, and
## returns the y of the player after `frames` physics frames (a platform top gives about top - 26).
func _try_climb(level: LevelBase, from: Vector2, with_pad: bool, double: bool, direction: float) -> float:
	var player: Player = level.player
	player.global_position = from
	player.velocity = Vector2.ZERO
	await _physics(20)
	if direction > 0.0:
		Input.action_press(&"move_right")
	elif direction < 0.0:
		Input.action_press(&"move_left")
	await _press(&"jump", 18)
	if double:
		await _physics(1)
		await _press(&"jump", 14)
	await _physics(70)
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	await _physics(30)
	return player.global_position.y


func _test_level_two_geometry() -> void:
	_clean_state()
	GameState.decisions.clear()
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
	var level: LevelBase = _level(2)
	add_child(level)
	await _frames(8)
	var rects: Dictionary = _platform_rects(level)
	var low_a: Rect2 = rects["ArenaLowA"]
	var high_a: Rect2 = rects["ArenaHighA"]
	var high_b: Rect2 = rects["ArenaHighB"]
	var floor_top: float = 600.0
	_check("platforms: low tier at most about 100 px above the floor (%.0f px), high tier about 250 px (%.0f px)" % [floor_top - low_a.position.y, floor_top - high_a.position.y],
		floor_top - low_a.position.y <= 105.0 and floor_top - low_a.position.y >= 60.0 and floor_top - high_a.position.y >= 220.0 and floor_top - high_a.position.y <= 280.0)
	level.player.story_invulnerable = true
	var low_b: Rect2 = rects["ArenaLowB"]
	var under_low_b: float = low_b.position.x + low_b.size.x * 0.5
	# Low tier by the normal jump: straight up from the floor under it.
	var y_low: float = await _try_climb(level, Vector2(under_low_b, 574.0), false, false, 0.0)
	_check("platforms: the low tier is reachable with the normal jump (y %.0f, platform top %.0f)" % [y_low, low_b.position.y], absf(y_low - (low_b.position.y - 26.0)) < 8.0)
	# The high tier is NOT reachable from the floor with the normal jump (the double jump is still locked: 1 decision).
	var y_floor_try: float = await _try_climb(level, Vector2(high_b.position.x + 90.0, 574.0), false, false, 0.0)
	_check("platforms: the high tier is not reachable from the floor with the normal jump (y %.0f, high tier stands at %.0f)" % [y_floor_try, high_b.position.y - 26.0], y_floor_try > high_b.position.y + 60.0)
	# From the low tier, with the double jump still locked, it is not reachable either.
	var y_low_locked: float = await _try_climb(level, Vector2(under_low_b + 40.0, low_b.position.y - 26.0), false, false, 0.0)
	_check("platforms: the high tier is not reachable from the low tier with the normal jump (y %.0f)" % y_low_locked, y_low_locked > high_b.position.y + 60.0)
	# By a lily pad: dropped onto pad A from above, the player is launched and steers onto the high tier.
	var pad_a: BouncePad = level.get_node("Content/ArenaPadA")
	level.player.global_position = Vector2(pad_a.global_position.x, pad_a.global_position.y - 70.0)
	level.player.velocity = Vector2(0.0, 150.0)
	var launch_guard: int = 0
	while pad_a.launch_count == 0 and launch_guard < 60:
		launch_guard += 1
		await get_tree().physics_frame
	Input.action_press(&"move_right")
	await _physics(40)
	Input.action_release(&"move_right")
	var on_high: bool = false
	for i in 140:
		await get_tree().physics_frame
		if level.player.is_on_floor() and level.player.global_position.y < high_a.position.y:
			on_high = true
			break
	_check("platforms: a lily pad launches the player onto the high tier (the only way up without the double jump)", on_high, "y %.0f, pad launches %d" % [level.player.global_position.y, pad_a.launch_count])
	await _physics(60)
	level.free()
	await _frames(2)
	# With the double jump unlocked, the high tier is reachable from the low tier.
	_clean_state()
	_unlock_double_jump(true)
	var level_two: LevelBase = _level(2)
	add_child(level_two)
	await _frames(8)
	level_two.player.story_invulnerable = true
	var rects_two: Dictionary = _platform_rects(level_two)
	var lb: Rect2 = rects_two["ArenaLowB"]
	var hb: Rect2 = rects_two["ArenaHighB"]
	var y_double: float = await _try_climb(level_two, Vector2(lb.position.x + lb.size.x * 0.5 + 40.0, lb.position.y - 26.0), false, true, 0.0)
	_check("platforms: with the double jump the high tier is reachable from the low tier (y %.0f, stands at %.0f)" % [y_double, hb.position.y - 26.0], absf(y_double - (hb.position.y - 26.0)) < 8.0)
	var y_double_floor: float = await _try_climb(level_two, Vector2(hb.position.x + 90.0, 574.0), false, true, 0.0)
	_check("platforms: the double jump alone from the floor does not reach the high tier (y %.0f)" % y_double_floor, y_double_floor > hb.position.y + 60.0)
	# Pads: 2-3 of them, on the floor; no KillZone in the arena; the floor stays continuous (as in Phase 15b).
	var pads: Array[Node] = level_two.find_children("ArenaPad*", "Area2D", true, false)
	_check("platforms: 3 lily pads sit on the arena floor", pads.size() == 3 and pads.all(func(n: Node) -> bool: return absf((n as Node2D).global_position.y + 22.0 - floor_top) < 1.0))
	var floor_rects: Array[Rect2] = []
	var kill_in_arena: bool = false
	var gate_x: float = (level_two.find_children("ArenaGate", "", true, false)[0] as Node2D).global_position.x
	var wall_inner: float = 0.0
	var ceiling_bottom: float = 0.0
	for shape_node in level_two.find_children("*", "CollisionShape2D", true, false):
		var rect_shape := (shape_node as CollisionShape2D).shape as RectangleShape2D
		if rect_shape == null:
			continue
		var body: Node = shape_node.get_parent()
		var rect := Rect2((shape_node as Node2D).global_position - rect_shape.size / 2.0, rect_shape.size)
		if String(body.name).begins_with("Floor"):
			floor_rects.append(rect)
		elif String(body.name) == "WallRight":
			wall_inner = rect.position.x
		elif String(body.name) == "ArenaCeiling":
			ceiling_bottom = rect.end.y
	floor_rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var covered_to: float = gate_x
	var progress: bool = true
	while progress and covered_to < wall_inner:
		progress = false
		for floor_rect in floor_rects:
			if floor_rect.position.x <= covered_to + 0.01 and floor_rect.end.x > covered_to:
				covered_to = floor_rect.end.x
				progress = true
	var arena_volume := Rect2(Vector2(gate_x, ceiling_bottom), Vector2(wall_inner - gate_x, 600.0 - ceiling_bottom))
	for shape_node in level_two.find_children("*", "CollisionShape2D", true, false):
		if shape_node.get_parent() is KillZone:
			var kill_shape := (shape_node as CollisionShape2D).shape as RectangleShape2D
			if Rect2((shape_node as Node2D).global_position - kill_shape.size / 2.0, kill_shape.size).intersects(arena_volume):
				kill_in_arena = true
	_check("platforms: the arena floor is still continuous from the gate to the right wall (covered to %.0f of %.0f)" % [covered_to, wall_inner], covered_to >= wall_inner)
	_check("platforms: no KillZone inside the arena", not kill_in_arena)
	var camera_limits: Rect2i = level_two.camera_limits
	_check("platforms: the camera limits show the whole vertical range (0 to 720) and the highest platform fits",
		camera_limits.position.y <= 0 and camera_limits.end.y >= 720 and high_a.position.y > ceiling_bottom + 120.0)
	# The anchors of the guardian: on the floor and on the platforms, standing positions.
	var anchors: Array[Node] = level_two.find_children("Anchor*", "Marker2D", true, false)
	var floor_anchors: int = 0
	var platform_anchors: int = 0
	var anchors_ok: bool = true
	for node in anchors:
		var anchor := node as BossAnchor
		anchors_ok = anchors_ok and anchor != null and anchor.is_in_group(BossAnchor.GROUP)
		if anchor.tier == BossAnchor.Tier.FLOOR:
			floor_anchors += 1
			anchors_ok = anchors_ok and absf(anchor.global_position.y - (floor_top - 44.0)) < 1.0
		else:
			platform_anchors += 1
	_check("platforms: %d floor anchors and %d platform anchors for the guardian" % [floor_anchors, platform_anchors], anchors_ok and floor_anchors >= 3 and platform_anchors >= 4)
	level_two.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 3. Floor spikes
# ---------------------------------------------------------------------------------------------

func _hazard_in(world: Node2D, x: float = -300.0) -> FloorHazard:
	var hazard := HAZARD_SCENE.instantiate() as FloorHazard
	hazard.position = Vector2(x, FLOOR_Y)
	hazard.length = 900.0
	world.add_child(hazard)
	return hazard


func _test_hazard() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var hazard: FloorHazard = _hazard_in(world)
	var player: Player = await _player_at(world)
	var log: Array = []
	var clock: Array[int] = [0]
	hazard.state_changed.connect(func(new_state: int) -> void: log.append([new_state, clock[0]]))
	_check("spikes: idle until started, nothing hurts", hazard.state == FloorHazard.State.IDLE and not hazard.is_dangerous())
	hazard.start()
	var frames: int = 0
	while frames < 60 * 9 and log.size() < 4:
		await get_tree().physics_frame
		frames += 1
		clock[0] = frames
	var warning_frames: int = 0
	var active_frames: int = 0
	var rest_frames: int = 0
	if log.size() >= 4:
		warning_frames = int(log[1][1]) - int(log[0][1])
		active_frames = int(log[2][1]) - int(log[1][1])
		rest_frames = int(log[3][1]) - int(log[2][1])
	var ids: Array[int] = []
	for entry in log:
		ids.append(int(entry[0]))
	_check("spikes: the cycle is warning, active, rest, warning", ids == [FloorHazard.State.WARNING, FloorHazard.State.ACTIVE, FloorHazard.State.REST, FloorHazard.State.WARNING], str(ids))
	_check("spikes: warning 1.2 s, active 3.0 s, rest 4.0 s (%d, %d, %d frames)" % [warning_frames, active_frames, rest_frames],
		absi(warning_frames - 72) <= 3 and absi(active_frames - 180) <= 3 and absi(rest_frames - 240) <= 3)
	hazard.stop()
	_check("spikes: stop() ends everything at once", hazard.state == FloorHazard.State.IDLE and not hazard.running)
	# The pads are cut out of the dangerous band.
	var pad := PAD_SCENE.instantiate() as BouncePad
	pad.position = Vector2(150.0, FLOOR_Y - 22.0)
	world.add_child(pad)
	hazard.start()
	var pad_range: Vector2 = pad.global_x_range()
	var overlaps_pad: bool = false
	for rect in hazard.segments:
		var global_left: float = hazard.global_position.x + rect.position.x
		if global_left < pad_range.y and global_left + rect.size.x > pad_range.x:
			overlaps_pad = true
	_check("spikes: lily pads are always safe (cut out of the dangerous floor)", not overlaps_pad and hazard.segments.size() == 2, str(hazard.segments.size()))
	hazard.stop()
	pad.free()
	# Damage goes through the normal path, with the hurt invulnerability of the player.
	var hp: int = player.health.current_health
	hazard.start()
	while hazard.state != FloorHazard.State.ACTIVE:
		await get_tree().physics_frame
	await _physics(8)
	_check("spikes: a hit takes exactly 1 heart through the normal damage path", player.health.current_health == hp - 1 and player.state == Player.State.HURT, "%d -> %d" % [hp, player.health.current_health])
	await _physics(40)
	_check("spikes: the hurt invulnerability protects against a second hit right away", player.health.current_health == hp - 1)
	hazard.stop()
	await _physics(90)
	# The dash invulnerability protects against them.
	player.health.reset()
	player.global_position = Vector2(0.0, FLOOR_Y - 26.0)
	player.velocity = Vector2.ZERO
	await _physics(30)
	hp = player.health.current_health
	hazard.start()
	while hazard.state_time < hazard.config.warning_time - 0.1:
		await get_tree().physics_frame
	Input.action_press(&"dash")
	await _physics(2)
	Input.action_release(&"dash")
	var protected_frames: int = 0
	var damaged_in_dash: bool = false
	for i in 20:
		await get_tree().physics_frame
		if player.state == Player.State.DASH:
			protected_frames += 1
			damaged_in_dash = damaged_in_dash or player.health.current_health < hp
	_check("spikes: the dash protects against them (%d dash frames, the spikes came out during it)" % protected_frames, protected_frames > 3 and not damaged_in_dash and hazard.state == FloorHazard.State.ACTIVE)
	await _physics(10)
	_check("spikes: right after the dash the player is hit (the spikes were really out)", player.health.current_health == hp - 1)
	hazard.stop()
	await _physics(80)
	# They cannot hurt the boss.
	var boss := (load("res://backend/bosses/placeholder_boss.tscn") as PackedScene).instantiate() as BossBase
	boss.position = Vector2(200.0, FLOOR_Y - 44.0)
	world.add_child(boss)
	await _physics(10)
	var boss_hp: int = boss.health.current_health
	hazard.start()
	while hazard.state != FloorHazard.State.ACTIVE:
		await get_tree().physics_frame
	await _physics(90)
	_check("spikes: they cannot hurt the boss", boss.health.current_health == boss_hp)
	hazard.stop()
	world.free()
	await _frames(2)
	# KillZone semantics are unchanged: it kills even through the hurt invulnerability.
	_clean_state()
	var kill_world: Node2D = _arena()
	var kill_player: Player = await _player_at(kill_world)
	kill_player.health.grant_invulnerability(5.0)
	var kill_zone := KILL_ZONE_SCENE.instantiate() as KillZone
	kill_zone.size = Vector2(200.0, 200.0)
	kill_zone.position = Vector2(0.0, FLOOR_Y)
	kill_world.add_child(kill_zone)
	await _physics(6)
	_check("spikes: a KillZone still kills even through invulnerability (it is not the damage path)", kill_player.is_dead)
	kill_world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 3b. The hazard follows the fight
# ---------------------------------------------------------------------------------------------

func _test_hazard_stops() -> void:
	_clean_state()
	GameState.decisions.clear()
	# Outside the fight and in phase 1 it never runs; phase 2 starts it.
	var level: LevelBase = await _boss_fight()
	var hazard := level.get_node("Content/FloorHazard") as FloorHazard
	_check("spikes: they do not run before phase 2", not hazard.running and hazard.state == FloorHazard.State.IDLE)
	_damage_boss_to_phase_two(level)
	await _physics(120)
	_check("spikes: boss phase 2 starts the cycle", hazard.running and level.boss.current_phase == 2, "phase %d state %d" % [level.boss.current_phase, hazard.state])
	var ended: Array[int] = [0]
	hazard.stopped.connect(func() -> void: ended[0] += 1)
	level.boss.health.kill()
	await _physics(2)
	_check("spikes: they stop at once when the boss dies", not hazard.running and hazard.state == FloorHazard.State.IDLE and not hazard.is_dangerous() and ended[0] == 1)
	level.free()
	await _frames(2)
	# Cancelling the fight (the encounter is reset).
	_clean_state()
	var cancel_level: LevelBase = await _boss_fight()
	var cancel_hazard := cancel_level.get_node("Content/FloorHazard") as FloorHazard
	_damage_boss_to_phase_two(cancel_level)
	await _physics(120)
	var was_running: bool = cancel_hazard.running
	cancel_level.boss.reset_encounter()
	await _physics(2)
	_check("spikes: they stop when the fight is cancelled", was_running and not cancel_hazard.running and cancel_hazard.state == FloorHazard.State.IDLE)
	cancel_level.free()
	await _frames(2)
	# The player dies.
	_clean_state()
	var die_level: LevelBase = await _boss_fight(true)
	var die_hazard := die_level.get_node("Content/FloorHazard") as FloorHazard
	_damage_boss_to_phase_two(die_level)
	await _physics(120)
	var running_before_death: bool = die_hazard.running
	die_level.player.health.kill()
	await _physics(4)
	_check("spikes: they stop when the player dies", running_before_death and not die_hazard.running and die_level.boss.state == BossBase.State.INACTIVE)
	die_level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# 8. Safety net: a refuge within the warning
# ---------------------------------------------------------------------------------------------

## Time (s) the real player needs to walk `distance` px from a standstill, measured by running it.
func _walk_time(distance: float) -> float:
	var world: Node2D = _arena()
	var player: Player = await _player_at(world, -1000.0)
	var start_x: float = player.global_position.x
	Input.action_press(&"move_right")
	var frames: int = 0
	while player.global_position.x - start_x < distance and frames < 600:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_right")
	world.free()
	await _frames(2)
	return float(frames) / 60.0


## Time (s) the real player needs to get its feet up to a platform top `rise` px above the floor.
func _jump_time(rise: float) -> float:
	var world: Node2D = _arena()
	var player: Player = await _player_at(world)
	var start_y: float = player.global_position.y
	Input.action_press(&"jump")
	var frames: int = 0
	while start_y - player.global_position.y < rise and frames < 120:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"jump")
	world.free()
	await _frames(2)
	return float(frames) / 60.0


func _test_refuge_time() -> void:
	_clean_state()
	var level: LevelBase = _level(2)
	add_child(level)
	await _frames(6)
	var rects: Dictionary = _platform_rects(level)
	var hazard := level.get_node("Content/FloorHazard") as FloorHazard
	var floor_left: float = hazard.global_position.x
	var floor_right: float = floor_left + hazard.length
	# Safe spots: pads (walk onto them) and the footprints of the platforms the normal jump reaches (walk under, jump).
	var pad_ranges: Array[Vector2] = []
	for pad in level.find_children("ArenaPad*", "Area2D", true, false):
		pad_ranges.append((pad as BouncePad).global_x_range())
	var low_ranges: Array[Vector2] = []
	var low_rise: float = 0.0
	for key in ["ArenaLowA", "ArenaLowB"]:
		var rect: Rect2 = rects[key]
		low_ranges.append(Vector2(rect.position.x, rect.end.x))
		low_rise = maxf(low_rise, 600.0 - rect.position.y)
	level.free()
	await _frames(2)
	var samples: Array[Vector2] = []
	for distance in [0.0, 50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 400.0]:
		samples.append(Vector2(distance, await _walk_time(distance)))
	var jump_seconds: float = await _jump_time(low_rise)
	var worst: float = 0.0
	var worst_x: float = floor_left
	var x: float = floor_left
	while x <= floor_right:
		var best: float = INF
		for span in pad_ranges:
			# A pad must be landed on from above: walk until a jump (reach `jump_reach`) can come down on it, then hop.
			var to_pad: float = maxf(maxf(span.x - x, x - span.y), 0.0)
			best = minf(best, _interpolate(samples, maxf(to_pad - jump_reach * 0.8, 0.0)) + jump_airtime)
		for span in low_ranges:
			best = minf(best, _interpolate(samples, maxf(maxf(span.x - x, x - span.y), 0.0)) + jump_seconds)
		if best > worst:
			worst = best
			worst_x = x
		x += 5.0
	var warning: float = FloorHazardConfig.get_default().warning_time
	print("MEASURE|spike refuge|worst %.2f s at x %.0f|warning %.1f s|margin %.2f s|jump to the low tier %.2f s|hop onto a pad %.2f s" % [worst, worst_x, warning, warning - worst, jump_seconds, jump_airtime])
	_check("refuge: from every floor x a pad or a low platform is reachable within the warning with margin (worst %.2f s of %.1f s, at x %.0f)" % [worst, warning, worst_x],
		worst <= warning - 0.3)


func _interpolate(samples: Array[Vector2], distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	for i in range(1, samples.size()):
		if distance <= samples[i].x:
			var a: Vector2 = samples[i - 1]
			var b: Vector2 = samples[i]
			return lerpf(a.y, b.y, (distance - a.x) / maxf(b.x - a.x, 0.001))
	var last: Vector2 = samples[samples.size() - 1]
	return last.y + (distance - last.x) / 300.0


# ---------------------------------------------------------------------------------------------
# 4. The guardian's leap
# ---------------------------------------------------------------------------------------------

func _leap_patterns(boss: BossBase) -> Array[LeapPattern]:
	var result: Array[LeapPattern] = []
	for pattern in boss.patterns:
		if pattern is LeapPattern:
			result.append(pattern as LeapPattern)
	return result


func _test_leap() -> void:
	_clean_state()
	var level: LevelBase = await _boss_fight()
	var boss: BossBase = level.boss
	var leaps: Array[LeapPattern] = _leap_patterns(boss)
	_check("leap: boss 2 has a leap pattern in phase 1 (modest weight) and one in phase 2 (higher weight and spikes)",
		leaps.size() == 2 and leaps[0].max_phase == 1 and leaps[1].min_phase == 2 and leaps[1].weight > leaps[0].weight and leaps[0].weight < 1.0)
	var light: LeapPattern = leaps[0]
	var volley: ProjectileVolleyPattern = boss.get_node("Patterns/LeapVolley") as ProjectileVolleyPattern
	_check("leap: its volley never starts by itself (phase window closed, weight 0)", volley != null and volley.weight == 0.0 and volley.min_phase > 2)
	await _physics(5)
	# Wait for the boss to be idle, then run the leap by hand.
	var guard: int = 0
	while boss.state == BossBase.State.PATTERN and guard < 600:
		guard += 1
		await get_tree().physics_frame
	boss.global_position = Vector2(5370.0, 556.0)
	boss.velocity = Vector2.ZERO
	await _physics(15)
	level.player.global_position = Vector2(5000.0, 574.0)
	light.cooldown_left = 0.0
	var anchor_target := Vector2(5350.0, 466.0)
	var floor_target := Vector2(5000.0, 556.0)
	light.forced_first = anchor_target
	light.forced_return = floor_target
	var phases: Array[StringName] = []
	light.phase_changed.connect(func(name_text: StringName) -> void: phases.append(name_text))
	var markers: Array = []
	light.marker_changed.connect(func(position: Vector2, shown: bool) -> void: markers.append([position, shown]))
	var landings: Array[Vector2] = []
	light.landed.connect(func(position: Vector2) -> void: landings.append(position))
	_check("leap: it can start from the floor with a player in the arena", light.can_start(boss))
	boss._set_state(BossBase.State.IDLE)
	boss._start_pattern(light)
	await _physics(5)
	var marker_node: Node = boss.find_child("LeapMarker", true, false)
	_check("leap: the telegraph (crouch) shows the landing marker on the target spot", markers.size() >= 1 and markers[0][1] == true and absf((markers[0][0] as Vector2).x - anchor_target.x) < 1.0
		and marker_node is LeapMarker and (marker_node as LeapMarker).visible)
	var perch_checked: bool = false
	var fired: Array = []
	var watcher: Callable = func(node: Node) -> void:
		if node is Projectile:
			fired.append(node)
	get_tree().node_added.connect(watcher)
	var shot_downward: bool = false
	var landing_hit_seen: bool = false
	var perch_position: Vector2 = Vector2.ZERO
	var frames: int = 0
	while boss.state == BossBase.State.PATTERN and frames < 60 * 14:
		await get_tree().physics_frame
		frames += 1
		var hitbox: Hitbox = boss.get_node("AttackPivot/LandingHitbox") as Hitbox
		landing_hit_seen = landing_hit_seen or hitbox.is_active
		for projectile in fired:
			if is_instance_valid(projectile) and (projectile as Projectile).velocity.y > 40.0:
				shot_downward = true
		if light.phase_name == LeapPattern.PHASE_PERCH and not perch_checked:
			perch_checked = true
			perch_position = boss.global_position
	get_tree().node_added.disconnect(watcher)
	_check("leap: the phases run telegraph, flight, perch, return, recovery", phases == [LeapPattern.PHASE_TELEGRAPH, LeapPattern.PHASE_ACTIVE, LeapPattern.PHASE_PERCH, LeapPattern.PHASE_RETURN, LeapPattern.PHASE_RECOVERY], str(phases))
	_check("leap: it lands on the platform anchor (%s) and the floor anchor" % str(perch_position), perch_position.distance_to(anchor_target) < 30.0 and landings.size() == 2 and (landings[1] as Vector2).distance_to(floor_target) < 30.0, str(landings))
	_check("leap: a landing has a small contact-damage area that was switched on", landing_hit_seen)
	_check("leap: the marker moved to the return spot and is hidden at the end", markers.size() >= 4 and markers[markers.size() - 1][1] == false and not light.marker_visible
		and (markers[2][0] as Vector2).distance_to(Vector2(floor_target.x, floor_target.y + 44.0)) < 2.0, str(markers.size()))
	_check("leap: the perch volley fires %d projectiles (aimed down at the player below)" % fired.size(), fired.size() == 3 and shot_downward)
	_check("leap: the boss ended on its feet and the old pattern flow continues", boss.state == BossBase.State.IDLE and boss.is_on_floor())
	# The boss can be hit while it is on a platform.
	light.cooldown_left = 0.0
	boss.global_position = Vector2(5370.0, 556.0)
	boss.velocity = Vector2.ZERO
	await _physics(15)
	boss._set_state(BossBase.State.IDLE)
	boss._start_pattern(light)
	var hit_on_platform: bool = false
	var perch_frames: int = 0
	while perch_frames < 60 * 10:
		await get_tree().physics_frame
		perch_frames += 1
		if light.phase_name == LeapPattern.PHASE_PERCH:
			var before: int = boss.health.current_health
			boss.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, level.player, CombatLayers.Team.PLAYER))
			hit_on_platform = boss.health.current_health == before - 1
			break
	_check("leap: the boss can be hit while it is on a platform", hit_on_platform)
	# Cancelling in the middle of the jump (phase 2 begins) hides the marker and leaves nothing running.
	var cancel_markers: Array = []
	light.marker_changed.connect(func(position: Vector2, shown: bool) -> void: cancel_markers.append(shown))
	await _physics(2)
	_damage_boss_to_phase_two(level)
	await _physics(4)
	_check("leap: the phase change cancels it cleanly (marker hidden, hitbox and volley off, the boss falls to the floor)",
		boss.state == BossBase.State.PHASE_TRANSITION and not light.marker_visible and not (boss.get_node("AttackPivot/LandingHitbox") as Hitbox).is_active and light.is_finished()
		and volley.is_finished() and (marker_node == null or not (boss.find_child("LeapMarker", true, false) as LeapMarker).visible))
	await _physics(150)
	_check("leap: after the transition the boss is on the floor and phase 2 runs", boss.is_on_floor() and boss.current_phase == 2)
	# Death in the middle of a leap.
	var strong: LeapPattern = leaps[1]
	strong.cooldown_left = 0.0
	strong.forced_first = anchor_target
	strong.forced_return = floor_target
	boss.global_position = Vector2(5370.0, 556.0)
	boss.velocity = Vector2.ZERO
	await _physics(10)
	boss._set_state(BossBase.State.IDLE)
	boss._start_pattern(strong)
	await _physics(75)
	boss.health.kill()
	await _physics(3)
	_check("leap: death in the middle of a leap stops it cleanly", strong.is_finished() and not strong.marker_visible and boss.state == BossBase.State.DEAD)
	level.free()
	await _frames(2)
	# Every anchor can be reached from the floor: the apex clears the ceiling and the flight is a sane length.
	_clean_state()
	var plan_level: LevelBase = await _boss_fight()
	var plan_boss: BossBase = plan_level.boss
	var plan_leap: LeapPattern = _leap_patterns(plan_boss)[0]
	var ceiling_bottom: float = 160.0
	var all_reachable: bool = true
	var worst_apex: float = 9999.0
	for node in plan_level.find_children("Anchor*", "Marker2D", true, false):
		var anchor := node as BossAnchor
		for start_name in ["AnchorFloor1", "AnchorFloor2", "AnchorFloor3"]:
			var start: Vector2 = (plan_level.find_child(start_name, true, false) as Node2D).global_position
			plan_boss.global_position = start
			plan_leap._plan_flight(plan_boss, anchor.global_position)
			var apex_y: float = minf(start.y, anchor.global_position.y) - plan_leap.apex_clearance
			worst_apex = minf(worst_apex, apex_y - 44.0)
			var rise: float = start.y - anchor.global_position.y
			var ok: bool = apex_y - 44.0 > ceiling_bottom and plan_leap._flight_expected > 0.3 and plan_leap._flight_expected < 2.5 and rise <= plan_leap.max_rise
			all_reachable = all_reachable and ok
	_check("leap: every anchor is reachable from every floor anchor (the boss head stays %.0f px under the ceiling at the worst apex)" % (worst_apex - ceiling_bottom), all_reachable and worst_apex > ceiling_bottom)
	# Real flights from the floor to each platform anchor end standing on it.
	var real_ok: bool = true
	var detail: String = ""
	for target_name in ["AnchorLowA", "AnchorLowB", "AnchorHighA", "AnchorHighB"]:
		var target_position: Vector2 = (plan_level.find_child(target_name, true, false) as Node2D).global_position
		plan_leap.cooldown_left = 0.0
		plan_leap.forced_first = target_position
		plan_leap.forced_return = Vector2(5000.0, 556.0)
		plan_boss.global_position = Vector2(5000.0, 556.0)
		plan_boss.velocity = Vector2.ZERO
		await _physics(15)
		plan_boss._set_state(BossBase.State.IDLE)
		plan_boss._start_pattern(plan_leap)
		var land_frames: int = 0
		var landed_at: Vector2 = Vector2.INF
		var landed_signal: Array[Vector2] = []
		plan_leap.landed.connect(func(position: Vector2) -> void: landed_signal.append(position), CONNECT_ONE_SHOT)
		while landed_signal.is_empty() and land_frames < 300:
			await get_tree().physics_frame
			land_frames += 1
		if not landed_signal.is_empty():
			landed_at = landed_signal[0]
		var good: bool = landed_at != Vector2.INF and absf(landed_at.x - target_position.x) < 30.0 and absf(landed_at.y - target_position.y) < 8.0
		real_ok = real_ok and good
		detail += "%s:%s " % [target_name, "ok" if good else str(landed_at)]
		# Let the pattern finish.
		var finish_guard: int = 0
		while plan_boss.state == BossBase.State.PATTERN and finish_guard < 60 * 12:
			finish_guard += 1
			await get_tree().physics_frame
	_check("leap: a real flight lands on each platform anchor", real_ok, detail)
	plan_level.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Old patterns and stats did not change
# ---------------------------------------------------------------------------------------------

func _test_old_patterns() -> void:
	var boss := (load("res://backend/bosses/boss_two.tscn") as PackedScene).instantiate() as BossBase
	var swipe := boss.get_node("Patterns/Swipe") as BossPattern
	var charge := boss.get_node("Patterns/Charge") as ChargePattern
	var volley := boss.get_node("Patterns/Volley") as ProjectileVolleyPattern
	_check("old patterns: swipe unchanged (weight 0.8, cooldown 1.8, windup 0.7, active 0.25, recovery 0.7)",
		is_equal_approx(swipe.weight, 0.8) and is_equal_approx(swipe.cooldown, 1.8) and is_equal_approx(swipe.telegraph_time, 0.7) and is_equal_approx(swipe.recovery_time, 0.7)
		and is_equal_approx((swipe as SwipePattern).active_time, 0.25))
	_check("old patterns: charge unchanged (weight 2.0, cooldown 2.2, windup 0.7, recovery 0.8, speed 560, duration 0.8)",
		is_equal_approx(charge.weight, 2.0) and is_equal_approx(charge.cooldown, 2.2) and is_equal_approx(charge.telegraph_time, 0.7) and is_equal_approx(charge.recovery_time, 0.8)
		and is_equal_approx(charge.charge_speed, 560.0) and is_equal_approx(charge.charge_duration, 0.8))
	_check("old patterns: volley unchanged (phase 2 only, weight 0.7, cooldown 5, windup 0.8, recovery 0.9, 3 shots, 24 degrees, 0.18 s apart, no steep aim)",
		volley.min_phase == 2 and is_equal_approx(volley.weight, 0.7) and is_equal_approx(volley.cooldown, 5.0) and is_equal_approx(volley.telegraph_time, 0.8)
		and is_equal_approx(volley.recovery_time, 0.9) and volley.projectile_count == 3 and is_equal_approx(volley.spread_angle_degrees, 24.0)
		and is_equal_approx(volley.shot_interval, 0.18) and not volley.allow_steep_aim)
	var stats: BossStats = boss.stats
	_check("boss stats unchanged (60 HP, phase 2 at 55%, 1.5 s transition, x1.35 speed, x0.55 gaps, gap 1.1 s, contact damage 1)",
		stats.max_health == 60 and is_equal_approx(stats.phase_2_health_ratio, 0.55) and is_equal_approx(stats.phase_transition_time, 1.5) and is_equal_approx(stats.phase_2_speed_multiplier, 1.35)
		and is_equal_approx(stats.phase_2_pattern_gap_multiplier, 0.55) and is_equal_approx(stats.pattern_gap_time, 1.1) and stats.contact_damage == 1)
	boss.free()


# ---------------------------------------------------------------------------------------------
# 6. The double jump card and the presentation order
# ---------------------------------------------------------------------------------------------

func _decide_level_two(level: LevelBase, choice: String) -> void:
	GameState.record_decision("fragment_level_2", "boss_two", 2, choice)
	level.decision_flow.decision_made.emit("fragment_level_2", choice)


func _test_cards() -> void:
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	for choice in [GameState.CHOICE_KEPT, GameState.CHOICE_RELEASED]:
		_clean_state()
		GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
		var level: LevelBase = _level(2)
		var intro := level.get_node("AbilityIntro") as AbilityIntro
		intro.play_when_headless = true
		add_child(level)
		await _frames(6)
		var queue: PresentationQueue = intro.get_queue()
		var seen_cards: Array[String] = []
		intro.card_shown.connect(func(card: AbilityCard) -> void: seen_cards.append(card.ability_name))
		_decide_level_two(level, choice)
		var cut: ExorcismCutscene = null
		if choice == GameState.CHOICE_KEPT:
			cut = EXORCISM_SCENE.instantiate() as ExorcismCutscene
			cut.fragment_id = "fragment_level_2"
			cut.player = level.player
			level.add_child(cut)
		await _frames(8)
		var label: String = "keep" if choice == GameState.CHOICE_KEPT else "release"
		if choice == GameState.CHOICE_KEPT:
			_check("cards (%s): no card opens while the corruption animation runs" % label, seen_cards.is_empty() and is_instance_valid(cut))
			cut._finish()
			await _frames(4)
			_check("cards (keep): the wave-upgrade card comes first, right after the animation", seen_cards.size() == 1 and seen_cards[0].begins_with("Onda de espada"), str(seen_cards))
			intro.card._elapsed = 1.0
			intro.card._input(accept)
			await _frames(4)
			_check("cards (keep): then the double jump card, never over the wave card", seen_cards.size() == 2 and seen_cards[1] == "Doble salto" and intro.card.is_open, str(seen_cards))
		else:
			_check("cards (release): no animation step is needed and the double jump card is the only one", seen_cards == ["Doble salto"], str(seen_cards))
		_check("cards (%s): the card names the Jump key read live from the InputMap and the game is paused only while it is open" % label,
			intro.card.key_text.begins_with("Tecla: ") and intro.card.key_text.length() > 8 and get_tree().paused and intro.card.description.contains("saltar"), intro.card.key_text)
		intro.card._elapsed = 1.0
		intro.card._input(accept)
		await _frames(4)
		_check("cards (%s): afterwards nothing is paused, the queue is idle and each card was shown once" % label, not get_tree().paused and not PauseLock.is_locked() and not queue.is_busy())
		_decide_level_two(level, choice)
		await _frames(6)
		_check("cards (%s): the same event never shows its card twice" % label, not get_tree().paused)
		var order: Array = queue.finished_ids
		if choice == GameState.CHOICE_KEPT:
			_check("cards (keep): the queue order was corruption, wave card, double jump card", order.size() >= 3 and String(order[0]).begins_with("corruption_") and String(order[1]).begins_with("card_wave_")
				and String(order[2]) == "card_double_jump", str(order))
		else:
			_check("cards (release): the queue order was the (empty) animation step, then the double jump card", order.size() >= 2 and String(order[0]).begins_with("corruption_") and String(order[1]) == "card_double_jump", str(order))
		level.free()
		await _frames(2)
	# Headless runs skip the cards (and the queue stays idle).
	_clean_state()
	var quiet: LevelBase = _level(2)
	add_child(quiet)
	await _frames(6)
	_decide_level_two(quiet, GameState.CHOICE_KEPT)
	await _frames(6)
	_check("cards: in automated (headless) runs no card opens and nothing pauses", not get_tree().paused and not (quiet.get_node("AbilityIntro") as AbilityIntro).get_queue().is_busy())
	quiet.free()
	await _frames(2)
	var texts := AbilityTexts.get_default()
	var accents := RegEx.new()
	accents.compile("[áéíóúñ¿]")
	_check("cards: the double jump texts are Spanish with accents, editable data, and tied to the story",
		texts.double_jump_name == "Doble salto" and texts.double_jump_description.contains("pantano") and accents.search(texts.double_jump_description) != null and texts.footer.contains("Opciones → Controles"))


# ---------------------------------------------------------------------------------------------
# Optional textures
# ---------------------------------------------------------------------------------------------

func _test_texture_override() -> void:
	_clean_state()
	var world: Node2D = _arena()
	var pad := PAD_SCENE.instantiate() as BouncePad
	pad.position = Vector2(0.0, FLOOR_Y - 22.0)
	world.add_child(pad)
	var hazard: FloorHazard = _hazard_in(world)
	await _frames(3)
	var pad_art := pad.get_node("Art") as BouncePadArt
	var hazard_art := hazard.get_node("Art") as FloorHazardArt
	_check("textures: without a texture the pad and the spikes are drawn in code", not pad_art.uses_texture() and not hazard_art.uses_texture())
	var image := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.8, 0.4, 1.0))
	var texture := ImageTexture.create_from_image(image)
	pad.texture = texture
	hazard_art.spike_texture = texture
	hazard.start()
	await _frames(6)
	_check("textures: a texture replaces the code drawing of the pad and of the spikes (both draw without error)", pad_art.uses_texture() and hazard_art.uses_texture())
	hazard.stop()
	await _physics(30)
	pad.texture = null
	hazard_art.spike_texture = null
	await _frames(3)
	_check("textures: clearing them goes back to the code drawing", not pad_art.uses_texture() and not hazard_art.uses_texture())
	world.free()
	await _frames(2)


# ---------------------------------------------------------------------------------------------
# Contrast against the level 2 biomes
# ---------------------------------------------------------------------------------------------

func _test_contrast() -> void:
	var presentation := load("res://frontend/presentation/default_profile_presentation.tres") as ProfilePresentation
	var backgrounds: Array[Color] = []
	var ground: Array[Color] = []
	for file in ["flooded_suburb_biome.tres", "swamp_biome.tres"]:
		var biome := load("res://frontend/levels/biome/" + file) as Biome
		var scenery: Array[Color] = [biome.sky_top, biome.sky_bottom, biome.haze, biome.far_color, biome.mid_color, biome.near_color]
		for profile in ["neutral", "compassionate", "corrupt"]:
			var tint: Color = presentation.get_look(profile).background_tint
			for color in scenery:
				backgrounds.append(Color(clampf(color.r * tint.r, 0.0, 1.0), clampf(color.g * tint.g, 0.0, 1.0), clampf(color.b * tint.b, 0.0, 1.0)))
		ground.append_array([biome.grass, biome.grass_dark, biome.soil, biome.soil_dark, biome.rock, biome.rock_dark])
	var worst: float = 99.0
	var worst_name: String = ""
	for entry in [["warning glow", FloorHazardArt.GLOW], ["spike body", FloorHazardArt.SPIKE]]:
		for bg in backgrounds + ground:
			# The same rule as Phase 14e: drawn over a dark outline, so it reads if either tone stands out.
			var value: float = maxf(_contrast_of(entry[1], bg), _contrast_of(FloorHazardArt.OUTLINE, bg))
			if value < worst:
				worst = value
				worst_name = String(entry[0])
	print("MEASURE|spike contrast|worst %.2f (%s)|threshold %.1f|%d background and %d ground colours of the level 2 biomes" % [worst, worst_name, MIN_CONTRAST, backgrounds.size(), ground.size()])
	_check("contrast: the warning and the spikes read against the level 2 biomes (worst %.2f, >= %.1f)" % [worst, MIN_CONTRAST], worst >= MIN_CONTRAST and backgrounds.size() >= 30)
	var set_resource := TelegraphSet.get_default()
	var leap_style: TelegraphStyle = set_resource.get_style(TelegraphSet.KIND_BOSS_LEAP)
	_check("contrast: the leap marker has a telegraph style (shape marker, 62 px radius) and every telegraph kind is still present",
		leap_style != null and leap_style.shape == TelegraphStyle.Shape.MARKER and is_equal_approx(leap_style.size, 62.0) and set_resource.has_all_kinds())


# ---------------------------------------------------------------------------------------------
# No leaked nodes
# ---------------------------------------------------------------------------------------------

func _test_leaks() -> void:
	_clean_state()
	var counts: Array[int] = []
	for round in 5:
		var level: LevelBase = await _boss_fight(true)
		_damage_boss_to_phase_two(level)
		var leaps: Array[LeapPattern] = _leap_patterns(level.boss)
		leaps[1].cooldown_left = 0.0
		leaps[1].forced_first = Vector2(5350.0, 466.0)
		level.boss._set_state(BossBase.State.IDLE)
		await _physics(100)
		level.player.story_invulnerable = true
		level.boss.health.kill()
		await _physics(30)
		level.free()
		await _frames(4)
		for projectile in get_tree().root.find_children("*", "Projectile", true, false):
			projectile.free()
		await _frames(2)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("MEASURE|node counts after repeated fights|%s" % str(counts))
	_check("leaks: no nodes are left behind after repeated fights with the leap, the spikes and the pads (%s)" % str(counts), counts[counts.size() - 1] <= counts[1] + 4)

extends Node
## Headless smoke test for Phase 12c: the player's ranged sword wave (config and tier resolution,
## input and cast flow, projectile behavior per tier, decision integration, HUD, tutorial step and
## the Level 1 gap). Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/wave_phase12c_smoke_test.tscn
## Uses a redirected save path; the AI service stays disabled; the real save is never touched.
## Projectiles are added to the current scene, which here is this test node.

const TEST_SAVE: String = "user://test_save_phase12c.json"
const CONFIG: SwordWaveConfig = preload("res://backend/player/default_sword_wave_config.tres")
const DEFAULT_REGISTRY: SceneRegistry = preload("res://backend/progression/default_scene_registry.tres")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const WAVE_SCENE: PackedScene = preload("res://backend/combat/sword_wave_projectile.tscn")
const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://backend/combat/projectile.tscn")
const ENEMY_PROJECTILE_STATS: ProjectileStats = preload("res://backend/combat/stats/enemy_projectile_stats.tres")
const DUMMY_SCENE: PackedScene = preload("res://frontend/scenes/test/training_dummy.tscn")
const MELEE_SCENE: PackedScene = preload("res://backend/enemies/melee_enemy.tscn")
const BOSS_TWO: PackedScene = preload("res://backend/bosses/boss_two.tscn")
const HUD_SCENE: PackedScene = preload("res://frontend/ui/player_health_hud.tscn")
const TUTORIAL_SCENE: PackedScene = preload("res://frontend/levels/tutorial.tscn")
const LEVEL_1_SCENE: PackedScene = preload("res://frontend/levels/level_1.tscn")
const FLOOR_Y: float = 300.0
const PLAYER_HALF_HEIGHT: float = 26.0
const PLAYER_HALF_WIDTH: float = 14.0
const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash", "attack", "wave"]
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const EXPECTED_ACTIONS: Array[String] = ["attack", "dash", "heavy_attack", "jump", "move_left", "move_right", "pause", "wave"]
const DASH_DELAY: float = 0.3

var failures: int = 0
var real_save_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig


func _ready() -> void:
	ai_config.enabled = false
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


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _release_actions() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _clean_state() -> void:
	_release_actions()
	get_tree().paused = false
	PauseLock.reset(get_tree())
	SaveSystem.purge()
	GameState.set_adaptive_config(null)
	GameState.start_new_game()
	GameState.autosave_enabled = true
	_free_projectiles()


func _free_projectiles() -> void:
	for child in get_children():
		if child is Projectile:
			child.free()


func _projectiles() -> Array[Projectile]:
	var result: Array[Projectile] = []
	for child in get_children():
		if child is Projectile and not child.is_queued_for_deletion():
			result.append(child as Projectile)
	return result


func _add_floor(parent: Node, left: float = -4000.0, right: float = 4000.0) -> StaticBody2D:
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


## World with a floor and a player standing at `x`. Returns {world, player}.
func _make_world(x: float = 0.0) -> Dictionary:
	var world := Node2D.new()
	add_child(world)
	_add_floor(world)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(x, FLOOR_Y - PLAYER_HALF_HEIGHT)
	world.add_child(player)
	return {"world": world, "player": player}


func _make_dummy(parent: Node, x: float) -> TrainingDummy:
	var dummy := DUMMY_SCENE.instantiate() as TrainingDummy
	dummy.position = Vector2(x, FLOOR_Y - PLAYER_HALF_HEIGHT - 4.0)
	parent.add_child(dummy)
	return dummy


# --- Real input events ---

func _mouse_event(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	return event


func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event


func _tap_wave(use_mouse: bool = true) -> void:
	Input.parse_input_event(_mouse_event(true) if use_mouse else _key_event(KEY_U, true))
	await get_tree().physics_frame
	Input.parse_input_event(_mouse_event(false) if use_mouse else _key_event(KEY_U, false))


func _hit(player: Player, amount: int = 1) -> void:
	player.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.ENEMY))


func _run() -> void:
	_check("AI service disabled for the whole test", not ai_config.enabled)
	_test_config()
	_test_input_map_and_scans()
	await _test_cast_flow()
	await _test_blocking()
	await _test_cancel_and_respawn()
	await _test_tiers()
	await _test_pierce_and_world()
	await _test_teams_and_targets()
	await _test_decisions()
	await _test_hud()
	await _test_tutorial()
	await _test_level_1_gap()
	_clean_state()
	SaveSystem.purge()
	_check("real save file untouched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- Config / tier resolution ---

func _decision(fragment_id: Variant, choice: Variant) -> Dictionary:
	return {"fragment_id": fragment_id, "boss_id": "x", "level": 1, "choice": choice}


func _test_config() -> void:
	var rules: Dictionary = CONFIG.upgrade_rules
	_check("config: three tiers and the default rules", CONFIG.tiers.size() == 3 and rules == {"fragment_level_1": "kept", "fragment_level_2": "kept"} and CONFIG.projectile_scene != null)
	var t0: SwordWaveTier = CONFIG.get_tier(0)
	var t1: SwordWaveTier = CONFIG.get_tier(1)
	var t2: SwordWaveTier = CONFIG.get_tier(2)
	_check("config: tier table", t0.damage == 1 and t0.speed == 520.0 and t0.lifetime == 0.9 and t0.size_scale == 1.0 and t0.pierce_count == 0 and t0.cooldown == 1.0
		and t1.damage == 1 and t1.speed == 580.0 and t1.lifetime == 1.1 and t1.size_scale == 1.35 and t1.pierce_count == 1 and t1.cooldown == 0.9
		and t2.damage == 2 and t2.speed == 640.0 and t2.lifetime == 1.3 and t2.size_scale == 1.7 and t2.pierce_count == 2 and t2.cooldown == 1.2)
	_check("config: timings", CONFIG.startup_time == 0.12 and CONFIG.recovery_time == 0.2 and CONFIG.horizontal_speed_multiplier == 0.4 and CONFIG.can_cast_in_air
		and CONFIG.input_buffer_time == 0.12 and CONFIG.spawn_offset == Vector2(28.0, -4.0))
	_check("tier: no decisions -> 0", CONFIG.resolve_tier([]) == 0)
	_check("tier: level 1 kept -> 1", CONFIG.resolve_tier([_decision("fragment_level_1", "kept")]) == 1)
	_check("tier: level 1 and 2 kept -> 2", CONFIG.resolve_tier([_decision("fragment_level_1", "kept"), _decision("fragment_level_2", "kept")]) == 2)
	_check("tier: released decisions -> 0", CONFIG.resolve_tier([_decision("fragment_level_1", "released"), _decision("fragment_level_2", "released")]) == 0)
	_check("tier: level 3 kept has no effect", CONFIG.resolve_tier([_decision("fragment_level_3", "kept")]) == 0)
	_check("tier: all three kept -> 2 (level 3 ignored)", CONFIG.resolve_tier([_decision("fragment_level_1", "kept"), _decision("fragment_level_2", "kept"), _decision("fragment_level_3", "kept")]) == 2)
	_check("tier: mixed released/kept counts only the kept", CONFIG.resolve_tier([_decision("fragment_level_1", "released"), _decision("fragment_level_2", "kept")]) == 1)
	_check("tier: unknown ids ignored", CONFIG.resolve_tier([_decision("fragment_zzz", "kept"), _decision("", "kept")]) == 0)
	_check("tier: invalid entries ignored", CONFIG.resolve_tier([1, "x", null, {}, {"fragment_id": 5, "choice": "kept"}, {"fragment_id": "fragment_level_1"},
		{"choice": "kept"}, {"fragment_id": "fragment_level_1", "choice": 7}, [1, 2]]) == 0)
	_check("tier: each fragment id counts once", CONFIG.resolve_tier([_decision("fragment_level_1", "kept"), _decision("fragment_level_1", "kept")]) == 1)
	_check("tier: a repeated id with a different choice counts only once for its matching entry",
		CONFIG.resolve_tier([_decision("fragment_level_1", "released"), _decision("fragment_level_1", "kept")]) == 1)
	var many: SwordWaveConfig = CONFIG.duplicate() as SwordWaveConfig
	many.upgrade_rules = {"a": "kept", "b": "kept", "c": "kept", "d": "kept", "e": "kept"}
	_check("tier: never exceeds tiers.size() - 1", many.resolve_tier([_decision("a", "kept"), _decision("b", "kept"), _decision("c", "kept"), _decision("d", "kept"), _decision("e", "kept")]) == 2)
	var flipped: SwordWaveConfig = CONFIG.duplicate() as SwordWaveConfig
	flipped.upgrade_rules = {"fragment_level_1": "released", "fragment_level_2": "released"}
	_check("tier: rules edited to 'released' flip the behavior", flipped.resolve_tier([_decision("fragment_level_1", "released"), _decision("fragment_level_2", "released")]) == 2
		and flipped.resolve_tier([_decision("fragment_level_1", "kept")]) == 0)
	_check("tier: the original resource is not changed by editing a duplicate", CONFIG.upgrade_rules["fragment_level_1"] == "kept")
	_check("get_tier clamps", CONFIG.get_tier(-4) == t0 and CONFIG.get_tier(99) == t2)
	for index in CONFIG.tiers.size():
		var tier: SwordWaveTier = CONFIG.get_tier(index)
		var stats: ProjectileStats = CONFIG.build_projectile_stats(index)
		_check("build_projectile_stats copies tier %d" % index, stats.speed == tier.speed and stats.damage == tier.damage and stats.lifetime == tier.lifetime
			and stats.size_scale == tier.size_scale and stats.pierce_count == tier.pierce_count and stats.knockback == tier.knockback and stats.tint == tier.tint
			and stats.destroy_on_hit and stats.destroy_on_world and stats.gravity_scale == 0.0)
	# Sustained damage per second must stay below the sword's.
	var player_stats: PlayerStats = load("res://backend/player/default_player_stats.tres") as PlayerStats
	var sword_dps: float = float(player_stats.attack_damage) / (player_stats.attack_startup_time + player_stats.attack_active_time + player_stats.attack_recovery_time + player_stats.attack_cooldown)
	var all_below: bool = true
	var report: PackedStringArray = PackedStringArray()
	for index in CONFIG.tiers.size():
		var tier: SwordWaveTier = CONFIG.get_tier(index)
		var dps: float = float(tier.damage) / maxf(tier.cooldown, CONFIG.startup_time + CONFIG.recovery_time)
		report.append("tier %d = %.2f" % [index, dps])
		all_below = all_below and dps < sword_dps
	print("SUSTAINED DPS: sword %.2f | %s" % [sword_dps, " | ".join(report)])
	_check("sanity: every tier's sustained damage is below the sword's", all_below)


func _test_input_map_and_scans() -> void:
	var events: Array[InputEvent] = InputMap.action_get_events("wave")
	var has_right_mouse: bool = false
	var has_u: bool = false
	for event in events:
		var mouse := event as InputEventMouseButton
		var key := event as InputEventKey
		if mouse != null and mouse.button_index == MOUSE_BUTTON_RIGHT:
			has_right_mouse = true
		if key != null and key.physical_keycode == KEY_U:
			has_u = true
	_check("input: wave is bound to the right mouse button and U only", events.size() == 2 and has_right_mouse and has_u)
	var custom: Array[String] = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and not String(action).begins_with("spatial_editor"):
			custom.append(String(action))
	custom.sort()
	_check("input: no action other than wave and heavy_attack (Phase 13c) was added", custom == EXPECTED_ACTIONS, str(custom))
	var key_regex: RegEx = RegEx.create_from_string("KEY_[A-Z0-9_]+")
	var seen_level: Array[String] = _keys_in("res://backend/progression/level_debug.gd", key_regex)
	var seen_boss: Array[String] = _keys_in("res://frontend/scenes/test/boss_test.gd", key_regex)
	var absolute: RegEx = RegEx.create_from_string("(^|[^A-Za-z])[A-Za-z]:[\\\\/]|/Users/|/home/")
	for path in ["res://backend/player/sword_wave_caster.gd", "res://backend/player/sword_wave_config.gd", "res://backend/player/sword_wave_tier.gd", "res://backend/player/player.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		_check("scan: %s has no absolute paths and no keys" % path.get_file(), absolute.search(text) == null and key_regex.search(text) == null)
	var player_text: String = FileAccess.get_file_as_string("res://backend/player/player.gd").to_lower()
	_check("player: holds no reference to the HUD", not player_text.contains("hud") and not player_text.contains("playerhealthhud"))


func _keys_in(path: String, regex: RegEx) -> Array[String]:
	var found: Dictionary = {}
	for match_result in regex.search_all(FileAccess.get_file_as_string(path)):
		found[match_result.get_string()] = true
	var keys: Array[String] = []
	for key: Variant in found.keys():
		keys.append(String(key))
	keys.sort()
	return keys


# --- Cast flow ---

func _test_cast_flow() -> void:
	_clean_state()
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	var caster: SwordWaveCaster = player.wave_caster
	await _physics(5)
	_check("cast: the caster exists with the default config and tier 0", caster != null and caster.config == CONFIG and caster.get_effective_tier() == 0)
	var casts: Array[int] = []
	player.wave_cast.connect(func(tier: int) -> void: casts.append(tier))
	await _tap_wave(true)
	var entered: bool = await _wait_until(func() -> bool: return player.state == Player.State.WAVE, 5)
	_check("cast: the player enters the WAVE state", entered)
	_check("cast: nothing is spawned during startup", _projectiles().is_empty())
	await _physics(10)
	var waves: Array[Projectile] = _projectiles()
	_check("cast: exactly one projectile after startup (right mouse button)", waves.size() == 1 and casts == [0])
	var wave: Projectile = waves[0]
	_check("cast: the projectile is not a child of the player and lives in the current scene", wave.get_parent() == get_tree().current_scene and not player.is_ancestor_of(wave))
	_check("cast: PLAYER team, flying right", wave.hitbox.team == CombatLayers.Team.PLAYER and wave.velocity.x > 0.0 and is_zero_approx(wave.velocity.y))
	_check("cast: spawned at the configured offset", absf(wave.global_position.x - (player.global_position.x + 28.0)) < 40.0 and absf(wave.global_position.y - (player.global_position.y - 4.0)) < 2.0,
		"%s vs %s" % [wave.global_position, player.global_position])
	_check("cast: the cooldown started at the spawn", caster.get_cooldown_remaining() > 0.5 and caster.get_cooldown_total() == 1.0)
	await _wait_until(func() -> bool: return player.state != Player.State.WAVE, 60)
	_check("cast: recovery returns to a locomotion state", player.state == Player.State.IDLE)
	# Second press during the cooldown does nothing.
	await _tap_wave(true)
	await _physics(25)
	_check("cooldown: a second cast is blocked", _projectiles().size() <= 1 and casts.size() == 1)
	await _wait_until(func() -> bool: return caster.get_cooldown_remaining() <= 0.0, 120)
	await _physics(20)
	_free_projectiles()
	await _tap_wave(false)
	await _physics(12)
	_check("cooldown: allowed again after it ends (key U)", casts.size() == 2 and _projectiles().size() == 1)
	# Facing left.
	await _wait_until(func() -> bool: return caster.get_cooldown_remaining() <= 0.0 and player.state == Player.State.IDLE, 120)
	_free_projectiles()
	player.facing_direction = -1
	await _tap_wave(true)
	await _physics(12)
	var left_waves: Array[Projectile] = _projectiles()
	_check("cast: direction follows the facing (left)", left_waves.size() == 1 and left_waves[0].velocity.x < 0.0 and left_waves[0].global_position.x < player.global_position.x)
	# Input buffer: pressed slightly before the cooldown ends.
	await _wait_until(func() -> bool: return caster.get_cooldown_remaining() > 0.0 and caster.get_cooldown_remaining() < 0.07 and player.state == Player.State.IDLE, 120)
	_free_projectiles()
	var before: int = casts.size()
	await _tap_wave(true)
	_check("buffer: not cast yet (still on cooldown)", casts.size() == before)
	await _physics(14)
	_check("buffer: the early press casts as soon as the cooldown ends", casts.size() == before + 1 and _projectiles().size() == 1, "casts %d -> %d" % [before, casts.size()])
	# Casting in the air.
	await _wait_until(func() -> bool: return caster.get_cooldown_remaining() <= 0.0 and player.state == Player.State.IDLE, 150)
	_free_projectiles()
	player.global_position.y -= 200.0
	player.velocity = Vector2.ZERO
	await _physics(3)
	var airborne: bool = not player.is_on_floor()
	var air_before: int = casts.size()
	await _tap_wave(true)
	await _physics(11)
	_check("cast: works in the air", airborne and casts.size() == air_before + 1 and _projectiles().size() == 1)
	# Horizontal speed reduced while casting.
	await _wait_until(func() -> bool: return player.is_on_floor() and caster.get_cooldown_remaining() <= 0.0, 240)
	_free_projectiles()
	Input.action_press("move_right")
	await _physics(40)
	var run_speed: float = player.velocity.x
	await _tap_wave(true)
	await _physics(14)
	var cast_speed: float = player.velocity.x
	_check("cast: horizontal speed is reduced while casting (%.0f -> %.0f)" % [run_speed, cast_speed], player.state == Player.State.WAVE
		and cast_speed <= player.stats.max_speed * CONFIG.horizontal_speed_multiplier + 5.0 and run_speed > cast_speed + 100.0)
	var facing_while_casting: int = player.facing_direction
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _physics(3)
	_check("cast: facing is locked during the cast", player.state != Player.State.WAVE or player.facing_direction == facing_while_casting)
	Input.action_release("move_left")
	(parts["world"] as Node).free()
	_free_projectiles()


# --- Blocking ---

func _casts_after(player: Player, frames: int) -> int:
	var count: Array[int] = [0]
	var handler: Callable = func(_tier: int) -> void: count[0] += 1
	player.wave_cast.connect(handler)
	await _physics(frames)
	player.wave_cast.disconnect(handler)
	return count[0]


func _test_blocking() -> void:
	# ATTACK
	_clean_state()
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	await _physics(5)
	Input.action_press("attack")
	await _physics(2)
	Input.action_release("attack")
	var in_attack: bool = player.state == Player.State.ATTACK
	await _tap_wave(true)
	var casts: int = await _casts_after(player, 40)
	_check("blocked: while ATTACKing", in_attack and casts == 0 and _projectiles().is_empty())
	(parts["world"] as Node).free()
	# DASH
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	await _physics(5)
	Input.action_press("dash")
	await _physics(2)
	Input.action_release("dash")
	var in_dash: bool = player.state == Player.State.DASH
	await _tap_wave(true)
	casts = await _casts_after(player, 40)
	_check("blocked: while DASHing", in_dash and casts == 0 and _projectiles().is_empty())
	(parts["world"] as Node).free()
	# HURT
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	await _physics(5)
	_hit(player)
	var in_hurt: bool = player.state == Player.State.HURT
	await _tap_wave(true)
	casts = await _casts_after(player, 40)
	_check("blocked: while HURT", in_hurt and casts == 0 and _projectiles().is_empty())
	(parts["world"] as Node).free()
	# DEAD
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	player.set_auto_respawn(false)
	await _physics(5)
	player.health.kill()
	await _tap_wave(true)
	casts = await _casts_after(player, 40)
	_check("blocked: while DEAD", player.state == Player.State.DEAD and casts == 0 and _projectiles().is_empty())
	(parts["world"] as Node).free()
	# Input locked
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	await _physics(5)
	player.set_input_locked(true)
	await _tap_wave(true)
	casts = await _casts_after(player, 30)
	player.set_input_locked(false)
	casts += await _casts_after(player, 20)
	_check("blocked: while input-locked (the press is not remembered either)", casts == 0 and _projectiles().is_empty())
	(parts["world"] as Node).free()
	# Paused tree
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	await _physics(5)
	get_tree().paused = true
	await _tap_wave(true)
	await _physics(30)
	get_tree().paused = false
	casts = await _casts_after(player, 30)
	_check("blocked: while the tree is paused", casts == 0 and _projectiles().is_empty())
	(parts["world"] as Node).free()
	# attack + wave on the same frame: the sword wins.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	await _physics(5)
	Input.parse_input_event(_key_event(KEY_J, true))
	Input.parse_input_event(_mouse_event(true))
	await _physics(3)
	var state_now: Player.State = player.state
	Input.parse_input_event(_key_event(KEY_J, false))
	Input.parse_input_event(_mouse_event(false))
	casts = await _casts_after(player, 40)
	_check("same frame: attack wins over wave", state_now == Player.State.ATTACK and casts == 0 and _projectiles().is_empty() and player.wave_caster.get_cooldown_remaining() == 0.0)
	(parts["world"] as Node).free()
	# No caster: pressing wave does nothing and does not fail.
	_clean_state()
	var plain: Player = PLAYER_SCENE.instantiate() as Player
	plain.get_node("SwordWaveCaster").free()
	var plain_world := Node2D.new()
	add_child(plain_world)
	_add_floor(plain_world)
	plain.position = Vector2(0.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	plain_world.add_child(plain)
	await _physics(3)
	await _tap_wave(true)
	await _physics(30)
	_check("no caster: the player works and simply has no wave", plain.wave_caster == null and _projectiles().is_empty() and plain.state == Player.State.IDLE)
	plain_world.free()


# --- Cancel / respawn ---

func _test_cancel_and_respawn() -> void:
	_clean_state()
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	var caster: SwordWaveCaster = player.wave_caster
	await _physics(5)
	# Hurt during startup.
	await _tap_wave(true)
	await _physics(2)
	var in_startup: bool = player.state == Player.State.WAVE and _projectiles().is_empty()
	_hit(player)
	await _physics(40)
	_check("hurt in startup: cast cancelled, no projectile, no cooldown consumed", in_startup and player.state != Player.State.WAVE and _projectiles().is_empty()
		and caster.get_cooldown_remaining() == 0.0)
	# Hurt during recovery.
	await _wait_until(func() -> bool: return not player.health.is_invulnerable() and player.state == Player.State.IDLE, 180)
	await _tap_wave(true)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 30)
	var spawned: Array[Projectile] = _projectiles()
	var in_recovery: bool = player.state == Player.State.WAVE
	_hit(player)
	await _physics(4)
	_check("hurt in recovery: the spawned projectile stays alive", in_recovery and spawned.size() == 1 and is_instance_valid(spawned[0]) and not spawned[0].is_queued_for_deletion()
		and player.state == Player.State.HURT)
	_check("hurt in recovery: the cooldown keeps running", caster.get_cooldown_remaining() > 0.0)
	# Death during startup.
	_free_projectiles()
	await _wait_until(func() -> bool: return not player.health.is_invulnerable() and player.state == Player.State.IDLE and caster.get_cooldown_remaining() <= 0.0, 300)
	await _tap_wave(true)
	await _physics(2)
	player.set_auto_respawn(false)
	player.health.kill()
	await _physics(30)
	_check("death in startup: no projectile", player.state == Player.State.DEAD and _projectiles().is_empty())
	# Respawn resets the cooldown and the cast state.
	player.respawn()
	_check("respawn: ready to cast and not in WAVE", caster.get_cooldown_remaining() == 0.0 and player.state != Player.State.WAVE)
	await _wait_until(func() -> bool: return not player.health.is_invulnerable(), 180)
	await _tap_wave(true)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 30)
	_check("respawn: a cooldown is running after a cast", caster.get_cooldown_remaining() > 0.0)
	player.respawn()
	_check("respawn: the cooldown is reset", caster.get_cooldown_remaining() == 0.0 and caster.get_cooldown_total() == 0.0)
	await _tap_wave(true)
	await _physics(2)
	player.respawn()
	await _physics(30)
	var after_respawn: int = _projectiles().size()
	_check("respawn during startup resets the cast state without a projectile", player.state != Player.State.WAVE and after_respawn <= 1)
	# Dash cancels a cast in startup.
	_free_projectiles()
	await _wait_until(func() -> bool: return caster.get_cooldown_remaining() <= 0.0 and player.state == Player.State.IDLE and not player.health.is_invulnerable(), 300)
	await _tap_wave(true)
	await _physics(2)
	Input.action_press("dash")
	await _physics(2)
	Input.action_release("dash")
	await _physics(20)
	_check("dash cancels a cast in startup (no projectile, no cooldown)", _projectiles().is_empty() and caster.get_cooldown_remaining() == 0.0)
	(parts["world"] as Node).free()
	_free_projectiles()


# --- Projectile per tier ---

func _wait_despawn(wave: Projectile, max_frames: int) -> Dictionary:
	var info := {"reason": &"", "x": 0.0, "hitbox_active": true}
	wave.despawned.connect(func(reason: StringName) -> void:
		info["reason"] = reason
		info["x"] = wave.global_position.x
		info["hitbox_active"] = wave.hitbox.is_active)
	await _wait_until(func() -> bool: return info["reason"] != &"", max_frames)
	return info


func _cast_now(player: Player, tier: int) -> Projectile:
	player.wave_caster.set_tier_override(tier)
	player.wave_caster.reset()
	await _tap_wave(true)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 40)
	var waves: Array[Projectile] = _projectiles()
	return waves[0] if not waves.is_empty() else null


func _test_tiers() -> void:
	_clean_state()
	for tier_index in CONFIG.tiers.size():
		var tier: SwordWaveTier = CONFIG.get_tier(tier_index)
		var tag: String = "tier %d" % tier_index
		var parts: Dictionary = _make_world()
		var player: Player = parts["player"]
		await _physics(5)
		var wave: Projectile = await _cast_now(player, tier_index)
		_check("%s: a wave was cast" % tag, wave != null)
		if wave == null:
			(parts["world"] as Node).free()
			continue
		var start_x: float = wave.global_position.x
		var world_shape := wave.get_node("CollisionShape2D") as CollisionShape2D
		var hit_shape := wave.hitbox.get_node("CollisionShape2D") as CollisionShape2D
		var fresh := WAVE_SCENE.instantiate() as Projectile
		var base_circle: float = (fresh.get_node("CollisionShape2D") as CollisionShape2D).shape.radius
		var base_rect: Vector2 = (fresh.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape.size
		fresh.free()
		_check("%s: size scale applied to the visual and both shapes" % tag, is_equal_approx(absf(wave.visual.scale.x), tier.size_scale) and is_equal_approx(wave.visual.scale.y, tier.size_scale)
			and is_equal_approx((world_shape.shape as CircleShape2D).radius, base_circle * tier.size_scale)
			and (hit_shape.shape as RectangleShape2D).size.is_equal_approx(base_rect * tier.size_scale))
		_check("%s: tint applied to the visual only" % tag, (wave.visual as Polygon2D).color == tier.tint)
		_check("%s: speed and damage from the tier" % tag, is_equal_approx(wave.velocity.length(), tier.speed) and wave.hitbox.damage == tier.damage and wave.hitbox.knockback == tier.knockback)
		var info: Dictionary = await _wait_despawn(wave, 200)
		var travelled: float = info["x"] - start_x
		print("%s: travelled %.1f px of %.1f (speed x lifetime)" % [tag, travelled, tier.speed * tier.lifetime])
		_check("%s: despawns by lifetime after speed x lifetime" % tag, info["reason"] == &"lifetime" and absf(travelled - tier.speed * tier.lifetime) <= tier.speed / 30.0)
		_check("%s: no hitbox left active" % tag, info["hitbox_active"] == false)
		(parts["world"] as Node).free()
		_free_projectiles()
	# Two simultaneous waves never share a shape; the shared scene resource is never modified.
	var a := WAVE_SCENE.instantiate() as Projectile
	var b := WAVE_SCENE.instantiate() as Projectile
	add_child(a)
	add_child(b)
	a.global_position = Vector2(0.0, -2000.0)
	b.global_position = Vector2(0.0, -3000.0)
	a.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, CONFIG.build_projectile_stats(2), null)
	b.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, CONFIG.build_projectile_stats(0), null)
	var a_hit := a.hitbox.get_node("CollisionShape2D") as CollisionShape2D
	var b_hit := b.hitbox.get_node("CollisionShape2D") as CollisionShape2D
	var third := WAVE_SCENE.instantiate() as Projectile
	var third_rect: Vector2 = (third.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape.size
	_check("two live waves do not share shapes", a_hit.shape != b_hit.shape and (a.get_node("CollisionShape2D") as CollisionShape2D).shape != (b.get_node("CollisionShape2D") as CollisionShape2D).shape
		and (a_hit.shape as RectangleShape2D).size.x > (b_hit.shape as RectangleShape2D).size.x and (b_hit.shape as RectangleShape2D).size == third_rect)
	var scene_probe := WAVE_SCENE.instantiate() as Projectile
	var scene_rect: Vector2 = (scene_probe.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape.size
	scene_probe.free()
	_check("the scene's shared shape resource is untouched", scene_rect == Vector2(16.0, 44.0) and third_rect == Vector2(16.0, 44.0))
	third.free()
	a.free()
	b.free()
	_check("tier override clamps", _override_effective(7) == 2 and _override_effective(-1) == 0)


func _override_effective(value: int) -> int:
	var caster := SwordWaveCaster.new()
	caster.set_tier_override(value)
	caster.config = CONFIG
	var tier: int = caster.get_effective_tier()
	caster.free()
	return tier


# --- Hits, pierce, world ---

func _test_pierce_and_world() -> void:
	_clean_state()
	for tier_index in CONFIG.tiers.size():
		var tier: SwordWaveTier = CONFIG.get_tier(tier_index)
		var tag: String = "tier %d" % tier_index
		var parts: Dictionary = _make_world()
		var player: Player = parts["player"]
		var world: Node2D = parts["world"]
		var dummies: Array[TrainingDummy] = []
		for i in 4:
			dummies.append(_make_dummy(world, 260.0 + 130.0 * i))
		var infos: Array[DamageInfo] = []
		dummies[0].health.damaged.connect(func(info: DamageInfo) -> void: infos.append(info))
		await _physics(5)
		var wave: Projectile = await _cast_now(player, tier_index)
		var info: Dictionary = await _wait_despawn(wave, 240)
		await _physics(10)
		var lost: Array[int] = []
		for dummy in dummies:
			lost.append(dummy.health.max_health - dummy.health.current_health)
		var expected_hits: int = tier.pierce_count + 1
		var expected: Array[int] = []
		for i in 4:
			expected.append(tier.damage if i < expected_hits else 0)
		print("%s: pierce %d -> HP lost per dummy %s, despawn '%s'" % [tag, tier.pierce_count, str(lost), String(info["reason"])])
		_check("%s: damage %d lands once per target and pierce %d passes through %d" % [tag, tier.damage, tier.pierce_count, tier.pierce_count], lost == expected)
		_check("%s: despawns on the hit that exceeds the pierce count" % tag, info["reason"] == &"hit" and info["hitbox_active"] == false)
		_check("%s: knockback pushes away from the caster" % tag, infos.size() == 1 and infos[0].knockback == Vector2(tier.knockback.x, tier.knockback.y))
		world.free()
		_free_projectiles()
	# Wall: despawns on world contact.
	_clean_state()
	var parts_wall: Dictionary = _make_world()
	var wall_player: Player = parts_wall["player"]
	var wall_world: Node2D = parts_wall["world"]
	var wall := StaticBody2D.new()
	wall.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	wall.position = Vector2(300.0, FLOOR_Y - 100.0)
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(40.0, 400.0)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	wall_world.add_child(wall)
	await _physics(5)
	var wall_wave: Projectile = await _cast_now(wall_player, 2)
	var wall_info: Dictionary = await _wait_despawn(wall_wave, 120)
	_check("world: despawns on a wall, no hitbox active", wall_info["reason"] == &"world" and wall_info["hitbox_active"] == false and wall_info["x"] < 300.0, str(wall_info))
	wall_world.free()
	_free_projectiles()


# --- Teams and targets ---

func _test_teams_and_targets() -> void:
	_clean_state()
	# A PLAYER-team wave never damages the player (launched right on top of them).
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	await _physics(5)
	var self_wave := WAVE_SCENE.instantiate() as Projectile
	add_child(self_wave)
	self_wave.global_position = player.global_position
	self_wave.launch(Vector2.ZERO + Vector2.RIGHT, CombatLayers.Team.PLAYER, CONFIG.build_projectile_stats(2), player)
	await _physics(10)
	_check("team: a player wave never damages the player", player.health.current_health == player.health.max_health and player.state != Player.State.HURT)
	_free_projectiles()
	# An enemy projectile still behaves as before (pierce 0, scale 1, tint untouched).
	var enemy_shot := ENEMY_PROJECTILE_SCENE.instantiate() as Projectile
	add_child(enemy_shot)
	enemy_shot.global_position = player.global_position + Vector2(-60.0, 0.0)
	enemy_shot.launch(Vector2.RIGHT, CombatLayers.Team.ENEMY, ENEMY_PROJECTILE_STATS, null)
	var enemy_info: Dictionary = await _wait_despawn(enemy_shot, 60)
	_check("regression: an enemy projectile still hurts the player once and despawns on hit", enemy_info["reason"] == &"hit"
		and player.health.current_health == player.health.max_health - ENEMY_PROJECTILE_STATS.damage)
	_check("regression: default stats keep scale 1, no pierce and no tint", ENEMY_PROJECTILE_STATS.pierce_count == 0 and ENEMY_PROJECTILE_STATS.size_scale == 1.0 and ENEMY_PROJECTILE_STATS.tint.a == 0.0)
	var plain_shot := ENEMY_PROJECTILE_SCENE.instantiate() as Projectile
	add_child(plain_shot)
	plain_shot.global_position = Vector2(0.0, -2000.0)
	plain_shot.launch(Vector2.RIGHT, CombatLayers.Team.ENEMY, ENEMY_PROJECTILE_STATS, null)
	var plain_circle: float = (plain_shot.get_node("CollisionShape2D") as CollisionShape2D).shape.radius
	_check("regression: an unscaled projectile keeps its original shape and color", plain_circle == 6.0 and (plain_shot.visual as Polygon2D).color == Color(1, 0.55, 0.15, 1)
		and (plain_shot.visual as Polygon2D).scale == Vector2.ONE)
	plain_shot.free()
	(parts["world"] as Node).free()
	_free_projectiles()
	# A melee enemy dies to a wave from a distance.
	_clean_state()
	var far: Dictionary = _make_world(-500.0)
	var far_player: Player = far["player"]
	var far_world: Node2D = far["world"]
	var melee := MELEE_SCENE.instantiate() as EnemyBase
	melee.position = Vector2(0.0, FLOOR_Y - 24.0)
	far_world.add_child(melee)
	await _physics(5)
	melee.health.current_health = 2
	var died: Array[bool] = [false]
	melee.health.died.connect(func() -> void: died[0] = true)
	var far_wave: Projectile = await _cast_now(far_player, 2)
	var far_info: Dictionary = await _wait_despawn(far_wave, 200)
	_check("target: a tier 2 wave kills a melee enemy 500 px away", died[0] and far_info["reason"] == &"lifetime", "a tier 2 wave pierces: %s" % str(far_info))
	far_world.free()
	_free_projectiles()
	# A boss takes the hit without losing its current pattern.
	_clean_state()
	var boss_world := Node2D.new()
	add_child(boss_world)
	_add_floor(boss_world)
	var target := Node2D.new()
	target.position = Vector2(300.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	boss_world.add_child(target)
	var boss := BOSS_TWO.instantiate() as BossBase
	boss.rng_seed = 11
	boss.position = Vector2(390.0, FLOOR_Y - 44.0)
	boss_world.add_child(boss)
	await _physics(3)
	boss.activate(target)
	var in_pattern: bool = await _wait_until(func() -> bool: return boss.state == BossBase.State.PATTERN, 600)
	var pattern_before: BossPattern = boss.current_pattern
	var hp_before: int = boss.health.current_health
	var boss_shot := WAVE_SCENE.instantiate() as Projectile
	add_child(boss_shot)
	boss_shot.global_position = boss.global_position + Vector2(-120.0, 0.0)
	boss_shot.launch(Vector2.RIGHT, CombatLayers.Team.PLAYER, CONFIG.build_projectile_stats(0), null)
	await _wait_until(func() -> bool: return boss.health.current_health < hp_before, 40)
	_check("target: a wave damages a boss through its hurtbox without interrupting the pattern", in_pattern and boss.health.current_health == hp_before - 1
		and boss.state == BossBase.State.PATTERN and boss.current_pattern == pattern_before)
	boss_world.free()
	_free_projectiles()


# --- Decisions integration ---

func _test_decisions() -> void:
	_clean_state()
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	var caster: SwordWaveCaster = player.wave_caster
	await _physics(3)
	_check("decisions: tier 0 at the start", caster.current_tier == 0)
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	_check("decisions: kept level 1 -> tier 1 immediately, no restart", caster.current_tier == 1 and caster.get_effective_tier() == 1)
	GameState.record_decision("fragment_level_2", "boss_two", 2, GameState.CHOICE_KEPT)
	_check("decisions: kept level 2 -> tier 2", caster.current_tier == 2)
	GameState.record_decision("fragment_level_3", "boss_three", 3, GameState.CHOICE_KEPT)
	_check("decisions: level 3 changes nothing", caster.current_tier == 2)
	var snapshot: Dictionary = GameState.to_dict()
	_check("decisions: exactly seven save keys", snapshot.keys().size() == SAVE_KEYS.size() and SAVE_KEYS.all(func(key: String) -> bool: return snapshot.has(key)))
	GameState.set_checkpoint("level_3_start")
	_check("decisions: the save is written", GameState.save_to_disk())
	var text: String = _read_file(TEST_SAVE).to_lower()
	var parsed: Variant = JSON.parse_string(text)
	_check("decisions: the save has seven keys and no wave data", parsed is Dictionary and (parsed as Dictionary).keys().size() == SAVE_KEYS.size() and not text.contains("wave") and not text.contains("tier"))
	GameState.reset_run()
	_check("decisions: reset_run returns the tier to 0", caster.current_tier == 0)
	GameState.load_from_dict(snapshot)
	_check("decisions: loading a save restores the tier from the decisions", caster.current_tier == 2)
	GameState.start_new_game()
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_RELEASED)
	_check("decisions: a released decision gives no tier", caster.current_tier == 0)
	caster.set_tier_override(1)
	_check("decisions: the test override wins and clears with -1", caster.get_effective_tier() == 1)
	caster.set_tier_override(-1)
	_check("decisions: clearing the override returns to the real tier", caster.get_effective_tier() == 0)
	# A new player (new level) reads the tier at ready.
	GameState.start_new_game()
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	var second := PLAYER_SCENE.instantiate() as Player
	(parts["world"] as Node).add_child(second)
	await _physics(2)
	_check("decisions: a freshly loaded player starts at the right tier", second.wave_caster.current_tier == 1)
	var signals_before: int = GameState.decision_recorded.get_connections().size()
	second.free()
	_check("decisions: the caster disconnects from GameState when freed", GameState.decision_recorded.get_connections().size() == signals_before - 1)
	(parts["world"] as Node).free()
	_clean_state()


# --- HUD ---

func _test_hud() -> void:
	_clean_state()
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	var hud := HUD_SCENE.instantiate() as PlayerHealthHud
	add_child(hud)
	hud.bind(player)
	await _physics(3)
	_check("hud: the cooldown bar is visible and full when ready", hud.wave_bar.visible and is_equal_approx(hud.wave_bar.value, 1.0))
	_check("hud: tinted by the tier", hud.wave_bar.modulate.is_equal_approx(CONFIG.get_tier(0).tint))
	await _tap_wave(true)
	await _physics(20)
	var during: float = hud.wave_bar.value
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var later: float = hud.wave_bar.value
	_check("hud: the bar empties at the cast and refills with the cooldown (%.2f -> %.2f)" % [during, later], during < 0.5 and later > during)
	await _wait_until(func() -> bool: return player.wave_caster.get_cooldown_remaining() <= 0.0, 120)
	await get_tree().process_frame
	_check("hud: full again when the cooldown ends", is_equal_approx(hud.wave_bar.value, 1.0))
	player.wave_caster.set_tier_override(2)
	await get_tree().process_frame
	_check("hud: tint follows the tier", hud.wave_bar.modulate.is_equal_approx(CONFIG.get_tier(2).tint))
	hud.free()
	_free_projectiles()
	(parts["world"] as Node).free()
	# Without a caster the bar stays hidden.
	var bare: Player = PLAYER_SCENE.instantiate() as Player
	bare.get_node("SwordWaveCaster").free()
	var bare_world := Node2D.new()
	add_child(bare_world)
	bare_world.add_child(bare)
	var bare_hud := HUD_SCENE.instantiate() as PlayerHealthHud
	add_child(bare_hud)
	bare_hud.bind(bare)
	await _physics(3)
	_check("hud: hidden when the player has no caster", not bare_hud.wave_bar.visible)
	bare_hud.free()
	bare_world.free()


# --- Tutorial ---

func _test_tutorial() -> void:
	_clean_state()
	SceneManager.dry_run = true
	var registry := SceneRegistry.new()
	registry.scenes = DEFAULT_REGISTRY.scenes.duplicate()
	registry.fade_out_time = 0.0
	registry.fade_in_time = 0.0
	SceneManager.set_registry(registry)
	var tutorial := TUTORIAL_SCENE.instantiate() as LevelBase
	add_child(tutorial)
	await _physics(5)
	var controller: TutorialController = tutorial.get_node("TutorialController")
	var player: Player = tutorial.player
	var ids: Array[String] = []
	for step in controller.steps:
		ids.append(String(step["id"]))
	_check("tutorial: the wave step is followed by the Phase 13c steps", ids == ["move", "jump", "dash", "attack", "hit_dummy", "wave", "heavy", "dash_slash"], str(ids))
	_check("tutorial: the wave prompt resolves its key from the InputMap", controller.build_text(String(controller.steps[5]["text"])).contains("U") and not controller.build_text(String(controller.steps[5]["text"])).contains("{"))
	# A real cast before its step does not count.
	await _tap_wave(true)
	await _physics(15)
	_check("tutorial: a real cast before the wave step does not complete anything", controller.current_index == 0)
	await _wait_until(func() -> bool: return player.wave_caster.get_cooldown_remaining() <= 0.0 and player.state == Player.State.IDLE, 120)
	_free_projectiles()
	player.dash_started.emit()
	player.attack_started.emit()
	player.state_changed.emit(Player.State.IDLE, Player.State.JUMP)
	controller.current_index = 0
	controller._moved = 999.0
	await _physics(2)
	_check("tutorial: move completes", controller.get_current_step_id() == "jump")
	player.state_changed.emit(Player.State.IDLE, Player.State.JUMP)
	player.dash_started.emit()
	player.attack_started.emit()
	_check("tutorial: jump, dash and attack complete in order", controller.get_current_step_id() == "hit_dummy")
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: the exit stays closed", SceneManager.last_requested_scene_id == "" and not controller.is_completed)
	controller.dummy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	_check("tutorial: the dummy hit leads to the wave step", controller.get_current_step_id() == "wave" and not controller.is_completed)
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: the exit still requires the wave step", SceneManager.last_requested_scene_id == "" and not controller.is_completed)
	await _wait_until(func() -> bool: return controller._feedback_left <= 0.0, 120)
	await _tap_wave(false)
	var completed: bool = await _wait_until(func() -> bool: return controller.current_index == 6, 40)
	_check("tutorial: a real cast completes the wave step (the heavy and dash slash steps follow)", completed and controller.get_current_step_id() == "heavy" and not controller.is_completed)
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: the exit stays locked until the last step", SceneManager.last_requested_scene_id == "" and not controller.is_completed)
	tutorial.free()
	_free_projectiles()
	await get_tree().process_frame
	while SceneManager.is_transitioning():
		await get_tree().process_frame
	SceneManager.dry_run = false
	_clean_state()


# --- Level 1 gap ---

func _measure_jump(player: Player, dash_delay: float) -> void:
	_release_actions()
	player.global_position = Vector2(-300.0, FLOOR_Y - PLAYER_HALF_HEIGHT)
	player.velocity = Vector2.ZERO
	await _physics(30)
	Input.action_press("move_right")
	while player.global_position.x < -4.0:
		await get_tree().physics_frame
	Input.action_press("jump")
	var elapsed: float = 0.0
	var dashed: bool = false
	while elapsed < 3.0:
		await get_tree().physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
		if dash_delay >= 0.0 and not dashed and elapsed >= dash_delay:
			Input.action_press("dash")
			dashed = true
		elif dashed:
			Input.action_release("dash")
		if elapsed > 0.1 and player.global_position.y >= FLOOR_Y - PLAYER_HALF_HEIGHT and player.velocity.y >= 0.0:
			break
	_release_actions()


func _test_level_1_gap() -> void:
	_clean_state()
	var level := LEVEL_1_SCENE.instantiate() as LevelBase
	var content: Node = level.get_node("Content")
	var start_floor: PlaceholderPlatform = content.get_node("FloorStart")
	var end_floor: PlaceholderPlatform = content.get_node("FloorEnd")
	var gap_left: float = start_floor.position.x + start_floor.size.x * 0.5
	var gap_right: float = end_floor.position.x - end_floor.size.x * 0.5
	var gap: float = gap_right - gap_left
	var kill_zone: KillZone = content.get_node("KillZone")
	var zone_left: float = kill_zone.position.x - kill_zone.size.x * 0.5
	var zone_right: float = kill_zone.position.x + kill_zone.size.x * 0.5
	_check("level 1: the gap is 285 px", is_equal_approx(gap, 285.0), "%.1f" % gap)
	_check("level 1: the landing platform keeps its right edge (5400) and top (600)", is_equal_approx(end_floor.position.x + end_floor.size.x * 0.5, 5400.0)
		and is_equal_approx(end_floor.position.y - end_floor.size.y * 0.5, 600.0) and is_equal_approx(gap_left, 2400.0))
	_check("level 1: the KillZone still covers the gap from below", zone_left <= gap_left and zone_right >= gap_right and kill_zone.position.y - kill_zone.size.y * 0.5 > 600.0)
	level.free()
	var results: Dictionary = {}
	for use_dash in [false, true]:
		var world := Node2D.new()
		add_child(world)
		_add_floor(world, -4000.0, 0.0)
		_add_floor(world, gap, gap + 2000.0)
		var runner := PLAYER_SCENE.instantiate() as Player
		world.add_child(runner)
		await _physics(2)
		await _measure_jump(runner, DASH_DELAY if use_dash else -1.0)
		await _physics(60)
		results[use_dash] = runner.global_position.x > gap and runner.global_position.y < FLOOR_Y
		_check("level 1 gap: %s %s (x %.0f y %.0f)" % ["jump + dash" if use_dash else "jump alone", "crosses" if results[use_dash] else "falls", runner.global_position.x, runner.global_position.y],
			results[use_dash] == use_dash)
		_release_actions()
		world.free()
	# Early dashes (the sweep minimum was ~298 px of reach) are no longer the edge case.
	var early_ok: bool = true
	for delay in [0.2, 0.3, 0.4, 0.5]:
		var world := Node2D.new()
		add_child(world)
		_add_floor(world, -4000.0, 0.0)
		_add_floor(world, gap, gap + 2000.0)
		var runner := PLAYER_SCENE.instantiate() as Player
		world.add_child(runner)
		await _physics(2)
		await _measure_jump(runner, delay)
		await _physics(60)
		var crossed: bool = runner.global_position.x > gap and runner.global_position.y < FLOOR_Y
		early_ok = early_ok and crossed
		_check("level 1 gap: jump + dash at %.1fs crosses" % delay, crossed)
		_release_actions()
		world.free()
	_check("level 1 gap: every dash delay from 0.2 to 0.5 s crosses", early_ok)
	_clean_state()

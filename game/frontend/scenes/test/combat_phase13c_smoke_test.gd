extends Node
## Headless smoke test for Phase 13c: contact damage (enemies and bosses), player health 8, the heavy
## slash, the dash slash, the sustained-damage balance rules, the tutorial steps and the input map.
## Development only. Run: <godot> --headless --path game res://frontend/scenes/test/combat_phase13c_smoke_test.tscn
## Uses a redirected save path; the AI service stays disabled; the real save is never touched.

const TEST_SAVE: String = "user://test_save_phase13c.json"
const DEFAULT_REGISTRY: SceneRegistry = preload("res://backend/progression/default_scene_registry.tres")
const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://frontend/scenes/test/training_dummy.tscn")
const HUD_SCENE: PackedScene = preload("res://frontend/ui/player_health_hud.tscn")
const TUTORIAL_SCENE: PackedScene = preload("res://frontend/levels/tutorial.tscn")
const ENEMIES: Dictionary = {
	"melee": preload("res://backend/enemies/melee_enemy.tscn"),
	"fast": preload("res://backend/enemies/fast_enemy.tscn"),
	"ranged": preload("res://backend/enemies/ranged_enemy.tscn"),
}
const BOSSES: Dictionary = {
	"boss_one": preload("res://backend/bosses/placeholder_boss.tscn"),
	"boss_two": preload("res://backend/bosses/boss_two.tscn"),
	"boss_three": preload("res://backend/bosses/boss_three.tscn"),
}
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const FLOOR_Y: float = 300.0
const PLAYER_HALF_HEIGHT: float = 26.0
const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash", "attack", "wave", "heavy_attack"]
const DEBUG_KEYCODES: Array[int] = [KEY_K, KEY_H, KEY_F2, KEY_F3, KEY_G, KEY_R, KEY_L, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const EXPECTED_KEYS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_UP], "dash": [KEY_SHIFT, KEY_K],
	"attack": [KEY_J, KEY_X], "wave": [KEY_U], "pause": [KEY_ESCAPE, KEY_P], "heavy_attack": [KEY_I],
}
const EXPECTED_MOUSE: Dictionary = {"attack": [MOUSE_BUTTON_LEFT], "wave": [MOUSE_BUTTON_RIGHT], "heavy_attack": [MOUSE_BUTTON_MIDDLE]}

var failures: int = 0
var real_save_before: String = ""
var ai_config: AiServiceConfig = load("res://backend/ai/default_ai_service_config.tres") as AiServiceConfig
var default_stats: PlayerStats = load("res://backend/player/default_player_stats.tres") as PlayerStats


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
	for child in get_children():
		if child is Projectile:
			child.free()


func _add_floor(parent: Node) -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.position = Vector2(0.0, FLOOR_Y + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8000.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	parent.add_child(floor_body)


## World with a floor and a player standing at x = 0. Returns {world, player}.
func _make_world(player_x: float = 0.0) -> Dictionary:
	var world := Node2D.new()
	add_child(world)
	_add_floor(world)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(player_x, FLOOR_Y - PLAYER_HALF_HEIGHT)
	world.add_child(player)
	return {"world": world, "player": player}


func _make_dummy(parent: Node, x: float) -> TrainingDummy:
	var dummy := DUMMY_SCENE.instantiate() as TrainingDummy
	dummy.position = Vector2(x, FLOOR_Y)
	parent.add_child(dummy)
	return dummy


# --- Real input events ---

func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event


func _mouse_event(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _press_heavy(use_mouse: bool = false) -> void:
	Input.parse_input_event(_mouse_event(MOUSE_BUTTON_MIDDLE, true) if use_mouse else _key_event(KEY_I, true))


func _release_heavy(use_mouse: bool = false) -> void:
	Input.parse_input_event(_mouse_event(MOUSE_BUTTON_MIDDLE, false) if use_mouse else _key_event(KEY_I, false))


func _tap_heavy(use_mouse: bool = false) -> void:
	_press_heavy(use_mouse)
	await get_tree().physics_frame
	_release_heavy(use_mouse)


func _tap_key(keycode: Key) -> void:
	Input.parse_input_event(_key_event(keycode, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(keycode, false))


func _hit_player(player: Player, amount: int = 1) -> void:
	player.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, null, CombatLayers.Team.ENEMY))


func _count_signal(player: Player, signal_name: String) -> Array[int]:
	var counter: Array[int] = [0]
	player.connect(signal_name, func() -> void: counter[0] += 1)
	return counter


func _run() -> void:
	_check("AI service disabled for the whole test", not ai_config.enabled)
	_test_input_map()
	_test_balance()
	await _test_health()
	await _test_contact_enemies()
	await _test_contact_rules()
	await _test_contact_bosses()
	await _test_heavy()
	await _test_dash_slash()
	await _test_bosses_hit_by_moves()
	await _test_tutorial()
	_test_save()
	_clean_state()
	SaveSystem.purge()
	_check("real save file untouched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- Input map ---

func _test_input_map() -> void:
	var all_ok: bool = true
	for action: String in EXPECTED_KEYS:
		var keys: Array[int] = []
		var buttons: Array[int] = []
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			var mouse := event as InputEventMouseButton
			if key != null:
				keys.append(int(key.physical_keycode))
			elif mouse != null:
				buttons.append(int(mouse.button_index))
		keys.sort()
		buttons.sort()
		var want_keys: Array = (EXPECTED_KEYS[action] as Array).duplicate()
		want_keys.sort()
		var want_buttons: Array = (EXPECTED_MOUSE.get(action, []) as Array).duplicate()
		want_buttons.sort()
		var matches: bool = keys == want_keys and buttons == want_buttons
		all_ok = all_ok and matches
		if not matches:
			print("  mismatch for %s: keys %s buttons %s" % [action, str(keys), str(buttons)])
	_check("input map: every action has exactly the expected keys and mouse buttons (new action: heavy_attack = I + middle mouse)", all_ok)
	var custom: Array[String] = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and not String(action).begins_with("spatial_editor"):
			custom.append(String(action))
	custom.sort()
	_check("input map: only one action was added", custom == ["attack", "dash", "heavy_attack", "jump", "move_left", "move_right", "pause", "wave"], str(custom))
	var collides: bool = false
	for event in InputMap.action_get_events("heavy_attack"):
		var key := event as InputEventKey
		if key != null and DEBUG_KEYCODES.has(int(key.physical_keycode)):
			collides = true
	_check("input map: heavy_attack collides with no debug key", not collides)


# --- Balance ---

func _test_balance() -> void:
	var s: PlayerStats = default_stats
	var light: float = float(s.attack_damage) / (s.attack_startup_time + s.attack_active_time + s.attack_recovery_time + s.attack_cooldown)
	var heavy: float = float(s.heavy_damage) / (s.heavy_startup_time + s.heavy_active_time + s.heavy_recovery_time + s.heavy_cooldown)
	var dash_slash: float = float(s.dash_slash_damage) / (s.dash_duration + s.dash_cooldown + s.dash_slash_extra_recovery_time)
	var wave_config: SwordWaveConfig = load("res://backend/player/default_sword_wave_config.tres") as SwordWaveConfig
	var rows: PackedStringArray = PackedStringArray()
	var waves: Array[float] = []
	for index in wave_config.tiers.size():
		var tier: SwordWaveTier = wave_config.get_tier(index)
		waves.append(float(tier.damage) / maxf(tier.cooldown, wave_config.startup_time + wave_config.recovery_time))
		rows.append("wave tier %d = %.2f" % [index, waves[index]])
	print("BALANCE (sustained damage per second): light sword %.2f | heavy slash %.2f (%.2fx) | dash slash %.2f (%.2fx) | %s" % [
		light, heavy, heavy / light, dash_slash, dash_slash / light, " | ".join(rows)])
	_check("balance: heavy slash between 1.0x and 1.5x the light sword", heavy >= light and heavy <= light * 1.5, "%.2fx" % (heavy / light))
	_check("balance: dash slash at most 1.5x the light sword", dash_slash <= light * 1.5, "%.2fx" % (dash_slash / light))
	var below: bool = true
	for value in waves:
		below = below and value < light
	_check("balance: every sword wave tier stays below the light sword", below)
	_check("stats: the new moves have their own defaults", s.heavy_damage == 3 and s.heavy_knockback == Vector2(420.0, -180.0) and s.heavy_width_multiplier == 1.6
		and s.dash_slash_damage == 2 and s.dash_slash_knockback == Vector2(360.0, -140.0) and s.dash_slash_width_multiplier == 1.3 and s.dash_slash_extra_recovery_time == 0.12)


# --- Health ---

func _test_health() -> void:
	_clean_state()
	_check("health: the default max health is 8", default_stats.max_health == 8 and (load("res://backend/player/default_player_stats.tres") as PlayerStats).max_health == 8)
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	var hud := HUD_SCENE.instantiate() as PlayerHealthHud
	add_child(hud)
	hud.bind(player)
	await _physics(3)
	_check("health: the player starts with 8", player.health.max_health == 8 and player.health.current_health == 8)
	_check("health: the HUD builds 8 squares and they are all full", hud.pips.get_child_count() == 8 and hud.filled_pips() == 8)
	var separation: int = hud.pips.get_theme_constant("separation")
	var row_width: float = 8.0 * hud.pip_size.x + 7.0 * float(separation)
	_check("health: 8 squares fit the HUD row (%.0f px of %.0f)" % [row_width, hud.pips.size.x], row_width <= hud.pips.size.x + 0.5)
	_hit_player(player, 3)
	await _physics(2)
	_check("health: the HUD follows damage", hud.filled_pips() == 5 and hud.pips.get_child_count() == 8)
	player.health.kill()
	player.respawn()
	await _physics(2)
	_check("health: respawn restores the stats value", player.health.current_health == default_stats.max_health and hud.filled_pips() == default_stats.max_health)
	hud.free()
	(parts["world"] as Node).free()


# --- Contact damage ---

## An enemy that cannot see anyone (no attacks, no patrol) with a distinctive contact damage.
func _isolated_enemy(kind: String, contact_damage: int = 3, extra: Dictionary = {}) -> EnemyBase:
	var enemy := (ENEMIES[kind] as PackedScene).instantiate() as EnemyBase
	var stats: EnemyStats = enemy.stats.duplicate() as EnemyStats
	stats.detection_range = 0.0
	stats.patrol_enabled = false
	stats.contact_damage = contact_damage
	stats.max_health = 50
	for key: String in extra:
		stats.set(key, extra[key])
	enemy.stats = stats
	return enemy


## A world where the player cannot move or regain health on its own: only contact damage matters.
func _frozen_player_world(player_x: float) -> Dictionary:
	var parts: Dictionary = _make_world(player_x)
	var player: Player = parts["player"]
	player.health.max_health = 50
	player.health.reset()
	player.health.invulnerability_time = 0.0
	player.set_physics_process(false)
	return parts


func _count_damage_events(player: Player) -> Array:
	var events: Array = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: events.append(info))
	return events


func _test_contact_enemies() -> void:
	for kind in ENEMIES:
		_clean_state()
		var parts: Dictionary = _frozen_player_world(10.0)
		var player: Player = parts["player"]
		var world: Node2D = parts["world"]
		var enemy: EnemyBase = _isolated_enemy(kind)
		enemy.position = Vector2(0.0, FLOOR_Y - 24.0)
		world.add_child(enemy)
		var events: Array = _count_damage_events(player)
		await _physics(4)
		_check("contact (%s): the contact hitbox is active while alive" % kind, enemy.contact_hitbox.is_active and enemy.contact_hitbox.damage == 3)
		_check("contact (%s): a living enemy damages the player by contact_damage" % kind, events.size() >= 1 and (events[0] as DamageInfo).amount == 3 and player.health.current_health == 47)
		_check("contact (%s): knockback pushes away from the enemy (player on the right)" % kind, (events[0] as DamageInfo).knockback.x > 0.0 and (events[0] as DamageInfo).knockback.y < 0.0)
		# Re-hit interval: hits over a 3.1 s window (the player has no invulnerability here).
		events.clear()
		await _physics(186)
		var expected_max: int = int(ceil(3.1 / enemy.stats.contact_rehit_interval))
		_check("contact (%s): re-hit interval %.1fs respected (%d hits in 3.1s)" % [kind, enemy.stats.contact_rehit_interval, events.size()],
			events.size() >= expected_max - 1 and events.size() <= expected_max)
		# Knocked from the left.
		world.free()
		parts = _frozen_player_world(-10.0)
		player = parts["player"]
		world = parts["world"]
		enemy = _isolated_enemy(kind)
		enemy.position = Vector2(0.0, FLOOR_Y - 24.0)
		world.add_child(enemy)
		events = _count_damage_events(player)
		await _physics(4)
		_check("contact (%s): knockback pushes left when the player is on the left" % kind, events.size() >= 1 and (events[0] as DamageInfo).knockback.x < 0.0)
		world.free()


func _test_contact_rules() -> void:
	# Dead enemy.
	_clean_state()
	var parts: Dictionary = _frozen_player_world(10.0)
	var player: Player = parts["player"]
	var world: Node2D = parts["world"]
	var enemy: EnemyBase = _isolated_enemy("melee")
	enemy.position = Vector2(0.0, FLOOR_Y - 24.0)
	world.add_child(enemy)
	var events: Array = _count_damage_events(player)
	await _physics(3)
	events.clear()
	enemy.health.kill()
	_check("contact: the hitbox is inactive the moment the enemy dies", not enemy.contact_hitbox.is_active and enemy.state == EnemyBase.State.DEAD)
	await _physics(20)
	_check("contact: a dead enemy never hurts the player", events.is_empty())
	world.free()
	# HURT state: off by default, on with contact_active_while_hurt.
	for while_hurt in [false, true]:
		_clean_state()
		parts = _frozen_player_world(300.0)
		player = parts["player"]
		world = parts["world"]
		enemy = _isolated_enemy("melee", 3, {"contact_active_while_hurt": while_hurt, "hurt_stun_time": 1.0})
		enemy.position = Vector2(0.0, FLOOR_Y - 24.0)
		world.add_child(enemy)
		await _physics(3)
		enemy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.PLAYER))
		_check("contact: an enemy in HURT %s (contact_active_while_hurt = %s)" % ["is dangerous" if while_hurt else "is harmless", str(while_hurt)],
			enemy.state == EnemyBase.State.HURT and enemy.contact_hitbox.is_active == while_hurt)
		await _physics(70)
		_check("contact: the hitbox comes back after the HURT state (%s)" % str(while_hurt), enemy.state != EnemyBase.State.HURT and enemy.contact_hitbox.is_active)
		world.free()
	# contact_damage = 0 disables it.
	_clean_state()
	parts = _frozen_player_world(10.0)
	player = parts["player"]
	world = parts["world"]
	enemy = _isolated_enemy("fast", 0)
	enemy.position = Vector2(0.0, FLOOR_Y - 24.0)
	world.add_child(enemy)
	events = _count_damage_events(player)
	await _physics(90)
	_check("contact: contact_damage = 0 disables it", not enemy.contact_hitbox.is_active and events.is_empty())
	world.free()
	# Invulnerability (post-hit / respawn) blocks contact damage.
	_clean_state()
	parts = _frozen_player_world(10.0)
	player = parts["player"]
	world = parts["world"]
	player.health.grant_invulnerability(2.0)
	enemy = _isolated_enemy("melee")
	enemy.position = Vector2(0.0, FLOOR_Y - 24.0)
	world.add_child(enemy)
	events = _count_damage_events(player)
	await _physics(90)
	_check("contact: post-hit / respawn invulnerability blocks contact damage", events.is_empty() and enemy.contact_hitbox.is_active)
	await _physics(60)
	_check("contact: and the hit lands once the invulnerability ends", not events.is_empty())
	world.free()
	# Dash invulnerability blocks contact damage: dash straight through a strong enemy.
	_clean_state()
	parts = _make_world(-10.0)
	player = parts["player"]
	world = parts["world"]
	enemy = _isolated_enemy("melee", 5)
	enemy.position = Vector2(40.0, FLOOR_Y - 24.0)
	world.add_child(enemy)
	events = _count_damage_events(player)
	await _physics(5)
	Input.parse_input_event(_key_event(KEY_D, true))
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	await _physics(2)
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	Input.parse_input_event(_key_event(KEY_D, false))
	await _wait_until(func() -> bool: return player.state != Player.State.DASH, 40)
	await _physics(5)
	_check("contact: dashing through an enemy is safe (dash invulnerability)", events.is_empty() and player.global_position.x > 40.0, "x %.0f" % player.global_position.x)
	world.free()
	# Death and respawn under contact.
	_clean_state()
	parts = _make_world(10.0)
	player = parts["player"]
	world = parts["world"]
	player.set_respawn_point(Vector2(-600.0, FLOOR_Y - PLAYER_HALF_HEIGHT))
	await _physics(3)
	player.health.current_health = 1
	enemy = _isolated_enemy("melee")
	enemy.position = Vector2(0.0, FLOOR_Y - 24.0)
	world.add_child(enemy)
	var died: bool = await _wait_until(func() -> bool: return player.is_dead, 30)
	_check("contact: contact damage can kill the player", died)
	var back: bool = await _wait_until(func() -> bool: return not player.is_dead, 120)
	_check("contact: the player respawns with full health at the respawn point", back and player.health.current_health == player.health.max_health
		and player.global_position.x < -500.0)
	world.free()
	# Unique shapes and training dummy.
	_clean_state()
	var first: EnemyBase = _isolated_enemy("melee")
	var second: EnemyBase = _isolated_enemy("melee")
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(first)
	holder.add_child(second)
	await _physics(2)
	var shape_a: Shape2D = (first.contact_hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape
	var shape_b: Shape2D = (second.contact_hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape
	_check("contact: the shape is a unique inset copy of the body (20 x 40 for a 28 x 48 body)", shape_a != shape_b and shape_a != first.body_shape.shape
		and (shape_a as RectangleShape2D).size == Vector2(20.0, 40.0) and (first.body_shape.shape as RectangleShape2D).size == Vector2(28.0, 48.0))
	holder.free()
	_clean_state()
	parts = _frozen_player_world(0.0)
	player = parts["player"]
	world = parts["world"]
	var dummy: TrainingDummy = _make_dummy(world, 0.0)
	events = _count_damage_events(player)
	await _physics(90)
	_check("contact: the training dummy deals no contact damage", dummy.get_node_or_null("ContactHitbox") == null and events.is_empty())
	world.free()
	# Enemy attack + contact together: a single hit inside the invulnerability window.
	_clean_state()
	parts = _make_world(10.0)
	player = parts["player"]
	world = parts["world"]
	var normal := (ENEMIES["melee"] as PackedScene).instantiate() as EnemyBase
	normal.position = Vector2(0.0, FLOOR_Y - 24.0)
	world.add_child(normal)
	events = _count_damage_events(player)
	await _physics(56)
	_check("contact: enemy attack + contact overlap give one hit inside the invulnerability window", events.size() == 1, "hits: %d" % events.size())
	world.free()


# --- Boss contact ---

func _isolated_boss(scene: PackedScene, extra: Dictionary = {}) -> BossBase:
	var boss := scene.instantiate() as BossBase
	var stats: BossStats = boss.stats.duplicate() as BossStats
	stats.pattern_gap_time = 500.0
	stats.contact_damage = 3
	stats.max_health = 400
	for key: String in extra:
		stats.set(key, extra[key])
	boss.stats = stats
	boss.rng_seed = 5
	return boss


func _test_contact_bosses() -> void:
	for boss_name in BOSSES:
		var scene: PackedScene = BOSSES[boss_name]
		_clean_state()
		var parts: Dictionary = _frozen_player_world(10.0)
		var player: Player = parts["player"]
		var world: Node2D = parts["world"]
		var boss: BossBase = _isolated_boss(scene)
		boss.position = Vector2(0.0, FLOOR_Y - 44.0)
		world.add_child(boss)
		var events: Array = _count_damage_events(player)
		await _physics(60)
		_check("contact (%s): an inactive boss never hurts" % boss_name, not boss.contact_hitbox.is_active and events.is_empty())
		boss.activate(player)
		await _physics(4)
		_check("contact (%s): an active boss hurts by contact_damage" % boss_name, boss.contact_hitbox.is_active and events.size() >= 1 and (events[0] as DamageInfo).amount == 3)
		_check("contact (%s): knockback pushes away from the boss" % boss_name, (events[0] as DamageInfo).knockback.x > 0.0)
		events.clear()
		await _physics(190)
		var expected_max: int = int(ceil(3.2 / boss.stats.contact_rehit_interval))
		_check("contact (%s): re-hit interval %.1fs respected (%d hits in 3.2s)" % [boss_name, boss.stats.contact_rehit_interval, events.size()],
			events.size() >= expected_max - 1 and events.size() <= expected_max)
		# Phase transition: harmless.
		var damage: int = boss.stats.max_health - int(floor(boss.stats.max_health * boss.stats.phase_2_health_ratio))
		boss.hurtbox.receive_hit(DamageInfo.create(damage, Vector2.ZERO, null, CombatLayers.Team.PLAYER))
		events.clear()
		_check("contact (%s): harmless during the phase transition" % boss_name, boss.state == BossBase.State.PHASE_TRANSITION and not boss.contact_hitbox.is_active)
		await _physics(30)
		_check("contact (%s): no damage during the phase transition" % boss_name, events.is_empty())
		await _wait_until(func() -> bool: return boss.state != BossBase.State.PHASE_TRANSITION, 200)
		await _physics(4)
		_check("contact (%s): dangerous again in phase 2" % boss_name, boss.contact_hitbox.is_active)
		# Reset: inactive again.
		boss.reset_encounter()
		_check("contact (%s): inactive after the encounter is reset" % boss_name, not boss.contact_hitbox.is_active)
		boss.activate(player)
		await _physics(3)
		# Defeat: inactive immediately.
		boss.hurtbox.receive_hit(DamageInfo.create(9999, Vector2.ZERO, null, CombatLayers.Team.PLAYER))
		events.clear()
		_check("contact (%s): inactive the moment the boss is defeated" % boss_name, boss.state == BossBase.State.DEAD and not boss.contact_hitbox.is_active)
		await _physics(30)
		_check("contact (%s): a defeated boss never hurts" % boss_name, events.is_empty())
		world.free()
	# Zero damage and the shape.
	_clean_state()
	var parts_zero: Dictionary = _frozen_player_world(10.0)
	var zero_boss: BossBase = _isolated_boss(BOSSES["boss_two"], {"contact_damage": 0})
	zero_boss.position = Vector2(0.0, FLOOR_Y - 44.0)
	(parts_zero["world"] as Node).add_child(zero_boss)
	var zero_events: Array = _count_damage_events(parts_zero["player"])
	await _physics(3)
	zero_boss.activate(parts_zero["player"])
	await _physics(120)
	_check("contact (boss): contact_damage = 0 disables it", not zero_boss.contact_hitbox.is_active and zero_events.is_empty())
	var other: BossBase = _isolated_boss(BOSSES["boss_three"])
	(parts_zero["world"] as Node).add_child(other)
	other.position = Vector2(800.0, FLOOR_Y - 44.0)
	await _physics(2)
	var shape_a: Shape2D = (zero_boss.contact_hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape
	var shape_b: Shape2D = (other.contact_hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape
	_check("contact (boss): the shape is a unique inset copy (44 x 76 for a 56 x 88 body)", shape_a != shape_b and (shape_a as RectangleShape2D).size == Vector2(44.0, 76.0)
		and (zero_boss.body_shape.shape as RectangleShape2D).size == Vector2(56.0, 88.0))
	(parts_zero["world"] as Node).free()


# --- Heavy slash ---

## Heavy-attack timeline in physics frames since the press: start, hitbox on/off, end.
func _heavy_timeline(player: Player, use_mouse: bool) -> Dictionary:
	var info := {"start": -1, "on": -1, "off": -1, "end": -1}
	_press_heavy(use_mouse)
	var frame: int = 0
	var seen_hitbox: bool = false
	while frame < 200:
		await get_tree().physics_frame
		frame += 1
		if frame == 1:
			_release_heavy(use_mouse)
		if player.state == Player.State.HEAVY and info["start"] < 0:
			info["start"] = frame
		if player.attack_hitbox.is_active and info["on"] < 0:
			info["on"] = frame
			seen_hitbox = true
		if seen_hitbox and not player.attack_hitbox.is_active and info["off"] < 0:
			info["off"] = frame
		if info["start"] >= 0 and player.state != Player.State.HEAVY:
			info["end"] = frame
			break
	return info


func _swing_reach(player: Player, world: Node2D, use_heavy: bool) -> float:
	var dummies: Array[TrainingDummy] = []
	for step in 15:
		dummies.append(_make_dummy(world, player.global_position.x + 70.0 + 5.0 * step))
	await _physics(2)
	if use_heavy:
		await _tap_heavy(false)
	else:
		Input.parse_input_event(_key_event(KEY_J, true))
		await get_tree().physics_frame
		Input.parse_input_event(_key_event(KEY_J, false))
	await _physics(60)
	var farthest: float = 0.0
	for dummy in dummies:
		if dummy.health.current_health < dummy.health.max_health:
			farthest = maxf(farthest, dummy.global_position.x - player.global_position.x)
		dummy.free()
	return farthest


func _test_heavy() -> void:
	_clean_state()
	var parts: Dictionary = _make_world()
	var player: Player = parts["player"]
	var world: Node2D = parts["world"]
	await _physics(5)
	var started: Array[int] = _count_signal(player, "heavy_attack_started")
	# Damage, exactly once per swing, knockback.
	var dummy: TrainingDummy = _make_dummy(world, 70.0)
	var hits: Array = []
	dummy.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	await _tap_heavy(false)
	await _physics(70)
	_check("heavy: the key I performs it and deals exactly 3 damage once per swing", started[0] == 1 and dummy.health.max_health - dummy.health.current_health == 3 and hits.size() == 1)
	_check("heavy: knockback is larger than the light attack's", hits.size() == 1 and (hits[0] as DamageInfo).knockback.x == default_stats.heavy_knockback.x
		and default_stats.heavy_knockback.x > default_stats.attack_knockback.x)
	# Timeline (key and middle mouse).
	await _physics(40)
	var timeline: Dictionary = await _heavy_timeline(player, false)
	var frames_per_second: float = float(Engine.physics_ticks_per_second)
	var startup_frames: int = int(round(default_stats.heavy_startup_time * frames_per_second))
	var active_frames: int = int(round(default_stats.heavy_active_time * frames_per_second))
	var recovery_frames: int = int(round(default_stats.heavy_recovery_time * frames_per_second))
	print("HEAVY TIMELINE (physics frames): %s | expected startup %d active %d recovery %d" % [str(timeline), startup_frames, active_frames, recovery_frames])
	_check("heavy: startup lasts about %d frames" % startup_frames, absi((timeline["on"] - timeline["start"]) - startup_frames) <= 2)
	_check("heavy: the hitbox is active about %d frames" % active_frames, absi((timeline["off"] - timeline["on"]) - active_frames) <= 2)
	_check("heavy: recovery lasts about %d frames" % recovery_frames, absi((timeline["end"] - timeline["off"]) - recovery_frames) <= 2)
	# Cooldown: blocked 0.25 s after the end, allowed 0.5 s after.
	var before: int = started[0]
	await _physics(15)
	await _tap_heavy(false)
	await _physics(5)
	_check("heavy: the cooldown blocks a new heavy attack 0.25s after the end", started[0] == before)
	await _physics(25)
	await _tap_heavy(true)
	await _physics(3)
	_check("heavy: it works again after the cooldown (middle mouse button)", started[0] == before + 1 and player.state == Player.State.HEAVY)
	await _physics(80)
	# Reach vs the light attack, then the light attack is unchanged afterwards.
	world.free()
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	var light_reach: float = await _swing_reach(player, world, false)
	await _physics(40)
	var heavy_reach: float = await _swing_reach(player, world, true)
	await _physics(90)
	var light_again: float = await _swing_reach(player, world, false)
	print("REACH (farthest dummy centre hit): light %.0f | heavy %.0f | light after heavy %.0f" % [light_reach, heavy_reach, light_again])
	_check("heavy: reaches farther than the light attack", heavy_reach > light_reach + 15.0)
	var shape_rect := player.attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	_check("heavy: the shared hitbox shape and damage are restored for the light attack", light_again == light_reach and (shape_rect.shape as RectangleShape2D).size == Vector2(52.0, 44.0)
		and shape_rect.position == Vector2(42.0, 0.0) and player.attack_hitbox.damage == default_stats.attack_damage and player.current_sword_kind == Player.SwordKind.LIGHT)
	var other := PLAYER_SCENE.instantiate() as Player
	world.add_child(other)
	await _physics(2)
	_check("heavy: each player owns its own sword shape", (other.attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape != shape_rect.shape)
	other.free()
	world.free()
	# Light attack damage after a heavy swing is still 1.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	dummy = _make_dummy(world, 60.0)
	await _physics(5)
	await _tap_heavy(false)
	await _physics(100)
	var hp_after_heavy: int = dummy.health.current_health
	Input.parse_input_event(_key_event(KEY_J, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_J, false))
	await _physics(40)
	_check("heavy: a light attack afterwards still deals 1", hp_after_heavy - dummy.health.current_health == 1)
	world.free()
	# Same-frame press: the light attack wins.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	started = _count_signal(player, "heavy_attack_started")
	var light_started: Array[int] = _count_signal(player, "attack_started")
	Input.parse_input_event(_key_event(KEY_J, true))
	_press_heavy(false)
	await _physics(3)
	Input.parse_input_event(_key_event(KEY_J, false))
	_release_heavy(false)
	await _physics(50)
	_check("heavy: attack and heavy on the same frame -> the light attack wins", light_started[0] == 1 and started[0] == 0)
	world.free()
	# Blocking states.
	for blocked in ["attack", "dash", "hurt", "dead", "wave", "locked", "paused"]:
		_clean_state()
		parts = _make_world()
		player = parts["player"]
		world = parts["world"]
		player.set_auto_respawn(false)
		await _physics(5)
		started = _count_signal(player, "heavy_attack_started")
		match blocked:
			"attack":
				Input.parse_input_event(_key_event(KEY_J, true))
				await _physics(2)
				Input.parse_input_event(_key_event(KEY_J, false))
			"dash":
				Input.parse_input_event(_key_event(KEY_SHIFT, true))
				await _physics(2)
				Input.parse_input_event(_key_event(KEY_SHIFT, false))
			"hurt":
				_hit_player(player)
			"dead":
				player.health.kill()
			"wave":
				Input.parse_input_event(_mouse_event(MOUSE_BUTTON_RIGHT, true))
				await _physics(2)
				Input.parse_input_event(_mouse_event(MOUSE_BUTTON_RIGHT, false))
			"locked":
				player.set_input_locked(true)
			"paused":
				get_tree().paused = true
		var in_state: bool = player.state == {"attack": Player.State.ATTACK, "dash": Player.State.DASH, "hurt": Player.State.HURT, "dead": Player.State.DEAD, "wave": Player.State.WAVE}.get(blocked, player.state)
		await _tap_heavy(false)
		await _physics(8)
		get_tree().paused = false
		_check("heavy: blocked while %s" % blocked, in_state and started[0] == 0)
		world.free()
	# Hurt during startup cancels: no damage, no cooldown consumed.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	dummy = _make_dummy(world, 60.0)
	await _physics(5)
	started = _count_signal(player, "heavy_attack_started")
	await _tap_heavy(false)
	await _physics(4)
	var in_startup: bool = player.state == Player.State.HEAVY and not player.attack_hitbox.is_active
	_hit_player(player)
	await _physics(60)
	_check("heavy: a hit during startup cancels it with no damage dealt", in_startup and dummy.health.current_health == dummy.health.max_health and not player.attack_hitbox.is_active)
	await _wait_until(func() -> bool: return not player.health.is_invulnerable() and player.state == Player.State.IDLE, 120)
	await _tap_heavy(false)
	await _physics(4)
	_check("heavy: the cooldown was not consumed by the cancelled move", started[0] == 2 and player.state == Player.State.HEAVY)
	await _physics(90)
	world.free()
	# No cancels by the player's own actions.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	await _tap_heavy(false)
	await _physics(3)
	var y_before: float = player.global_position.y
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	Input.parse_input_event(_key_event(KEY_SPACE, true))
	Input.parse_input_event(_key_event(KEY_J, true))
	Input.parse_input_event(_mouse_event(MOUSE_BUTTON_RIGHT, true))
	await _physics(5)
	var still: bool = player.state == Player.State.HEAVY and absf(player.global_position.y - y_before) < 1.0
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	Input.parse_input_event(_key_event(KEY_SPACE, false))
	Input.parse_input_event(_key_event(KEY_J, false))
	Input.parse_input_event(_mouse_event(MOUSE_BUTTON_RIGHT, false))
	_check("heavy: dash, jump, attack and wave do not cancel it", still)
	await _wait_until(func() -> bool: return player.state != Player.State.HEAVY, 100)
	_check("heavy: it ends by itself", player.state != Player.State.HEAVY)
	world.free()
	# In the air.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	started = _count_signal(player, "heavy_attack_started")
	player.global_position.y -= 200.0
	await _physics(3)
	var airborne: bool = not player.is_on_floor()
	await _tap_heavy(false)
	await _physics(3)
	_check("heavy: works in the air", airborne and started[0] == 1)
	world.free()


# --- Dash slash ---

func _hold_dash_slash(player: Player, attack_delay_frames: int) -> void:
	Input.parse_input_event(_key_event(KEY_D, true))
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	await _physics(attack_delay_frames)
	Input.parse_input_event(_key_event(KEY_J, true))
	await _physics(2)
	Input.parse_input_event(_key_event(KEY_J, false))


func _test_dash_slash() -> void:
	_clean_state()
	var parts: Dictionary = _make_world(-200.0)
	var player: Player = parts["player"]
	var world: Node2D = parts["world"]
	var dummy: TrainingDummy = _make_dummy(world, -100.0)
	await _physics(5)
	var slashes: Array[int] = _count_signal(player, "dash_slash_started")
	var lights: Array[int] = _count_signal(player, "attack_started")
	var hits: Array = []
	dummy.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var dash_starts: Array[int] = _count_signal(player, "dash_started")
	await _hold_dash_slash(player, 2)
	Input.parse_input_event(_key_event(KEY_D, false))
	var slash_active: bool = player.attack_hitbox.is_active and player.current_sword_kind == Player.SwordKind.DASH_SLASH
	# A second attack press in the same dash does nothing.
	Input.parse_input_event(_key_event(KEY_J, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_J, false))
	await _physics(60)
	_check("dash slash: attack during the dash performs it once", slashes[0] == 1 and lights[0] == 0 and dash_starts[0] == 1 and slash_active, "slashes %d lights %d dashes %d active %s kind %d state %d" % [slashes[0], lights[0], dash_starts[0], str(slash_active), player.current_sword_kind, player.state])
	_check("dash slash: deals 2 damage once per dash", dummy.health.max_health - dummy.health.current_health == 2 and hits.size() == 1)
	_check("dash slash: knockback is the configured one", hits.size() == 1 and (hits[0] as DamageInfo).knockback.x == default_stats.dash_slash_knockback.x)
	_check("dash slash: the hitbox is off and the light profile restored afterwards", not player.attack_hitbox.is_active and player.current_sword_kind == Player.SwordKind.LIGHT
		and player.attack_hitbox.damage == default_stats.attack_damage)
	world.free()
	# Attack outside the dash is the normal light attack.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	dummy = _make_dummy(world, 60.0)
	await _physics(5)
	slashes = _count_signal(player, "dash_slash_started")
	lights = _count_signal(player, "attack_started")
	Input.parse_input_event(_key_event(KEY_J, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_J, false))
	await _physics(40)
	_check("dash slash: attack outside a dash is the light attack (1 damage)", slashes[0] == 0 and lights[0] == 1 and dummy.health.max_health - dummy.health.current_health == 1)
	world.free()
	# Dash cooldown and invulnerability window unchanged.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	dash_starts = _count_signal(player, "dash_started")
	var invulnerable_frames: Array[int] = [0]
	var dash_frames: Array[int] = [0]
	Input.parse_input_event(_key_event(KEY_D, true))
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_J, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_J, false))
	while player.state == Player.State.DASH and dash_frames[0] < 60:
		dash_frames[0] += 1
		if player.is_dash_invulnerable:
			invulnerable_frames[0] += 1
		await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_D, false))
	var expected_invulnerable: int = int(round(default_stats.dash_invulnerability_time * Engine.physics_ticks_per_second))
	_check("dash slash: the dash keeps its duration and invulnerability window (%d of %d frames)" % [invulnerable_frames[0], dash_frames[0]],
		absi(invulnerable_frames[0] - maxi(expected_invulnerable - 3, 0)) <= 3 and absi(dash_frames[0] + 3 - int(round(default_stats.dash_duration * Engine.physics_ticks_per_second))) <= 3)
	await _physics(8)
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	await _physics(3)
	_check("dash slash: it uses the dash cooldown (no new dash 0.15s after the end)", dash_starts[0] == 1)
	await _physics(int(default_stats.dash_cooldown * 60.0))
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	await _physics(3)
	_check("dash slash: a new dash is allowed after the dash cooldown", dash_starts[0] == 2)
	world.free()
	# Extra recovery blocks chaining.
	_clean_state()
	parts = _make_world()
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	slashes = _count_signal(player, "dash_slash_started")
	lights = _count_signal(player, "attack_started")
	var heavies: Array[int] = _count_signal(player, "heavy_attack_started")
	await _hold_dash_slash(player, 2)
	await _wait_until(func() -> bool: return player.state != Player.State.DASH, 40)
	Input.parse_input_event(_key_event(KEY_D, false))
	await _physics(2)
	Input.parse_input_event(_key_event(KEY_J, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_J, false))
	_press_heavy(false)
	await get_tree().physics_frame
	_release_heavy(false)
	await _physics(4)
	_check("dash slash: the extra recovery blocks an immediate attack or heavy attack", slashes[0] == 1 and lights[0] == 0 and heavies[0] == 0)
	await _physics(40)
	Input.parse_input_event(_key_event(KEY_J, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_J, false))
	await _physics(3)
	_check("dash slash: attacking works again after the extra recovery (a press buffered during it fires once it ends)", lights[0] >= 1, "lights %d state %d" % [lights[0], player.state])
	world.free()
	# Hurt cancels.
	_clean_state()
	parts = _make_world(-200.0)
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	await _hold_dash_slash(player, 2)
	var active_before: bool = player.attack_hitbox.is_active
	player.health.apply_damage(DamageInfo.create(1, Vector2.ZERO, null, CombatLayers.Team.ENEMY))
	_check("dash slash: a hit cancels it and leaves no active hitbox", active_before and not player.attack_hitbox.is_active and player.current_sword_kind == Player.SwordKind.LIGHT, "before %s state %d" % [str(active_before), player.state])
	Input.parse_input_event(_key_event(KEY_D, false))
	await _physics(30)
	world.free()
	# Death cancels.
	_clean_state()
	parts = _make_world(-200.0)
	player = parts["player"]
	world = parts["world"]
	player.set_auto_respawn(false)
	await _physics(5)
	await _hold_dash_slash(player, 2)
	player.health.kill()
	_check("dash slash: death cancels it and leaves no active hitbox", not player.attack_hitbox.is_active and player.state == Player.State.DEAD)
	Input.parse_input_event(_key_event(KEY_D, false))
	world.free()
	# In the air, once per air dash.
	_clean_state()
	parts = _make_world(-200.0)
	player = parts["player"]
	world = parts["world"]
	await _physics(5)
	slashes = _count_signal(player, "dash_slash_started")
	dash_starts = _count_signal(player, "dash_started")
	player.global_position.y -= 220.0
	await _physics(3)
	player.global_position.y -= 380.0
	await _physics(2)
	var in_air: bool = not player.is_on_floor()
	var air_dashes_before: int = player.air_dashes_left
	await _hold_dash_slash(player, 2)
	await _wait_until(func() -> bool: return player.state != Player.State.DASH, 40)
	_check("dash slash: works in the air and spends the air dash", in_air and slashes[0] == 1 and player.air_dashes_left == air_dashes_before - 1)
	await _physics(30)
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	await _physics(3)
	_check("dash slash: the air-dash limit is unchanged (no second air dash)", dash_starts[0] == 1 and not player.is_on_floor())
	Input.parse_input_event(_key_event(KEY_D, false))
	world.free()


# --- Bosses ---

func _test_bosses_hit_by_moves() -> void:
	for move in ["heavy", "dash_slash"]:
		_clean_state()
		var parts: Dictionary = _make_world()
		var player: Player = parts["player"]
		var world: Node2D = parts["world"]
		player.health.max_health = 200
		player.health.reset()
		player.health.grant_invulnerability(60.0)
		var boss := (BOSSES["boss_one"] as PackedScene).instantiate() as BossBase
		var stats: BossStats = boss.stats.duplicate() as BossStats
		stats.contact_damage = 0
		boss.stats = stats
		boss.rng_seed = 11
		boss.position = Vector2(75.0 if move == "heavy" else 150.0, FLOOR_Y - 44.0)
		world.add_child(boss)
		await _physics(3)
		boss.activate(player)
		var in_pattern: bool = await _wait_until(func() -> bool: return boss.state == BossBase.State.PATTERN, 600)
		var snapshot := {"pattern": boss.current_pattern, "state": -1, "same": false, "damage": 0}
		boss.health.damaged.connect(func(info: DamageInfo) -> void:
			snapshot["state"] = boss.state
			snapshot["same"] = boss.current_pattern == snapshot["pattern"]
			snapshot["damage"] = info.amount)
		var hp_before: int = boss.health.current_health
		if move == "heavy":
			await _tap_heavy(false)
		else:
			await _hold_dash_slash(player, 1)
		await _physics(40)
		Input.parse_input_event(_key_event(KEY_D, false))
		var expected: int = default_stats.heavy_damage if move == "heavy" else default_stats.dash_slash_damage
		_check("boss: the %s damages the boss by %d without interrupting its pattern" % [move, expected],
			in_pattern and hp_before - boss.health.current_health >= expected and snapshot["damage"] == expected and snapshot["state"] == BossBase.State.PATTERN and snapshot["same"],
			"hp lost %d, state %s" % [hp_before - boss.health.current_health, str(snapshot["state"])])
		world.free()


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
	_check("tutorial: eight steps ending with heavy and dash_slash", ids == ["move", "jump", "dash", "attack", "hit_dummy", "wave", "heavy", "dash_slash"], str(ids))
	var heavy_text: String = controller.build_text(String(controller.steps[6]["text"]))
	var slash_text: String = controller.build_text(String(controller.steps[7]["text"]))
	_check("tutorial: the new prompts resolve their keys from the InputMap", heavy_text.contains("I") and not heavy_text.contains("{") and slash_text.contains("J") and slash_text.contains("Shift")
		and not slash_text.contains("{"), heavy_text + " | " + slash_text)
	# Real moves before their step do not count.
	await _tap_heavy(false)
	await _physics(80)
	_check("tutorial: a real heavy attack before its step completes nothing", controller.current_index == 0)
	player.heavy_attack_started.emit()
	player.dash_slash_started.emit()
	_check("tutorial: the new signals before their step are ignored", controller.current_index == 0)
	# Move the controller to the wave step with the usual signals.
	controller._moved = 999.0
	await _physics(2)
	player.state_changed.emit(Player.State.IDLE, Player.State.JUMP)
	player.dash_started.emit()
	player.attack_started.emit()
	controller.dummy.hurtbox.receive_hit(DamageInfo.create(1, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
	_check("tutorial: reaches the wave step", controller.get_current_step_id() == "wave")
	player.heavy_attack_started.emit()
	_check("tutorial: heavy does not skip the wave step", controller.get_current_step_id() == "wave")
	player.wave_cast.emit(0)
	_check("tutorial: wave completes, then the heavy step", controller.get_current_step_id() == "heavy")
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: the exit is locked before the heavy step", SceneManager.last_requested_scene_id == "" and not controller.is_completed)
	player.dash_slash_started.emit()
	_check("tutorial: dash slash does not skip the heavy step", controller.get_current_step_id() == "heavy")
	await _wait_until(func() -> bool: return controller._feedback_left <= 0.0, 120)
	await _wait_until(func() -> bool: return player.state == Player.State.IDLE and not player.health.is_invulnerable(), 120)
	await _tap_heavy(true)
	var heavy_done: bool = await _wait_until(func() -> bool: return controller.get_current_step_id() == "dash_slash", 20)
	_check("tutorial: a real heavy attack (middle mouse) completes the heavy step", heavy_done)
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: the exit stays locked before the dash slash step", SceneManager.last_requested_scene_id == "" and not controller.is_completed)
	await _wait_until(func() -> bool: return player.state == Player.State.IDLE, 150)
	await _physics(40)
	# A plain dash and a plain attack do not complete it; the combination does.
	Input.parse_input_event(_key_event(KEY_SHIFT, true))
	await get_tree().physics_frame
	Input.parse_input_event(_key_event(KEY_SHIFT, false))
	await _physics(30)
	_check("tutorial: a plain dash does not complete the dash slash step", controller.get_current_step_id() == "dash_slash")
	await _physics(40)
	await _hold_dash_slash(player, 2)
	Input.parse_input_event(_key_event(KEY_D, false))
	var all_done: bool = await _wait_until(func() -> bool: return controller.is_completed, 30)
	_check("tutorial: a real dash slash completes the tutorial", all_done and controller.current_index == 8)
	controller.exit_area.body_entered.emit(player)
	_check("tutorial: the exit opens only now", SceneManager.last_requested_scene_id == "level_1")
	tutorial.free()
	await get_tree().process_frame
	while SceneManager.is_transitioning():
		await get_tree().process_frame
	SceneManager.dry_run = false
	_clean_state()


# --- Save ---

func _test_save() -> void:
	_clean_state()
	GameState.record_decision("fragment_level_1", "placeholder_boss", 1, GameState.CHOICE_KEPT)
	var data: Dictionary = GameState.to_dict()
	_check("save: exactly seven keys", data.keys().size() == SAVE_KEYS.size() and SAVE_KEYS.all(func(key: String) -> bool: return data.has(key)))
	_check("save: the save file is written", GameState.save_to_disk())
	var text: String = _read_file(TEST_SAVE).to_lower()
	_check("save: no heavy / slash / contact data in the file", not text.contains("heavy") and not text.contains("slash") and not text.contains("contact") and not text.contains("health"))

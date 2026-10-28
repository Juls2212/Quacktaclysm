extends Node
## Headless smoke test for Phase 5: projectile, fast enemy, ranged enemy, line of sight, rename.
## Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/enemy_phase5_smoke_test.tscn

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const MELEE_SCENE: PackedScene = preload("res://backend/enemies/melee_enemy.tscn")
const FAST_SCENE: PackedScene = preload("res://backend/enemies/fast_enemy.tscn")
const RANGED_SCENE: PackedScene = preload("res://backend/enemies/ranged_enemy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://backend/combat/projectile.tscn")
const MELEE_STATS: EnemyStats = preload("res://backend/enemies/stats/melee_basic_stats.tres")
const FAST_STATS: FastEnemyStats = preload("res://backend/enemies/stats/fast_basic_stats.tres")
const RANGED_STATS: RangedEnemyStats = preload("res://backend/enemies/stats/ranged_basic_stats.tres")
const PROJECTILE_STATS: ProjectileStats = preload("res://backend/combat/stats/enemy_projectile_stats.tres")
const FLOOR_Y: float = 300.0
const ENEMY_FLOOR_Y: float = FLOOR_Y - 24.0
const PLAYER_START: Vector2 = Vector2(-2000.0, FLOOR_Y - 30.0)
const PLATFORM_LEFT: float = 500.0
const PLATFORM_RIGHT: float = 700.0
const PLATFORM_TOP: float = 220.0
const ENEMY_ON_PLATFORM_Y: float = PLATFORM_TOP - 24.0
const WALL_LEFT: float = 1000.0
const PASSIVE: Dictionary = {"detection_range": 1.0, "lose_target_range": 1.0, "patrol_enabled": false, "max_health": 10}

## Methods the enemy subclasses may define (documented EnemyBase hooks and their own helpers).
const ALLOWED_SUBCLASS_METHODS: Array[String] = [
	"_create_default_stats", "_attack_phase_duration", "_update_attack_motion", "_on_attack_phase_entered",
	"_update_chase", "_can_start_attack", "_lunge_blocked", "_fire_projectile",
]

var failures: int = 0
var player: Player
var base_player_stats: PlayerStats
var spawned_projectiles: Array[Projectile] = []


func _ready() -> void:
	_add_static(Vector2(0.0, FLOOR_Y + 20.0), Vector2(6000.0, 40.0))
	_add_static(Vector2((PLATFORM_LEFT + PLATFORM_RIGHT) / 2.0, PLATFORM_TOP + 10.0), Vector2(PLATFORM_RIGHT - PLATFORM_LEFT, 20.0))
	_add_static(Vector2(WALL_LEFT + 20.0, FLOOR_Y - 50.0), Vector2(40.0, 100.0))
	child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile:
			spawned_projectiles.append(node as Projectile))

	player = PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_START
	add_child(player)
	base_player_stats = player.stats
	_run.call_deferred()


func _add_static(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	body.collision_mask = 0
	body.position = pos
	body.add_child(_rect_shape(size))
	add_child(body)
	return body


func _rect_shape(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	return shape


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _tap(action: String, frames: int = 2) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _copy(source: Resource, overrides: Dictionary) -> Resource:
	var copy: Resource = source.duplicate()
	for key in overrides:
		copy.set(key, overrides[key])
	return copy


func _spawn_enemy(scene: PackedScene, x: float, y: float, stats: EnemyStats) -> EnemyBase:
	var enemy := scene.instantiate() as EnemyBase
	enemy.stats = stats
	enemy.position = Vector2(x, y)
	add_child(enemy)
	return enemy


func _remove(node: Node) -> void:
	if is_instance_valid(node):
		if node is EnemyBase:
			(node as EnemyBase).attack_hitbox.deactivate()
		node.queue_free()
	await _frames(2)


func _clear_projectiles() -> void:
	for projectile in spawned_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	await _frames(2)
	spawned_projectiles.clear()


func _reset_player(pos: Vector2 = PLAYER_START) -> void:
	for action in ["move_left", "move_right", "jump", "dash", "attack"]:
		Input.action_release(action)
	player.stats = base_player_stats
	player.health.invulnerability_time = 0.0
	player.revive()
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.facing_direction = 1
	await _frames(40)


func _spawn_projectile(pos: Vector2, direction: Vector2, team: CombatLayers.Team, stats: ProjectileStats) -> Projectile:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectile.position = pos
	add_child(projectile)
	projectile.launch(direction, team, stats, null)
	return projectile


func _hit_enemy(enemy: EnemyBase) -> void:
	var hitbox := Hitbox.new()
	hitbox.team = CombatLayers.Team.PLAYER
	hitbox.damage = 1
	hitbox.knockback = Vector2(100.0, -50.0)
	hitbox.add_child(_rect_shape(Vector2(60.0, 60.0)))
	hitbox.position = enemy.global_position
	add_child(hitbox)
	hitbox.activate()
	await _frames(4)
	hitbox.deactivate()
	hitbox.queue_free()


func _run() -> void:
	await _test_projectile()
	await _test_fast_stats_and_lunge()
	await _test_fast_ledge_wall()
	await _test_fast_interrupt()
	await _test_ranged_spacing()
	await _test_ranged_shooting()
	await _test_ranged_cancel_and_death()
	await _test_line_of_sight()
	_test_subclass_hooks()
	_test_rename()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_projectile() -> void:
	await _reset_player()
	var slow: ProjectileStats = _copy(PROJECTILE_STATS, {"speed": 300.0, "lifetime": 0.5}) as ProjectileStats

	# Straight line and lifetime expiry.
	var reasons: Array[StringName] = [&""]
	var hitbox_active_on_despawn: Array[bool] = [true]
	var start := Vector2(0.0, 100.0)
	var projectile := _spawn_projectile(start, Vector2.RIGHT, CombatLayers.Team.ENEMY, slow)
	projectile.despawned.connect(func(reason: StringName) -> void:
		reasons[0] = reason
		hitbox_active_on_despawn[0] = projectile.hitbox.is_active)
	await _frames(15)
	var moved: Vector2 = projectile.global_position - start
	_check("projectile: flies straight at the configured speed", absf(moved.x - 300.0 * 15.0 / 60.0) <= 10.0 and absf(moved.y) < 0.5,
		"moved=%s" % moved)
	await _frames(30)
	_check("projectile: despawns on lifetime expiry", reasons[0] == &"lifetime" and not is_instance_valid(projectile), "reason=%s" % reasons[0])
	_check("projectile: no active hitbox after despawn", not hitbox_active_on_despawn[0])

	# World contact.
	reasons[0] = &""
	var falling := _spawn_projectile(Vector2(300.0, 250.0), Vector2.DOWN, CombatLayers.Team.ENEMY, slow)
	falling.despawned.connect(func(reason: StringName) -> void: reasons[0] = reason)
	await _frames(30)
	_check("projectile: despawns on world contact", reasons[0] == &"world" and not is_instance_valid(falling),
		"reason=%s valid=%s pos=%s" % [reasons[0], is_instance_valid(falling), falling.global_position if is_instance_valid(falling) else "-"])

	# Damages the player exactly once and despawns.
	var max_hp: int = player.health.max_health
	reasons[0] = &""
	var shot := _spawn_projectile(PLAYER_START + Vector2(-100.0, 0.0), Vector2.RIGHT, CombatLayers.Team.ENEMY, slow)
	shot.despawned.connect(func(reason: StringName) -> void: reasons[0] = reason)
	await _frames(40)
	_check("projectile: damages the player once and despawns",
		player.health.current_health == max_hp - PROJECTILE_STATS.damage and reasons[0] == &"hit" and not is_instance_valid(shot),
		"hp=%d reason=%s" % [player.health.current_health, reasons[0]])
	await _reset_player()

	# A projectile that passes through still damages only once.
	var piercing: ProjectileStats = _copy(PROJECTILE_STATS, {"speed": 100.0, "lifetime": 3.0, "destroy_on_hit": false}) as ProjectileStats
	var passing := _spawn_projectile(PLAYER_START + Vector2(-60.0, 0.0), Vector2.RIGHT, CombatLayers.Team.ENEMY, piercing)
	await _frames(100)
	_check("projectile: hits the same target at most once (no destroy_on_hit)", player.health.current_health == max_hp - PROJECTILE_STATS.damage,
		"hp=%d" % player.health.current_health)
	await _remove(passing)
	await _reset_player()

	# An enemy-team projectile never hurts enemies.
	var dummy := _spawn_enemy(MELEE_SCENE, 0.0, ENEMY_FLOOR_Y, _copy(MELEE_STATS, PASSIVE) as EnemyStats)
	var long_lived: ProjectileStats = _copy(PROJECTILE_STATS, {"speed": 300.0, "lifetime": 1.0}) as ProjectileStats
	var through := _spawn_projectile(Vector2(-100.0, ENEMY_FLOOR_Y), Vector2.RIGHT, CombatLayers.Team.ENEMY, long_lived)
	await _frames(40)
	_check("projectile: enemy-team projectile does not damage enemies",
		dummy.health.current_health == dummy.health.max_health and is_instance_valid(through) and through.global_position.x > 50.0)
	await _remove(through)
	await _remove(dummy)

	# The sword does not destroy it.
	await _reset_player()
	var parked_stats: ProjectileStats = _copy(PROJECTILE_STATS, {"speed": 0.0, "lifetime": 3.0}) as ProjectileStats
	var parked := _spawn_projectile(PLAYER_START + Vector2(40.0, 0.0), Vector2.RIGHT, CombatLayers.Team.ENEMY, parked_stats)
	await _tap("attack", 1)
	await _frames(40)
	_check("projectile: not destroyed by the player's sword", is_instance_valid(parked) and player.health.current_health == player.health.max_health)
	await _remove(parked)


func _test_fast_stats_and_lunge() -> void:
	await _reset_player()
	var fast := _spawn_enemy(FAST_SCENE, 3000.0, ENEMY_FLOOR_Y, FAST_STATS)
	await _frames(3)
	_check("fast: stats applied, faster and more fragile than melee",
		fast.health.max_health == FAST_STATS.max_health and fast.health.max_health < MELEE_STATS.max_health
		and FAST_STATS.move_speed >= MELEE_STATS.move_speed * 2.0,
		"hp=%d speed=%.0f" % [fast.health.max_health, FAST_STATS.move_speed])
	await _remove(fast)

	var stats: FastEnemyStats = _copy(FAST_STATS, {"patrol_enabled": false}) as FastEnemyStats
	var enemy := _spawn_enemy(FAST_SCENE, PLAYER_START.x + 150.0, ENEMY_FLOOR_Y, stats)
	var max_hp: int = player.health.max_health
	var log: Array[Dictionary] = []
	var in_attack: bool = false
	var end_index: int = -1
	for i in 400:
		await get_tree().physics_frame
		var attacking: bool = enemy.state == EnemyBase.State.ATTACK
		log.append({"attack": attacking, "active": enemy.attack_hitbox.is_active, "vx": enemy.velocity.x})
		if in_attack and not attacking:
			end_index = i
			break
		in_attack = attacking
	var first_attack: int = -1
	var first_active: int = -1
	var last_active: int = -1
	var max_lunge_speed: float = 0.0
	for i in log.size():
		if log[i]["attack"] and first_attack < 0:
			first_attack = i
		if log[i]["active"]:
			if first_active < 0:
				first_active = i
			last_active = i
			max_lunge_speed = maxf(max_lunge_speed, absf(log[i]["vx"]))
	_check("fast: lunge happens after the telegraph", first_attack >= 0 and first_active > first_attack and not log[first_attack]["active"],
		"attack@%d active@%d" % [first_attack, first_active])
	_check("fast: telegraph is stopped and hitbox inactive", first_active > 0 and absf(log[first_active - 1]["vx"]) < 1.0 and not log[first_active - 1]["active"])
	_check("fast: hitbox active during the lunge at lunge_speed", last_active >= first_active and is_equal_approx(max_lunge_speed, stats.lunge_speed),
		"speed=%.0f frames=%d" % [max_lunge_speed, last_active - first_active + 1])
	_check("fast: recovery is stopped and hitbox inactive", end_index > last_active + 1
		and not log[last_active + 1]["active"] and absf(log[last_active + 1]["vx"]) < 1.0)
	_check("fast: one hit per lunge", player.health.current_health == max_hp - stats.attack_damage, "hp=%d" % player.health.current_health)
	await _remove(enemy)


func _test_fast_ledge_wall() -> void:
	await _reset_player()
	var base: Dictionary = PASSIVE.duplicate()

	var ledge_enemy := _spawn_enemy(FAST_SCENE, PLATFORM_RIGHT - 30.0, ENEMY_ON_PLATFORM_Y, _copy(FAST_STATS, base) as EnemyStats)
	await _frames(5)
	(ledge_enemy as FastEnemy)._start_attack()
	var max_x: float = ledge_enemy.global_position.x
	for i in 90:
		await get_tree().physics_frame
		max_x = maxf(max_x, ledge_enemy.global_position.x)
	_check("fast: lunge stops at a ledge", max_x <= PLATFORM_RIGHT and ledge_enemy.global_position.y < PLATFORM_TOP,
		"max_x=%.1f y=%.1f" % [max_x, ledge_enemy.global_position.y])
	await _remove(ledge_enemy)

	var leaping := _spawn_enemy(FAST_SCENE, PLATFORM_RIGHT - 30.0, ENEMY_ON_PLATFORM_Y,
			_copy(FAST_STATS, _merge(base, {"lunge_stop_on_ledge": false, "turn_on_ledge": false})) as EnemyStats)
	await _frames(5)
	(leaping as FastEnemy)._start_attack()
	await _frames(90)
	_check("fast: lunge leaves the ledge when lunge_stop_on_ledge is false", leaping.global_position.x > PLATFORM_RIGHT,
		"x=%.1f" % leaping.global_position.x)
	await _remove(leaping)

	var wall_enemy := _spawn_enemy(FAST_SCENE, WALL_LEFT - 60.0, ENEMY_FLOOR_Y, _copy(FAST_STATS, base) as EnemyStats)
	await _frames(5)
	(wall_enemy as FastEnemy)._start_attack()
	var wall_max_x: float = wall_enemy.global_position.x
	for i in 90:
		await get_tree().physics_frame
		wall_max_x = maxf(wall_max_x, wall_enemy.global_position.x)
	_check("fast: lunge stops at a wall", wall_max_x <= WALL_LEFT - 13.5, "max_x=%.1f" % wall_max_x)
	await _remove(wall_enemy)


func _merge(first: Dictionary, second: Dictionary) -> Dictionary:
	var merged: Dictionary = first.duplicate()
	merged.merge(second, true)
	return merged


func _test_fast_interrupt() -> void:
	for phase in ["telegraph", "lunge"]:
		await _reset_player()
		var enemy := _spawn_enemy(FAST_SCENE, 0.0, ENEMY_FLOOR_Y,
			_copy(FAST_STATS, _merge(PASSIVE, {"attack_startup_time": 0.6, "lunge_duration": 0.6})) as EnemyStats)
		await _frames(5)
		(enemy as FastEnemy)._start_attack()
		var ready_to_hit: bool
		if phase == "telegraph":
			await _frames(5)
			ready_to_hit = enemy.state == EnemyBase.State.ATTACK and not enemy.attack_hitbox.is_active
		else:
			ready_to_hit = await _wait_until(func() -> bool: return enemy.attack_hitbox.is_active, 90)
		await _hit_enemy(enemy)
		_check("fast: hit during %s cancels the attack" % phase,
			ready_to_hit and enemy.state == EnemyBase.State.HURT and not enemy.attack_hitbox.is_active
			and absf(enemy.velocity.x) < FAST_STATS.lunge_speed,
			"state=%s vx=%.0f" % [EnemyBase.State.keys()[enemy.state], enemy.velocity.x])
		await _frames(3)
		_check("fast: no hitbox left monitoring after %s hit" % phase, not enemy.attack_hitbox.monitoring)
		await _remove(enemy)

	# Recovery leaves it vulnerable to the real sword.
	await _reset_player()
	var target := _spawn_enemy(FAST_SCENE, 0.0, ENEMY_FLOOR_Y, _copy(FAST_STATS, PASSIVE) as EnemyStats)
	await _frames(5)
	var recovering: Array[bool] = [false]
	target.attack_phase_changed.connect(func(phase: EnemyBase.AttackPhase) -> void:
		if phase == EnemyBase.AttackPhase.RECOVERY:
			recovering[0] = true)
	(target as FastEnemy)._start_attack()
	await _wait_until(func() -> bool: return recovering[0], 120)
	player.global_position = target.global_position + Vector2(-60.0, 0.0)
	player.velocity = Vector2.ZERO
	await _frames(2)
	await _tap("attack", 1)
	await _frames(30)
	_check("fast: vulnerable to the sword during recovery",
		target.health.current_health == target.health.max_health - base_player_stats.attack_damage, "hp=%d" % target.health.current_health)
	await _remove(target)


func _test_ranged_spacing() -> void:
	await _reset_player()
	var no_shots: Dictionary = {"projectile_scene": null, "patrol_enabled": false}
	var stats: RangedEnemyStats = _copy(RANGED_STATS, no_shots) as RangedEnemyStats
	var enemy := _spawn_enemy(RANGED_SCENE, PLAYER_START.x + 300.0, ENEMY_FLOOR_Y, stats)
	await _frames(300)
	var distance: float = absf(enemy.global_position.x - player.global_position.x)
	_check("ranged: approaches until preferred_range and stops",
		absf(distance - stats.preferred_range) <= 8.0 and absf(enemy.velocity.x) < 1.0, "distance=%.1f" % distance)

	player.global_position = enemy.global_position + Vector2(-50.0, 0.0)
	player.velocity = Vector2.ZERO
	var start_x: float = enemy.global_position.x
	await _frames(150)
	distance = absf(enemy.global_position.x - player.global_position.x)
	_check("ranged: retreats when the player is inside min_range",
		enemy.global_position.x > start_x and distance >= stats.min_range - 4.0 and enemy.facing_direction == -1,
		"distance=%.1f facing=%d" % [distance, enemy.facing_direction])
	await _remove(enemy)

	# Retreat stops at a ledge and at a wall.
	await _reset_player(Vector2(PLATFORM_RIGHT - 80.0, FLOOR_Y - 30.0))
	var ledge_enemy := _spawn_enemy(RANGED_SCENE, PLATFORM_RIGHT - 50.0, ENEMY_ON_PLATFORM_Y, stats)
	await _frames(240)
	_check("ranged: does not retreat off a ledge", ledge_enemy.global_position.x <= PLATFORM_RIGHT
		and ledge_enemy.global_position.y < PLATFORM_TOP and ledge_enemy.facing_direction == -1,
		"x=%.1f y=%.1f" % [ledge_enemy.global_position.x, ledge_enemy.global_position.y])
	await _remove(ledge_enemy)

	await _reset_player(Vector2(WALL_LEFT - 80.0, FLOOR_Y - 30.0))
	var wall_enemy := _spawn_enemy(RANGED_SCENE, WALL_LEFT - 50.0, ENEMY_FLOOR_Y, stats)
	await _frames(240)
	_check("ranged: does not retreat into a wall", wall_enemy.global_position.x <= WALL_LEFT - 13.5,
		"x=%.1f" % wall_enemy.global_position.x)
	await _remove(wall_enemy)


func _test_ranged_shooting() -> void:
	await _reset_player()
	await _clear_projectiles()
	var stats: RangedEnemyStats = _copy(RANGED_STATS, {"patrol_enabled": false}) as RangedEnemyStats
	var enemy := _spawn_enemy(RANGED_SCENE, PLAYER_START.x + 250.0, ENEMY_FLOOR_Y, stats)
	var attack_starts: Array[int] = []
	var attack_ends: Array[int] = []
	enemy.state_changed.connect(func(_old: EnemyBase.State, new_state: EnemyBase.State) -> void:
		if new_state == EnemyBase.State.ATTACK:
			attack_starts.append(Engine.get_physics_frames()))
	enemy.attack_ended.connect(func() -> void: attack_ends.append(Engine.get_physics_frames()))
	var shot_frames: Array[int] = []
	var known: int = 0
	var cycles_seen: bool = false
	for i in 400:
		await get_tree().physics_frame
		while known < spawned_projectiles.size():
			shot_frames.append(Engine.get_physics_frames())
			known += 1
		if attack_starts.size() >= 2 and not cycles_seen:
			cycles_seen = true
			break
	_check("ranged: fires exactly one projectile per shot cycle",
		attack_starts.size() >= 2 and attack_ends.size() >= 1 and shot_frames.size() >= 1
		and shot_frames[0] >= attack_starts[0] and shot_frames[0] <= attack_ends[0],
		"shots=%d starts=%s ends=%s" % [shot_frames.size(), attack_starts, attack_ends])
	var startup_frames: int = int(floor(stats.attack_startup_time * 60.0))
	_check("ranged: shot comes after the startup", shot_frames.size() >= 1 and shot_frames[0] - attack_starts[0] >= startup_frames - 2,
		"delay=%d startup=%d" % [shot_frames[0] - attack_starts[0] if shot_frames.size() > 0 else -1, startup_frames])
	_check("ranged: only one projectile before the next cycle", shot_frames.size() == 1 or (shot_frames.size() == 2 and shot_frames[1] >= attack_starts[1]),
		"shots=%s second_start=%s" % [shot_frames, attack_starts])
	var cooldown_frames: int = int(stats.attack_cooldown * 60.0)
	_check("ranged: cooldown respected", attack_starts.size() >= 2 and attack_starts[1] - attack_ends[0] >= cooldown_frames - 2,
		"gap=%d cooldown=%d" % [attack_starts[1] - attack_ends[0] if attack_starts.size() >= 2 else -1, cooldown_frames])
	_check("ranged: projectile hit the player", player.health.current_health < player.health.max_health, "hp=%d" % player.health.current_health)
	await _remove(enemy)
	await _clear_projectiles()


func _test_ranged_cancel_and_death() -> void:
	# Hit during startup cancels the shot.
	await _reset_player()
	await _clear_projectiles()
	var charging: Dictionary = {"attack_startup_time": 0.6, "patrol_enabled": false, "max_health": 10}
	var enemy := _spawn_enemy(RANGED_SCENE, PLAYER_START.x + 250.0, ENEMY_FLOOR_Y, _copy(RANGED_STATS, charging) as EnemyStats)
	var attacking: bool = await _wait_until(func() -> bool: return enemy.state == EnemyBase.State.ATTACK, 120)
	await _hit_enemy(enemy)
	await _frames(70)
	_check("ranged: hit during startup cancels the shot", attacking and spawned_projectiles.is_empty(), "shots=%d" % spawned_projectiles.size())
	await _remove(enemy)

	# A projectile outlives its shooter.
	await _reset_player()
	await _clear_projectiles()
	var slow_shot: ProjectileStats = _copy(PROJECTILE_STATS, {"speed": 100.0, "lifetime": 5.0}) as ProjectileStats
	var shooter := _spawn_enemy(RANGED_SCENE, PLAYER_START.x + 250.0, ENEMY_FLOOR_Y,
		_copy(RANGED_STATS, {"attack_startup_time": 0.2, "patrol_enabled": false, "projectile_stats": slow_shot}) as EnemyStats)
	await _wait_until(func() -> bool: return not spawned_projectiles.is_empty(), 120)
	var projectile: Projectile = spawned_projectiles[0] if not spawned_projectiles.is_empty() else null
	var x_before: float = projectile.global_position.x if projectile else 0.0
	shooter.health.kill()
	await _frames(45)
	_check("ranged: projectile survives its shooter's death",
		projectile != null and is_instance_valid(projectile) and not is_instance_valid(shooter)
		and projectile.global_position.x < x_before, "x %.1f -> %.1f" % [x_before, projectile.global_position.x if projectile else 0.0])
	await _clear_projectiles()

	# Never fires at a dead player.
	await _reset_player()
	await _clear_projectiles()
	var copy: PlayerStats = base_player_stats.duplicate() as PlayerStats
	copy.auto_respawn = false
	player.stats = copy
	player.health.kill()
	await _frames(3)
	var bystander := _spawn_enemy(RANGED_SCENE, PLAYER_START.x + 250.0, ENEMY_FLOOR_Y, _copy(RANGED_STATS, {"patrol_enabled": false}) as EnemyStats)
	await _frames(150)
	_check("ranged: does not fire at a dead player", spawned_projectiles.is_empty() and bystander.state == EnemyBase.State.IDLE,
		"shots=%d" % spawned_projectiles.size())
	await _remove(bystander)

	# Player dies during the startup: the shot is dropped.
	await _reset_player()
	player.stats = copy
	var dropper := _spawn_enemy(RANGED_SCENE, PLAYER_START.x + 250.0, ENEMY_FLOOR_Y,
		_copy(RANGED_STATS, {"attack_startup_time": 0.6, "patrol_enabled": false}) as EnemyStats)
	await _wait_until(func() -> bool: return dropper.state == EnemyBase.State.ATTACK, 120)
	player.health.kill()
	await _frames(70)
	_check("ranged: no shot when the player dies during startup", spawned_projectiles.is_empty(), "shots=%d" % spawned_projectiles.size())
	await _remove(dropper)
	await _reset_player()


func _test_line_of_sight() -> void:
	await _reset_player()
	var stats: EnemyStats = _copy(MELEE_STATS, {"detection_requires_line_of_sight": true, "patrol_enabled": false}) as EnemyStats
	var enemy := _spawn_enemy(MELEE_SCENE, PLAYER_START.x + 150.0, ENEMY_FLOOR_Y, stats)
	var blocker := _add_static(Vector2(PLAYER_START.x + 75.0, FLOOR_Y - 100.0), Vector2(20.0, 200.0))
	await _frames(20)
	_check("line of sight: target behind a wall is not acquired", enemy.target == null and enemy.state == EnemyBase.State.IDLE,
		"state=%s" % EnemyBase.State.keys()[enemy.state])
	blocker.queue_free()
	await _frames(5)
	_check("line of sight: acquired once the wall is gone", enemy.target != null and enemy.state == EnemyBase.State.CHASE)
	await _remove(enemy)

	# The ranged enemy does not shoot through a wall when it needs line of sight.
	await _reset_player()
	await _clear_projectiles()
	var shooter := _spawn_enemy(RANGED_SCENE, PLAYER_START.x + 250.0, ENEMY_FLOOR_Y,
		_copy(RANGED_STATS, {"patrol_enabled": false, "preferred_range": 400.0}) as EnemyStats)
	var wall := _add_static(Vector2(PLAYER_START.x + 120.0, FLOOR_Y - 100.0), Vector2(20.0, 200.0))
	await _frames(120)
	_check("line of sight: ranged enemy does not shoot through a wall", spawned_projectiles.is_empty(), "shots=%d" % spawned_projectiles.size())
	wall.queue_free()
	await _remove(shooter)
	await _clear_projectiles()


func _test_subclass_hooks() -> void:
	for subclass in [MeleeEnemy, FastEnemy, RangedEnemy]:
		var script: Script = subclass
		var offenders: Array[String] = []
		var pattern := RegEx.create_from_string("(?m)^func\\s+(\\w+)")
		for match in pattern.search_all(script.source_code):
			var method_name: String = match.get_string(1)
			if not ALLOWED_SUBCLASS_METHODS.has(method_name):
				offenders.append(method_name)
		_check("subclass: %s only defines documented hooks/helpers" % script.get_global_name(), offenders.is_empty(), "extra=%s" % [offenders])
	_check("subclass: stats resources extend EnemyStats", FAST_STATS is EnemyStats and RANGED_STATS is EnemyStats)


func _test_rename() -> void:
	var old_name: String = "Ducks of the " + "Fallen Stars"
	_check("rename: project name is Quacktaclysm", ProjectSettings.get_setting("application/config/name") == "Quacktaclysm")
	var root: String = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var hits: Array[String] = []
	_scan_for_text(root, old_name, hits)
	_check("rename: old project name no longer appears in text files", hits.is_empty(), "files=%s" % [hits])


func _scan_for_text(dir_path: String, needle: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub != ".godot" and sub != ".git":
			_scan_for_text(dir_path.path_join(sub), needle, hits)
	for file_name in dir.get_files():
		var extension: String = file_name.get_extension()
		if extension in ["gd", "tscn", "tres", "godot", "md", "cfg", "gitignore", "gitattributes", "txt"] or file_name.begins_with("."):
			var file := FileAccess.open(dir_path.path_join(file_name), FileAccess.READ)
			if file and file.get_as_text().contains(needle):
				hits.append(file_name)

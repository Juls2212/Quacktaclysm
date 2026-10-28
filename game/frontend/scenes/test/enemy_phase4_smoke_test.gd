extends Node
## Headless smoke test for Phase 4: EnemyBase and MeleeEnemy. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/enemy_phase4_smoke_test.tscn

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const MELEE_SCENE: PackedScene = preload("res://backend/enemies/melee_enemy.tscn")
const BASIC_STATS: EnemyStats = preload("res://backend/enemies/stats/melee_basic_stats.tres")
const TOUGH_STATS: EnemyStats = preload("res://backend/enemies/stats/melee_tough_stats.tres")
const FLOOR_Y: float = 300.0
const ENEMY_HALF_HEIGHT: float = 24.0
const ENEMY_FLOOR_Y: float = FLOOR_Y - ENEMY_HALF_HEIGHT
const PLAYER_START: Vector2 = Vector2(-2000.0, FLOOR_Y - 30.0)
## Ledge platform spans x 500..700 with its top at y = 220.
const PLATFORM_LEFT: float = 500.0
const PLATFORM_RIGHT: float = 700.0
const PLATFORM_TOP: float = 220.0
const ENEMY_ON_PLATFORM_Y: float = PLATFORM_TOP - ENEMY_HALF_HEIGHT
## Wall block spans x 1000..1040.
const WALL_LEFT: float = 1000.0

var failures: int = 0
var player: Player
var base_player_stats: PlayerStats
var attack_started_count: int = 0
var died_count: int = 0


func _ready() -> void:
	_add_static(Vector2(0.0, FLOOR_Y + 20.0), Vector2(6000.0, 40.0))
	_add_static(Vector2((PLATFORM_LEFT + PLATFORM_RIGHT) / 2.0, PLATFORM_TOP + 10.0), Vector2(PLATFORM_RIGHT - PLATFORM_LEFT, 20.0))
	_add_static(Vector2(WALL_LEFT + 20.0, FLOOR_Y - 50.0), Vector2(40.0, 100.0))

	player = PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_START
	add_child(player)
	base_player_stats = player.stats
	player.attack_started.connect(func() -> void: attack_started_count += 1)
	_run.call_deferred()


func _add_static(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	body.collision_mask = 0
	body.position = pos
	body.add_child(_rect_shape(size))
	add_child(body)


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


func _stats(overrides: Dictionary) -> EnemyStats:
	var copy: EnemyStats = BASIC_STATS.duplicate() as EnemyStats
	for key in overrides:
		copy.set(key, overrides[key])
	return copy


func _spawn(x: float, y: float, stats: EnemyStats = null) -> MeleeEnemy:
	var enemy := MELEE_SCENE.instantiate() as MeleeEnemy
	if stats != null:
		enemy.stats = stats
	enemy.position = Vector2(x, y)
	add_child(enemy)
	return enemy


func _remove(enemy: EnemyBase) -> void:
	if is_instance_valid(enemy):
		enemy.attack_hitbox.deactivate()
		enemy.queue_free()
	await _frames(2)


func _reset_player(pos: Vector2 = PLAYER_START) -> void:
	for action in ["move_left", "move_right", "jump", "dash", "attack"]:
		Input.action_release(action)
	player.stats = base_player_stats
	player.health.invulnerability_time = base_player_stats.hurt_invulnerability_time
	player.revive()
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.facing_direction = 1
	await _frames(40)
	attack_started_count = 0


## A player-team hit placed on the enemy, standing in for the sword.
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
	await _test_stats()
	await _test_detection()
	await _test_patrol()
	await _test_attack()
	await _test_hurt()
	await _test_death()
	await _test_collision()
	await _test_buffer_fix()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_stats() -> void:
	await _reset_player()
	var basic := _spawn(2000.0, ENEMY_FLOOR_Y)
	var tough := _spawn(2400.0, ENEMY_FLOOR_Y, TOUGH_STATS)
	await _frames(3)
	var radius: float = (basic.detection_shape.shape as CircleShape2D).radius
	_check("stats: health applied", basic.health.max_health == BASIC_STATS.max_health and tough.health.max_health == TOUGH_STATS.max_health)
	_check("stats: hitbox damage and knockback applied",
		basic.attack_hitbox.damage == BASIC_STATS.attack_damage and tough.attack_hitbox.damage == TOUGH_STATS.attack_damage
		and tough.attack_hitbox.knockback == TOUGH_STATS.attack_knockback)
	_check("stats: detection shape sized from detection_range", is_equal_approx(radius, BASIC_STATS.detection_range), "radius=%.0f" % radius)
	_check("stats: tough enemy differs from basic",
		tough.health.max_health != basic.health.max_health and tough.stats.move_speed != basic.stats.move_speed
		and tough.attack_hitbox.damage != basic.attack_hitbox.damage)
	_check("stats: enemy body collides only with world",
		basic.collision_mask == CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
		and basic.collision_layer == CombatLayers.layer_bit(CombatLayers.LAYER_ENEMY))
	await _remove(basic)
	await _remove(tough)


func _test_detection() -> void:
	await _reset_player()
	var idle_stats := _stats({"patrol_enabled": false})
	var enemy := _spawn(PLAYER_START.x + 200.0, ENEMY_FLOOR_Y, idle_stats)
	var acquired: Array[int] = [0]
	var lost: Array[int] = [0]
	enemy.target_acquired.connect(func(_t: Node2D) -> void: acquired[0] += 1)
	enemy.target_lost.connect(func() -> void: lost[0] += 1)
	await _frames(5)
	_check("detect: acquires target inside range and chases", acquired[0] == 1 and enemy.state == EnemyBase.State.CHASE)
	var before: float = absf(enemy.global_position.x - player.global_position.x)
	await _frames(30)
	var after: float = absf(enemy.global_position.x - player.global_position.x)
	_check("detect: moves toward the player", after < before - 10.0, "%.1f -> %.1f" % [before, after])
	_check("detect: faces the player", enemy.facing_direction == -1)

	player.global_position = enemy.global_position + Vector2(-(idle_stats.lose_target_range + 100.0), 0.0)
	await _frames(4)
	_check("detect: loses target beyond lose_target_range", lost[0] == 1 and enemy.target == null and enemy.state == EnemyBase.State.IDLE,
		"state=%s lost=%d target=%s" % [EnemyBase.State.keys()[enemy.state], lost[0], enemy.target])
	await _remove(enemy)

	# Returns to patrol after losing the target.
	await _reset_player()
	var patrol_enemy := _spawn(PLAYER_START.x + 200.0, ENEMY_FLOOR_Y, _stats({"patrol_wait_time": 0.2}))
	await _frames(5)
	player.global_position = patrol_enemy.global_position + Vector2(-500.0, 0.0)
	await _frames(30)
	_check("detect: returns to PATROL after losing the target", patrol_enemy.state == EnemyBase.State.PATROL,
		"state=%s" % EnemyBase.State.keys()[patrol_enemy.state])
	await _remove(patrol_enemy)

	# A dead player is ignored and the enemy stands still.
	await _reset_player()
	var copy: PlayerStats = base_player_stats.duplicate() as PlayerStats
	copy.auto_respawn = false
	player.stats = copy
	player.health.kill()
	await _frames(3)
	var bystander := _spawn(PLAYER_START.x + 100.0, ENEMY_FLOOR_Y, _stats({"patrol_wait_time": 0.1}))
	var start_x: float = bystander.global_position.x
	await _frames(40)
	_check("detect: ignores a dead player and stands still",
		bystander.target == null and bystander.state == EnemyBase.State.IDLE and is_equal_approx(bystander.global_position.x, start_x),
		"state=%s" % EnemyBase.State.keys()[bystander.state])
	player.revive()
	await _frames(5)
	_check("detect: acquires the player again once alive", bystander.state == EnemyBase.State.CHASE)
	await _remove(bystander)

	# Killing the player mid-chase drops the target.
	await _reset_player()
	player.stats = copy
	var chaser := _spawn(PLAYER_START.x + 200.0, ENEMY_FLOOR_Y, idle_stats)
	await _frames(10)
	var was_chasing: bool = chaser.state == EnemyBase.State.CHASE
	player.health.kill()
	await _frames(4)
	_check("detect: player death during chase drops the target", was_chasing and chaser.target == null and chaser.state != EnemyBase.State.CHASE)
	await _remove(chaser)
	await _reset_player()


func _test_patrol() -> void:
	await _reset_player()
	var fast: Dictionary = {"move_speed": 200.0, "patrol_wait_time": 0.1}

	var wall_enemy := _spawn(WALL_LEFT - 100.0, ENEMY_FLOOR_Y, _stats(fast))
	var turned: bool = await _wait_until(func() -> bool: return wall_enemy.facing_direction == -1, 240)
	_check("patrol: turns at a wall", turned and wall_enemy.global_position.x < WALL_LEFT - 14.0,
		"x=%.1f" % wall_enemy.global_position.x)
	await _remove(wall_enemy)

	var ledge_enemy := _spawn((PLATFORM_LEFT + PLATFORM_RIGHT) / 2.0, ENEMY_ON_PLATFORM_Y, _stats(fast))
	var min_x: float = ledge_enemy.global_position.x
	var max_x: float = min_x
	var max_y: float = ledge_enemy.global_position.y
	var flips: int = 0
	var last_facing: int = ledge_enemy.facing_direction
	for i in 500:
		await get_tree().physics_frame
		min_x = minf(min_x, ledge_enemy.global_position.x)
		max_x = maxf(max_x, ledge_enemy.global_position.x)
		max_y = maxf(max_y, ledge_enemy.global_position.y)
		if ledge_enemy.facing_direction != last_facing:
			flips += 1
			last_facing = ledge_enemy.facing_direction
	_check("patrol: turns at ledges and never falls", flips >= 2 and max_y < PLATFORM_TOP and min_x >= PLATFORM_LEFT and max_x <= PLATFORM_RIGHT,
		"flips=%d x=[%.0f,%.0f] max_y=%.0f" % [flips, min_x, max_x, max_y])
	await _remove(ledge_enemy)

	# Chasing stops at the edge instead of walking off.
	await _reset_player(Vector2(PLATFORM_RIGHT + 60.0, FLOOR_Y - 30.0))
	var chaser := _spawn(PLATFORM_RIGHT - 150.0, ENEMY_ON_PLATFORM_Y, _stats({"patrol_enabled": false}))
	await _frames(240)
	_check("chase: stops at a ledge", chaser.target != null and chaser.state == EnemyBase.State.CHASE
		and chaser.global_position.x <= PLATFORM_RIGHT and chaser.global_position.y < PLATFORM_TOP
		and chaser.global_position.x > PLATFORM_RIGHT - 150.0,
		"x=%.1f y=%.1f" % [chaser.global_position.x, chaser.global_position.y])
	await _remove(chaser)


func _test_attack() -> void:
	await _reset_player()
	var stats := _stats({"patrol_enabled": false})
	var enemy := _spawn(PLAYER_START.x + 150.0, ENEMY_FLOOR_Y, stats)
	var max_hp: int = player.health.max_health
	player.health.invulnerability_time = 0.0

	var log: Array[Dictionary] = []
	var segments: int = 0
	var first_segment_end: int = -1
	var second_segment_start: int = -1
	var second_segment_end: int = -1
	var in_attack: bool = false
	var hp_after_first: int = -1
	var distance_at_start: float = -1.0
	for i in 700:
		await get_tree().physics_frame
		var attacking: bool = enemy.state == EnemyBase.State.ATTACK
		log.append({"attack": attacking, "active": enemy.attack_hitbox.is_active})
		if attacking and not in_attack:
			segments += 1
			if segments == 1:
				distance_at_start = enemy.global_position.distance_to(player.global_position)
			elif segments == 2:
				second_segment_start = i
		if not attacking and in_attack:
			if segments == 1:
				first_segment_end = i
				hp_after_first = player.health.current_health
				# The second swing must be blocked by i-frames.
				player.health.invulnerability_time = 0.0
				player.health.grant_invulnerability(10.0)
			elif segments == 2:
				second_segment_end = i
				break
		in_attack = attacking
	_check("attack: starts only within attack_range", segments >= 1 and distance_at_start <= stats.attack_range + 4.0,
		"distance=%.1f range=%.0f" % [distance_at_start, stats.attack_range])
	var first_start: int = -1
	var first_active: int = -1
	var last_active: int = -1
	for i in first_segment_end:
		if log[i]["attack"] and first_start < 0:
			first_start = i
		if log[i]["active"]:
			if first_active < 0:
				first_active = i
			last_active = i
	_check("attack: hitbox inactive in startup", first_active > first_start and not log[first_start]["active"],
		"start@%d active@%d" % [first_start, first_active])
	_check("attack: hitbox active in the active window", last_active >= first_active and first_active >= 0,
		"active frames=%d" % (last_active - first_active + 1))
	_check("attack: hitbox inactive in recovery", first_segment_end - 1 > last_active and not log[first_segment_end - 1]["active"])
	_check("attack: hits the player exactly once per swing", hp_after_first == max_hp - stats.attack_damage, "hp=%d" % hp_after_first)
	var gap: int = second_segment_start - first_segment_end
	var cooldown_frames: int = int(stats.attack_cooldown * 60.0)
	_check("attack: respects cooldown", second_segment_start > 0 and gap >= cooldown_frames - 2, "gap=%d cooldown=%d" % [gap, cooldown_frames])
	_check("attack: player i-frames are honored", second_segment_end > 0 and player.health.current_health == hp_after_first,
		"hp=%d" % player.health.current_health)
	await _remove(enemy)
	await _reset_player()

	# Out of range: no attack.
	var far_enemy := _spawn(PLAYER_START.x + 200.0, ENEMY_FLOOR_Y, _stats({"patrol_enabled": false, "move_speed": 0.0}))
	await _frames(60)
	_check("attack: does not start out of range", far_enemy.state == EnemyBase.State.CHASE and player.health.current_health == player.health.max_health)
	await _remove(far_enemy)


func _test_hurt() -> void:
	await _reset_player()
	var passive := _stats({"detection_range": 1.0, "lose_target_range": 1.0, "patrol_enabled": false, "max_health": 5})
	var enemy := _spawn(PLAYER_START.x + 60.0, ENEMY_FLOOR_Y, passive)
	await _frames(5)
	await _tap("attack", 1)
	var hurt_velocity: float = 0.0
	var saw_hurt: bool = false
	for i in 30:
		await get_tree().physics_frame
		if enemy.state == EnemyBase.State.HURT and not saw_hurt:
			saw_hurt = true
			hurt_velocity = enemy.velocity.x
	_check("hurt: player's sword damages the enemy",
		enemy.health.current_health == passive.max_health - base_player_stats.attack_damage, "hp=%d" % enemy.health.current_health)
	_check("hurt: enters HURT with knockback away from the player", saw_hurt and hurt_velocity > 0.0, "vx=%.1f" % hurt_velocity)
	await _remove(enemy)

	var swinging := _stats({"attack_range": 120.0, "patrol_enabled": false, "attack_startup_time": 0.4,
		"attack_active_time": 0.5, "max_health": 10})
	for phase in ["startup", "active"]:
		await _reset_player()
		var attacker := _spawn(PLAYER_START.x + 100.0, ENEMY_FLOOR_Y, swinging)
		var ready_to_hit: bool
		if phase == "startup":
			ready_to_hit = await _wait_until(func() -> bool: return attacker.state == EnemyBase.State.ATTACK and not attacker.attack_hitbox.is_active, 60)
		else:
			ready_to_hit = await _wait_until(func() -> bool: return attacker.attack_hitbox.is_active, 90)
		await _hit_enemy(attacker)
		_check("hurt: hit during %s cancels the attack" % phase,
			ready_to_hit and attacker.state == EnemyBase.State.HURT and not attacker.attack_hitbox.is_active,
			"state=%s" % EnemyBase.State.keys()[attacker.state])
		await _frames(3)
		_check("hurt: no hitbox left monitoring after %s hit" % phase, not attacker.attack_hitbox.monitoring)
		await _remove(attacker)


func _test_death() -> void:
	await _reset_player()
	var stats := _stats({"max_health": 1, "patrol_enabled": false, "attack_range": 120.0,
		"attack_startup_time": 0.6, "death_fade_time": 0.5})
	var enemy := _spawn(PLAYER_START.x + 100.0, ENEMY_FLOOR_Y, stats)
	died_count = 0
	enemy.died.connect(func(_e: EnemyBase) -> void: died_count += 1)
	var attacking: bool = await _wait_until(func() -> bool: return enemy.state == EnemyBase.State.ATTACK, 60)
	await _hit_enemy(enemy)
	_check("death: died emitted once and state DEAD", attacking and died_count == 1 and enemy.state == EnemyBase.State.DEAD,
		"died=%d" % died_count)
	_check("death: hurtbox and hitbox disabled", not enemy.hurtbox.enabled and not enemy.attack_hitbox.is_active)
	await _frames(3)
	_check("death: hitbox not monitoring", not enemy.attack_hitbox.monitoring)
	await _frames(int(ceil(stats.death_fade_time * 60.0)) + 10)
	_check("death: enemy freed after the fade", not is_instance_valid(enemy))
	_check("death: died not emitted again", died_count == 1)
	_check("death: dead enemy never damaged the player", player.health.current_health == player.health.max_health)


func _test_collision() -> void:
	await _reset_player()
	var passive := _stats({"detection_range": 1.0, "lose_target_range": 1.0, "patrol_enabled": false})
	var enemy := _spawn(PLAYER_START.x + 60.0, ENEMY_FLOOR_Y, passive)
	var enemy_x: float = enemy.global_position.x
	await _frames(5)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check("collision: player walks through the enemy body",
		player.global_position.x > enemy_x + 20.0 and is_equal_approx(enemy.global_position.x, enemy_x),
		"player_x=%.1f enemy_x=%.1f" % [player.global_position.x, enemy.global_position.x])
	await _remove(enemy)


func _test_buffer_fix() -> void:
	await _reset_player()
	var copy: PlayerStats = base_player_stats.duplicate() as PlayerStats
	copy.attack_input_buffer_time = 0.0
	player.stats = copy
	await _tap("attack", 2)
	_check("player: attack starts with attack_input_buffer_time = 0", attack_started_count == 1, "started=%d" % attack_started_count)
	await _reset_player()

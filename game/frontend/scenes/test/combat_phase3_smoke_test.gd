extends Node
## Headless smoke test for Phase 3: sword, death/respawn, checkpoint, kill zone, HUD. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/combat_phase3_smoke_test.tscn

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://frontend/scenes/test/training_dummy.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://backend/progression/checkpoint.tscn")
const KILL_ZONE_SCENE: PackedScene = preload("res://backend/combat/kill_zone.tscn")
const HUD_SCENE: PackedScene = preload("res://frontend/ui/player_health_hud.tscn")
const FLOOR_Y: float = 300.0
const PLAYER_START: Vector2 = Vector2(-2000.0, FLOOR_Y - 30.0)
const FAR_AWAY: Vector2 = Vector2(-9000.0, 0.0)
const DUMMY_DISTANCE: float = 60.0

var failures: int = 0
var player: Player
var base_stats: PlayerStats
var attack_started_count: int = 0
var attack_finished_count: int = 0
var dash_count: int = 0
var respawn_count: int = 0
var checkpoint_activations: int = 0
var last_checkpoint_id: StringName = &""


func _ready() -> void:
	# Never touch the real save file.
	SaveSystem.set_save_path("user://test_save_phase3.json")
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.collision_mask = 0
	floor_body.position = Vector2(0.0, FLOOR_Y + 20.0)
	floor_body.add_child(_rect_shape(Vector2(6000.0, 40.0)))
	add_child(floor_body)

	player = PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_START
	add_child(player)
	base_stats = player.stats
	player.attack_started.connect(func() -> void: attack_started_count += 1)
	player.attack_finished.connect(func() -> void: attack_finished_count += 1)
	player.dash_started.connect(func() -> void: dash_count += 1)
	player.respawned.connect(func() -> void: respawn_count += 1)
	_run.call_deferred()


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


## Presses an action; the player consumes it on its next physics step.
func _tap(action: String, frames: int = 2) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _stats_copy() -> PlayerStats:
	var copy: PlayerStats = base_stats.duplicate() as PlayerStats
	player.stats = copy
	return copy


func _reset() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "attack"]:
		Input.action_release(action)
	player.stats = base_stats
	player.set_respawn_point(PLAYER_START)
	player.revive()
	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	player.facing_direction = 1
	await _frames(40)
	attack_started_count = 0
	attack_finished_count = 0
	dash_count = 0
	respawn_count = 0


func _make_dummy(x_offset: float) -> TrainingDummy:
	var dummy := DUMMY_SCENE.instantiate() as TrainingDummy
	dummy.position = Vector2(player.global_position.x + x_offset, FLOOR_Y)
	add_child(dummy)
	return dummy


func _make_hazard() -> Hitbox:
	var hazard := Hitbox.new()
	hazard.team = CombatLayers.Team.ENEMY
	hazard.damage = 1
	hazard.rehit_interval = 10.0
	hazard.knockback = Vector2(100.0, -50.0)
	hazard.add_child(_rect_shape(Vector2(40.0, 40.0)))
	hazard.position = FAR_AWAY
	add_child(hazard)
	return hazard


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _run() -> void:
	await _test_attack_phases()
	await _test_attack_hits()
	await _test_cooldown_buffer_air()
	await _test_attack_locks()
	await _test_interruption()
	await _test_death_respawn()
	await _test_checkpoint()
	await _test_kill_zone()
	await _test_hud()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	SaveSystem.purge()
	SaveSystem.set_save_path(SaveSystem.DEFAULT_PATH)
	get_tree().quit(1 if failures > 0 else 0)


func _test_attack_phases() -> void:
	await _reset()
	Input.action_press("attack")
	await _frames(1)
	Input.action_release("attack")
	var log: Array[Dictionary] = []
	for i in 40:
		await get_tree().physics_frame
		log.append({"attack": player.state == Player.State.ATTACK, "active": player.attack_hitbox.is_active})
	var first_attack: int = -1
	var last_attack: int = -1
	var first_active: int = -1
	var last_active: int = -1
	var attack_frames: int = 0
	for i in log.size():
		if log[i]["attack"]:
			attack_frames += 1
			if first_attack < 0:
				first_attack = i
			last_attack = i
		if log[i]["active"]:
			if first_active < 0:
				first_active = i
			last_active = i
	_check("attack: enters ATTACK", first_attack >= 0)
	_check("attack: hitbox inactive during startup", first_active > first_attack and not log[first_attack]["active"],
		"attack@%d active@%d" % [first_attack, first_active])
	_check("attack: hitbox active in the active window", last_active >= first_active and first_active >= 0,
		"active frames=%d" % (last_active - first_active + 1))
	_check("attack: hitbox inactive during recovery", last_attack > last_active and not log[last_attack]["active"],
		"last_active@%d last_attack@%d" % [last_active, last_attack])
	_check("attack: returns to normal state", not log[log.size() - 1]["attack"] and attack_finished_count == 1)
	var expected: int = int(round((base_stats.attack_startup_time + base_stats.attack_active_time + base_stats.attack_recovery_time) * 60.0))
	_check("attack: total duration matches stats", absi(attack_frames - expected) <= 3, "frames=%d expected~%d" % [attack_frames, expected])


func _test_attack_hits() -> void:
	await _reset()
	var front := _make_dummy(DUMMY_DISTANCE)
	var behind := _make_dummy(-DUMMY_DISTANCE)
	await _tap("attack", 1)
	await _frames(40)
	_check("attack: dummy in front loses exactly attack_damage once",
		front.health.current_health == front.health.max_health - base_stats.attack_damage, "hp=%d" % front.health.current_health)
	_check("attack: dummy behind is not hit", behind.health.current_health == behind.health.max_health)
	front.queue_free()
	behind.queue_free()

	await _reset()
	Input.action_press("move_left")
	await _frames(10)
	Input.action_release("move_left")
	await _frames(40)
	var left := _make_dummy(-DUMMY_DISTANCE)
	var right := _make_dummy(DUMMY_DISTANCE)
	await _tap("attack", 1)
	await _frames(40)
	_check("attack: facing left hits dummy on the left", player.facing_direction == -1
		and left.health.current_health == left.health.max_health - base_stats.attack_damage, "hp=%d" % left.health.current_health)
	_check("attack: facing left does not hit dummy on the right", right.health.current_health == right.health.max_health)
	left.queue_free()
	right.queue_free()


func _test_cooldown_buffer_air() -> void:
	# Cooldown: with a tiny buffer, an immediate second press is blocked, a later one works.
	await _reset()
	var stats: PlayerStats = _stats_copy()
	stats.attack_input_buffer_time = 0.02
	await _tap("attack", 1)
	await _wait_until(func() -> bool: return player.state == Player.State.ATTACK, 10)
	await _wait_until(func() -> bool: return player.state != Player.State.ATTACK, 60)
	await _tap("attack", 2)
	_check("attack: cooldown blocks immediate second attack", attack_started_count == 1 and player.state != Player.State.ATTACK,
		"started=%d" % attack_started_count)
	await _frames(int(ceil(stats.attack_cooldown * 60.0)) + 2)
	await _tap("attack", 2)
	_check("attack: allowed after cooldown", attack_started_count == 2, "started=%d" % attack_started_count)

	# Buffer: a press during the cooldown fires once the cooldown ends.
	await _reset()
	await _tap("attack", 1)
	await _wait_until(func() -> bool: return player.state == Player.State.ATTACK, 10)
	await _wait_until(func() -> bool: return player.state != Player.State.ATTACK, 60)
	await _frames(1)
	await _tap("attack", 1)
	await _frames(12)
	_check("attack: input buffer triggers attack pressed during cooldown", attack_started_count == 2, "started=%d" % attack_started_count)

	# Air attack.
	await _reset()
	Input.action_press("jump")
	await _frames(8)
	await _tap("attack", 2)
	_check("attack: air attack allowed by default", not player.is_on_floor() and player.state == Player.State.ATTACK)
	Input.action_release("jump")

	await _reset()
	_stats_copy().can_attack_in_air = false
	Input.action_press("jump")
	await _frames(8)
	await _tap("attack", 2)
	_check("attack: air attack blocked when can_attack_in_air is false", not player.is_on_floor() and player.state != Player.State.ATTACK)
	Input.action_release("jump")


func _test_attack_locks() -> void:
	await _reset()
	await _tap("attack", 3)
	Input.action_press("jump")
	Input.action_press("dash")
	await _frames(3)
	Input.action_release("jump")
	Input.action_release("dash")
	_check("attack: jump and dash blocked during attack",
		player.state == Player.State.ATTACK and player.is_on_floor() and dash_count == 0 and player.velocity.y >= 0.0,
		"state=%s dashes=%d" % [Player.State.keys()[player.state], dash_count])

	# Facing is locked while swinging.
	await _reset()
	await _tap("attack", 3)
	Input.action_press("move_left")
	await _frames(4)
	Input.action_release("move_left")
	_check("attack: facing locked during attack", player.facing_direction == 1 and player.state == Player.State.ATTACK)


func _test_interruption() -> void:
	var hazard := _make_hazard()

	await _reset()
	_stats_copy().attack_startup_time = 0.3
	await _tap("attack", 2)
	var in_startup: bool = player.state == Player.State.ATTACK and not player.attack_hitbox.is_active
	hazard.global_position = player.global_position + Vector2(-30.0, 0.0)
	hazard.activate()
	await _frames(5)
	_check("interrupt: damage during startup enters HURT with no active hitbox",
		in_startup and player.state == Player.State.HURT and not player.attack_hitbox.is_active,
		"state=%s" % Player.State.keys()[player.state])
	hazard.deactivate()
	hazard.global_position = FAR_AWAY
	await _frames(4)
	_check("interrupt: sword hitbox monitoring is off", not player.attack_hitbox.monitoring)
	await _frames(int(ceil(base_stats.hurt_stun_time * 60.0)))
	_check("interrupt: control returns after stun", player.can_act() and player.state != Player.State.ATTACK)
	_check("interrupt: attack_finished emitted", attack_finished_count == attack_started_count)

	await _reset()
	_stats_copy().attack_active_time = 0.5
	await _tap("attack", 1)
	var became_active: bool = await _wait_until(func() -> bool: return player.attack_hitbox.is_active, 30)
	hazard.global_position = player.global_position + Vector2(-30.0, 0.0)
	hazard.activate()
	await _frames(5)
	_check("interrupt: damage during active window leaves no active hitbox",
		became_active and player.state == Player.State.HURT and not player.attack_hitbox.is_active,
		"state=%s" % Player.State.keys()[player.state])
	hazard.deactivate()
	hazard.global_position = FAR_AWAY
	await _frames(4)
	_check("interrupt: sword monitoring off after active-window hit", not player.attack_hitbox.monitoring)
	await _frames(int(ceil(base_stats.hurt_stun_time * 60.0)))
	_check("interrupt: control returns after stun (active window)", player.can_act() and player.state != Player.State.ATTACK)
	hazard.queue_free()


func _test_death_respawn() -> void:
	await _reset()
	player.global_position = PLAYER_START + Vector2(200.0, 0.0)
	await _frames(5)
	player.health.apply_damage(DamageInfo.create(99))
	await _frames(3)
	_check("death: state is DEAD with control disabled", player.state == Player.State.DEAD and player.is_dead and not player.can_act())
	_check("death: hurtbox disabled", not player.hurtbox.enabled)
	await _frames(30)
	_check("death: stays dead during respawn delay", player.state == Player.State.DEAD and respawn_count == 0)
	var respawned: bool = await _wait_until(func() -> bool: return respawn_count > 0, 120)
	_check("respawn: happens after delay", respawned)
	_check("respawn: at respawn point with full health and zero velocity",
		absf(player.global_position.x - PLAYER_START.x) < 2.0 and player.health.current_health == player.stats.max_health
		and absf(player.velocity.x) < 1.0 and absf(player.velocity.y) < 60.0,
		"pos=%s hp=%d vel=%s" % [player.global_position, player.health.current_health, player.velocity])
	_check("respawn: brief invulnerability and control restored",
		player.is_invulnerable() and player.can_act() and player.state != Player.State.DEAD and not player.is_dead)
	var hazard := _make_hazard()
	hazard.global_position = player.global_position + Vector2(-30.0, 0.0)
	hazard.activate()
	await _frames(10)
	_check("respawn: invulnerability blocks damage", player.health.current_health == player.stats.max_health)
	# Deactivate first: a freed hazard still polls overlaps until the end of the frame.
	hazard.deactivate()
	hazard.queue_free()
	await _frames(2)

	await _reset()
	_stats_copy().auto_respawn = false
	player.health.apply_damage(DamageInfo.create(99))
	await _frames(150)
	_check("respawn: auto_respawn=false stays dead", player.state == Player.State.DEAD and player.is_dead and respawn_count == 0,
		"state=%s dead=%s respawns=%d" % [Player.State.keys()[player.state], player.is_dead, respawn_count])
	player.respawn()
	await _frames(2)
	_check("respawn: manual respawn() revives", not player.is_dead and player.state != Player.State.DEAD and respawn_count == 1)


func _test_checkpoint() -> void:
	await _reset()
	var checkpoint := CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.checkpoint_id = &"cp_test"
	checkpoint.position = Vector2(-1500.0, FLOOR_Y)
	add_child(checkpoint)
	checkpoint.activated.connect(func(id: StringName) -> void:
		checkpoint_activations += 1
		last_checkpoint_id = id)
	var spot: Vector2 = checkpoint.global_position + checkpoint.respawn_offset
	player.global_position = Vector2(-1500.0, FLOOR_Y - 30.0)
	player.velocity = Vector2.ZERO
	await _frames(5)
	_check("checkpoint: sets respawn point", player.get_respawn_point() == spot, "point=%s" % player.get_respawn_point())
	_check("checkpoint: emits activated once with id", checkpoint_activations == 1 and last_checkpoint_id == &"cp_test")
	player.global_position = PLAYER_START
	await _frames(5)
	player.global_position = Vector2(-1500.0, FLOOR_Y - 30.0)
	await _frames(5)
	_check("checkpoint: re-entering does not emit again", checkpoint_activations == 1, "count=%d" % checkpoint_activations)
	player.global_position = PLAYER_START
	await _frames(5)
	player.health.apply_damage(DamageInfo.create(99))
	var respawned: bool = await _wait_until(func() -> bool: return respawn_count > 0, 120)
	_check("checkpoint: player respawns at the checkpoint", respawned and absf(player.global_position.x - spot.x) < 2.0,
		"x=%.1f" % player.global_position.x)
	checkpoint.queue_free()


func _test_kill_zone() -> void:
	await _reset()
	var zone := KILL_ZONE_SCENE.instantiate() as KillZone
	zone.size = Vector2(400.0, 100.0)
	zone.position = Vector2(-1000.0, 600.0)
	add_child(zone)
	player.health.grant_invulnerability(5.0)
	_check("kill zone: player starts invulnerable", player.is_invulnerable())
	player.global_position = zone.position
	player.velocity = Vector2.ZERO
	await _frames(4)
	_check("kill zone: kills an invulnerable player", player.is_dead and player.state == Player.State.DEAD)
	var respawned: bool = await _wait_until(func() -> bool: return respawn_count > 0, 120)
	_check("kill zone: death triggers respawn", respawned and absf(player.global_position.x - PLAYER_START.x) < 2.0)
	zone.queue_free()


func _test_hud() -> void:
	await _reset()
	var hud := HUD_SCENE.instantiate() as PlayerHealthHud
	add_child(hud)
	hud.bind(player)
	var max_hp: int = player.stats.max_health
	_check("hud: shows full health when bound", hud.current_health == max_hp and hud.filled_pips() == max_hp)
	player.health.apply_damage(DamageInfo.create(2))
	_check("hud: updates on damage", hud.current_health == max_hp - 2 and hud.filled_pips() == max_hp - 2)
	player.health.heal(1)
	_check("hud: updates on heal", hud.current_health == max_hp - 1 and hud.filled_pips() == max_hp - 1)
	player.health.kill()
	_check("hud: shows 0 on death", hud.current_health == 0 and hud.filled_pips() == 0)
	await _wait_until(func() -> bool: return respawn_count > 0, 120)
	_check("hud: refills on respawn", hud.current_health == max_hp and hud.filled_pips() == max_hp)
	hud.queue_free()

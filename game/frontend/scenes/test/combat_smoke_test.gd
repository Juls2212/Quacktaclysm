extends Node
## Headless smoke test for the combat framework. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/combat_smoke_test.tscn

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const FLOOR_Y: float = 300.0
const PLAYER_START: Vector2 = Vector2(-2000.0, FLOOR_Y - 30.0)
const FAR_AWAY: Vector2 = Vector2(-9000.0, 0.0)
const TEAM_PLAYER := CombatLayers.Team.PLAYER
const TEAM_ENEMY := CombatLayers.Team.ENEMY

var failures: int = 0
var died_count: int = 0
var hit_count: int = 0
var player: Player


func _ready() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	floor_body.collision_mask = 0
	floor_body.position = Vector2(0.0, FLOOR_Y + 20.0)
	floor_body.add_child(_rect_shape(Vector2(6000.0, 40.0)))
	add_child(floor_body)
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


func _make_target(team: CombatLayers.Team, pos: Vector2, max_hp: int = 10) -> Hurtbox:
	var body := Node2D.new()
	body.position = pos
	var hp := HealthComponent.new()
	hp.max_health = max_hp
	body.add_child(hp)
	var hurtbox := Hurtbox.new()
	hurtbox.team = team
	hurtbox.health = hp
	hurtbox.add_child(_rect_shape(Vector2(40.0, 40.0)))
	body.add_child(hurtbox)
	add_child(body)
	return hurtbox


func _make_hitbox(team: CombatLayers.Team, pos: Vector2, size: Vector2 = Vector2(60.0, 60.0),
		rehit: float = 0.0, knockback: Vector2 = Vector2.ZERO) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.team = team
	hitbox.damage = 1
	hitbox.rehit_interval = rehit
	hitbox.knockback = knockback
	hitbox.position = pos
	hitbox.add_child(_rect_shape(size))
	add_child(hitbox)
	return hitbox


func _run() -> void:
	await _test_health()
	await _test_hitboxes()
	await _test_player()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_health() -> void:
	var health := HealthComponent.new()
	health.max_health = 3
	health.invulnerability_time = 0.2
	add_child(health)
	health.died.connect(func() -> void: died_count += 1)

	_check("health: damage reduces health", health.apply_damage(DamageInfo.create(1)) and health.current_health == 2)
	_check("health: i-frames block second hit", not health.apply_damage(DamageInfo.create(1)) and health.current_health == 2 and health.is_invulnerable())
	await _frames(16)
	_check("health: i-frames end", not health.is_invulnerable())
	_check("health: damage works after i-frames", health.apply_damage(DamageInfo.create(1)) and health.current_health == 1)
	await _frames(16)
	_check("health: clamped at 0", health.apply_damage(DamageInfo.create(5)) and health.current_health == 0 and health.is_dead)
	_check("health: no damage when dead", not health.apply_damage(DamageInfo.create(1)) and health.current_health == 0)
	_check("health: died emitted once", died_count == 1, "count=%d" % died_count)
	health.reset()
	_check("health: reset restores state", health.current_health == 3 and not health.is_dead and not health.is_invulnerable())
	health.apply_damage(DamageInfo.create(1))
	health.heal(10)
	_check("health: heal clamps to max", health.current_health == 3)

	var no_frames := HealthComponent.new()
	no_frames.max_health = 5
	add_child(no_frames)
	_check("health: zero i-frames allows consecutive hits",
		no_frames.apply_damage(DamageInfo.create(1)) and no_frames.apply_damage(DamageInfo.create(1)) and no_frames.current_health == 3)
	health.queue_free()
	no_frames.queue_free()


func _test_hitboxes() -> void:
	# Once per activation, even across exit/enter; again after re-activation.
	var target := _make_target(TEAM_ENEMY, Vector2.ZERO)
	var hitbox := _make_hitbox(TEAM_PLAYER, Vector2.ZERO)
	hitbox.activate()
	await _frames(20)
	_check("hitbox: hits once while overlapping many frames", target.health.current_health == 9, "hp=%d" % target.health.current_health)
	hitbox.position = Vector2(1000.0, 0.0)
	await _frames(3)
	hitbox.position = Vector2.ZERO
	await _frames(6)
	_check("hitbox: exit and re-enter does not re-hit", target.health.current_health == 9, "hp=%d" % target.health.current_health)
	hitbox.deactivate()
	await _frames(3)
	hitbox.activate()
	await _frames(10)
	_check("hitbox: new activation hits again", target.health.current_health == 8, "hp=%d" % target.health.current_health)
	target.get_parent().queue_free()
	hitbox.queue_free()

	# Same team is ignored.
	var ally := _make_target(TEAM_PLAYER, Vector2(2000.0, 0.0))
	var ally_hitbox := _make_hitbox(TEAM_PLAYER, Vector2(2000.0, 0.0))
	ally_hitbox.activate()
	await _frames(15)
	_check("hitbox: ignores own team", ally.health.current_health == 10)
	ally.get_parent().queue_free()
	ally_hitbox.queue_free()

	# Rehit interval.
	var hazard_target := _make_target(TEAM_PLAYER, Vector2(4000.0, 0.0), 50)
	var hazard := _make_hitbox(TEAM_ENEMY, Vector2(4000.0, 0.0), Vector2(60.0, 60.0), 0.2)
	hit_count = 0
	hazard.hit_landed.connect(func(_h: Hurtbox, _i: DamageInfo) -> void: hit_count += 1)
	hazard.activate()
	await _frames(60)
	_check("hitbox: rehit interval hits repeatedly (~1s / 0.2s)", hit_count >= 4 and hit_count <= 6, "hits=%d" % hit_count)
	hazard.deactivate()
	hazard_target.get_parent().queue_free()
	hazard.queue_free()

	# Inactive hitbox does nothing.
	var idle_target := _make_target(TEAM_ENEMY, Vector2(6000.0, 0.0))
	var idle_hitbox := _make_hitbox(TEAM_PLAYER, Vector2(6000.0, 0.0))
	await _frames(15)
	_check("hitbox: inactive does nothing", idle_target.health.current_health == 10)
	idle_target.get_parent().queue_free()
	idle_hitbox.queue_free()

	# Knockback direction.
	var right_target := _make_target(TEAM_ENEMY, Vector2(8050.0, 0.0))
	var left_target := _make_target(TEAM_ENEMY, Vector2(7950.0, 0.0))
	var kb_hitbox := _make_hitbox(TEAM_PLAYER, Vector2(8000.0, 0.0), Vector2(200.0, 60.0), 0.0, Vector2(200.0, -100.0))
	var infos: Dictionary = {}
	kb_hitbox.hit_landed.connect(func(hurtbox: Hurtbox, info: DamageInfo) -> void: infos[hurtbox] = info)
	kb_hitbox.activate()
	await _frames(10)
	var right_info: DamageInfo = infos.get(right_target)
	var left_info: DamageInfo = infos.get(left_target)
	_check("knockback: target on the right gets +x", right_info != null and right_info.knockback == Vector2(200.0, -100.0))
	_check("knockback: target on the left gets -x", left_info != null and left_info.knockback == Vector2(-200.0, -100.0))
	right_target.get_parent().queue_free()
	left_target.get_parent().queue_free()
	kb_hitbox.queue_free()


func _place_on_player(hitbox: Hitbox, offset: Vector2) -> void:
	hitbox.global_position = player.global_position + offset


func _test_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.position = PLAYER_START
	add_child(player)
	var player_died_count: Array[int] = [0]
	player.died.connect(func() -> void: player_died_count[0] += 1)
	await _frames(30)

	var stats: PlayerStats = player.stats
	var hazard := _make_hitbox(TEAM_ENEMY, FAR_AWAY, Vector2(40.0, 40.0), 10.0, Vector2(200.0, -100.0))
	_place_on_player(hazard, Vector2(-30.0, 0.0))
	hazard.activate()
	await _frames(4)
	_check("player: damaged by enemy hitbox", player.health.current_health == stats.max_health - 1, "hp=%d" % player.health.current_health)
	_check("player: enters HURT", player.state == Player.State.HURT)
	_check("player: cannot act while hurt", not player.can_act())
	_check("player: knocked away from hitbox", player.velocity.x > 0.0, "vx=%.1f" % player.velocity.x)
	hazard.deactivate()
	hazard.global_position = FAR_AWAY
	await _frames(int(ceil(stats.hurt_stun_time * 60.0)) + 2)
	_check("player: regains control after stun", player.can_act() and player.state != Player.State.HURT)
	_place_on_player(hazard, Vector2(-30.0, 0.0))
	hazard.activate()
	await _frames(6)
	_check("player: hurt i-frames block another hit", player.health.current_health == stats.max_health - 1, "hp=%d" % player.health.current_health)
	hazard.deactivate()
	hazard.global_position = FAR_AWAY

	# Dash invulnerability window.
	await _frames(int(ceil(stats.hurt_invulnerability_time * 60.0)) + 10)
	player.health.reset()
	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	await _frames(40)
	var big := _make_hitbox(TEAM_ENEMY, FAR_AWAY, Vector2(800.0, 100.0), 0.05, Vector2(100.0, -50.0))
	_place_on_player(big, Vector2.ZERO)
	Input.action_press("move_right")
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	big.activate()
	await _frames(3)
	_check("player: not damaged inside dash invulnerability window",
		player.state == Player.State.DASH and player.is_dash_invulnerable and player.health.current_health == stats.max_health,
		"state=%s hp=%d" % [Player.State.keys()[player.state], player.health.current_health])
	await _frames(8)
	_check("player: damaged after the window while still overlapping",
		player.health.current_health == stats.max_health - 1 and player.state == Player.State.HURT,
		"state=%s hp=%d" % [Player.State.keys()[player.state], player.health.current_health])
	Input.action_release("move_right")
	big.deactivate()
	big.global_position = FAR_AWAY

	# Death and revive.
	await _frames(int(ceil(stats.hurt_invulnerability_time * 60.0)) + 10)
	player.health.apply_damage(DamageInfo.create(stats.max_health + 5))
	await _frames(int(ceil(stats.hurt_stun_time * 60.0)) + 5)
	_check("player: dies at 0 health", player.is_dead and player.health.current_health == 0 and player_died_count[0] == 1,
		"died=%d" % player_died_count[0])
	_check("player: cannot act when dead", not player.can_act())
	player.revive()
	_check("player: revive restores control and health",
		player.can_act() and not player.is_dead and player.health.current_health == stats.max_health)

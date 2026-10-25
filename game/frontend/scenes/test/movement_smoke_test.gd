extends Node
## Headless smoke test for player movement. Development only.
## Run: <godot> --headless --path game res://frontend/scenes/test/movement_smoke_test.tscn

const PLAYER_SCENE: PackedScene = preload("res://backend/player/player.tscn")
const FLOOR_Y: float = 300.0
const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash"]

var player: Player
var failures: int = 0
var dash_started_count: int = 0
var dash_finished_count: int = 0


func _ready() -> void:
	_build_world()
	_run.call_deferred()


func _build_world() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector2(0.0, FLOOR_Y + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	add_child(floor_body)

	player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(0.0, FLOOR_Y - 30.0)
	add_child(player)
	player.dash_started.connect(func() -> void: dash_started_count += 1)
	player.dash_finished.connect(func() -> void: dash_finished_count += 1)


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _reset() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	player.global_position = Vector2(0.0, FLOOR_Y - 30.0)
	player.velocity = Vector2.ZERO
	await _frames(40)


func _wait_for_floor(max_frames: int) -> bool:
	for i in max_frames:
		await get_tree().physics_frame
		if player.is_on_floor():
			return true
	return false


func _run() -> void:
	await _frames(30)
	_check("player settles on floor", player.is_on_floor())

	# Horizontal movement and facing.
	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	await _frames(30)
	_check("moves right", player.global_position.x - start_x > 50.0, "dx=%.1f" % (player.global_position.x - start_x))
	_check("faces right", player.facing_direction == 1 and player.visual.scale.x > 0.0)
	_check("state RUN", player.state == Player.State.RUN)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(20)
	_check("faces left", player.facing_direction == -1 and player.visual.scale.x < 0.0)
	Input.action_release("move_left")
	await _frames(40)
	_check("stops with friction", absf(player.velocity.x) < 1.0 and player.state == Player.State.IDLE)

	# Jump leaves the floor and lands.
	await _reset()
	Input.action_press("jump")
	await _frames(3)
	_check("jump leaves floor", not player.is_on_floor() and player.velocity.y < 0.0)
	Input.action_release("jump")
	var landed: bool = await _wait_for_floor(180)
	_check("jump lands again", landed)

	# Variable jump height: short tap rises less than a held jump.
	await _reset()
	var base_y: float = player.global_position.y
	var min_y_tap: float = base_y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	for i in 90:
		await get_tree().physics_frame
		min_y_tap = minf(min_y_tap, player.global_position.y)
	await _reset()
	var min_y_hold: float = base_y
	Input.action_press("jump")
	for i in 90:
		await get_tree().physics_frame
		min_y_hold = minf(min_y_hold, player.global_position.y)
	Input.action_release("jump")
	_check("short tap jumps lower than held jump", (base_y - min_y_tap) < (base_y - min_y_hold) - 10.0,
		"tap=%.1f hold=%.1f" % [base_y - min_y_tap, base_y - min_y_hold])

	# Run vs dash distance over the same time window.
	var window: int = 24
	await _reset()
	var x0: float = player.global_position.x
	Input.action_press("move_right")
	await _frames(window)
	var run_dist: float = player.global_position.x - x0
	Input.action_release("move_right")

	await _reset()
	x0 = player.global_position.x
	dash_started_count = 0
	dash_finished_count = 0
	Input.action_press("move_right")
	Input.action_press("dash")
	# The press is consumed by the player's next physics step, so wait two frames.
	await _frames(2)
	Input.action_release("dash")
	var invuln_frames: int = 0
	var dash_frames: int = 0
	var invuln_at_first: bool = player.state == Player.State.DASH and player.is_dash_invulnerable
	for i in window - 2:
		await get_tree().physics_frame
		if player.state == Player.State.DASH:
			dash_frames += 1
			if player.is_dash_invulnerable:
				invuln_frames += 1
	var dash_dist: float = player.global_position.x - x0
	Input.action_release("move_right")
	_check("dash covers more than run", dash_dist > run_dist, "dash=%.1f run=%.1f" % [dash_dist, run_dist])
	_check("dash started and finished once", dash_started_count == 1 and dash_finished_count == 1,
		"started=%d finished=%d" % [dash_started_count, dash_finished_count])
	var max_invuln_frames: int = ceili(player.stats.dash_invulnerability_time * 60.0) + 1
	_check("invulnerable at dash start", invuln_at_first)
	_check("invulnerability is brief", invuln_frames <= max_invuln_frames and invuln_frames < dash_frames,
		"invuln=%d dash=%d max=%d" % [invuln_frames, dash_frames, max_invuln_frames])
	_check("not invulnerable after dash", not player.is_dash_invulnerable)

	# Dash cooldown blocks a second dash, then allows it.
	await _reset()
	dash_started_count = 0
	Input.action_press("dash")
	await _frames(1)
	Input.action_release("dash")
	await _frames(int(ceil((player.stats.dash_duration + 0.05) * 60.0)))
	Input.action_press("dash")
	await _frames(1)
	Input.action_release("dash")
	await _frames(2)
	_check("second dash blocked during cooldown", dash_started_count == 1, "started=%d" % dash_started_count)
	await _frames(int(ceil(player.stats.dash_cooldown * 60.0)))
	Input.action_press("dash")
	await _frames(1)
	Input.action_release("dash")
	await _frames(2)
	_check("dash allowed after cooldown", dash_started_count == 2, "started=%d" % dash_started_count)

	# Air dashes are limited and reset on landing.
	# A dash cancels vertical speed, so the airtime left is shorter than the default cooldown.
	# Use a copy with a short cooldown so the air-dash limit is what blocks the second dash.
	var default_stats: PlayerStats = player.stats
	player.stats = default_stats.duplicate() as PlayerStats
	player.stats.dash_cooldown = 0.05
	await _reset()
	dash_started_count = 0
	Input.action_press("jump")
	await _frames(6)
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	_check("air dash used", dash_started_count == 1 and player.air_dashes_left == player.stats.max_air_dashes - 1,
		"started=%d left=%d" % [dash_started_count, player.air_dashes_left])
	# Just past the dash and its short cooldown, while still in the air.
	await _frames(int(ceil((player.stats.dash_duration + player.stats.dash_cooldown) * 60.0)) - 1)
	var still_airborne: bool = not player.is_on_floor()
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	Input.action_release("jump")
	_check("second air dash blocked (airborne=%s)" % still_airborne,
		still_airborne and dash_started_count == 1, "started=%d" % dash_started_count)
	await _wait_for_floor(240)
	await _frames(2)
	_check("air dashes reset on landing", player.air_dashes_left == player.stats.max_air_dashes,
		"left=%d" % player.air_dashes_left)
	player.stats = default_stats

	await _reset()
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)

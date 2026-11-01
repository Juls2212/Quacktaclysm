extends Node2D
## The real player and enemy scenes on a flat floor, with an autopilot that runs, dashes,
## slashes, dash-slashes and heavy-attacks so the duck animations can be seen in game.
## F6 to watch. `-- --shots=<dir>` saves a frame at each scripted beat and quits.

const PLAYER_SCENE := preload("res://backend/player/player.tscn")
const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://backend/enemies/melee_enemy.tscn"),
	preload("res://backend/enemies/fast_enemy.tscn"),
	preload("res://backend/enemies/ranged_enemy.tscn"),
]
const TOUGH_STATS := preload("res://backend/enemies/stats/melee_tough_stats.tres")
const FLOOR_Y: float = 560.0

## Autopilot beats: [time in seconds, action to tap or "right"/"stop", screenshot name or ""].
const BEATS: Array = [
	[0.4, "", "idle"],
	[0.6, "right", ""],
	[0.95, "", "run"],
	[1.1, "dash", ""],
	[1.16, "", "dash"],
	[1.5, "stop", ""],
	[1.7, "attack", ""],
	[1.8, "", "slash"],
	[2.3, "jump", ""],
	[2.48, "", "jump"],
	[3.2, "heavy_attack", ""],
	[3.45, "", "heavy_windup"],
	[3.6, "", "heavy_strike"],
	[4.4, "dash", ""],
	[4.43, "attack", ""],
	[4.5, "", "dash_slash"],
	[5.2, "", "enemies"],
]

var _time: float = 0.0
var _beat: int = 0
var _shots_dir: String = ""
var _held_right: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.substr(8)
	RenderingServer.set_default_clear_color(Color(0.96, 0.95, 0.92))
	_add_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = Vector2(260, FLOOR_Y - 26)
	add_child(player)
	player.set_auto_respawn(true)
	var xs: Array[float] = [1500.0, 1700.0, 1900.0, 1300.0]
	for i in xs.size():
		var enemy: EnemyBase = ENEMY_SCENES[i % ENEMY_SCENES.size()].instantiate()
		if i == 3:
			enemy.stats = TOUGH_STATS
		enemy.position = Vector2(xs[i], FLOOR_Y - 24)
		add_child(enemy)


func _add_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	body.position = Vector2(640, FLOOR_Y + 20)
	body.add_child(shape)
	var line := Polygon2D.new()
	line.color = Color(0.82, 0.8, 0.76)
	line.polygon = PackedVector2Array([Vector2(-2000, -20), Vector2(2000, -20), Vector2(2000, 20), Vector2(-2000, 20)])
	body.add_child(line)
	add_child(body)


func _physics_process(delta: float) -> void:
	_time += delta
	while _beat < BEATS.size() and _time >= float(BEATS[_beat][0]):
		var beat: Array = BEATS[_beat]
		_beat += 1
		_apply(beat[1])
		if beat[2] != "" and _shots_dir != "":
			_capture(beat[2])
	if _beat >= BEATS.size() and _shots_dir != "" and _time > float(BEATS[-1][0]) + 0.2:
		get_tree().quit()


func _apply(command: String) -> void:
	match command:
		"":
			return
		"right":
			_held_right = true
			Input.action_press("move_right")
		"stop":
			_held_right = false
			Input.action_release("move_right")
		_:
			Input.action_press(command)
			get_tree().create_timer(0.05, true, true).timeout.connect(Input.action_release.bind(command))


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(name + ".png"))

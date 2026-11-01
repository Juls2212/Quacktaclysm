extends Node2D
## Contact sheet of every DuckRig look in every pose. Open and press F6 to review the art;
## Tab switches between the minions page and the bosses page.
## Attack columns loop through windup -> strike -> recover so the motion can be judged.
## `-- --shot=<file.png>` saves one frame (with `--freeze`, attacks hold mid-pose) and quits;
## `--bosses` opens the bosses page, `--row=N` shows one look large.

const DuckRigScript := preload("res://frontend/animations/duck_rig.gd")
const MINION_POSES: Array[String] = ["idle", "run", "jump", "dash", "windup", "strike", "heavy", "hurt", "dead"]
const BOSS_POSES: Array[String] = ["idle", "run", "windup", "strike", "charge", "cast", "enraged", "hurt", "dead"]
const MINION_LOOKS: Array = [DuckRig.Look.HERO, DuckRig.Look.BRUTE, DuckRig.Look.BRUTE_TOUGH, DuckRig.Look.BANDIT, DuckRig.Look.SLINGER]
const MINION_NAMES: Array[String] = ["Héroe", "Bruto", "Bruto acorazado", "Bandido", "Hondero"]
const BOSS_LOOKS: Array = [DuckRig.Look.BOSS_WOODCUTTER, DuckRig.Look.BOSS_SWAMP, DuckRig.Look.BOSS_STORM]
const BOSS_NAMES: Array[String] = ["Capataz (nivel 1)", "Guardián del Pantano", "Guardián de la Tormenta"]

var CELL := Vector2(136, 138)
var ZOOM: float = 1.75

var _rigs: Array = []
var _clock: float = 0.0
var _shot_path: String = ""
var _freeze: bool = false
var _frames: int = 0
var _only_row: int = -1
var _bosses: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--row="):
			_only_row = int(arg.substr(6))
		elif arg == "--freeze":
			_freeze = true
		elif arg == "--bosses":
			_bosses = true
	RenderingServer.set_default_clear_color(Color(0.96, 0.95, 0.92))
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_bosses = not _bosses
		_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_rigs.clear()
	var looks: Array = BOSS_LOOKS if _bosses else MINION_LOOKS
	var names: Array[String] = BOSS_NAMES if _bosses else MINION_NAMES
	var poses: Array[String] = BOSS_POSES if _bosses else MINION_POSES
	CELL = Vector2(138, 200) if _bosses else Vector2(136, 138)
	ZOOM = 0.8 if _bosses else 1.75
	var per_line: int = poses.size()
	# `--row=N` shows one look large (poses wrapped on two lines) to inspect details.
	if _only_row >= 0:
		ZOOM = 1.8 if _bosses else 3.0
		CELL = Vector2(250, 340)
		per_line = 5
	var head_room: float = 62.0 * ZOOM * (DuckRig.BOSS_SCALE if _bosses else 1.0)
	var foot: float = (44.0 if _bosses else 24.0) * ZOOM
	var line_index: int = 0
	for row in looks.size():
		if _only_row >= 0 and row != _only_row:
			continue
		var label := Label.new()
		label.text = names[row]
		label.position = Vector2(8, 4 + line_index * CELL.y)
		label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
		add_child(label)
		for i in poses.size():
			var col: int = i % per_line
			var y: float = 30.0 + (line_index + i / per_line) * CELL.y + head_room
			var rig: DuckRig = DuckRigScript.new()
			rig.look = looks[row]
			rig.foot_y = 44.0 if _bosses else 26.0
			rig.scale = Vector2.ONE * ZOOM
			rig.position = Vector2(80 + col * CELL.x, y - foot)
			add_child(rig)
			_rigs.append([rig, poses[i]])
			var header := Label.new()
			header.text = poses[i]
			header.position = Vector2(80 + col * CELL.x - 20, y + 6)
			header.add_theme_color_override("font_color", Color(0.35, 0.33, 0.4))
			add_child(header)
		line_index += ceili(float(poses.size()) / per_line)


func _process(delta: float) -> void:
	_clock += delta
	for entry in _rigs:
		_pose(entry[0], entry[1])
	_frames += 1
	if _shot_path != "" and _frames == 50:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _pose(rig: DuckRig, pose: String) -> void:
	rig.ground_speed = 0.0
	rig.grounded = true
	rig.vertical_speed = 0.0
	rig.dashing = false
	rig.hurt = false
	rig.dead = false
	rig.enraged = false
	rig.action = DuckRig.Action.NONE
	match pose:
		"run":
			rig.ground_speed = 240.0
		"jump":
			rig.grounded = false
			rig.vertical_speed = -300.0
		"dash":
			rig.dashing = true
		"windup", "strike":
			_animate_action(rig, DuckRig.Action.SLASH if rig.look == DuckRig.Look.HERO else DuckRig.Action.ATTACK, pose == "windup")
		"heavy":
			_animate_action(rig, DuckRig.Action.HEAVY if rig.look == DuckRig.Look.HERO else DuckRig.Action.ATTACK, false)
		"charge":
			_animate_action(rig, DuckRig.Action.CHARGE, false)
		"cast":
			_animate_action(rig, DuckRig.Action.CAST, false)
		"enraged":
			rig.enraged = true
		"hurt":
			rig.hurt = true
		"dead":
			rig.dead = true


## Loops windup -> strike -> recover, or holds one pose when frozen for a screenshot.
func _animate_action(rig: DuckRig, action: DuckRig.Action, hold_windup: bool) -> void:
	rig.action = action
	var loop: float = fmod(_clock, 1.2) / 1.2
	if _freeze:
		rig.phase = DuckRig.Phase.WINDUP if hold_windup else DuckRig.Phase.STRIKE
		rig.phase_t = 0.9 if hold_windup else 0.6
	elif loop < 0.45:
		rig.phase = DuckRig.Phase.WINDUP
		rig.phase_t = loop / 0.45
	elif loop < 0.6:
		rig.phase = DuckRig.Phase.STRIKE
		rig.phase_t = (loop - 0.45) / 0.15
	else:
		rig.phase = DuckRig.Phase.RECOVER
		rig.phase_t = (loop - 0.6) / 0.4

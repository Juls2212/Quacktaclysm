extends Node2D
## Contact sheet of every DuckRig look in every pose. Open and press F6 to review the art.
## Attack columns loop through windup -> strike -> recover so the motion can be judged.
## `-- --shot=<file.png>` saves one frame (with `--freeze`, attacks hold mid-pose) and quits.

const DuckRigScript := preload("res://frontend/animations/duck_rig.gd")
const POSES: Array[String] = ["idle", "run", "jump", "dash", "windup", "strike", "heavy", "hurt", "dead"]
var CELL := Vector2(136, 138)
var ZOOM: float = 1.75

var _rigs: Array = []
var _clock: float = 0.0
var _shot_path: String = ""
var _freeze: bool = false
var _frames: int = 0
var _only_row: int = -1


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--row="):
			_only_row = int(arg.substr(6))
		elif arg == "--freeze":
			_freeze = true
	RenderingServer.set_default_clear_color(Color(0.96, 0.95, 0.92))
	var looks: Array = [DuckRig.Look.HERO, DuckRig.Look.BRUTE, DuckRig.Look.BRUTE_TOUGH, DuckRig.Look.BANDIT, DuckRig.Look.SLINGER]
	var names: Array[String] = ["Héroe", "Bruto", "Bruto acorazado", "Bandido", "Hondero"]
	# `--row=N` shows one look large (poses wrapped on two lines) to inspect details.
	var per_line: int = POSES.size()
	if _only_row >= 0:
		ZOOM = 3.0
		CELL = Vector2(250, 340)
		per_line = 5
	var line_index: int = 0
	for row in looks.size():
		if _only_row >= 0 and row != _only_row:
			continue
		var label := Label.new()
		label.text = names[row]
		label.position = Vector2(8, 4 + line_index * CELL.y)
		label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
		add_child(label)
		for i in POSES.size():
			var col: int = i % per_line
			var y: float = 30.0 + (line_index + i / per_line) * CELL.y + 62.0 * ZOOM
			var rig: DuckRig = DuckRigScript.new()
			rig.look = looks[row]
			rig.scale = Vector2.ONE * ZOOM
			rig.position = Vector2(80 + col * CELL.x, y - 24.0 * ZOOM)
			add_child(rig)
			_rigs.append([rig, POSES[i]])
			var header := Label.new()
			header.text = POSES[i]
			header.position = Vector2(80 + col * CELL.x - 20, y + 6)
			header.add_theme_color_override("font_color", Color(0.35, 0.33, 0.4))
			add_child(header)
		line_index += ceili(float(POSES.size()) / per_line)


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
	rig.action = DuckRig.Action.NONE
	var loop: float = fmod(_clock, 1.2) / 1.2
	match pose:
		"run":
			rig.ground_speed = 240.0
		"jump":
			rig.grounded = false
			rig.vertical_speed = -300.0
		"dash":
			rig.dashing = true
		"windup", "strike", "heavy":
			rig.action = DuckRig.Action.ATTACK if rig.look != DuckRig.Look.HERO else DuckRig.Action.SLASH
			if pose == "heavy" and rig.look == DuckRig.Look.HERO:
				rig.action = DuckRig.Action.HEAVY
			elif pose == "heavy":
				rig.action = DuckRig.Action.ATTACK
			if _freeze:
				rig.phase = DuckRig.Phase.WINDUP if pose == "windup" else DuckRig.Phase.STRIKE
				rig.phase_t = 0.9 if pose == "windup" else 0.6
			elif loop < 0.45:
				rig.phase = DuckRig.Phase.WINDUP
				rig.phase_t = loop / 0.45
			elif loop < 0.6:
				rig.phase = DuckRig.Phase.STRIKE
				rig.phase_t = (loop - 0.45) / 0.15
			else:
				rig.phase = DuckRig.Phase.RECOVER
				rig.phase_t = (loop - 0.6) / 0.4
		"hurt":
			rig.hurt = true
		"dead":
			rig.dead = true

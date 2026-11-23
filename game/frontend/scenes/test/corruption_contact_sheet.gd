extends Node
## Not a test: renders contact sheets of the corrupted duck (every stage and ending pose over the real backgrounds, and frames of the absorption)
## to user://sheet_*.png so they can be LOOKED at (Phase 15o). It needs a real window (a headless run draws nothing). Run it with
## `godot --path game res://frontend/scenes/test/corruption_contact_sheet.tscn`; it quits by itself. The window shows the 1280 x 720 game area.

const SCREEN := Vector2(1280.0, 720.0)
const SHEETS: Array = [
	["sheet_poses_a.png", "kept", [[&"stand", 0.0, 0.6], [&"labored", 0.5, 1.0], [&"stagger", 0.95, 1.0], [&"kneel", 0.95, 1.0]]],
	["sheet_poses_b.png", "kept", [[&"reach", 0.7, 1.0], [&"resist", 0.5, 1.0], [&"kneel_edge", 1.0, 1.0], [&"head_down", 1.0, 1.0]]],
	["sheet_poses_c.png", "released", [[&"stand", 0.0, 0.6], [&"kneel_edge", 1.0, 1.0], [&"head_down", 1.0, 1.0], [&"walk", 0.5, 0.4]]],
]


func _ready() -> void:
	await _frames(5)
	for sheet in SHEETS:
		await _sheet_poses(sheet[0], sheet[1], sheet[2])
	await _sheet_stages()
	await _sheet_absorption()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _clear() -> void:
	for child in get_children():
		child.free()


func _save(file: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://" + file)
	print("saved ", ProjectSettings.globalize_path("user://" + file), " ", image.get_size())


## A 1280 x 720 world shown at half size in a quarter of the screen.
func _quarter(index: int) -> SubViewport:
	var holder := SubViewportContainer.new()
	holder.position = Vector2(float(index % 2) * SCREEN.x * 0.5, float(index / 2) * SCREEN.y * 0.5)
	holder.size = SCREEN
	holder.scale = Vector2(0.5, 0.5)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(SCREEN.x), int(SCREEN.y))
	holder.add_child(viewport)
	add_child(holder)
	return viewport


func _sheet_poses(file: String, style: String, poses: Array) -> void:
	_clear()
	for index in poses.size():
		var entry: Array = poses[index]
		var scene := EndingScene.new()
		scene.style = style
		scene.pose = entry[0]
		scene.pose_p = entry[1]
		scene.veins = 1.0 if style == "kept" else 0.0
		scene.corruption_scale = 1.0
		scene.breath = float(entry[2])
		scene.light = 0.5
		scene.focus = Vector2(560.0, 440.0)
		scene.zoom = 2.2
		scene.duck_from = Vector2(560.0, 520.0)
		scene.duck_to = Vector2(560.0, 520.0)
		_quarter(index).add_child(scene)
	await _frames(14)
	_save(file)


func _sheet_stages() -> void:
	_clear()
	var backgrounds: Array[Color] = [Color(0.36, 0.5, 0.42), Color(0.2, 0.22, 0.3), Color(0.55, 0.45, 0.36), Color(0.1, 0.1, 0.16)]
	for stage in 4:
		for row in 2:
			var panel := ColorRect.new()
			panel.color = backgrounds[stage]
			panel.position = Vector2(float(stage) * 320.0, float(row) * 360.0)
			panel.size = Vector2(320.0, 360.0)
			add_child(panel)
			panel.clip_contents = true
			var rig := DuckRig.new()
			rig.look = DuckRig.Look.HERO
			rig.corruption_stage = stage
			rig.corruption_growth = 1.0
			if row == 0:
				rig.position = panel.position + Vector2(150.0, 250.0)
				rig.scale = Vector2.ONE * 3.2
			else:
				rig.position = panel.position + Vector2(100.0, 400.0)
				rig.scale = Vector2.ONE * 7.0
			panel.add_child(rig)
			rig.position -= panel.position
	await _frames(14)
	_save("sheet_stages.png")


func _sheet_absorption() -> void:
	_clear()
	GameState.start_new_game()
	GameState.record_decision("fragment_level_1", "x", 1, GameState.CHOICE_KEPT)
	GameState.record_decision("fragment_level_2", "y", 2, GameState.CHOICE_KEPT)
	var frames: Array[float] = [0.25, 0.5, 0.75, 0.93]
	for index in frames.size():
		var cut := ExorcismCutscene.new()
		cut.fragment_id = "fragment_level_2"
		_quarter(index).add_child(cut)
		await _frames(2)
		cut._t = cut.config.length * frames[index]
		await _frames(3)
		cut._t = cut.config.length * frames[index]
		cut._bolt_clock = 99.0
		await _frames(2)
		cut.set_process(false)
	await _frames(3)
	_save("sheet_absorption.png")

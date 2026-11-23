extends Node
## Not a test: renders stills of the Phase 15r pieces (the grandfather in the sky over the real backgrounds, the two ending silhouette beats and the guardian
## spirits) to user://sheet15r_*.png so they can be LOOKED at. It needs a real window. Run it with
## `godot --path game res://frontend/scenes/test/sky_contact_sheet.tscn`; it quits by itself.

const SCREEN := Vector2(1280.0, 720.0)
const LEVELS: Array[String] = ["res://frontend/levels/level_1.tscn", "res://frontend/levels/level_2.tscn", "res://frontend/levels/level_3.tscn"]


func _ready() -> void:
	await _frames(5)
	await _sheet_spirits()
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


func _sheet_grandfather_levels() -> void:
	_clear()
	for index in 3:
		var viewport: SubViewport = _quarter(index)
		var level := (load(LEVELS[index]) as PackedScene).instantiate()
		viewport.add_child(level)
		for junk in ["LevelTitleCard", "ElderScene"]:
			if level.get_node_or_null(junk) != null:
				level.get_node(junk).free()
		var face := GrandfatherFace.new()
		face.setup(GrandfatherPresentation.get_default(), index + 1, false)
		viewport.add_child(face)
	await _frames(70)
	_save("sheet15r_grandfather_levels.png")


func _sheet_grandfather_endings() -> void:
	_clear()
	var specs: Array = [["kept", &"watching", 0.7], ["kept", &"grieving", 0.7], ["released", &"solemn", 0.7], ["released", &"speaking", 0.7]]
	for index in specs.size():
		var spec: Array = specs[index]
		var viewport: SubViewport = _quarter(index)
		var scene := EndingScene.new()
		scene.style = spec[0]
		scene.light = 0.6
		viewport.add_child(scene)
		var sky := GrandfatherSky.new()
		sky.alpha = float(spec[2])
		sky.position = Vector2(640.0, 250.0)
		sky.scale = Vector2.ONE * GrandfatherPresentation.get_default().face_scale
		viewport.add_child(sky)
		sky.set_expression(spec[1])
		sky.talking = spec[1] == &"speaking"
	await _frames(30)
	_save("sheet15r_grandfather_endings.png")


func _sheet_rig_probe() -> void:
	_clear()
	var bg := ColorRect.new()
	bg.color = Color(0.3, 0.35, 0.5)
	bg.size = SCREEN
	add_child(bg)
	var rig := DuckRig.new()
	rig.look = DuckRig.Look.GRANDFATHER
	rig.position = Vector2(640.0, 500.0)
	rig.scale = Vector2.ONE * 6.0
	add_child(rig)
	var cross := ColorRect.new()
	cross.color = Color.RED
	cross.size = Vector2(40.0, 2.0)
	cross.position = Vector2(620.0, 500.0)
	add_child(cross)
	await _frames(10)
	_save("sheet15r_probe.png")


func _sheet_close() -> void:
	_clear()
	var scene := EndingScene.new()
	scene.style = "released"
	scene.light = 0.6
	add_child(scene)
	var sky := GrandfatherSky.new()
	sky.alpha = 0.7
	sky.position = Vector2(640.0, 250.0)
	sky.scale = Vector2.ONE * GrandfatherPresentation.get_default().face_scale
	add_child(sky)
	sky.set_expression(&"solemn")
	await _frames(30)
	_save("sheet15r_close.png")


func _sheet_silhouettes() -> void:
	_clear()
	var kinds: Array = [EndingSilhouette.KNEEL_SWORD, EndingSilhouette.LYING_SWORD, EndingSilhouette.EDGE_SKY]
	for index in kinds.size():
		var viewport: SubViewport = _quarter(index)
		var white := ColorRect.new()
		white.color = Color(1.0, 1.0, 1.0)
		white.size = SCREEN
		viewport.add_child(white)
		var sil := EndingSilhouette.new()
		viewport.add_child(sil)
		sil.kind = kinds[index]
		sil.alpha = 1.0
	var viewport4: SubViewport = _quarter(3)
	var scene := EndingScene.new()
	scene.style = "released"
	scene.light = 0.5
	scene.duck_visible = false
	scene.items_left = true
	viewport4.add_child(scene)
	await _frames(20)
	_save("sheet15r_silhouettes.png")


func _sheet_spirits() -> void:
	_clear()
	var looks: Array = [DuckRig.Look.BOSS_WOODCUTTER, DuckRig.Look.BOSS_SWAMP, DuckRig.Look.BOSS_STORM]
	for index in 3:
		var viewport: SubViewport = _quarter(index)
		var level := (load(LEVELS[index]) as PackedScene).instantiate()
		viewport.add_child(level)
		for junk in ["LevelTitleCard", "ElderScene"]:
			if level.get_node_or_null(junk) != null:
				level.get_node(junk).free()
		var spirit := GuardianSpirit.new()
		spirit.setup(looks[index], Vector2(700.0, 520.0), Vector2.ONE * DuckRig.BOSS_SCALE, false, Vector2(760.0, 470.0))
		viewport.add_child(spirit)
	var viewport4: SubViewport = _quarter(3)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.18)
	bg.size = SCREEN
	viewport4.add_child(bg)
	var spirit4 := GuardianSpirit.new()
	spirit4.setup(DuckRig.Look.BOSS_WOODCUTTER, Vector2(500.0, 520.0), Vector2.ONE * DuckRig.BOSS_SCALE, false, Vector2(900.0, 440.0))
	viewport4.add_child(spirit4)
	await _frames(100)
	_save("sheet15r_spirits.png")
	spirit4.dissolve()
	await _frames(7)
	if is_instance_valid(spirit4):
		print("particles ", spirit4.particles.size(), " strength ", spirit4.strength, " state ", spirit4.state)
	_save("sheet15r_spirits_b.png")

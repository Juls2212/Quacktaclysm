extends Node2D
## The living picture behind the main menu: the ruined town under a yellow smog, smoke columns,
## a red omen star burning too bright and corrupted stars falling now and then; the worn-out hero
## standing on the rubble with his katana, deformed ducks shuffling past in the distance as
## silhouettes, and the post the menu signs are nailed to. Visual only.

const RUINS := preload("res://frontend/levels/biome/ruined_city_biome.tres")
const INK := Color(0.106, 0.098, 0.122)
const GROUND_Y: float = 612.0
const SILHOUETTE := Color(0.27, 0.25, 0.21)

## Screen x of the sign post the menu hangs from.
@export var post_x: float = 1012.0
@export var post_top: float = 118.0

var _hero: DuckRig
var _walkers: Array[Dictionary] = []
var _time: float = 0.0
var _next_slash: float = 2.5


func _ready() -> void:
	# A copy of the ruined-city look with the omen star lit and more falling stars (the .tres is untouched).
	var biome := RUINS.duplicate() as Biome
	biome.omen_star = true
	biome.omen_star_position = Vector2(0.6, 0.36)
	biome.falling_star_rate = 0.7
	var backdrop := Backdrop.new()
	backdrop.biome = biome
	backdrop.auto_scroll = 22.0
	# No foreground silhouettes here: they would sit over the menu text.
	backdrop.show_foreground = false
	add_child(backdrop)
	var ground := TerrainSkin.new()
	ground.biome = biome
	ground.kind = TerrainSkin.Kind.GROUND
	ground.size = Vector2(1500, 40)
	ground.position = Vector2(640, GROUND_Y + 20)
	add_child(ground)
	# Mutated ducks shuffling across the far end of the street, dark against the smog.
	var specs: Array = [[DuckRig.Look.BRUTE, 160.0, 0.62, 1.0], [DuckRig.Look.BANDIT, 520.0, 0.55, -1.0],
			[DuckRig.Look.SLINGER, 900.0, 0.58, 1.0], [DuckRig.Look.BRUTE_TOUGH, 1180.0, 0.6, -1.0]]
	for spec in specs:
		var walker := DuckRig.new()
		walker.look = spec[0]
		walker.scale = Vector2(float(spec[3]), 1.0) * float(spec[2])
		walker.modulate = SILHOUETTE
		walker.wear = 0.4
		walker.position = Vector2(spec[1], GROUND_Y - 6.0 - 26.0 * float(spec[2]))
		add_child(walker)
		_walkers.append({ "rig": walker, "dir": float(spec[3]), "speed": 26.0 + float(spec[2]) * 30.0 })
	_hero = DuckRig.new()
	_hero.look = DuckRig.Look.HERO
	_hero.scale = Vector2.ONE * 2.1
	_hero.position = Vector2(300, GROUND_Y + 2.0 - 26.0 * 2.1)
	_hero.z_index = 2
	add_child(_hero)


func _process(delta: float) -> void:
	_time += delta
	for w in _walkers:
		var rig: DuckRig = w["rig"]
		rig.position.x += float(w["dir"]) * float(w["speed"]) * delta
		# Off one edge, back in from the other: an endless trickle of the corrupted.
		if rig.position.x > 1340.0:
			rig.position.x = -60.0
		elif rig.position.x < -60.0:
			rig.position.x = 1340.0
		rig.ground_speed = float(w["speed"]) * 2.0
	# Now and then the hero draws and cuts the air.
	_next_slash -= delta
	_hero.action = DuckRig.Action.NONE
	if _next_slash < 0.0:
		var t: float = -_next_slash
		_hero.action = DuckRig.Action.SLASH
		if t < 0.12:
			_hero.phase = DuckRig.Phase.WINDUP
			_hero.phase_t = t / 0.12
		elif t < 0.26:
			_hero.phase = DuckRig.Phase.STRIKE
			_hero.phase_t = (t - 0.12) / 0.14
		elif t < 0.6:
			_hero.phase = DuckRig.Phase.RECOVER
			_hero.phase_t = (t - 0.26) / 0.34
		else:
			_next_slash = 4.0 + fmod(_time * 1.7, 3.0)
	queue_redraw()


func _draw() -> void:
	# The sign post: a weathered pole with a cross beam the ropes hang from.
	var base := Vector2(post_x, GROUND_Y + 6.0)
	var pole := PackedVector2Array([base + Vector2(-9, 0), Vector2(post_x - 7, post_top), Vector2(post_x + 7, post_top - 2), base + Vector2(10, 0)])
	draw_colored_polygon(pole, Color(0.45, 0.3, 0.19))
	draw_line(Vector2(post_x + 2, post_top + 10), base + Vector2(3, -6), Color(0.33, 0.21, 0.13), 2.0, true)
	_outline(pole)
	var beam := PackedVector2Array([Vector2(post_x - 190, post_top + 6), Vector2(post_x + 190, post_top - 2), Vector2(post_x + 192, post_top + 14),
			Vector2(post_x - 188, post_top + 22)])
	draw_colored_polygon(beam, Color(0.5, 0.33, 0.21))
	_outline(beam)
	draw_circle(Vector2(post_x, post_top + 10), 4.0, INK)


func _outline(points: PackedVector2Array) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, INK, 3.0, true)

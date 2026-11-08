@tool
class_name BackdropLayer
extends Node2D
## One painted depth layer of a biome backdrop: smoggy ridges, broken buildings, dead trees, sunken
## houses, chimneys, a temple among broken towers... Drawn once over a tile `WIDTH` px wide that
## repeats seamlessly (child of a Parallax2D). Every shape is built once and painted at x - WIDTH,
## x and x + WIDTH so the tile wraps.
## Far layers melt into the biome haze and lose detail; the middle and near layers carry a dark
## hand-drawn edge. The whole backdrop is graded darker and grayer than the play field
## (Biome.backdrop_dim / backdrop_desaturation) so ducks and platforms read first. Only the small
## accents (lit windows, beacons, star shards) keep their full color.
## World y: the screen spans 0..720 in levels, the floor sits around y 600.

enum Depth { FAR, MIDFAR, MID, NEAR, FORE }

const WIDTH: float = 2048.0
const BOTTOM: float = 1200.0
const INK := Color(0.106, 0.098, 0.122)

@export var biome: Biome:
	set(value):
		biome = value
		queue_redraw()
@export var depth: Depth = Depth.FAR:
	set(value):
		depth = value
		queue_redraw()

var _salt: int = 0
# Ground line of the layer being painted (set by _set_ground, read by _gy).
var _gb: float = 600.0
var _ga: float = 0.0
var _gf: Array = [2, 3, 5]


func _draw() -> void:
	if biome == null:
		return
	_salt = biome.scenery_seed * 101 + int(depth) * 17
	match biome.kind:
		Biome.Kind.MEADOW:
			_town()
		Biome.Kind.FOREST:
			_dead_forest()
		Biome.Kind.SWAMP:
			_swamp()
		Biome.Kind.STORM:
			_star_crater()
		Biome.Kind.RUINED_CITY:
			_ruined_city()
		Biome.Kind.FLOODED_SUBURB:
			_flooded_suburb()
		Biome.Kind.INDUSTRIAL:
			_industrial()


# =====================================================================================
# Biomes
# =====================================================================================

## The town the day before: houses still lit, dry trees, poles and fences, a smoggy sunset.
func _town() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_set_ground(400.0, 60.0, [2, 3, 7])
			_extras(c)
			_ridge(c)
		Depth.MIDFAR:
			_set_ground(478.0, 26.0, [3, 5, 9])
			for i in 9:
				var x: float = _slot(i, 9)
				if i == 3:
					_steeple(x, _gy(x) + 4.0, 150.0, c)
				elif i == 6:
					_water_tower(x, _gy(x) + 4.0, 120.0, c)
				else:
					_house(x, _gy(x) + 6.0, 54.0 + _r(i) * 30.0, 34.0 + _r(i + 4) * 18.0, c, 0.0, true)
			_extras(c)
			_ridge(c)
			_mist(505.0, 0.45)
		Depth.MID:
			_set_ground(578.0, 18.0, [2, 4, 6])
			var tops: Array[Vector2] = []
			for i in 5:
				var x: float = _slot(i, 5) + 60.0
				tops.append(_pole(x, _gy(x), 190.0 + _r(i) * 30.0, (_r(i + 20) - 0.5) * 0.06, c))
			_wires(tops, 26.0)
			for i in 4:
				var x: float = _slot(i, 4) + 210.0
				_bare_tree(x, _gy(x), 150.0 + _r(i + 7) * 80.0, c, 0.0)
			for i in 3:
				var x: float = _slot(i, 3) + 380.0
				_fence(x, x + 180.0, 40.0, c, false)
			_extras(c)
			_ridge(c)
			_mist(612.0, 0.4)
		Depth.NEAR:
			_set_ground(660.0, 18.0, [3, 7, 11])
			for i in 40:
				var x: float = _slot(i, 40)
				_blades(x, _gy(x) + 4.0, 22.0 + _r(i) * 26.0, c)
			_ridge(c)
		Depth.FORE:
			_fore_grass(c)


## Level 1, zone B: black twisted trunks, needle-less pines, stumps and brambles.
func _dead_forest() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_set_ground(380.0, 110.0, [2, 3, 5])
			_extras(c)
			_ridge(c, true)
		Depth.MIDFAR:
			_set_ground(480.0, 30.0, [3, 5, 8])
			for i in 26:
				var x: float = _slot(i, 26)
				_dead_pine(x, _gy(x) + 10.0, 80.0 + _r(i) * 80.0, c)
			_extras(c)
			_ridge(c)
			_mist(510.0)
		Depth.MID:
			_set_ground(590.0, 22.0, [2, 5, 7])
			# Huge black trunks rising out of frame, bent like old fingers.
			for i in 4:
				var x: float = _slot(i, 4)
				_twisted_trunk(x, 30.0 + _r(i) * 22.0, _gy(x), c)
			for i in 9:
				var x: float = _slot(i, 9) + 80.0
				_dead_pine(x, _gy(x) + 8.0, 110.0 + _r(i + 4) * 70.0, c)
			for i in 3:
				var x: float = _slot(i, 3) + 150.0
				_stump(x, _gy(x), 34.0 + _r(i + 30) * 20.0, c)
			_extras(c)
			_ridge(c)
			_mist(622.0, 0.45)
		Depth.NEAR:
			_set_ground(665.0, 16.0, [3, 6, 10])
			for i in 12:
				var x: float = _slot(i, 12)
				_brambles(x, _gy(x) + 4.0, 40.0 + _r(i) * 34.0, c)
			for i in 4:
				var x: float = _slot(i, 4) + 90.0
				_stump(x, _gy(x) + 4.0, 50.0 + _r(i + 9) * 30.0, c)
			_ridge(c)
		Depth.FORE:
			_fore_branches(c)


## Level 3, zone B: the crater where the stars fell. An old temple stands among broken towers,
## rocks hang in the air where time stopped, and the ground still glows.
func _star_crater() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_jagged_ridge(390.0, 130.0, c)
			_extras(c)
		Depth.MIDFAR:
			_set_ground(500.0, 25.0, [3, 5, 7])
			for i in 8:
				var x: float = _slot(i, 8)
				match i % 4:
					0:
						_pagoda(x, _gy(x) + 8.0, 150.0 + _r(i) * 40.0, c)
					1:
						_building(x, _gy(x) + 8.0, 46.0 + _r(i) * 20.0, 200.0 + _r(i + 3) * 70.0, c, true, 0.08)
					2:
						_torii(x, _gy(x) + 6.0, 80.0 + _r(i) * 20.0, c)
					_:
						_building(x, _gy(x) + 8.0, 70.0 + _r(i) * 30.0, 130.0 + _r(i + 3) * 60.0, c, true, 0.0)
			_extras(c)
			_ridge(c)
			_mist(530.0)
		Depth.MID:
			for i in 5:
				var x: float = _slot(i, 5)
				_floating_rock(Vector2(x, 250.0 + _r(i) * 160.0), 36.0 + _r(i + 5) * 46.0, c)
			for i in 4:
				var x: float = _slot(i, 4) + 170.0
				_floating_chunk(Vector2(x, 200.0 + _r(i + 11) * 200.0), 18.0 + _r(i + 13) * 16.0, c)
			_jagged_ridge(600.0, 40.0, c)
			for i in 6:
				var x: float = _slot(i, 6) + 40.0
				_star_shard(Vector2(x, 596.0 + _r(i + 17) * 14.0), 8.0 + _r(i + 19) * 6.0)
			_mist(632.0, 0.45)
		Depth.NEAR:
			_jagged_ridge(668.0, 26.0, c)
			_ground_glow(676.0)
		Depth.FORE:
			_fore_shards(c)


## Level 1, zone A: broken concrete blocks with empty windows, burned cars, fallen lamps.
func _ruined_city() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			# Distant skyline, flattened by smog: just blocks and a few broken crowns.
			_set_ground(445.0, 6.0, [2, 5, 9])
			for i in 16:
				var x: float = _slot(i, 16)
				_building(x, _gy(x), 60.0 + _r(i) * 70.0, 90.0 + _r(i + 40) * 170.0, c, _r(i + 9) > 0.45, 0.0)
			_ridge(c)
		Depth.MIDFAR:
			_set_ground(505.0, 10.0, [3, 5, 9])
			for i in 8:
				var x: float = _slot(i, 8)
				_building(x, _gy(x) + 6.0, 90.0 + _r(i) * 60.0, 120.0 + _r(i + 3) * 130.0, c, _r(i + 8) > 0.25, 0.04)
			_extras(c)
			_ridge(c)
			_mist(525.0)
		Depth.MID:
			_set_ground(590.0, 10.0, [2, 4, 7])
			for i in 3:
				var x: float = _slot(i, 3) + 60.0
				_building(x, _gy(x) + 4.0, 110.0 + _r(i) * 40.0, 90.0 + _r(i + 4) * 70.0, c, true, 0.0)
			for i in 4:
				var x: float = _slot(i, 4) + 290.0
				_lamp(x, _gy(x), 150.0 + _r(i) * 30.0, (_r(i + 6) - 0.5) * 0.5 + (0.9 if i == 2 else 0.0), c)
			for i in 4:
				var x: float = _slot(i, 4) + 430.0
				_car(x, _gy(x) + 2.0, 74.0 + _r(i + 2) * 14.0, (_r(i + 12) - 0.5) * 0.2, c)
			for i in 3:
				var x: float = _slot(i, 3) + 560.0
				_rubble(x, _gy(x) + 4.0, 120.0 + _r(i + 22) * 80.0, 26.0 + _r(i + 24) * 24.0, c)
			_fence(_slot(1, 3) + 720.0, _slot(1, 3) + 880.0, 36.0, c, true)
			_extras(c)
			_ridge(c)
			_mist(625.0, 0.4)
		Depth.NEAR:
			_set_ground(662.0, 12.0, [3, 6, 11])
			for i in 6:
				var x: float = _slot(i, 6)
				_rubble(x, _gy(x) + 6.0, 140.0 + _r(i) * 90.0, 40.0 + _r(i + 8) * 40.0, c)
			_car(_slot(2, 6) + 160.0, 666.0, 96.0, 0.35, c)
			_ridge(c)
		Depth.FORE:
			_fore_rubble(c)


## Level 3, zone A: chimneys, gas holders, a cooling tower and pipes, under orange lights.
func _industrial() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_set_ground(450.0, 6.0, [2, 3, 7])
			for i in 9:
				var x: float = _slot(i, 9)
				_factory(x, _gy(x), 120.0 + _r(i) * 80.0, 50.0 + _r(i + 3) * 40.0, c, false)
				if i % 3 == 1:
					_chimney(x + 40.0, _gy(x) - 160.0 - _r(i + 5) * 60.0, _gy(x), 14.0, c, false)
			_ridge(c)
		Depth.MIDFAR:
			_set_ground(505.0, 8.0, [3, 5, 9])
			for i in 2:
				var x: float = _slot(i, 2) + 260.0
				_tank(x, _gy(x), 70.0 + _r(i) * 20.0, 70.0 + _r(i + 2) * 20.0, c)
			for i in 5:
				var x: float = _slot(i, 5) + 120.0
				_factory(x, _gy(x) + 4.0, 150.0 + _r(i) * 70.0, 70.0 + _r(i + 3) * 40.0, c, true)
			for src in BackdropFx.smoke_sources(biome):
				_chimney(src.x, src.y, _gy(src.x) + 6.0, 30.0, c, true)
			_extras(c)
			_ridge(c)
			_mist(528.0, 0.45)
		Depth.MID:
			_set_ground(592.0, 8.0, [2, 4, 7])
			_cooling_tower(_slot(1, 3), _gy(_slot(1, 3)) + 6.0, 170.0, 230.0, c)
			for i in 2:
				var x: float = _slot(i, 2) + 520.0
				_scaffold(x, _gy(x), 70.0, 170.0 + _r(i) * 40.0, c)
			_pipes(548.0, 18.0, c)
			_pipes(572.0, 12.0, c)
			for i in 3:
				var x: float = _slot(i, 3) + 820.0
				_barrel(x, _gy(x) + 2.0, 18.0, 0.0, c)
				_barrel(x + 30.0, _gy(x) + 2.0, 18.0, 1.4, c)
			_extras(c)
			_ridge(c)
			_mist(626.0, 0.4)
		Depth.NEAR:
			_set_ground(664.0, 10.0, [3, 6, 11])
			for i in 5:
				var x: float = _slot(i, 5)
				_rubble(x, _gy(x) + 6.0, 130.0 + _r(i) * 80.0, 36.0 + _r(i + 8) * 30.0, c)
			_pipes(650.0, 22.0, c)
			_ridge(c)
		Depth.FORE:
			_fore_girders(c)


## Level 2 marsh, in sage-green flat layers that pale with distance (zone A: the flooded village;
## zone B, `dense`: the toxic swamp, darker, more fog and trees, fewer houses). FAR: pale thin
## trunks lost in the fog and a crooked village far away. MIDFAR: a band of fog and mid-green
## trees with dry branches. MID: dark trees hung with moss and sunken houses with bright moss roofs
## and warm windows (their moss sways and windows flicker in BackdropFx MARSH). NEAR: thick black
## trunks framing the view (behind the play field). FORE: crouching moss creatures and a fallen
## trunk below the floor line.
const MARSH_TRUNK := Color("1e2818")
const MARSH_ROOF := Color("7cc23a")
const MARSH_WINDOW := Color("ffb84a")
const MARSH_WALL := Color(0.45, 0.5, 0.43)


func _flooded_suburb() -> void:
	_marsh(false)


func _swamp() -> void:
	_marsh(true)


func _marsh(dense: bool) -> void:
	var dark: float = 0.22 if dense else 0.0
	var far: Color = biome.far_color.darkened(dark)
	var mid: Color = biome.mid_color.darkened(dark)
	var near: Color = biome.near_color.darkened(dark)
	match depth:
		Depth.FAR:
			for i in 28:
				var x: float = _slot(i, 28)
				var w: float = 5.0 + _r(i) * 7.0
				var col: Color = far.lerp(biome.haze, 0.35 + 0.3 * _r(i + 5))
				_line(Vector2(x, 660), Vector2(x + (_r(i + 9) - 0.5) * 10.0, 40.0 + _r(i + 3) * 80.0), col, w)
				_line(Vector2(x, 260.0 + _r(i + 7) * 120.0), Vector2(x + 30.0 * (1.0 if i % 2 == 0 else -1.0), 230.0 + _r(i + 8) * 100.0), col, w * 0.4)
			var houses: int = 4 if dense else 9
			for i in houses:
				_marsh_far_house(_slot(i, houses), 520.0 + _r(i + 40) * 20.0, 40.0 + _r(i + 41) * 30.0, 50.0 + _r(i + 42) * 40.0, mid.lerp(biome.haze, 0.25))
			draw_rect(Rect2(-WIDTH, 530, WIDTH * 3.0, BOTTOM), mid.lerp(biome.haze, 0.3))
			_mist(560.0, 0.55 if dense else 0.4)
		Depth.MIDFAR:
			_mist(330.0, 0.25 if dense else 0.15)
			var n: int = 20 if dense else 16
			for i in n:
				var x: float = _slot(i, n)
				_marsh_tree(x, 560.0, 220.0 + _r(i) * 140.0, 10.0 + _r(i + 2) * 6.0, mid, false, i)
			draw_rect(Rect2(-WIDTH, 556, WIDTH * 3.0, BOTTOM), mid)
			_mist(600.0, 0.55 if dense else 0.4)
		Depth.MID:
			for tree in BackdropFx.marsh_trees(biome):
				_marsh_tree(float(tree[0]), 600.0, float(tree[1]), 16.0 + _r(int(tree[0])) * 8.0, near, true, int(tree[0]))
			for house in BackdropFx.marsh_houses(biome):
				_marsh_house(house)
			draw_rect(Rect2(-WIDTH, 596, WIDTH * 3.0, BOTTOM), near.darkened(0.2))
			if dense:
				_mist(630.0, 0.35)
		Depth.NEAR:
			for i in 4:
				var x: float = _slot(i, 4) + 200.0
				_marsh_trunk(x, 34.0 + _r(i) * 16.0)
		Depth.FORE:
			for cr in BackdropFx.marsh_creatures(biome):
				_marsh_creature(float(cr[0]), float(cr[1]))
			var log_x: float = _slot(1, 2) + 300.0
			_fill(PackedVector2Array([Vector2(log_x - 160, 770), Vector2(log_x - 150, 742), Vector2(log_x + 140, 730), Vector2(log_x + 160, 752), Vector2(log_x + 150, 772)]),
					Color(biome.foreground_color, 0.92), false)
			_dot(Vector2(log_x + 150, 751), 12.0, Color(biome.foreground_color.lightened(0.08), 0.92))


## A crooked house far away: a box with a sharp roof, a window or two lit faintly.
func _marsh_far_house(x: float, ground: float, w: float, h: float, col: Color) -> void:
	var lean: float = (_r(int(x)) - 0.5) * 10.0
	_fill(PackedVector2Array([Vector2(x - w * 0.5, ground + 20), Vector2(x - w * 0.5 + lean * 0.3, ground - h), Vector2(x + lean, ground - h - w * 0.8),
			Vector2(x + w * 0.5 + lean * 0.3, ground - h), Vector2(x + w * 0.5, ground + 20)]), col, false)
	if _r(int(x) + 3) > 0.4:
		_rect(Rect2(Vector2(x - 4, ground - h * 0.6), Vector2(7, 9)), Color(MARSH_WINDOW, 0.45))


## A tree: trunk, a few dry branches; the dark ones carry hanging moss tufts.
func _marsh_tree(x: float, ground: float, h: float, w: float, col: Color, mossy: bool, salt: int) -> void:
	var lean: float = (_r(salt + 3) - 0.5) * 18.0
	var top := Vector2(x + lean, ground - h)
	_fill(PackedVector2Array([Vector2(x - w, ground + 10), Vector2(top.x - w * 0.4, top.y), Vector2(top.x + w * 0.4, top.y), Vector2(x + w, ground + 10)]), col, mossy)
	for k in 4:
		var p: Vector2 = Vector2(x, ground).lerp(top, 0.45 + 0.15 * float(k))
		var dir: float = -1.0 if (k + salt) % 2 == 0 else 1.0
		var tip: Vector2 = p + Vector2(dir * (30.0 + _r(salt + k) * 40.0), -20.0 - _r(salt + k + 9) * 30.0)
		_stroke(p, tip, col, maxf(w * 0.3, 2.0))
		_line(tip, tip + Vector2(dir * 12.0, -10.0), col, 2.0)
	if mossy:
		var moss: Color = col.lerp(Color(0.45, 0.6, 0.3), 0.35)
		for k in 3:
			var p: Vector2 = Vector2(x, ground).lerp(top, 0.5 + 0.15 * float(k))
			_fill(_ellipse(p + Vector2(0, 6), w * 1.3, 8.0), moss, false)


## A sunken, crooked house among the trees: grey-green walls with beams, a bright dripping moss
## roof with holes and a chimney, warm lit windows (their glow is animated by BackdropFx).
func _marsh_house(house: Array) -> void:
	var origin := Vector2(float(house[0]), float(house[1]))
	var w: float = house[2]
	var h: float = house[3]
	var tilt: float = house[4]
	var wall := PackedVector2Array([Vector2(-w * 0.5, 30), Vector2(-w * 0.5, -h), Vector2(w * 0.5, -h), Vector2(w * 0.5, 30)])
	_fill(_rot(_moved(wall, origin), origin, tilt), MARSH_WALL)
	for bx in [-0.25, 0.25]:
		_line(origin + Vector2(w * float(bx), 20).rotated(tilt), origin + Vector2(w * float(bx), -h).rotated(tilt), Color(0.28, 0.3, 0.24), 4.0)
	_line(origin + Vector2(-w * 0.5, -h * 0.45).rotated(tilt), origin + Vector2(w * 0.5, -h * 0.45).rotated(tilt), Color(0.28, 0.3, 0.24), 4.0)
	var roof := PackedVector2Array([Vector2(-w * 0.64, -h + 8), Vector2(-w * 0.3, -h - w * 0.3), Vector2(0, -h - w * 0.4), Vector2(w * 0.12, -h - w * 0.36),
			Vector2(w * 0.64, -h + 8), Vector2(w * 0.5, -h + 18), Vector2(w * 0.36, -h + 8), Vector2(w * 0.16, -h + 22), Vector2(-w * 0.08, -h + 10),
			Vector2(-w * 0.3, -h + 20), Vector2(-w * 0.48, -h + 10)])
	_fill(_rot(_moved(roof, origin), origin, tilt), MARSH_ROOF)
	# Moss tufts along the ridge, a hole with broken rafters, and a crooked brick chimney on top.
	for k in 4:
		var q: Vector2 = Vector2(-w * 0.3, -h - w * 0.3).lerp(Vector2(w * 0.12, -h - w * 0.36), float(k) / 3.0)
		_fill(_ellipse(origin + (q + Vector2(0, 3)).rotated(tilt), 9.0, 5.0), MARSH_ROOF.lightened(0.15), false)
	var hole: Vector2 = origin + Vector2(-w * 0.22, -h - w * 0.08).rotated(tilt)
	_fill(_rot(PackedVector2Array([hole + Vector2(-12, -5), hole + Vector2(4, -9), hole + Vector2(13, -1), hole + Vector2(2, 7), hole + Vector2(-10, 5)]), hole, tilt),
			Color(0.1, 0.12, 0.08), false)
	_line(hole + Vector2(-9, -6).rotated(tilt), hole + Vector2(8, 5).rotated(tilt), Color(0.32, 0.26, 0.16), 2.5)
	_line(hole + Vector2(-2, -8).rotated(tilt), hole + Vector2(-1, 6).rotated(tilt), Color(0.32, 0.26, 0.16), 2.5)
	var chimney := PackedVector2Array([Vector2(w * 0.24, -h - w * 0.2), Vector2(w * 0.22, -h - w * 0.46), Vector2(w * 0.38, -h - w * 0.48), Vector2(w * 0.38, -h - w * 0.12)])
	_fill(_rot(_moved(chimney, origin), origin, tilt), Color(0.42, 0.36, 0.34))
	_line(origin + Vector2(w * 0.23, -h - w * 0.34).rotated(tilt), origin + Vector2(w * 0.38, -h - w * 0.35).rotated(tilt), Color(0.24, 0.2, 0.18), 2.0)
	for win in BackdropFx.house_windows(house):
		var p: Vector2 = origin + (win as Vector2).rotated(tilt)
		_fill(_rot(PackedVector2Array([p + Vector2(-9, -11), p + Vector2(9, -11), p + Vector2(9, 11), p + Vector2(-9, 11)]), p, tilt), MARSH_WINDOW)
		_line(p + Vector2(0, -11).rotated(tilt), p + Vector2(0, 11).rotated(tilt), Color(0.3, 0.2, 0.1), 2.0)


func _marsh_trunk(x: float, w: float) -> void:
	var lean: float = (_r(int(x)) - 0.5) * 40.0
	_fill(PackedVector2Array([Vector2(x - w, 760), Vector2(x - w * 0.8 + lean, -60), Vector2(x + w * 0.8 + lean, -60), Vector2(x + w, 760)]), MARSH_TRUNK, false)
	for k in 2:
		var y: float = 160.0 + float(k) * 200.0 + _r(int(x) + k) * 80.0
		var dir: float = -1.0 if k % 2 == 0 else 1.0
		var p := Vector2(x + lean * (1.0 - y / 760.0) + dir * w * 0.7, y)
		_line(p, p + Vector2(dir * 90.0, -50.0), MARSH_TRUNK, w * 0.35)


## A mound of moss crouched like a creature (its eyes blink in BackdropFx CREATURE_EYES).
func _marsh_creature(x: float, s: float) -> void:
	var col := Color(biome.foreground_color, 0.92)
	var pts := PackedVector2Array([Vector2(x - s, 770), Vector2(x - s * 0.8, 760 - s * 0.6), Vector2(x - s * 0.3, 760 - s * 1.0), Vector2(x + s * 0.2, 760 - s * 1.3),
			Vector2(x + s * 0.65, 760 - s * 1.2), Vector2(x + s * 0.8, 760 - s * 0.7), Vector2(x + s * 1.1, 770)])
	_fill(pts, col, false)
	for k in 3:
		var p := Vector2(x - s * 0.6 + float(k) * s * 0.5, 760 - s * (0.7 + 0.15 * float(k % 2)))
		_line(p, p + Vector2(2, s * 0.35), col, 3.0)


func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


## Optional silhouettes a biome switches on (ruins far away, dead trees in the middle).
func _extras(c: Color) -> void:
	if biome.ruin_silhouettes and depth == Depth.FAR:
		for i in 6:
			var x: float = _slot(i, 6) + 90.0
			_building(x, _gy(x) + 10.0, 50.0 + _r(i + 60) * 50.0, 70.0 + _r(i + 61) * 120.0, c, true, 0.0)
	if biome.dead_trees and depth == Depth.MID:
		for i in 3:
			var x: float = _slot(i, 3) + 470.0
			_bare_tree(x, _gy(x), 160.0 + _r(i + 70) * 70.0, c, 0.1)


# =====================================================================================
# Ground lines
# =====================================================================================

func _set_ground(base: float, amp: float, freqs: Array) -> void:
	_gb = base
	_ga = amp
	_gf = freqs


func _gy(x: float) -> float:
	return _ridge_y(x, _gb, _ga, _gf)


## Fills the current ground line down to the bottom; scenery drawn before it sinks behind its crest.
func _ridge(color: Color, peaked: bool = false) -> void:
	var pts := PackedVector2Array()
	var x: float = -WIDTH
	while x <= WIDTH * 2.0:
		var y: float = _gy(x)
		if peaked:
			y = _gb - _ga * pow(absf(sin(x / WIDTH * PI * float(_gf[0]) + _salt)), 0.6) + (y - _gb) * 0.4
		pts.append(Vector2(x, y))
		x += 16.0
	var rim := PackedVector2Array(pts)
	pts.append(Vector2(WIDTH * 2.0, BOTTOM))
	pts.append(Vector2(-WIDTH, BOTTOM))
	draw_colored_polygon(pts, color)
	_rim(rim, color)


func _ridge_y(x: float, base: float, amp: float, freqs: Array) -> float:
	var y: float = 0.0
	var weights: Array = [0.55, 0.3, 0.15]
	for i in freqs.size():
		y += sin(x / WIDTH * TAU * float(freqs[i]) + float(_salt + i * 31)) * float(weights[i])
	return base - y * amp


func _jagged_ridge(base: float, amp: float, color: Color) -> void:
	_set_ground(base, amp * 0.3, [2])
	var pts := PackedVector2Array()
	var count: int = 48
	for i in range(-count, count * 2 + 1):
		var x: float = float(i) / float(count) * WIDTH
		var k: int = posmod(i, count)
		var spike: float = _r(k + 400) * (1.0 if k % 2 == 0 else 0.35)
		pts.append(Vector2(x, base - spike * amp + sin(x / WIDTH * TAU * 2.0 + _salt) * amp * 0.3))
	var rim := PackedVector2Array(pts)
	pts.append(Vector2(WIDTH * 2.0, BOTTOM))
	pts.append(Vector2(-WIDTH, BOTTOM))
	draw_colored_polygon(pts, color)
	_rim(rim, color)


## Edge along a ridge top: a thin smog-lit line far away, a hand-drawn ink line up close.
func _rim(points: PackedVector2Array, color: Color) -> void:
	if depth == Depth.FORE:
		return
	if _ink_w() > 1.8:
		draw_polyline(points, _ink_color(), _ink_w(), true)
		return
	var lit := PackedVector2Array()
	for p in points:
		lit.append(p + Vector2(0, 2.0))
	draw_polyline(lit, Color(color.lerp(biome.sun, 0.3), 0.5), 2.0, true)


# =====================================================================================
# Scenery
# =====================================================================================

## Concrete block. Broken ones lose a slanted bite off the top and show bent rebar; windows are
## empty dark holes, a few (`lit_chance`) still glowing with the accent color.
func _building(x: float, ground: float, w: float, h: float, color: Color, broken: bool, lit_chance: float) -> void:
	var l: float = x - w * 0.5
	var r: float = x + w * 0.5
	var top: float = ground - h
	var k: int = int(x * 3.0) + int(w)
	var profile := PackedVector2Array()
	if broken:
		var n: int = 6
		var slope_left: bool = _r(k + 1) > 0.5
		var bite: float = h * (0.18 + 0.32 * _r(k + 2))
		for i in n + 1:
			var t: float = float(i) / float(n)
			var side: float = t if slope_left else 1.0 - t
			var cut: float = side * bite + _r(k + i * 7) * h * 0.07
			profile.append(Vector2(lerpf(l, r, t), top + cut))
	else:
		profile.append(Vector2(l, top))
		profile.append(Vector2(r, top))
	var body := PackedVector2Array([Vector2(l, ground + 40.0)])
	body.append_array(profile)
	body.append(Vector2(r, ground + 40.0))
	_fill(body, color)
	if depth == Depth.FAR and _ink_w() <= 0.0 and h < 120.0:
		return
	var hole: Color = color.darkened(0.5)
	var lit: Color = biome.accent.lerp(biome.sun, 0.5)
	var cols: int = maxi(int(w / 26.0), 1)
	var rows: int = maxi(int(h / 32.0), 1)
	var cell := Vector2(w / float(cols), h / float(rows))
	var win := Vector2(minf(cell.x * 0.45, 14.0), minf(cell.y * 0.45, 16.0))
	for cx in cols:
		for ry in rows:
			var c := Vector2(l + (float(cx) + 0.5) * cell.x, top + (float(ry) + 0.5) * cell.y)
			if c.y - win.y * 0.5 < _profile_y(profile, c.x) + 6.0 or c.y + win.y * 0.5 > ground - 4.0:
				continue
			var roll: float = _r(k + cx * 13 + ry * 29)
			if roll < 0.1:
				continue
			_rect(Rect2(c - win * 0.5, win), lit if roll > 1.0 - lit_chance else hole)
	if broken and depth != Depth.FAR:
		# Bent rebar sticking out of the break.
		for i in 3:
			var p: Vector2 = profile[1 + i * 2]
			var lean: float = (_r(k + i + 50) - 0.5) * 14.0
			_line(p, p + Vector2(lean, -10.0 - _r(k + i + 60) * 10.0), _ink_color(), 1.6)
		# A crack running down from the break.
		var crack := PackedVector2Array()
		var cx0: float = lerpf(l + 8.0, r - 8.0, _r(k + 70))
		var cy: float = _profile_y(profile, cx0)
		for i in 5:
			crack.append(Vector2(cx0 + (_r(k + i + 80) - 0.5) * 10.0, cy + float(i) * h * 0.08))
		_pline(crack, Color(INK, 0.5), 1.4)


func _profile_y(profile: PackedVector2Array, x: float) -> float:
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return profile[0].y


## House with a pitched roof and chimney. `lit` windows glow warm (the town before the end);
## otherwise they are dark and broken. `tilt` leans it, sunk into soft ground or water.
func _house(x: float, ground: float, w: float, h: float, color: Color, tilt: float, lit: bool) -> void:
	var pivot := Vector2(x, ground)
	var l: float = x - w * 0.5
	var r: float = x + w * 0.5
	var top: float = ground - h
	var roof_h: float = h * 0.75
	var chimney := _box(x + w * 0.18, top - roof_h * 0.85, x + w * 0.3, top - roof_h * 0.2)
	_fill(_rot(chimney, pivot, tilt), color.darkened(0.06))
	_fill(_rot(_box(l, top, r, ground + 40.0), pivot, tilt), color)
	_fill(_rot(PackedVector2Array([Vector2(l - 8.0, top + 2.0), Vector2(x, top - roof_h), Vector2(r + 8.0, top + 2.0)]), pivot, tilt), color.darkened(0.1))
	var glass: Color = Color(biome.sun.lerp(biome.accent, 0.25), 0.9) if lit else color.darkened(0.5)
	for side in [-1.0, 1.0]:
		var wx: float = x + float(side) * w * 0.24
		var pane := _box(wx - w * 0.09, top + h * 0.22, wx + w * 0.09, top + h * 0.52)
		_fill(_rot(pane, pivot, tilt), glass, false)
		if not lit and _r(int(x) + int(side * 3.0)) > 0.4:
			# Broken pane: a dark crack across it.
			_line(pivot + (Vector2(wx - w * 0.08, top + h * 0.25) - pivot).rotated(tilt), pivot + (Vector2(wx + w * 0.05, top + h * 0.48) - pivot).rotated(tilt), Color(INK, 0.6), 1.2)
	_fill(_rot(_box(x - w * 0.07, top + h * 0.5, x + w * 0.07, ground), pivot, tilt), color.darkened(0.35), false)


func _steeple(x: float, ground: float, h: float, color: Color) -> void:
	var w: float = h * 0.22
	_fill(_box(x - w * 0.5, ground - h * 0.55, x + w * 0.5, ground + 40.0), color)
	_fill(PackedVector2Array([Vector2(x - w * 0.62, ground - h * 0.55), Vector2(x, ground - h), Vector2(x + w * 0.62, ground - h * 0.55)]), color.darkened(0.08))
	_line(Vector2(x, ground - h), Vector2(x, ground - h - 16.0), _ink_color(), 2.0)
	_line(Vector2(x - 5.0, ground - h - 10.0), Vector2(x + 5.0, ground - h - 10.0), _ink_color(), 2.0)
	_dot(Vector2(x, ground - h * 0.4), w * 0.18, Color(biome.sun, 0.8))


func _water_tower(x: float, ground: float, h: float, color: Color) -> void:
	var w: float = h * 0.42
	for side in [-1.0, 1.0]:
		_line(Vector2(x + float(side) * w * 0.4, ground + 10.0), Vector2(x + float(side) * w * 0.25, ground - h * 0.6), color, 4.0)
	_line(Vector2(x - w * 0.36, ground - h * 0.3), Vector2(x + w * 0.3, ground - h * 0.5), color, 2.0)
	_line(Vector2(x + w * 0.36, ground - h * 0.3), Vector2(x - w * 0.3, ground - h * 0.5), color, 2.0)
	var tank := PackedVector2Array([Vector2(x - w * 0.5, ground - h * 0.6), Vector2(x - w * 0.5, ground - h * 0.88), Vector2(x, ground - h),
			Vector2(x + w * 0.5, ground - h * 0.88), Vector2(x + w * 0.5, ground - h * 0.6)])
	_fill(tank, color)


## Utility pole with a crossbar. Returns the top, where the wires hang from.
func _pole(x: float, ground: float, h: float, tilt: float, color: Color) -> Vector2:
	var dir := Vector2.from_angle(-PI * 0.5 + tilt)
	var base := Vector2(x, ground + 20.0)
	var top: Vector2 = Vector2(x, ground) + dir * h
	_stroke(base, top, color, 6.0)
	var bar: Vector2 = top - dir * 14.0
	var perp: Vector2 = dir.orthogonal()
	_stroke(bar - perp * 24.0, bar + perp * 24.0, color, 4.0)
	for k in [-1.0, 1.0]:
		_dot(bar + perp * 18.0 * float(k) - dir * 4.0, 2.6, color.darkened(0.2))
	return bar


## Sagging wires between pole tops (and from the last one to the first of the next tile).
func _wires(tops: Array[Vector2], sag: float) -> void:
	if tops.size() < 2:
		return
	for i in tops.size():
		var a: Vector2 = tops[i]
		var b: Vector2 = tops[(i + 1) % tops.size()]
		if i == tops.size() - 1:
			b.x += WIDTH
		var pts := PackedVector2Array()
		for j in 11:
			var t: float = float(j) / 10.0
			pts.append(a.lerp(b, t) + Vector2(0.0, sin(t * PI) * sag))
		_pline(pts, Color(INK, 0.55), 1.4)


## Street lamp with a bent arm; a large `tilt` lays it on the ground.
func _lamp(x: float, ground: float, h: float, tilt: float, color: Color) -> void:
	var dir := Vector2.from_angle(-PI * 0.5 + tilt)
	var base := Vector2(x, ground + 16.0)
	var top: Vector2 = Vector2(x, ground) + dir * h
	_stroke(base, top, color, 5.0)
	var arm: Vector2 = top + dir.orthogonal() * -26.0 + dir * 4.0
	_stroke(top, arm, color, 3.5)
	_fill(_rot(_box(arm.x - 9.0, arm.y - 2.0, arm.x + 9.0, arm.y + 6.0), arm, tilt), color.darkened(0.1))


## Burned-out car: no glass, one wheel gone, sitting crooked.
func _car(x: float, ground: float, w: float, tilt: float, color: Color) -> void:
	var h: float = w * 0.34
	var pivot := Vector2(x, ground)
	var g: float = ground - h * 0.18
	var body := PackedVector2Array([
		Vector2(x - w * 0.5, g - h * 0.2), Vector2(x - w * 0.47, g - h * 0.56), Vector2(x - w * 0.3, g - h * 0.62),
		Vector2(x - w * 0.18, g - h * 1.05), Vector2(x + w * 0.16, g - h * 1.05), Vector2(x + w * 0.3, g - h * 0.62),
		Vector2(x + w * 0.47, g - h * 0.56), Vector2(x + w * 0.5, g - h * 0.2),
	])
	body.append(Vector2(x + w * 0.5, g))
	body.append(Vector2(x - w * 0.5, g))
	_fill(_rot(body, pivot, tilt), color.darkened(0.05))
	var hole: Color = color.darkened(0.55)
	_fill(_rot(PackedVector2Array([Vector2(x - w * 0.25, g - h * 0.64), Vector2(x - w * 0.15, g - h * 0.95), Vector2(x - w * 0.02, g - h * 0.95),
			Vector2(x - w * 0.02, g - h * 0.64)]), pivot, tilt), hole, false)
	_fill(_rot(PackedVector2Array([Vector2(x + w * 0.03, g - h * 0.64), Vector2(x + w * 0.03, g - h * 0.95), Vector2(x + w * 0.13, g - h * 0.95),
			Vector2(x + w * 0.25, g - h * 0.64)]), pivot, tilt), hole, false)
	for side in [-1.0, 1.0]:
		var hub: Vector2 = pivot + (Vector2(x + float(side) * w * 0.3, g) - pivot).rotated(tilt)
		if side > 0.0 and _r(int(x)) > 0.4:
			_dot(hub, h * 0.12, hole)
			continue
		_dot(hub, h * 0.26, INK if depth != Depth.FAR else color.darkened(0.3))
		_dot(hub, h * 0.1, color.darkened(0.2))


## Fence posts with two rails; a broken one leans and loses rails. `base` overrides the ground.
func _fence(x0: float, x1: float, h: float, color: Color, broken: bool, base: float = -1.0) -> void:
	var posts: int = maxi(int((x1 - x0) / 26.0), 2)
	var tops: Array[Vector2] = []
	var feet: Array[Vector2] = []
	for i in posts + 1:
		var x: float = lerpf(x0, x1, float(i) / float(posts))
		var ground: float = base if base > 0.0 else _gy(x)
		var lean: float = (_r(int(x) + i) - 0.5) * (0.6 if broken else 0.08)
		if broken and _r(int(x) + i + 5) < 0.2:
			continue
		var foot := Vector2(x, ground + 8.0)
		var top: Vector2 = foot + Vector2.from_angle(-PI * 0.5 + lean) * (h + 8.0)
		_stroke(foot, top, color, 4.0)
		tops.append(top)
		feet.append(foot)
	for i in tops.size() - 1:
		for k in 2:
			if broken and _r(i * 3 + k + int(x0)) < 0.35:
				continue
			var t: float = 0.3 + 0.4 * float(k)
			_stroke(tops[i].lerp(feet[i], t), tops[i + 1].lerp(feet[i + 1], t), color, 2.6)


## Leafless tree: a forked trunk splitting into thinner and thinner twigs. `twist` bends it.
func _bare_tree(x: float, ground: float, h: float, color: Color, twist: float) -> void:
	_branch(Vector2(x, ground + 8.0), -PI * 0.5 + (_r(int(x)) - 0.5) * 0.25, h * 0.42, maxf(h * 0.07, 3.0), 0, int(x) + 3, color, twist)


func _branch(from: Vector2, angle: float, length: float, w: float, level: int, salt: int, color: Color, twist: float) -> void:
	var bend: float = (_r(salt * 3 + level) - 0.5) * 0.6 + twist
	var mid: Vector2 = from + Vector2.from_angle(angle) * length * 0.5
	var tip: Vector2 = mid + Vector2.from_angle(angle + bend) * length * 0.5
	_stroke_path(PackedVector2Array([from, mid, tip]), color, w)
	if level >= 3:
		return
	var n: int = 3 if level == 0 else 2
	for k in n:
		var spread: float = lerpf(-0.75, 0.75, float(k) / float(n - 1)) + (_r(salt + k * 13 + level * 7) - 0.5) * 0.4
		var start: Vector2 = tip if k != 1 else mid.lerp(tip, 0.6)
		_branch(start, angle + bend + spread, length * 0.62, maxf(w * 0.58, 1.2), level + 1, salt * 2 + k + 1, color, twist)


## Black trunk of the dead wood, bent like a finger, with a hollow knot.
func _twisted_trunk(x: float, w: float, ground: float, color: Color) -> void:
	var dark: Color = color.darkened(0.25)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 13:
		var t: float = float(i) / 12.0
		var y: float = lerpf(ground + 40.0, -60.0, t)
		var sway: float = sin(t * 4.2 + x * 0.013) * w * 1.1 * t
		var half: float = lerpf(w * 1.5, w * 0.75, t) + (w * 0.9 * (1.0 - t * 8.0) if t < 0.125 else 0.0)
		left.append(Vector2(x + sway - half, y))
		right.append(Vector2(x + sway + half, y))
	right.reverse()
	left.append_array(right)
	_fill(left, dark)
	for k in 3:
		var t: float = 0.35 + 0.18 * float(k)
		var y: float = lerpf(ground + 40.0, -60.0, t)
		var sway: float = sin(t * 4.2 + x * 0.013) * w * 1.1 * t
		var dir: float = -1.0 if k % 2 == 0 else 1.0
		var start := Vector2(x + sway + dir * w * 0.6, y)
		var elbow: Vector2 = start + Vector2(dir * (50.0 + _r(int(x) + k) * 40.0), -30.0)
		var end: Vector2 = elbow + Vector2(dir * 40.0, 30.0 + _r(int(x) + k + 9) * 30.0)
		_stroke_path(PackedVector2Array([start, elbow, end]), dark, w * 0.3)
		_stroke(elbow, elbow + Vector2(dir * 12.0, -26.0), dark, w * 0.14)
	var knot_t: float = 0.22
	var knot := Vector2(x + sin(knot_t * 4.2 + x * 0.013) * w * 1.1 * knot_t, lerpf(ground + 40.0, -60.0, knot_t))
	_fill(_ellipse(knot, w * 0.32, w * 0.5), INK, false)


## Pine stripped of its needles: a spine with short drooping spikes, some snapped off.
func _dead_pine(x: float, ground: float, h: float, color: Color) -> void:
	var top := Vector2(x + (_r(int(x)) - 0.5) * 8.0, ground - h)
	_stroke(Vector2(x, ground + 20.0), top, color, maxf(h * 0.045, 2.0))
	for k in 6:
		var p: Vector2 = Vector2(x, ground).lerp(top, 0.25 + 0.12 * float(k))
		var length: float = h * (0.26 - 0.03 * float(k))
		for side in [-1.0, 1.0]:
			if _r(int(x) + k * 5 + int(side * 2.0)) < 0.28:
				continue
			_stroke(p, p + Vector2(float(side) * length, length * 0.4), color, maxf(h * 0.016, 1.4))


func _stump(x: float, ground: float, h: float, color: Color) -> void:
	var w: float = h * 0.55
	var pts := PackedVector2Array([Vector2(x - w * 0.8, ground + 30.0), Vector2(x - w * 0.55, ground - h * 0.7), Vector2(x - w * 0.3, ground - h),
			Vector2(x - w * 0.05, ground - h * 0.72), Vector2(x + w * 0.2, ground - h * 0.92), Vector2(x + w * 0.5, ground - h * 0.6),
			Vector2(x + w * 0.8, ground + 30.0)])
	_fill(pts, color.darkened(0.12))


func _brambles(x: float, ground: float, h: float, color: Color) -> void:
	for k in 4:
		var a: float = lerpf(-2.6, -0.5, float(k) / 3.0)
		var tip: Vector2 = Vector2(x, ground) + Vector2.from_angle(a) * h
		var mid: Vector2 = Vector2(x, ground).lerp(tip, 0.5) + Vector2(0, -h * 0.15)
		_stroke_path(PackedVector2Array([Vector2(x, ground), mid, tip]), color, 3.0)
		for j in 2:
			var p: Vector2 = Vector2(x, ground).lerp(tip, 0.4 + 0.3 * float(j))
			_line(p, p + Vector2.from_angle(a - 0.9) * 7.0, color, 2.0)


func _willow(x: float, ground: float, h: float, color: Color) -> void:
	_stroke(Vector2(x, ground + 10.0), Vector2(x + 10.0, ground - h * 0.65), color.darkened(0.1), h * 0.07)
	var crown := Vector2(x + 10.0, ground - h * 0.7)
	# Rotten crown: a few thin lumps, more gaps than leaves.
	for k in 5:
		if k == 1 or k == 4:
			continue
		_dot(crown + Vector2((float(k) - 2.0) * h * 0.13, (absf(float(k) - 2.0)) * h * 0.04), h * 0.13, color)
	for k in 4:
		var dir: float = -1.0 if k % 2 == 0 else 1.0
		var start: Vector2 = crown + Vector2(dir * h * 0.05 * float(k), h * 0.02)
		_stroke_path(PackedVector2Array([start, start + Vector2(dir * h * 0.16, -h * 0.12), start + Vector2(dir * h * 0.3, -h * 0.02)]), color, 3.0)
	# Hanging moss strands.
	for k in 11:
		var sx: float = crown.x + (float(k) - 5.0) * h * 0.06
		var length: float = h * (0.3 + _r(k + int(x)) * 0.4)
		_line(Vector2(sx, crown.y), Vector2(sx + sin(float(k) * 1.7) * 6.0, crown.y + length), color, 2.6)


func _barrel(x: float, ground: float, r: float, tilt: float, color: Color) -> void:
	var pivot := Vector2(x, ground)
	var body := _box(x - r * 0.7, ground - r * 2.0, x + r * 0.7, ground)
	_fill(_rot(body, pivot, tilt), color.lightened(0.04))
	for k in 2:
		var y: float = ground - r * (0.6 + 0.8 * float(k))
		_line(pivot + (Vector2(x - r * 0.7, y) - pivot).rotated(tilt), pivot + (Vector2(x + r * 0.7, y) - pivot).rotated(tilt), _ink_color(), 1.4)
	# Leaking a little of the accent sludge.
	_dot(pivot + (Vector2(x, ground - r * 1.0) - pivot).rotated(tilt), r * 0.18, Color(biome.accent, 0.7))


## Tuft of withered grass: three blades, the outer ones bent over.
func _blades(x: float, ground: float, h: float, color: Color) -> void:
	for k in 3:
		var lean: float = (float(k) - 1.0) * 6.0
		var bx: float = x + float(k) * 5.0 - 6.0
		var tip := Vector2(bx + lean, ground - h * (0.7 + 0.15 * float(k)))
		_fill(PackedVector2Array([Vector2(bx, ground), tip, Vector2(bx + 6.0, ground)]), color, false)
		if k != 1:
			_line(tip, tip + Vector2(lean * 1.4, h * 0.25), color, 2.0)


func _reeds(x: float, ground: float, h: float, color: Color) -> void:
	for k in 3:
		var top := Vector2(x + (float(k) - 1.0) * 6.0 + sin(k + x) * 4.0, ground - h * (0.75 + 0.12 * k))
		_line(Vector2(x + (float(k) - 1.0) * 4.0, ground), top, color, 3.0)
		if k == 1:
			_fill(_ellipse(top + Vector2(0, 6), 3.2, 8.0), color.darkened(0.15), false)


func _water(level: float, color: Color, toxic: bool) -> void:
	var water: Color = color.lerp(biome.sky_bottom, 0.22).darkened(0.08)
	draw_rect(Rect2(-WIDTH, level, WIDTH * 3.0, BOTTOM - level), water)
	for i in 40:
		var x: float = _slot(i, 40)
		var y: float = level + 6.0 + _r(i + 90) * 30.0
		_line(Vector2(x, y), Vector2(x + 18.0 + _r(i) * 30.0, y), Color(biome.haze, 0.25), 2.0)
	if toxic:
		# Scum and slow bubbles on the poisoned water.
		for i in 14:
			var x: float = _slot(i, 14)
			_fill(_ellipse(Vector2(x, level + 4.0 + _r(i + 40) * 10.0), 24.0 + _r(i) * 30.0, 4.0), Color(biome.accent.lerp(water, 0.55), 0.6), false)
			if i % 2 == 0:
				var b := Vector2(x + 30.0, level - 2.0)
				_dot(b, 3.5, Color(biome.accent.lerp(water, 0.4), 0.8))
				_ring(b, 3.5, Color(INK, 0.5))
	draw_line(Vector2(-WIDTH, level), Vector2(WIDTH * 2.0, level), Color(biome.haze, 0.45), 2.0, true)
	if _ink_w() > 1.8:
		draw_line(Vector2(-WIDTH, level + 2.0), Vector2(WIDTH * 2.0, level + 2.0), Color(INK, 0.5), 2.0, true)


func _floating_junk(at: Vector2, i: int, color: Color) -> void:
	match i % 3:
		0:
			_dot(at, 9.0, color.darkened(0.25))
			_dot(at, 4.0, color.lerp(biome.sky_bottom, 0.3))
		1:
			_fill(_rot(_box(at.x - 22.0, at.y - 3.0, at.x + 22.0, at.y + 3.0), at, 0.12), color.lightened(0.05))
		_:
			_barrel(at.x, at.y + 6.0, 12.0, 1.3, color)


## Old temple tower: stacked tiers with flared roofs, the top one knocked crooked.
func _pagoda(x: float, ground: float, h: float, color: Color) -> void:
	var tiers: int = 4
	var th: float = h / float(tiers + 1)
	var y: float = ground + 30.0
	_fill(_box(x - h * 0.2, ground - th * 0.3, x + h * 0.2, ground + 40.0), color)
	y = ground - th * 0.3
	for k in tiers:
		var w: float = h * (0.32 - 0.05 * float(k))
		var pivot := Vector2(x, y)
		var tilt: float = 0.12 if k == tiers - 1 else 0.0
		_fill(_rot(_box(x - w * 0.55, y - th * 0.55, x + w * 0.55, y), pivot, tilt), color.darkened(0.05))
		var ry: float = y - th * 0.55
		var roof := PackedVector2Array([Vector2(x - w * 1.05, ry - th * 0.12), Vector2(x - w * 0.7, ry - th * 0.2), Vector2(x - w * 0.42, ry - th * 0.55),
				Vector2(x + w * 0.42, ry - th * 0.55), Vector2(x + w * 0.7, ry - th * 0.2), Vector2(x + w * 1.05, ry - th * 0.12),
				Vector2(x + w * 0.8, ry + 3.0), Vector2(x - w * 0.8, ry + 3.0)])
		_fill(_rot(roof, pivot, tilt), color.darkened(0.12))
		y = ry - th * 0.45
	_line(Vector2(x + 6.0, y), Vector2(x + 12.0, y - th * 1.1), _ink_color(), 2.4)
	for k in 3:
		_dot(Vector2(x + 7.0 + float(k) * 1.5, y - th * (0.3 + 0.25 * float(k))), 3.0, color.darkened(0.2))
	_dot(Vector2(x, ground - th * 1.2), 3.0, Color(biome.star_color, 0.8))


func _torii(x: float, ground: float, h: float, color: Color) -> void:
	var w: float = h * 0.9
	var top: float = ground - h
	for side in [-1.0, 1.0]:
		var px: float = x + float(side) * w * 0.38
		_fill(PackedVector2Array([Vector2(px - 5.0, ground + 30.0), Vector2(px - 4.0 + float(side) * -3.0, top + 8.0),
				Vector2(px + 4.0 + float(side) * -3.0, top + 8.0), Vector2(px + 5.0, ground + 30.0)]), color)
	_fill(_box(x - w * 0.5, top + h * 0.2, x + w * 0.5, top + h * 0.28), color)
	_fill(PackedVector2Array([Vector2(x - w * 0.7, top - 12.0), Vector2(x - w * 0.4, top - 4.0), Vector2(x + w * 0.4, top - 4.0),
			Vector2(x + w * 0.7, top - 12.0), Vector2(x + w * 0.62, top + 8.0), Vector2(x - w * 0.62, top + 8.0)]), color.darkened(0.08))


func _floating_rock(c: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-size, 0), c + Vector2(-size * 0.7, -size * 0.3), c + Vector2(size * 0.6, -size * 0.32),
			c + Vector2(size, 0), c + Vector2(size * 0.35, size * 0.5), c + Vector2(0, size * 1.1), c + Vector2(-size * 0.4, size * 0.45)])
	_fill(pts, color)
	_line(pts[1], pts[2], Color(biome.star_color, 0.35), 2.0)


## A piece of a wall that never finished falling, with an empty window.
func _floating_chunk(c: Vector2, size: float, color: Color) -> void:
	var tilt: float = (_r(int(c.x)) - 0.5) * 1.2
	_fill(_rot(_box(c.x - size, c.y - size * 0.7, c.x + size, c.y + size * 0.7), c, tilt), color.lightened(0.04))
	_fill(_rot(_box(c.x - size * 0.3, c.y - size * 0.35, c.x + size * 0.2, c.y + size * 0.25), c, tilt), color.darkened(0.5), false)


## A fallen star stuck in the ground, still glowing.
func _star_shard(c: Vector2, size: float) -> void:
	var col: Color = biome.star_color
	_dot(c, size * 2.6, Color(col, 0.12))
	_dot(c, size * 1.5, Color(col, 0.2))
	var pts := PackedVector2Array([c + Vector2(0, -size * 1.4), c + Vector2(size * 0.45, 0), c + Vector2(0, size * 0.5), c + Vector2(-size * 0.45, 0)])
	_fill(pts, col.lightened(0.25), false)
	_ring_poly(pts, INK, 1.6)


## Glowing seams in the crater floor.
func _ground_glow(y: float) -> void:
	var col: Color = biome.star_color
	for i in 7:
		var x: float = _slot(i, 7)
		var seam := PackedVector2Array()
		for j in 6:
			seam.append(Vector2(x + float(j) * 22.0, y + (_r(i * 7 + j) - 0.5) * 14.0 + float(j % 2) * 6.0))
		_pline(seam, Color(col, 0.18), 9.0)
		_pline(seam, Color(col.lightened(0.3), 0.85), 2.0)


func _rubble(x: float, ground: float, w: float, h: float, color: Color) -> void:
	var k: int = int(x * 2.0) + int(w)
	var pts := PackedVector2Array([Vector2(x - w * 0.5, ground + 30.0)])
	var n: int = 8
	for i in n + 1:
		var t: float = float(i) / float(n)
		var lift: float = pow(sin(t * PI), 0.7) * h * (0.7 + 0.3 * _r(k + i))
		pts.append(Vector2(lerpf(x - w * 0.5, x + w * 0.5, t), ground - lift))
	pts.append(Vector2(x + w * 0.5, ground + 30.0))
	_fill(pts, color)
	for i in 3:
		var c := Vector2(x + (_r(k + i + 20) - 0.5) * w * 0.6, ground - h * (0.55 + 0.3 * _r(k + i + 30)))
		var s: float = 6.0 + _r(k + i + 40) * 10.0
		_fill(_rot(_box(c.x - s, c.y - s * 0.6, c.x + s, c.y + s * 0.6), c, (_r(k + i + 50) - 0.5) * 1.4), color.lightened(0.06))
	var bar := Vector2(x + (_r(k + 60) - 0.5) * w * 0.4, ground - h * 0.6)
	_line(bar, bar + Vector2(10.0, -h * 0.5), _ink_color(), 1.6)
	_line(bar + Vector2(10.0, -h * 0.5), bar + Vector2(20.0, -h * 0.45), _ink_color(), 1.6)


## Factory hall with a saw-tooth roof; `lit` rows of windows glow orange.
func _factory(x: float, ground: float, w: float, h: float, color: Color, lit: bool) -> void:
	var l: float = x - w * 0.5
	var teeth: int = maxi(int(w / 38.0), 2)
	var tw: float = w / float(teeth)
	var top: float = ground - h
	var pts := PackedVector2Array([Vector2(l, ground + 40.0), Vector2(l, top)])
	for k in teeth:
		pts.append(Vector2(l + (float(k) + 1.0) * tw - 1.0, top - tw * 0.45))
		pts.append(Vector2(l + (float(k) + 1.0) * tw, top))
	pts.append(Vector2(l + w, ground + 40.0))
	_fill(pts, color)
	if not lit:
		return
	var glow: Color = biome.accent
	for k in teeth:
		var wx: float = l + (float(k) + 0.5) * tw
		if _r(int(x) + k) < 0.3:
			continue
		_rect(Rect2(wx - tw * 0.3, top + h * 0.25, tw * 0.6, h * 0.18), Color(glow, 0.85))
		_dot(Vector2(wx, top + h * 0.34), tw * 0.5, Color(glow, 0.1))


func _chimney(x: float, top_y: float, ground: float, w: float, color: Color, beacon: bool) -> void:
	var h: float = ground + 40.0 - top_y
	var pts := PackedVector2Array([Vector2(x - w * 0.62, ground + 40.0), Vector2(x - w * 0.42, top_y), Vector2(x + w * 0.42, top_y), Vector2(x + w * 0.62, ground + 40.0)])
	_fill(pts, color)
	# Faded warning bands near the top.
	for k in 2:
		var y0: float = top_y + h * (0.06 + 0.1 * float(k))
		var y1: float = y0 + h * 0.04
		var hw0: float = lerpf(w * 0.42, w * 0.62, (y0 - top_y) / h)
		var hw1: float = lerpf(w * 0.42, w * 0.62, (y1 - top_y) / h)
		_fill(PackedVector2Array([Vector2(x - hw0, y0), Vector2(x + hw0, y0), Vector2(x + hw1, y1), Vector2(x - hw1, y1)]), color.lerp(biome.star_color, 0.18), false)
	_fill(_box(x - w * 0.52, top_y - 5.0, x + w * 0.52, top_y + 3.0), color.darkened(0.12))
	if beacon:
		_dot(Vector2(x + w * 0.3, top_y + 12.0), 9.0, Color(biome.accent, 0.18))
		_dot(Vector2(x + w * 0.3, top_y + 12.0), 3.0, biome.accent)


func _tank(x: float, ground: float, r: float, h: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(x - r, ground + 40.0), Vector2(x - r, ground - h)])
	for i in range(1, 10):
		var a: float = PI + PI * float(i) / 10.0
		pts.append(Vector2(x + cos(a) * r, ground - h + sin(a) * r * 0.35))
	pts.append(Vector2(x + r, ground - h))
	pts.append(Vector2(x + r, ground + 40.0))
	_fill(pts, color)
	for k in 5:
		var sx: float = lerpf(x - r * 0.8, x + r * 0.8, float(k) / 4.0)
		_line(Vector2(sx, ground - h), Vector2(sx, ground), Color(INK, 0.3), 1.4)
	_line(Vector2(x - r, ground - h * 0.5), Vector2(x + r, ground - h * 0.5), Color(INK, 0.3), 1.4)


func _cooling_tower(x: float, ground: float, w: float, h: float, color: Color) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 11:
		var t: float = float(i) / 10.0
		var half: float = w * (0.5 - 0.2 * sin(t * PI * 0.85))
		left.append(Vector2(x - half, ground + 40.0 - (h + 40.0) * t))
		right.append(Vector2(x + half, ground + 40.0 - (h + 40.0) * t))
	right.reverse()
	left.append_array(right)
	_fill(left, color)
	for k in 4:
		var sx: float = x + (float(k) - 1.5) * w * 0.14
		_line(Vector2(sx, ground - h + 6.0), Vector2(sx + 2.0, ground - h + 30.0 + _r(k + int(x)) * 50.0), Color(INK, 0.3), 2.0)
	var crack := PackedVector2Array([Vector2(x + w * 0.1, ground - h), Vector2(x + w * 0.04, ground - h * 0.8), Vector2(x + w * 0.12, ground - h * 0.62), Vector2(x + w * 0.06, ground - h * 0.45)])
	_pline(crack, Color(INK, 0.55), 1.8)


func _scaffold(x: float, ground: float, w: float, h: float, color: Color) -> void:
	for side in [-1.0, 1.0]:
		_stroke(Vector2(x + float(side) * w * 0.5, ground + 20.0), Vector2(x + float(side) * w * 0.44, ground - h), color, 4.0)
	var levels: int = 4
	for k in levels:
		var y0: float = ground - h * float(k) / float(levels)
		var y1: float = ground - h * float(k + 1) / float(levels)
		_stroke(Vector2(x - w * 0.48, y1), Vector2(x + w * 0.48, y1), color, 3.0)
		_stroke(Vector2(x - w * 0.48, y0), Vector2(x + w * 0.46, y1), color, 2.0)
	_dot(Vector2(x, ground - h - 6.0), 8.0, Color(biome.accent, 0.2))
	_dot(Vector2(x, ground - h - 6.0), 3.0, biome.accent)


## A pipe running across the whole tile with joints, supports and the odd riser.
func _pipes(y: float, thick: float, color: Color) -> void:
	var tone: Color = color.lightened(0.05)
	draw_rect(Rect2(-WIDTH, y - thick * 0.5, WIDTH * 3.0, thick), tone)
	if _ink_w() > 0.0:
		draw_line(Vector2(-WIDTH, y - thick * 0.5), Vector2(WIDTH * 2.0, y - thick * 0.5), _ink_color(), _ink_w(), true)
		draw_line(Vector2(-WIDTH, y + thick * 0.5), Vector2(WIDTH * 2.0, y + thick * 0.5), _ink_color(), _ink_w(), true)
	draw_line(Vector2(-WIDTH, y - thick * 0.2), Vector2(WIDTH * 2.0, y - thick * 0.2), Color(biome.haze, 0.18), 2.0, true)
	for i in 16:
		var x: float = _slot(i, 16)
		_fill(_box(x - 4.0, y - thick * 0.65, x + 4.0, y + thick * 0.65), color.darkened(0.1))
		if i % 3 == 0:
			_stroke(Vector2(x + 30.0, y + thick * 0.5), Vector2(x + 30.0, y + 80.0), color, 4.0)
		if i % 5 == 2:
			_fill(_box(x + 50.0, y - thick * 0.5 - 60.0 - _r(i) * 50.0, x + 50.0 + thick, y), tone)


# =====================================================================================
# Foreground silhouettes (very dark, kept to the screen edges, no ink)
# =====================================================================================

func _fore_grass(color: Color) -> void:
	for i in 16:
		var x: float = _slot(i, 16)
		for k in 4:
			var h: float = 60.0 + _r(i * 4 + k) * 70.0
			var lean: float = (float(k) - 1.5) * 14.0
			_fill(PackedVector2Array([Vector2(x + k * 12.0 - 18.0, 760.0), Vector2(x + k * 12.0 - 18.0 + lean, 760.0 - h),
					Vector2(x + k * 12.0 - 2.0, 760.0)]), color, false)
			if k % 2 == 1:
				# Withered tips folding over.
				var tip := Vector2(x + k * 12.0 - 18.0 + lean, 760.0 - h)
				_line(tip, tip + Vector2(14.0 * signf(lean + 0.1), 18.0), color, 3.0)


func _fore_branches(color: Color) -> void:
	for i in 6:
		var x: float = _slot(i, 6)
		if i % 2 == 0:
			var start := Vector2(x, -20.0)
			var mid: Vector2 = start + Vector2(60.0 + _r(i) * 50.0, 60.0 + _r(i + 3) * 40.0)
			var end: Vector2 = mid + Vector2(70.0, -10.0 + _r(i + 5) * 40.0)
			_stroke_path(PackedVector2Array([start, mid, end]), color, 12.0)
			_line(mid, mid + Vector2(-10.0, 50.0), color, 5.0)
			_line(end, end + Vector2(24.0, 22.0), color, 4.0)
		else:
			_rubble(x, 770.0, 150.0, 50.0 + _r(i) * 40.0, color)


func _fore_reeds(color: Color) -> void:
	for i in 12:
		var x: float = _slot(i, 12)
		_reeds(x, 770.0, 120.0 + _r(i) * 60.0, color)
		if i % 4 == 1:
			for k in 5:
				_line(Vector2(x + 90.0 + k * 9.0, -10.0), Vector2(x + 90.0 + k * 9.0 + sin(k) * 5.0, 40.0 + _r(k + i) * 50.0), color, 4.0)


func _fore_shards(color: Color) -> void:
	for i in 10:
		var x: float = _slot(i, 10)
		var h: float = 50.0 + _r(i) * 70.0
		_fill(PackedVector2Array([Vector2(x - 40.0, 770.0), Vector2(x - 10.0, 770.0 - h), Vector2(x + 6.0, 770.0 - h * 0.7),
				Vector2(x + 46.0, 770.0)]), color, false)


func _fore_rubble(color: Color) -> void:
	for i in 8:
		var x: float = _slot(i, 8)
		_rubble(x, 775.0, 130.0 + _r(i) * 80.0, 40.0 + _r(i + 2) * 50.0, color)
		if i % 3 == 0:
			# A cable hanging into the top of the screen.
			var pts := PackedVector2Array()
			for j in 9:
				var t: float = float(j) / 8.0
				pts.append(Vector2(x + 40.0 + t * 220.0, -10.0 + sin(t * PI) * (50.0 + _r(i + 7) * 30.0)))
			_pline(pts, color, 5.0)


func _fore_wires(color: Color) -> void:
	for i in 10:
		var x: float = _slot(i, 10)
		for k in 3:
			var px: float = x + k * 16.0
			var h: float = 50.0 + _r(i * 3 + k) * 40.0
			_fill(PackedVector2Array([Vector2(px - 5.0, 780.0), Vector2(px - 5.0, 780.0 - h), Vector2(px, 780.0 - h - 8.0), Vector2(px + 5.0, 780.0 - h),
					Vector2(px + 5.0, 780.0)]), color, false)
		if i % 4 == 2:
			var pts := PackedVector2Array()
			for j in 9:
				var t: float = float(j) / 8.0
				pts.append(Vector2(x - 60.0 + t * 300.0, -10.0 + sin(t * PI) * 70.0))
			_pline(pts, color, 3.0)


func _fore_girders(color: Color) -> void:
	for i in 6:
		var x: float = _slot(i, 6)
		if i % 2 == 0:
			var a := Vector2(x, -30.0)
			var b := Vector2(x + 200.0, 50.0 + _r(i) * 40.0)
			_stroke(a, b, color, 16.0)
			var n: int = 5
			for k in n:
				var p: Vector2 = a.lerp(b, (float(k) + 0.5) / float(n))
				_dot(p, 3.0, color.lightened(0.08))
		else:
			_fill(_box(x - 120.0, 735.0, x + 140.0, 790.0), color, false)
			for k in 3:
				_fill(_box(x - 100.0 + k * 90.0, 725.0, x - 84.0 + k * 90.0, 790.0), color.lightened(0.04), false)


## Soft band of haze at a layer's foot, which separates it from the layer in front.
func _mist(y: float, strength: float = 0.55) -> void:
	var haze: Color = _grade(biome.haze)
	var c0 := Color(haze, 0.0)
	var c1 := Color(haze, strength)
	draw_polygon(PackedVector2Array([Vector2(-WIDTH, y - 70.0), Vector2(WIDTH * 2.0, y - 70.0), Vector2(WIDTH * 2.0, y + 30.0), Vector2(-WIDTH, y + 30.0)]),
			PackedColorArray([c0, c0, c1, c1]))
	draw_rect(Rect2(-WIDTH, y + 30.0, WIDTH * 3.0, BOTTOM - y), c1)


# =====================================================================================
# Drawing helpers (each paints its shape at the three tile offsets)
# =====================================================================================

func _offsets() -> Array[float]:
	return [-WIDTH, 0.0, WIDTH]


## Filled polygon with the layer's hand-drawn edge.
func _fill(pts: PackedVector2Array, color: Color, ink: bool = true) -> void:
	if pts.size() < 3:
		return
	var w: float = _ink_w() if ink else 0.0
	for o in _offsets():
		var moved: PackedVector2Array = Transform2D(0.0, Vector2(o, 0.0)) * pts
		draw_colored_polygon(moved, color)
		if w > 0.0:
			var closed := PackedVector2Array(moved)
			closed.append(moved[0])
			draw_polyline(closed, _ink_color(), w, true)


func _rect(r: Rect2, color: Color) -> void:
	for o in _offsets():
		draw_rect(Rect2(r.position + Vector2(o, 0.0), r.size), color)


func _line(a: Vector2, b: Vector2, color: Color, w: float) -> void:
	for o in _offsets():
		draw_line(a + Vector2(o, 0.0), b + Vector2(o, 0.0), color, w, true)


func _pline(pts: PackedVector2Array, color: Color, w: float) -> void:
	if pts.size() < 2:
		return
	for o in _offsets():
		draw_polyline(Transform2D(0.0, Vector2(o, 0.0)) * pts, color, w, true)


func _dot(c: Vector2, r: float, color: Color) -> void:
	for o in _offsets():
		draw_circle(c + Vector2(o, 0.0), r, color)


func _ring(c: Vector2, r: float, color: Color) -> void:
	for o in _offsets():
		draw_arc(c + Vector2(o, 0.0), r, 0.0, TAU, 12, color, 1.2, true)


func _ring_poly(pts: PackedVector2Array, color: Color, w: float) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	_pline(closed, color, w)


## A thick stroke (trunk, pole) with the ink edge showing on both sides.
func _stroke(a: Vector2, b: Vector2, color: Color, w: float) -> void:
	if _ink_w() > 0.0:
		_line(a, b, _ink_color(), w + _ink_w() * 1.4)
	_line(a, b, color, w)


func _stroke_path(pts: PackedVector2Array, color: Color, w: float) -> void:
	if _ink_w() > 0.0:
		_pline(pts, _ink_color(), w + _ink_w() * 1.4)
	_pline(pts, color, w)


# =====================================================================================
# Helpers
# =====================================================================================

## Layer color after haze and the backdrop grade.
func _color() -> Color:
	var c: Color
	match depth:
		Depth.FAR:
			c = biome.far_color.lerp(biome.haze, biome.haze_amount.x)
		Depth.MIDFAR:
			c = biome.mid_color.lerp(biome.far_color, 0.4).lerp(biome.haze, biome.haze_amount.y)
		Depth.MID:
			c = biome.mid_color.lerp(biome.haze, biome.haze_amount.z)
		Depth.NEAR:
			c = biome.near_color
		_:
			return biome.foreground_color
	return _grade(c)


## Pulls a backdrop color toward gray and darkens it, so the play field stands out in front.
func _grade(c: Color) -> Color:
	var nearness: float = float(mini(int(depth), 3)) / 3.0
	var gray: float = c.get_luminance()
	var out: Color = c.lerp(Color(gray, gray, gray, c.a), biome.backdrop_desaturation * (1.0 - nearness * 0.4))
	return out.darkened(biome.backdrop_dim * (0.3 + 0.4 * nearness))


func _ink_w() -> float:
	match depth:
		Depth.MIDFAR:
			return 1.6
		Depth.MID:
			return 2.4
		Depth.NEAR:
			return 3.0
	return 0.0


func _ink_color() -> Color:
	match depth:
		Depth.MIDFAR:
			return Color(INK, 0.35)
		Depth.MID:
			return Color(INK, 0.7)
		Depth.FAR, Depth.FORE:
			return Color(INK, 0.0)
	return INK


## Evenly spread position `i` of `count` across the tile, with a seeded jitter.
func _slot(i: int, count: int) -> float:
	return (float(i) + _r(i * 7 + 3) * 0.7) / float(count) * WIDTH


func _r(i: int) -> float:
	var v: float = sin(float(_salt) * 12.9898 + float(i) * 78.233) * 43758.5453
	return v - floorf(v)


func _box(l: float, t: float, r: float, b: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(l, t), Vector2(r, t), Vector2(r, b), Vector2(l, b)])


func _rot(pts: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	if is_zero_approx(angle):
		return pts
	var out := PackedVector2Array()
	for p in pts:
		out.append(pivot + (p - pivot).rotated(angle))
	return out


func _ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a: float = TAU * float(i) / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

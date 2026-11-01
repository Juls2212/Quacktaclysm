@tool
class_name BackdropLayer
extends Node2D
## One painted depth layer of a biome backdrop: far ridges, tree lines, trunks, reeds, spires...
## Drawn once over a tile `width` px wide that repeats seamlessly (child of a Parallax2D).
## Far layers melt into the biome haze and lose detail; the near layer and the foreground are
## darker and carry the most contrast, which is what makes the play field read as deep.
## World y: the screen spans 0..720 in levels, the floor sits around y 600.

enum Depth { FAR, MIDFAR, MID, NEAR, FORE }

const WIDTH: float = 2048.0
const BOTTOM: float = 1200.0

@export var biome: Biome:
	set(value):
		biome = value
		queue_redraw()
@export var depth: Depth = Depth.FAR:
	set(value):
		depth = value
		queue_redraw()

var _salt: int = 0


func _draw() -> void:
	if biome == null:
		return
	_salt = biome.scenery_seed * 101 + int(depth) * 17
	match biome.kind:
		Biome.Kind.MEADOW:
			_meadow()
		Biome.Kind.FOREST:
			_forest()
		Biome.Kind.SWAMP:
			_swamp()
		Biome.Kind.STORM:
			_storm()


# =====================================================================================
# Biomes
# =====================================================================================

func _meadow() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_ridge(400.0, 70.0, [2, 3, 7], c)
		Depth.MIDFAR:
			_ridge(470.0, 45.0, [3, 5, 9], c)
			for i in 9:
				var x: float = _slot(i, 9)
				_round_tree(x, _ridge_y(x, 470.0, 45.0, [3, 5, 9]) + 6.0, 60.0 + _r(i) * 40.0, c)
			_mist(500.0)
		Depth.MID:
			_ridge(560.0, 30.0, [2, 4, 6], c)
			for i in 5:
				var x: float = _slot(i, 5)
				_round_tree(x, _ridge_y(x, 560.0, 30.0, [2, 4, 6]) + 8.0, 120.0 + _r(i + 9) * 60.0, c)
				_bushes(x + 120.0, _ridge_y(x + 120.0, 560.0, 30.0, [2, 4, 6]) + 6.0, 40.0, c)
			_mist(600.0)
		Depth.NEAR:
			_ridge(660.0, 18.0, [3, 7, 11], c)
			for i in 40:
				var x: float = _slot(i, 40)
				_blades(x, _ridge_y(x, 660.0, 18.0, [3, 7, 11]) + 4.0, 22.0 + _r(i) * 26.0, c)
		Depth.FORE:
			_fore_grass(c)


func _forest() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_ridge(380.0, 110.0, [2, 3, 5], c, true)
		Depth.MIDFAR:
			_ridge(480.0, 30.0, [3, 5, 8], c)
			for i in 30:
				var x: float = _slot(i, 30)
				_pine(x, _ridge_y(x, 480.0, 30.0, [3, 5, 8]) + 10.0, 80.0 + _r(i) * 70.0, c)
			_mist(510.0)
		Depth.MID:
			# Huge trunks rising out of frame: the cathedral feel of an old wood.
			for i in 4:
				var x: float = _slot(i, 4)
				_trunk(x, 34.0 + _r(i) * 26.0, 580.0, c)
			_ridge(590.0, 22.0, [2, 5, 7], c)
			for i in 10:
				var x: float = _slot(i, 10) + 80.0
				_pine(x, _ridge_y(x, 590.0, 22.0, [2, 5, 7]) + 8.0, 110.0 + _r(i + 4) * 60.0, c)
			_mist(620.0)
		Depth.NEAR:
			_ridge(665.0, 16.0, [3, 6, 10], c)
			for i in 14:
				var x: float = _slot(i, 14)
				_fern(x, _ridge_y(x, 665.0, 16.0, [3, 6, 10]) + 4.0, 40.0 + _r(i) * 30.0, c)
		Depth.FORE:
			_fore_leaves(c, true)


func _swamp() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_ridge(450.0, 35.0, [2, 3, 6], c)
		Depth.MIDFAR:
			_ridge(500.0, 18.0, [3, 4, 9], c)
			for i in 8:
				var x: float = _slot(i, 8)
				_dead_tree(x, _ridge_y(x, 500.0, 18.0, [3, 4, 9]) + 6.0, 90.0 + _r(i) * 70.0, c)
			_mist(520.0, 0.7)
		Depth.MID:
			_ridge(585.0, 14.0, [2, 5, 8], c)
			for i in 4:
				var x: float = _slot(i, 4)
				_willow(x, _ridge_y(x, 585.0, 14.0, [2, 5, 8]) + 6.0, 200.0 + _r(i) * 80.0, c)
			_mist(620.0, 0.75)
		Depth.NEAR:
			_water(672.0, c)
			for i in 26:
				var x: float = _slot(i, 26)
				_reeds(x, 676.0, 40.0 + _r(i) * 40.0, c)
		Depth.FORE:
			_fore_reeds(c)


func _storm() -> void:
	var c: Color = _color()
	match depth:
		Depth.FAR:
			_jagged_ridge(390.0, 130.0, c)
		Depth.MIDFAR:
			_ridge(500.0, 25.0, [3, 5, 7], c)
			for i in 7:
				var x: float = _slot(i, 7)
				if i == 3:
					_tower(x, _ridge_y(x, 500.0, 25.0, [3, 5, 7]) + 10.0, c)
				else:
					_spire(x, _ridge_y(x, 500.0, 25.0, [3, 5, 7]) + 10.0, 90.0 + _r(i) * 110.0, 30.0 + _r(i + 3) * 30.0, c)
			_mist(530.0)
		Depth.MID:
			for i in 5:
				var x: float = _slot(i, 5)
				_floating_rock(Vector2(x, 260.0 + _r(i) * 160.0), 40.0 + _r(i + 5) * 50.0, c)
			_jagged_ridge(600.0, 40.0, c)
			_mist(630.0)
		Depth.NEAR:
			_jagged_ridge(668.0, 26.0, c)
		Depth.FORE:
			_fore_shards(c)


# =====================================================================================
# Shapes (every shape is drawn at x, x - WIDTH and x + WIDTH so the tile wraps)
# =====================================================================================

func _ridge(base: float, amp: float, freqs: Array, color: Color, peaked: bool = false) -> void:
	var pts := PackedVector2Array()
	var x: float = -WIDTH
	while x <= WIDTH * 2.0:
		var y: float = _ridge_y(x, base, amp, freqs)
		if peaked:
			y = base - amp * pow(absf(sin(x / WIDTH * PI * freqs[0] + _salt)), 0.6) + (y - base) * 0.4
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


func _round_tree(x: float, ground: float, h: float, color: Color) -> void:
	for ox in _wraps(x):
		var trunk_w: float = h * 0.09
		draw_colored_polygon(PackedVector2Array([Vector2(ox - trunk_w, ground), Vector2(ox - trunk_w * 0.6, ground - h * 0.6),
				Vector2(ox + trunk_w * 0.6, ground - h * 0.6), Vector2(ox + trunk_w, ground)]), color.darkened(0.08))
		var crown := Vector2(ox, ground - h * 0.68)
		for k in 4:
			var offset := Vector2((float(k) - 1.5) * h * 0.17, -absf(float(k) - 1.5) * -h * 0.06 - (h * 0.08 if k % 2 else 0.0))
			draw_circle(crown + offset, h * (0.24 + 0.04 * float(k % 2)), color)
		draw_arc(crown + Vector2(-h * 0.08, -h * 0.12), h * 0.22, PI * 1.05, PI * 1.6, 8, Color(color.lightened(0.25), 0.6), 3.0, true)


func _pine(x: float, ground: float, h: float, color: Color) -> void:
	for ox in _wraps(x):
		draw_rect(Rect2(ox - h * 0.04, ground - h * 0.25, h * 0.08, h * 0.25), color.darkened(0.1))
		for k in 3:
			var y0: float = ground - h * (0.18 + 0.27 * k)
			var w: float = h * (0.32 - 0.08 * k)
			draw_colored_polygon(PackedVector2Array([Vector2(ox - w, y0), Vector2(ox, y0 - h * 0.42), Vector2(ox + w, y0)]), color)


func _trunk(x: float, w: float, ground: float, color: Color) -> void:
	var dark: Color = color.darkened(0.12)
	for ox in _wraps(x):
		var pts := PackedVector2Array([Vector2(ox - w * 1.8, ground), Vector2(ox - w, ground - 70.0), Vector2(ox - w * 0.9, -40.0),
				Vector2(ox + w * 0.9, -40.0), Vector2(ox + w, ground - 70.0), Vector2(ox + w * 1.9, ground)])
		draw_colored_polygon(pts, dark)
		for k in 2:
			var by: float = 140.0 + 160.0 * k + _r(int(x) + k) * 60.0
			var dir: float = -1.0 if k % 2 == 0 else 1.0
			draw_line(Vector2(ox + w * 0.8 * dir, by), Vector2(ox + dir * (w + 90.0), by - 60.0), dark, w * 0.35, true)
		draw_line(Vector2(ox - w * 0.55, -40.0), Vector2(ox - w * 0.62, ground - 80.0), Color(color.lightened(0.18), 0.5), 3.0, true)


func _bushes(x: float, ground: float, size: float, color: Color) -> void:
	for ox in _wraps(x):
		for k in 3:
			draw_circle(Vector2(ox + (float(k) - 1.0) * size * 0.6, ground - size * (0.35 + 0.15 * float(k % 2))), size * 0.45, color.darkened(0.05))


func _blades(x: float, ground: float, h: float, color: Color) -> void:
	for ox in _wraps(x):
		for k in 3:
			var lean: float = (float(k) - 1.0) * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(ox + k * 5.0 - 6.0, ground), Vector2(ox + k * 5.0 - 6.0 + lean, ground - h * (0.7 + 0.15 * k)),
					Vector2(ox + k * 5.0, ground)]), color)


func _fern(x: float, ground: float, h: float, color: Color) -> void:
	for ox in _wraps(x):
		for k in 5:
			var a: float = lerpf(-2.5, -0.6, float(k) / 4.0)
			var tip: Vector2 = Vector2(ox, ground) + Vector2.from_angle(a) * h
			draw_line(Vector2(ox, ground), tip, color, 5.0, true)
			draw_circle(tip, 4.0, color)


func _dead_tree(x: float, ground: float, h: float, color: Color) -> void:
	for ox in _wraps(x):
		var lean: float = (_r(int(x) + 7) - 0.5) * 30.0
		var top := Vector2(ox + lean, ground - h)
		draw_line(Vector2(ox, ground), top, color, h * 0.08, true)
		for k in 3:
			var p: Vector2 = Vector2(ox, ground).lerp(top, 0.45 + 0.18 * k)
			var dir: float = -1.0 if k % 2 == 0 else 1.0
			var tip: Vector2 = p + Vector2(dir * h * 0.3, -h * 0.18)
			draw_line(p, tip, color, h * 0.035, true)
			draw_line(tip, tip + Vector2(dir * h * 0.08, h * 0.06), color, h * 0.02, true)


func _willow(x: float, ground: float, h: float, color: Color) -> void:
	for ox in _wraps(x):
		draw_line(Vector2(ox, ground), Vector2(ox + 10.0, ground - h * 0.65), color.darkened(0.1), h * 0.08, true)
		var crown := Vector2(ox + 10.0, ground - h * 0.7)
		for k in 5:
			draw_circle(crown + Vector2((float(k) - 2.0) * h * 0.13, (absf(float(k) - 2.0)) * h * 0.04), h * 0.17, color)
		# Hanging moss strands.
		for k in 9:
			var sx: float = crown.x + (float(k) - 4.0) * h * 0.07
			var len: float = h * (0.3 + _r(k + int(x)) * 0.35)
			draw_line(Vector2(sx, crown.y), Vector2(sx + sin(k * 1.7) * 6.0, crown.y + len), color, 3.0, true)


func _water(level: float, color: Color) -> void:
	var water: Color = color.lerp(biome.sky_bottom, 0.25)
	draw_rect(Rect2(-WIDTH, level, WIDTH * 3.0, BOTTOM - level), water)
	for i in 40:
		var x: float = _slot(i, 40)
		for ox in _wraps(x):
			var y: float = level + 6.0 + _r(i + 90) * 30.0
			draw_line(Vector2(ox, y), Vector2(ox + 18.0 + _r(i) * 30.0, y), Color(biome.haze, 0.35), 2.0, true)
	draw_line(Vector2(-WIDTH, level), Vector2(WIDTH * 2.0, level), Color(biome.haze, 0.5), 2.0, true)


func _reeds(x: float, ground: float, h: float, color: Color) -> void:
	for ox in _wraps(x):
		for k in 3:
			var top := Vector2(ox + (float(k) - 1.0) * 6.0 + sin(k + x) * 4.0, ground - h * (0.75 + 0.12 * k))
			draw_line(Vector2(ox + (float(k) - 1.0) * 4.0, ground), top, color, 3.0, true)
			if k == 1:
				draw_colored_polygon(_ellipse(top + Vector2(0, 6), 3.2, 8.0), color.darkened(0.15))


func _spire(x: float, ground: float, h: float, w: float, color: Color) -> void:
	for ox in _wraps(x):
		var pts := PackedVector2Array([Vector2(ox - w, ground), Vector2(ox - w * 0.55, ground - h * 0.55), Vector2(ox - w * 0.3, ground - h * 0.6),
				Vector2(ox - w * 0.1, ground - h), Vector2(ox + w * 0.25, ground - h * 0.7), Vector2(ox + w * 0.5, ground - h * 0.45), Vector2(ox + w, ground)])
		draw_colored_polygon(pts, color)
		draw_line(pts[3], pts[4], Color(biome.accent, 0.25), 2.0, true)


func _tower(x: float, ground: float, color: Color) -> void:
	for ox in _wraps(x):
		var w: float = 34.0
		var h: float = 210.0
		draw_colored_polygon(PackedVector2Array([Vector2(ox - w, ground), Vector2(ox - w * 0.8, ground - h), Vector2(ox + w * 0.8, ground - h),
				Vector2(ox + w, ground)]), color)
		for k in 3:
			draw_rect(Rect2(ox - w * 0.8 + k * w * 0.62, ground - h - 14.0, w * 0.34, 16.0), color)
		draw_colored_polygon(PackedVector2Array([Vector2(ox + w * 0.8, ground - h + 10), Vector2(ox + w * 0.3, ground - h - 4),
				Vector2(ox + w * 0.9, ground - h - 30)]), color)
		draw_rect(Rect2(ox - 5.0, ground - h * 0.7, 10.0, 18.0), Color(biome.accent, 0.55))


func _floating_rock(c: Vector2, size: float, color: Color) -> void:
	for ox in _wraps(c.x):
		var p := Vector2(ox, c.y)
		var pts := PackedVector2Array([p + Vector2(-size, 0), p + Vector2(-size * 0.7, -size * 0.3), p + Vector2(size * 0.6, -size * 0.32),
				p + Vector2(size, 0), p + Vector2(size * 0.35, size * 0.5), p + Vector2(0, size * 1.1), p + Vector2(-size * 0.4, size * 0.45)])
		draw_colored_polygon(pts, color)
		draw_line(pts[1], pts[2], Color(color.lightened(0.25), 0.6), 3.0, true)


func _fore_grass(color: Color) -> void:
	for i in 16:
		var x: float = _slot(i, 16)
		for ox in _wraps(x):
			for k in 4:
				var h: float = 60.0 + _r(i * 4 + k) * 70.0
				var lean: float = (float(k) - 1.5) * 14.0
				draw_colored_polygon(PackedVector2Array([Vector2(ox + k * 12.0 - 18.0, 760.0), Vector2(ox + k * 12.0 - 18.0 + lean, 760.0 - h),
						Vector2(ox + k * 12.0 - 2.0, 760.0)]), color)


func _fore_leaves(color: Color, hanging: bool) -> void:
	for i in 9:
		var x: float = _slot(i, 9)
		for ox in _wraps(x):
			for k in 3:
				draw_colored_polygon(_ellipse(Vector2(ox + (float(k) - 1.0) * 34.0, 735.0 - _r(i + k) * 24.0), 36.0, 20.0, (float(k) - 1.0) * 0.6), color)
			if hanging and i % 3 == 0:
				var vx: float = ox + 200.0
				draw_line(Vector2(vx, -10.0), Vector2(vx + 8.0, 70.0 + _r(i) * 40.0), color, 6.0, true)
				for k in 3:
					draw_colored_polygon(_ellipse(Vector2(vx + 4.0 + (k - 1) * 10.0, 30.0 + k * 22.0), 12.0, 7.0, 0.8 * (k - 1)), color)


func _fore_reeds(color: Color) -> void:
	for i in 12:
		var x: float = _slot(i, 12)
		_reeds(x, 770.0, 120.0 + _r(i) * 60.0, color)
		if i % 4 == 1:
			for ox in _wraps(x + 90.0):
				for k in 5:
					draw_line(Vector2(ox + k * 9.0, -10.0), Vector2(ox + k * 9.0 + sin(k) * 5.0, 40.0 + _r(k + i) * 50.0), color, 4.0, true)


func _fore_shards(color: Color) -> void:
	for i in 10:
		var x: float = _slot(i, 10)
		for ox in _wraps(x):
			var h: float = 50.0 + _r(i) * 70.0
			draw_colored_polygon(PackedVector2Array([Vector2(ox - 40.0, 770.0), Vector2(ox - 10.0, 770.0 - h), Vector2(ox + 6.0, 770.0 - h * 0.7),
					Vector2(ox + 46.0, 770.0)]), color)


## Soft band of haze at a layer's foot, which separates it from the layer in front.
func _mist(y: float, strength: float = 0.55) -> void:
	var c0 := Color(biome.haze, 0.0)
	var c1 := Color(biome.haze, strength)
	draw_polygon(PackedVector2Array([Vector2(-WIDTH, y - 70.0), Vector2(WIDTH * 2.0, y - 70.0), Vector2(WIDTH * 2.0, y + 30.0), Vector2(-WIDTH, y + 30.0)]),
			PackedColorArray([c0, c0, c1, c1]))
	draw_rect(Rect2(-WIDTH, y + 30.0, WIDTH * 3.0, BOTTOM - y), c1)


## Thin light edge along a ridge top, on the side facing the sky.
func _rim(points: PackedVector2Array, color: Color) -> void:
	if depth == Depth.FORE:
		return
	var lit := PackedVector2Array()
	for p in points:
		lit.append(p + Vector2(0, 2.0))
	draw_polyline(lit, Color(color.lerp(biome.sun, 0.35), 0.6), 2.0, true)


# =====================================================================================
# Helpers
# =====================================================================================

func _color() -> Color:
	match depth:
		Depth.FAR:
			return biome.far_color.lerp(biome.haze, biome.haze_amount.x)
		Depth.MIDFAR:
			return biome.mid_color.lerp(biome.far_color, 0.4).lerp(biome.haze, biome.haze_amount.y)
		Depth.MID:
			return biome.mid_color.lerp(biome.haze, biome.haze_amount.z)
		Depth.NEAR:
			return biome.near_color
	return biome.foreground_color


func _wraps(x: float) -> Array[float]:
	return [x - WIDTH, x, x + WIDTH]


## Evenly spread position `i` of `count` across the tile, with a seeded jitter.
func _slot(i: int, count: int) -> float:
	return (float(i) + _r(i * 7 + 3) * 0.7) / float(count) * WIDTH


func _r(i: int) -> float:
	var v: float = sin(float(_salt) * 12.9898 + float(i) * 78.233) * 43758.5453
	return v - floorf(v)


func _ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a: float = TAU * float(i) / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

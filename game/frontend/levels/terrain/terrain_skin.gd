@tool
class_name TerrainSkin
extends Node2D
## Organic look for a level block, drawn in code with the same thick ink as the ducks.
## GROUND is a slab of earth that keeps going below the screen, ISLAND a floating clod with a
## tapered underside and hanging roots, WALL a rock pillar, CEILING a rock overhang, PLANK a bridge.
## The collision box (`size`, centered) is the walkable top: grass lips overhang it a little.
## Visual only. Shapes are seeded from the global position, so a block always looks the same.

enum Kind { AUTO, GROUND, ISLAND, WALL, CEILING, PLANK }

const INK := Color(0.106, 0.098, 0.122)
const INK_W := 2.8
const DEFAULT_BIOME := preload("res://frontend/levels/biome/meadow_biome.tres")
## How far a GROUND slab is drawn below its collision box (it reads as solid earth).
const GROUND_DEPTH: float = 420.0

@export var size: Vector2 = Vector2(200, 32):
	set(value):
		size = value
		queue_redraw()
@export var kind: Kind = Kind.AUTO:
	set(value):
		kind = value
		queue_redraw()
@export var biome: Biome:
	set(value):
		biome = value
		queue_redraw()

var _seed: int = 0


func _ready() -> void:
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


## The kind actually drawn: AUTO picks from the block's shape and height in the level.
func resolved_kind() -> Kind:
	if kind != Kind.AUTO:
		return kind
	if size.y > size.x * 1.5:
		return Kind.WALL
	if size.x >= 600.0:
		return Kind.CEILING if global_position.y < 300.0 else Kind.GROUND
	return Kind.ISLAND


func _draw() -> void:
	var b: Biome = biome if biome != null else DEFAULT_BIOME
	_seed = int(roundf(global_position.x * 0.37 + global_position.y * 1.91)) + b.scenery_seed * 7919
	match resolved_kind():
		Kind.GROUND:
			_draw_ground(b)
		Kind.ISLAND:
			_draw_island(b)
		Kind.WALL:
			_draw_wall(b)
		Kind.CEILING:
			_draw_ceiling(b)
		Kind.PLANK:
			_draw_plank(b)


# =====================================================================================
# Kinds
# =====================================================================================

func _draw_ground(b: Biome) -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	var bottom: float = half.y + GROUND_DEPTH
	var body := PackedVector2Array()
	# Rounded top corners, then sides that bulge a little as they drop out of sight.
	body.append_array(_corner(Vector2(-half.x + 12, top + 12), 12.0, PI, PI * 1.5))
	body.append_array(_corner(Vector2(half.x - 12, top + 12), 12.0, PI * 1.5, TAU))
	for i in range(1, 9):
		var y: float = lerpf(top + 12, bottom, float(i) / 8.0)
		body.append(Vector2(half.x + _wave(y, 0.03, 5.0, 3), y))
	for i in range(8, 0, -1):
		var y: float = lerpf(top + 12, bottom, float(i) / 8.0)
		body.append(Vector2(-half.x - _wave(y, 0.03, 5.0, 5), y))
	_draw_earth(b, body, top, bottom)
	_draw_grass_lip(b, -half.x, half.x, top)


func _draw_island(b: Biome) -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	var taper: float = clampf(size.x * 0.32, 26.0, 84.0)
	var body := PackedVector2Array()
	body.append_array(_corner(Vector2(-half.x + 8, top + 8), 8.0, PI, PI * 1.5))
	body.append_array(_corner(Vector2(half.x - 8, top + 8), 8.0, PI * 1.5, TAU))
	body.append(Vector2(half.x + 2, half.y))
	# Clod underside: a lumpy tongue of earth hanging below the slab.
	var steps: int = 14
	var tip_shift: float = (_rand(1) - 0.5) * size.x * 0.25
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var x: float = lerpf(half.x, -half.x, t)
		var drop: float = pow(sin(PI * t), 0.75) * taper
		x += tip_shift * sin(PI * t)
		body.append(Vector2(x, half.y + drop + _wave(x, 0.21, 3.0, 7)))
	body.append(Vector2(-half.x - 2, half.y))
	_draw_roots(b, body, half.y)
	_draw_earth(b, body, top, half.y + taper)
	_draw_grass_lip(b, -half.x, half.x, top)


func _draw_wall(b: Biome) -> void:
	var half: Vector2 = size * 0.5
	var body := PackedVector2Array()
	var rows: int = maxi(int(size.y / 38.0), 2)
	for i in rows + 1:
		var y: float = lerpf(-half.y, half.y, float(i) / float(rows))
		body.append(Vector2(half.x + 4.0 + (_rand(i * 3 + 1) - 0.5) * 7.0, y))
	for i in range(rows, -1, -1):
		var y: float = lerpf(-half.y, half.y, float(i) / float(rows))
		body.append(Vector2(-half.x - 4.0 - (_rand(i * 3 + 2) - 0.5) * 7.0, y))
	draw_colored_polygon(body, b.rock)
	# Shade the far side and break the column into stacked blocks.
	var shade := Geometry2D.intersect_polygons(body, _rect(Vector2(half.x * 0.15, -half.y - 20), Vector2(half.x + 20, half.y + 20)))
	for poly in shade:
		draw_colored_polygon(poly, Color(b.rock_dark, 0.55))
	for i in range(1, rows):
		var y: float = lerpf(-half.y, half.y, float(i) / float(rows)) + (_rand(i + 40) - 0.5) * 8.0
		draw_line(Vector2(-half.x + 3, y), Vector2(half.x - 3, y + (_rand(i + 70) - 0.5) * 6.0), Color(INK, 0.55), 1.8, true)
		if _rand(i + 90) > 0.5:
			var cx: float = lerpf(-half.x + 6, half.x - 6, _rand(i + 110))
			draw_line(Vector2(cx, y), Vector2(cx + 3, y + 16), Color(INK, 0.45), 1.4, true)
	# Moss creeping over the top and in a few patches.
	for i in rows / 3 + 1:
		var y: float = lerpf(-half.y + 30, half.y - 30, _rand(i + 150))
		var patch := _blob(Vector2((_rand(i + 170) - 0.5) * size.x, y), Vector2(size.x * 0.35, 6), 9, i)
		draw_colored_polygon(patch, Color(b.grass_dark, 0.85))
	_outline(body)
	_draw_grass_lip(b, -half.x - 2, half.x + 2, -half.y)


func _draw_ceiling(b: Biome) -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y - 260.0
	var body := PackedVector2Array([Vector2(-half.x - 6, top), Vector2(half.x + 6, top)])
	# Ragged underside with hanging stalactites.
	var steps: int = maxi(int(size.x / 28.0), 4)
	for i in steps + 1:
		var x: float = lerpf(half.x + 6, -half.x - 6, float(i) / float(steps))
		var y: float = half.y + (_rand(i + 5) - 0.5) * 6.0
		if i % 3 == 1 and i < steps:
			body.append(Vector2(x + 7, y))
			body.append(Vector2(x, y + 14.0 + _rand(i + 9) * 18.0))
			body.append(Vector2(x - 7, y))
		else:
			body.append(Vector2(x, y))
	draw_colored_polygon(body, b.rock)
	var under := Geometry2D.intersect_polygons(body, _rect(Vector2(-half.x - 20, half.y - 14), Vector2(half.x + 20, half.y + 60)))
	for poly in under:
		draw_colored_polygon(poly, Color(b.rock_dark, 0.7))
	for i in steps / 2:
		var x: float = lerpf(-half.x + 20, half.x - 20, _rand(i + 30))
		_vine(Vector2(x, half.y), 14.0 + _rand(i + 31) * 30.0, b.grass_dark, i)
	_outline(body)


func _draw_plank(b: Biome) -> void:
	var half: Vector2 = size * 0.5
	var wood := b.soil.lightened(0.15)
	var x: float = -half.x
	var i: int = 0
	while x < half.x:
		var w: float = minf(20.0 + _rand(i) * 6.0, half.x - x)
		var plank := _rect(Vector2(x + 1, -half.y + (_rand(i + 50) - 0.5) * 2.0), Vector2(x + w - 1, half.y))
		draw_colored_polygon(plank, wood)
		_outline(plank, 2.0)
		x += w
		i += 1
	draw_line(Vector2(-half.x, -half.y - 2), Vector2(half.x, -half.y - 2), INK, 3.0, true)


# =====================================================================================
# Shared pieces
# =====================================================================================

## Fills an earth body: soil, strata, buried stones and a deepening shadow, then the ink edge.
func _draw_earth(b: Biome, body: PackedVector2Array, top: float, bottom: float) -> void:
	var half: Vector2 = size * 0.5
	draw_colored_polygon(body, b.soil)
	# Wavy strata bands, each a little darker.
	for k in 4:
		var y0: float = top + 30.0 + k * 34.0
		if y0 > bottom - 10.0:
			break
		var band := PackedVector2Array()
		for i in 25:
			var x: float = lerpf(-half.x - 30, half.x + 30, float(i) / 24.0)
			band.append(Vector2(x, y0 + _wave(x, 0.025, 6.0, 11 + k)))
		for i in range(24, -1, -1):
			var x: float = lerpf(-half.x - 30, half.x + 30, float(i) / 24.0)
			band.append(Vector2(x, y0 + 12.0 + _wave(x, 0.03, 5.0, 17 + k)))
		for poly in Geometry2D.intersect_polygons(body, band):
			draw_colored_polygon(poly, Color(b.soil_dark, 0.22 + 0.08 * k))
	# Shadow that thickens with depth (ambient occlusion under the grass and down the slab).
	for k in 5:
		var y: float = top + 70.0 + k * 55.0
		if y > bottom:
			break
		for poly in Geometry2D.intersect_polygons(body, _rect(Vector2(-half.x - 30, y), Vector2(half.x + 30, bottom + 40))):
			draw_colored_polygon(poly, Color(b.soil_dark, 0.16))
	for poly in Geometry2D.intersect_polygons(body, _rect(Vector2(-half.x - 30, top), Vector2(half.x + 30, top + 16))):
		draw_colored_polygon(poly, Color(b.soil_dark, 0.35))
	# Buried stones.
	var stones: int = maxi(int(size.x / 85.0), 1)
	for i in stones:
		var c := Vector2(lerpf(-half.x + 18, half.x - 18, _rand(i * 5 + 200)), top + 26.0 + _rand(i * 5 + 201) * minf(110.0, bottom - top - 40.0))
		var r := Vector2(5.0 + _rand(i * 5 + 202) * 10.0, 4.0 + _rand(i * 5 + 203) * 7.0)
		var stone := _blob(c, r, 10, i + 300)
		draw_colored_polygon(stone, b.rock)
		draw_line(c + Vector2(-r.x * 0.5, -r.y * 0.4), c + Vector2(r.x * 0.2, -r.y * 0.6), Color(1, 1, 1, 0.35), 1.6, true)
		_outline(stone, 2.0)
	# Rootlets near the top.
	for i in maxi(int(size.x / 120.0), 1):
		var x: float = lerpf(-half.x + 20, half.x - 20, _rand(i * 3 + 400))
		var pts := PackedVector2Array()
		for j in 5:
			pts.append(Vector2(x + sin(j * 1.3 + i) * 4.0, top + 14.0 + j * 6.0))
		draw_polyline(pts, Color(b.soil_dark, 0.8), 2.0, true)
	_outline(body)


## Overhanging lip of grass along the walkable top, with scalloped drips, tufts and flowers.
func _draw_grass_lip(b: Biome, left: float, right: float, top: float) -> void:
	var overhang: float = 9.0
	var l: float = left - overhang
	var r: float = right + overhang
	var steps: int = maxi(int((r - l) / 10.0), 6)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in steps + 1:
		var x: float = lerpf(l, r, float(i) / float(steps))
		upper.append(Vector2(x, top - 4.0 - absf(sin(x * 0.19 + _seed)) * 2.5))
		# Drips hang lower near the ends, where the turf folds over the edge.
		var edge: float = 1.0 - clampf(minf(x - l, r - x) / 40.0, 0.0, 1.0)
		lower.append(Vector2(x, top + 9.0 + absf(sin(x * 0.11 + _seed * 0.3)) * 6.0 + edge * 10.0))
	var lip := PackedVector2Array()
	lip.append_array(_corner(Vector2(l + 5, top + 2), 7.0, PI * 0.5, PI * 1.5))
	lip.append_array(upper)
	lip.append_array(_corner(Vector2(r - 5, top + 2), 7.0, PI * 1.5, PI * 2.5))
	lower.reverse()
	lip.append_array(lower)
	draw_colored_polygon(lip, b.grass)
	# Darker underside of the turf and a lit top edge.
	var shade := PackedVector2Array(lower)
	shade.reverse()
	var shade_top := PackedVector2Array()
	for p in shade:
		shade_top.append(p + Vector2(0, -5))
	shade_top.reverse()
	var band := PackedVector2Array(shade)
	band.append_array(shade_top)
	for poly in Geometry2D.intersect_polygons(lip, band):
		draw_colored_polygon(poly, b.grass_dark)
	var highlight := PackedVector2Array()
	for p in upper:
		highlight.append(p + Vector2(0, 2.5))
	draw_polyline(highlight, b.grass.lightened(0.3), 2.0, true)
	_outline(lip)
	# Tufts and the odd flower.
	var tufts: int = int((r - l) / 26.0)
	for i in tufts:
		var x: float = lerpf(l + 10, r - 10, (float(i) + _rand(i + 500)) / float(maxi(tufts, 1)))
		var h: float = 5.0 + _rand(i + 520) * 9.0
		_tuft(Vector2(x, top - 4.0), h, b, i)
		if _rand(i + 540) > 0.82:
			_flower(Vector2(x + 6.0, top - 6.0 - h * 0.6), b.accent)


func _draw_roots(b: Biome, body: PackedVector2Array, under_y: float) -> void:
	var half: Vector2 = size * 0.5
	var count: int = maxi(int(size.x / 45.0), 2)
	for i in count:
		var x: float = lerpf(-half.x * 0.7, half.x * 0.7, _rand(i + 600))
		# Start inside the body's underside so the root grows out of the earth.
		var start_y: float = under_y
		for p in body:
			if absf(p.x - x) < 12.0:
				start_y = maxf(start_y, p.y - 6.0)
		_vine(Vector2(x, start_y), 18.0 + _rand(i + 610) * 34.0, b.soil_dark, i + 620)


func _vine(from: Vector2, length: float, color: Color, salt: int) -> void:
	var pts := PackedVector2Array()
	var segments: int = 6
	for j in segments + 1:
		var t: float = float(j) / float(segments)
		pts.append(from + Vector2(sin(t * 5.0 + salt) * 4.0 * t, t * length))
	draw_polyline(pts, INK, 5.0, true)
	draw_polyline(pts, color, 2.6, true)


func _tuft(at: Vector2, h: float, b: Biome, salt: int) -> void:
	for k in 3:
		var lean: float = (float(k) - 1.0) * 3.0 + (_rand(salt * 3 + k) - 0.5) * 2.0
		var blade := PackedVector2Array([at + Vector2(-2.2 + k * 2.2, 1), at + Vector2(lean + k * 2.2 - 2.2, -h * (0.7 + 0.3 * float(k % 2))),
				at + Vector2(1.6 + k * 2.2, 1)])
		draw_colored_polygon(blade, b.grass_dark if k == 1 else b.grass)
		draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2]]), INK, 1.6, true)


func _flower(at: Vector2, color: Color) -> void:
	for k in 5:
		var p: Vector2 = at + Vector2.from_angle(TAU * k / 5.0) * 2.6
		draw_circle(p, 2.2, INK)
	for k in 5:
		var p: Vector2 = at + Vector2.from_angle(TAU * k / 5.0) * 2.6
		draw_circle(p, 1.5, color)
	draw_circle(at, 1.4, Color(1, 0.98, 0.9))


# =====================================================================================
# Helpers
# =====================================================================================

func _outline(points: PackedVector2Array, width: float = INK_W) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, INK, width, true)


func _corner(center: Vector2, radius: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(center + Vector2.from_angle(lerpf(a0, a1, float(i) / 4.0)) * radius)
	return pts


func _rect(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


func _blob(c: Vector2, r: Vector2, steps: int, salt: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var k: float = 0.82 + _rand(salt * 13 + i) * 0.3
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts


## Smooth deterministic wobble: a sum of two sines seeded per block.
func _wave(x: float, freq: float, amp: float, salt: int) -> float:
	var s: float = float(_seed % 1000) * 0.13 + salt
	return (sin(x * freq + s) * 0.65 + sin(x * freq * 2.3 + s * 1.7) * 0.35) * amp


## Deterministic 0..1 value for this block and `salt`.
func _rand(salt: int) -> float:
	var v: float = sin(float(_seed) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floorf(v)

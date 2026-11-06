@tool
class_name TerrainSkin
extends Node2D
## Organic look for a level block, drawn in code with the same thick ink as the ducks. Parched
## biomes crack the earth, wither the tufts and scatter junk from the old world (Biome.rubble).
## GROUND is a slab of earth that keeps going below the screen, ISLAND a floating clod with a
## tapered underside and hanging roots, WALL a rock pillar, CEILING a rock overhang, PLANK a bridge.
## The collision box (`size`, centered) is the walkable top: grass lips overhang it a little.
## Visual only. Shapes are seeded from the global position, so a block always looks the same.

## Swamp kinds (level 2): MOSS_SLAB a long slab of stone bricks with grass on top and vines
## hanging off the edges; MOSS_BROKEN the same with cut ends and a missing chunk; MOSS_STONES a
## pile of big mossy boulders; CAR a rusted car on a mound of mud; CAR_SUNK a car tilted and half
## under dirty water; DOOR a door floating flat on the water. Outside the marsh, CAR sits on a heap
## of rubble instead of mud.
## Decay kinds (levels 1 and 3): BUS a long rusted school bus; CONTAINER a rusted cargo container;
## GIRDER a steel lattice girder; CRANE_HOOK a plate hanging from a crane hook on a chain that
## sways a little (only the chain and hook move: the plate stays where its collision is).
enum Kind { AUTO, GROUND, ISLAND, WALL, CEILING, PLANK, MOSS_SLAB, MOSS_BROKEN, MOSS_STONES, CAR, CAR_SUNK, DOOR,
		BUS, CONTAINER, GIRDER, CRANE_HOOK }

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
var _time: float = 0.0


func _ready() -> void:
	set_notify_transform(true)


func _process(delta: float) -> void:
	# Only the kinds with swaying vines, drips or ripples redraw every frame.
	var k: Kind = resolved_kind()
	if k in [Kind.MOSS_SLAB, Kind.MOSS_BROKEN, Kind.MOSS_STONES, Kind.CAR_SUNK, Kind.DOOR, Kind.CRANE_HOOK]:
		_time += delta
		queue_redraw()


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
		Kind.MOSS_SLAB:
			_draw_moss_slab(false)
		Kind.MOSS_BROKEN:
			_draw_moss_slab(true)
		Kind.MOSS_STONES:
			_draw_moss_stones()
		Kind.CAR:
			_draw_car(false, b)
		Kind.CAR_SUNK:
			_draw_car(true, b)
		Kind.DOOR:
			_draw_door()
		Kind.BUS:
			_draw_bus()
		Kind.CONTAINER:
			_draw_container()
		Kind.GIRDER:
			_draw_girder(-size.x * 0.5, size.x * 0.5, -size.y * 0.5, maxf(size.y, 20.0))
		Kind.CRANE_HOOK:
			_draw_crane_hook()


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
	# Buried stones (with rubble, some of them are bricks and broken pipes from the old world).
	var stones: int = maxi(int(size.x / 85.0), 1)
	for i in stones:
		var c := Vector2(lerpf(-half.x + 18, half.x - 18, _rand(i * 5 + 200)), top + 26.0 + _rand(i * 5 + 201) * minf(110.0, bottom - top - 40.0))
		var r := Vector2(5.0 + _rand(i * 5 + 202) * 10.0, 4.0 + _rand(i * 5 + 203) * 7.0)
		if _rand(i * 5 + 204) < b.rubble * 0.6:
			_draw_brick(c, r.x + 3.0, (_rand(i * 5 + 205) - 0.5) * 0.8, b)
			continue
		var stone := _blob(c, r, 10, i + 300)
		draw_colored_polygon(stone, b.rock)
		draw_line(c + Vector2(-r.x * 0.5, -r.y * 0.4), c + Vector2(r.x * 0.2, -r.y * 0.6), Color(1, 1, 1, 0.25), 1.6, true)
		_outline(stone, 2.0)
	if b.dry_ground:
		_draw_cracks(b, top, bottom)
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
	# Junk lying on the walkable top: drawn first so the tufts grow over it.
	if b.rubble > 0.0:
		var junk: int = int((r - l) / 110.0 * b.rubble * 1.6)
		for i in junk:
			var x: float = lerpf(l + 14, r - 14, (float(i) + _rand(i + 700)) / float(maxi(junk, 1)))
			_draw_junk(Vector2(x, top - 3.0), b, i)
	# Tufts and the odd flower (on parched ground, a shard of a fallen star instead).
	var tufts: int = int((r - l) / 26.0)
	for i in tufts:
		var x: float = lerpf(l + 10, r - 10, (float(i) + _rand(i + 500)) / float(maxi(tufts, 1)))
		var h: float = 5.0 + _rand(i + 520) * 9.0
		_tuft(Vector2(x, top - 4.0), h, b, i)
		if _rand(i + 540) > 0.82:
			if b.dry_ground:
				if _rand(i + 560) > 0.5:
					_shard(Vector2(x + 6.0, top - 4.0), b.accent)
			else:
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
		if b.dry_ground and k != 1:
			# Withered: the tip has given up and folds over.
			var fold: float = -1.0 if k == 0 else 1.0
			var tip: Vector2 = blade[1]
			var droop := PackedVector2Array([tip, tip + Vector2(fold * h * 0.35, h * 0.12), tip + Vector2(fold * h * 0.5, h * 0.38)])
			draw_polyline(droop, INK, 3.2, true)
			draw_polyline(droop, b.grass_dark, 1.4, true)


## Glowing sliver of a fallen star stuck in the ground.
func _shard(at: Vector2, color: Color) -> void:
	draw_circle(at + Vector2(0, -4), 7.0, Color(color, 0.18))
	var pts := PackedVector2Array([at + Vector2(-2.6, 1), at + Vector2(-0.6, -9), at + Vector2(2.8, -3.5), at + Vector2(2.2, 1)])
	draw_colored_polygon(pts, color)
	draw_line(at + Vector2(-0.4, -6.5), at + Vector2(0.8, -2.5), Color(1, 0.95, 0.8, 0.9), 1.2, true)
	_outline(pts, 1.6)


## Dry earth splitting: a few branching ink cracks running down from under the turf.
func _draw_cracks(b: Biome, top: float, bottom: float) -> void:
	var half: Vector2 = size * 0.5
	var count: int = maxi(int(size.x / 90.0), 1)
	for i in count:
		var x: float = lerpf(-half.x + 22, half.x - 22, (float(i) + _rand(i + 800)) / float(count))
		var p := Vector2(x, top + 18.0)
		var pts := PackedVector2Array([p])
		var steps: int = 3 + int(_rand(i + 810) * 3.0)
		for j in steps:
			p += Vector2((_rand(i * 7 + j + 820) - 0.5) * 12.0, 7.0 + _rand(i * 7 + j + 830) * 6.0)
			if p.y > bottom - 6.0:
				break
			pts.append(p)
		if pts.size() < 2:
			continue
		draw_polyline(pts, Color(INK, 0.7), 1.8, true)
		# One short split off the middle.
		var mid: Vector2 = pts[int(pts.size() * 0.5)]
		draw_line(mid, mid + Vector2((_rand(i + 840) - 0.5) * 16.0, 8.0), Color(INK, 0.55), 1.3, true)
		draw_line(pts[0] + Vector2(1.5, 0), pts[1] + Vector2(1.5, 0), Color(b.soil.lightened(0.2), 0.5), 1.0, true)


## Brick or concrete chunk buried in the earth.
func _draw_brick(c: Vector2, w: float, rot: float, b: Biome) -> void:
	var brick: Color = b.soil.lerp(Color(0.62, 0.3, 0.2), 0.45) if _rand(int(c.x) + 3) > 0.4 else b.rock
	var pts := PackedVector2Array()
	for p in [Vector2(-w, -w * 0.45), Vector2(w, -w * 0.45), Vector2(w, w * 0.45), Vector2(-w, w * 0.45)]:
		pts.append(c + (p as Vector2).rotated(rot))
	draw_colored_polygon(pts, brick)
	draw_line(c + Vector2(-w * 0.2, -w * 0.45).rotated(rot), c + Vector2(-w * 0.2, w * 0.45).rotated(rot), Color(INK, 0.45), 1.2, true)
	_outline(pts, 2.0)


## Small junk on the walkable top: a brick, a concrete lump, a rusty can or a bent rod.
func _draw_junk(at: Vector2, b: Biome, salt: int) -> void:
	match int(_rand(salt + 720) * 4.0):
		0:
			_draw_brick(at + Vector2(0, -2.5), 5.5, (_rand(salt + 730) - 0.5) * 0.5, b)
		1:
			var lump := _blob(at + Vector2(0, -3.0), Vector2(7.0, 4.5), 9, salt + 740)
			draw_colored_polygon(lump, b.rock)
			_outline(lump, 2.0)
		2:
			var can := PackedVector2Array([at + Vector2(-3.5, 0.5), at + Vector2(-3.5, -9.0), at + Vector2(3.5, -9.0), at + Vector2(3.5, 0.5)])
			draw_colored_polygon(can, b.rock_dark.lerp(Color(0.55, 0.32, 0.18), 0.5))
			draw_line(at + Vector2(-3.5, -6.0), at + Vector2(3.5, -6.0), Color(INK, 0.5), 1.0, true)
			_outline(can, 1.8)
		_:
			var rod := PackedVector2Array([at + Vector2(-8.0, 0.0), at + Vector2(2.0, -3.0), at + Vector2(7.0, -10.0)])
			draw_polyline(rod, INK, 3.4, true)
			draw_polyline(rod, b.rock_dark, 1.6, true)


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


# =====================================================================================
# Swamp kinds (level 2)
# =====================================================================================

const BRICK := Color("8a7e80")
const MORTAR := Color("3a2e2a")
const MOSS := Color("5aa83a")
const MOSS_LIGHT := Color("8fd06a")
const SWAMP_WATER := Color(0.33, 0.4, 0.28, 0.85)


## A slab of stone bricks; `broken` cuts the ends diagonally and bites a chunk off the bottom.
func _draw_moss_slab(broken: bool) -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	var bottom: float = half.y + 4.0
	var body := PackedVector2Array()
	if broken:
		body.append_array([Vector2(-half.x + 10, top), Vector2(half.x - 4, top), Vector2(half.x + 2, top + 6), Vector2(half.x - 14, bottom),
				Vector2(size.x * 0.12, bottom), Vector2(size.x * 0.06, bottom - 9), Vector2(-size.x * 0.1, bottom - 9),
				Vector2(-size.x * 0.14, bottom), Vector2(-half.x + 4, bottom), Vector2(-half.x - 2, top + 8)])
	else:
		body.append_array([Vector2(-half.x, top), Vector2(half.x, top), Vector2(half.x + 2, bottom - 4), Vector2(half.x - 4, bottom), Vector2(-half.x + 3, bottom), Vector2(-half.x - 2, top + 6)])
	draw_colored_polygon(body, MORTAR)
	# Bricks in staggered rows, clipped to the slab.
	var rows: int = maxi(int((bottom - top) / 11.0), 2)
	var row_h: float = (bottom - top) / float(rows)
	for r in rows:
		var y0: float = top + float(r) * row_h + 1.5
		var x: float = -half.x - (14.0 if r % 2 == 1 else 0.0)
		var i: int = 0
		while x < half.x:
			var w: float = 22.0 + _rand(r * 31 + i) * 14.0
			var brick := _rect(Vector2(x + 1.5, y0), Vector2(x + w - 1.5, y0 + row_h - 3.0))
			for clipped in Geometry2D.intersect_polygons(brick, body):
				draw_colored_polygon(clipped, BRICK.darkened(_rand(r * 17 + i) * 0.15))
			x += w
			i += 1
	_outline(body, 2.6)
	_draw_grass_top(-half.x + (10.0 if broken else 0.0), half.x - (4.0 if broken else 0.0), top)
	var vines: int = 1 if broken else maxi(int(size.x / 70.0), 2)
	for v in vines:
		var x: float = lerpf(-half.x + 12.0, half.x - 12.0, _rand(v + 900))
		_draw_vine_hang(Vector2(x, bottom - 2.0), 18.0 + _rand(v + 910) * 24.0, v)


## A pile of big mossy boulders with dark gaps between them.
func _draw_moss_stones() -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	var count: int = clampi(int(size.x / 50.0), 3, 5)
	var w: float = size.x / float(count)
	var depth: float = maxf(size.y, 30.0) + 18.0
	# Dark gaps: a shadowed lump behind the stones (never a box).
	draw_colored_polygon(_blob(Vector2(0, top + depth * 0.5 + 2.0), Vector2(half.x - 4.0, depth * 0.5), 16, 690), Color(0.1, 0.09, 0.08))
	for i in count:
		var x0: float = -half.x + w * float(i) + 2.0
		var h: float = depth - 6.0 - _rand(i + 700) * 12.0
		var c := Vector2(x0 + w * 0.5, top + h * 0.5 + 2.0)
		var stone := _blob(c, Vector2(w * 0.55, h * 0.55), 12, i + 720)
		draw_colored_polygon(stone, BRICK.lightened(0.05 * float(i % 2)))
		draw_line(c + Vector2(-w * 0.2, -h * 0.25), c + Vector2(w * 0.1, -h * 0.3), Color(1, 1, 1, 0.25), 2.0, true)
		_outline(stone, 2.4)
		_draw_grass_top(x0 + 4.0, x0 + w - 6.0, top)
	_draw_vine_hang(Vector2(-half.x + w * 1.0, top + depth * 0.6), 20.0, 3)


## Rusted car: on a mound of mud, or tilted and half under the water.
func _draw_car(sunk: bool, b: Biome = null) -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	var tilt: float = -0.1 if sunk else 0.0
	var rust := Color(0.5, 0.32, 0.2)
	var marsh: bool = b == null or b.kind == Biome.Kind.SWAMP or b.kind == Biome.Kind.FLOODED_SUBURB
	if not sunk and marsh:
		draw_colored_polygon(_blob(Vector2(0, top + 46), Vector2(half.x + 16, 30), 14, 41), Color(0.2, 0.17, 0.12))
	elif not sunk:
		_draw_rubble_heap(half.x, top)
	var w: float = size.x * 0.5
	var pts := PackedVector2Array([Vector2(-w, top + 22), Vector2(-w * 0.95, top + 8), Vector2(-w * 0.55, top + 4), Vector2(-w * 0.35, top),
			Vector2(w * 0.4, top), Vector2(w * 0.6, top + 5), Vector2(w * 0.97, top + 9), Vector2(w, top + 22), Vector2(w * 0.9, top + 34), Vector2(-w * 0.92, top + 34)])
	var car := PackedVector2Array()
	for p in pts:
		car.append(p.rotated(tilt))
	draw_colored_polygon(car, rust)
	for window in [[-0.3, 0.05], [0.1, 0.38]]:
		var win := PackedVector2Array([Vector2(w * float(window[0]), top + 3), Vector2(w * float(window[1]), top + 3), Vector2(w * float(window[1]) + 4, top + 12), Vector2(w * float(window[0]) - 3, top + 12)])
		var rot := PackedVector2Array()
		for p in win:
			rot.append(p.rotated(tilt))
		draw_colored_polygon(rot, Color(0.08, 0.1, 0.08))
	for k in 3:
		draw_circle(Vector2(-w * 0.5 + float(k) * w * 0.45, top + 18).rotated(tilt), 4.0, Color(0.68, 0.38, 0.18, 0.7))
	_outline(car, 2.6)
	for sx in [-0.6, 0.6]:
		draw_arc(Vector2(w * float(sx), top + 32).rotated(tilt), 9.0, PI, TAU, 10, INK, 3.0, true)
	if sunk:
		# The murky water it sinks into: a flat lens of water with ripples, no box.
		var lens := PackedVector2Array()
		for i in 17:
			var a: float = PI * float(i) / 16.0
			lens.append(Vector2(cos(a) * (w + 22.0), top + 22.0 + sin(a) * 16.0))
		draw_colored_polygon(lens, SWAMP_WATER)
		draw_line(Vector2(-w - 22, top + 22), Vector2(w + 22, top + 22), Color(0.75, 0.85, 0.6, 0.7), 2.0, true)
		for k in 2:
			var rx: float = w * (0.5 + 0.35 * float(k)) + sin(_time * 1.5 + float(k)) * 4.0
			draw_line(Vector2(-rx, top + 27 + k * 5), Vector2(-rx + 16, top + 27 + k * 5), Color(0.75, 0.85, 0.6, 0.5), 1.6, true)
			draw_line(Vector2(rx - 16, top + 27 + k * 5), Vector2(rx, top + 27 + k * 5), Color(0.75, 0.85, 0.6, 0.5), 1.6, true)
	draw_line(Vector2(-w * 0.35, top).rotated(tilt), Vector2(w * 0.4, top).rotated(tilt), MOSS, 3.0, true)


## A wooden door floating flat on the water.
func _draw_door() -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	var door := _rect(Vector2(-half.x, top), Vector2(half.x, top + maxf(size.y, 12.0)))
	draw_colored_polygon(door, Color(0.45, 0.3, 0.18))
	for k in 4:
		var x: float = lerpf(-half.x, half.x, float(k + 1) / 5.0)
		draw_line(Vector2(x, top + 2), Vector2(x, top + maxf(size.y, 12.0) - 2), Color(0.25, 0.16, 0.1), 1.6, true)
	draw_circle(Vector2(half.x - 10, top + size.y * 0.5), 2.6, Color(0.7, 0.6, 0.3))
	_outline(door, 2.4)
	# Wet moss and water dripping off its edge.
	var bottom: float = top + maxf(size.y, 12.0)
	for k in 3:
		var x: float = lerpf(-half.x + 12, half.x - 20, float(k) / 2.0)
		var fall: float = fposmod(_time * 0.7 + float(k) * 0.37, 1.0)
		draw_circle(Vector2(x, bottom + 2 + fall * 26.0), 2.0, Color(SWAMP_WATER, 0.9 * (1.0 - fall)))
	_draw_vine_hang(Vector2(half.x * 0.3, bottom - 2), 16.0, 5)
	draw_line(Vector2(-half.x + 8, top), Vector2(-half.x + 30, top), MOSS, 3.0, true)


## A row of grass blades sticking up along a walkable top.
func _draw_grass_top(l: float, r: float, top: float) -> void:
	draw_line(Vector2(l, top + 1), Vector2(r, top + 1), MOSS.darkened(0.3), 4.0, true)
	var blades: int = maxi(int((r - l) / 7.0), 2)
	for i in blades:
		var x: float = lerpf(l, r, (float(i) + _rand(i + 800)) / float(blades))
		var h: float = 4.0 + _rand(i + 810) * 7.0
		var lean: float = (_rand(i + 820) - 0.5) * 6.0
		var col: Color = MOSS_LIGHT if i % 3 == 0 else MOSS
		draw_line(Vector2(x, top + 2), Vector2(x + lean, top - h), INK, 2.6, true)
		draw_line(Vector2(x, top + 2), Vector2(x + lean, top - h), col, 1.4, true)


## A vine hanging from `from`, with little leaves, swaying a bit.
func _draw_vine_hang(from: Vector2, length: float, salt: int) -> void:
	var sway: float = sin(_time * 1.3 + float(salt)) * 3.0
	var pts := PackedVector2Array()
	for j in 7:
		var u: float = float(j) / 6.0
		pts.append(from + Vector2(sin(u * 4.0 + float(salt)) * 3.0 + sway * u * u, u * length))
	draw_polyline(pts, INK, 3.2, true)
	draw_polyline(pts, Color(0.25, 0.45, 0.18), 1.6, true)
	for j in range(1, 7, 2):
		var p: Vector2 = pts[j]
		var side: float = 1.0 if j % 4 == 1 else -1.0
		draw_colored_polygon(_blob(p + Vector2(side * 4.0, 0), Vector2(3.5, 2.2), 8, salt * 7 + j), MOSS_LIGHT)


# =====================================================================================
# Decay kinds (levels 1 and 3)
# =====================================================================================

const RUST := Color(0.5, 0.29, 0.17)
const RUST_LIGHT := Color(0.7, 0.4, 0.2)
const BUS_YELLOW := Color(0.82, 0.62, 0.2)
const STEEL_DARK := Color(0.3, 0.3, 0.32)
const GLASS_DARK := Color(0.1, 0.11, 0.12)


## A heap of broken concrete under a car, with a bent rebar or two sticking out.
func _draw_rubble_heap(half_w: float, top: float) -> void:
	draw_colored_polygon(_blob(Vector2(0, top + 44), Vector2(half_w + 14, 26), 14, 43), Color(0.24, 0.22, 0.21))
	for i in 6:
		var x: float = lerpf(-half_w, half_w, (float(i) + 0.5) / 6.0) + (_rand(i + 500) - 0.5) * 12.0
		var chunk := _blob(Vector2(x, top + 40 + _rand(i + 510) * 14.0), Vector2(10 + _rand(i + 520) * 8.0, 7 + _rand(i + 530) * 5.0), 6, i + 540)
		draw_colored_polygon(chunk, Color(0.55, 0.53, 0.5).darkened(_rand(i + 550) * 0.3))
		_outline(chunk, 2.0)
	for k in 2:
		var x: float = (_rand(k + 560) - 0.5) * half_w * 1.4
		draw_polyline(PackedVector2Array([Vector2(x, top + 44), Vector2(x + 6, top + 28), Vector2(x + 14, top + 24)]), RUST, 2.2, true)


## Long rusted school bus: its roof is the walkable top.
func _draw_bus() -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	var depth: float = 38.0
	var body := PackedVector2Array([Vector2(-half.x + 6, top), Vector2(half.x - 14, top), Vector2(half.x - 2, top + 8), Vector2(half.x, top + depth - 6),
			Vector2(half.x - 6, top + depth), Vector2(-half.x + 4, top + depth), Vector2(-half.x, top + depth - 6), Vector2(-half.x, top + 6)])
	draw_colored_polygon(body, BUS_YELLOW)
	# Black stripe, a row of windows (some smashed), rust bleeding down from the seams.
	draw_line(Vector2(-half.x + 2, top + 24), Vector2(half.x - 2, top + 24), INK, 3.0, true)
	var windows: int = maxi(int((size.x - 40.0) / 30.0), 2)
	for i in windows:
		var x0: float = -half.x + 14.0 + float(i) * (size.x - 40.0) / float(windows)
		var win := _rect(Vector2(x0, top + 6), Vector2(x0 + 20, top + 19))
		draw_colored_polygon(win, GLASS_DARK if _rand(i + 600) > 0.3 else Color(0.32, 0.36, 0.38))
		if _rand(i + 610) > 0.65:
			draw_line(Vector2(x0 + 3, top + 7), Vector2(x0 + 14, top + 17), Color(0.6, 0.64, 0.66, 0.8), 1.2, true)
		_outline(win, 1.6)
	for i in 5:
		var x: float = -half.x + _rand(i + 620) * size.x
		draw_colored_polygon(_blob(Vector2(x, top + 28 + _rand(i + 630) * 6.0), Vector2(8 + _rand(i + 640) * 10.0, 4.0), 8, i + 650), Color(RUST, 0.85))
		draw_line(Vector2(x, top + 26), Vector2(x + 1, top + 36), Color(RUST, 0.7), 1.6, true)
	# Front: a cracked windscreen and a dead headlight.
	draw_colored_polygon(PackedVector2Array([Vector2(half.x - 12, top + 4), Vector2(half.x - 4, top + 10), Vector2(half.x - 4, top + 20), Vector2(half.x - 12, top + 20)]), GLASS_DARK)
	draw_circle(Vector2(half.x - 4, top + 30), 3.0, Color(0.85, 0.8, 0.6))
	_outline(body, 2.8)
	for wx in [-half.x + 34.0, half.x - 40.0]:
		draw_colored_polygon(_blob(Vector2(wx, top + depth + 2), Vector2(11, 7), 10, int(wx)), Color(0.12, 0.12, 0.13))
		draw_arc(Vector2(wx, top + depth), 11.0, PI, TAU, 12, INK, 3.0, true)
	draw_line(Vector2(-half.x + 8, top + 1), Vector2(half.x - 16, top + 1), BUS_YELLOW.lightened(0.25), 2.0, true)


## Rusted cargo container: corrugated walls, door bars at one end, corner castings.
func _draw_container() -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	# Not much deeper than its collision: the player walks under some of them.
	var depth: float = maxf(size.y, 30.0)
	var base: Color = Color(0.6, 0.24, 0.17) if _rand(700) > 0.5 else Color(0.2, 0.4, 0.43)
	var box := _rect(Vector2(-half.x, top), Vector2(half.x, top + depth))
	draw_colored_polygon(box, base)
	var ribs: int = maxi(int(size.x / 9.0), 4)
	for i in ribs:
		var x: float = lerpf(-half.x + 6, half.x - 6, float(i) / float(ribs - 1))
		draw_line(Vector2(x, top + 4), Vector2(x, top + depth - 4), base.darkened(0.3), 2.0, true)
		draw_line(Vector2(x + 2, top + 4), Vector2(x + 2, top + depth - 4), base.lightened(0.12), 1.0, true)
	for i in 4:
		var x: float = -half.x + _rand(i + 710) * size.x
		var streak := PackedVector2Array([Vector2(x - 4, top + 3), Vector2(x + 5, top + 3), Vector2(x + 2, top + 10 + _rand(i + 720) * (depth - 14)), Vector2(x - 2, top + 8)])
		draw_colored_polygon(streak, Color(RUST_LIGHT, 0.75))
	# Door bars on the right end.
	for k in 2:
		var x: float = half.x - 8.0 - float(k) * 9.0
		draw_line(Vector2(x, top + 3), Vector2(x, top + depth - 3), STEEL_DARK, 3.0, true)
		draw_rect(Rect2(x - 2.5, top + depth * 0.5 - 3, 5, 6), STEEL_DARK)
	for corner in [Vector2(-half.x, top), Vector2(half.x - 8, top), Vector2(-half.x, top + depth - 7), Vector2(half.x - 8, top + depth - 7)]:
		draw_rect(Rect2(corner, Vector2(8, 7)), base.darkened(0.45))
	draw_line(Vector2(-half.x, top + 1.5), Vector2(half.x, top + 1.5), base.lightened(0.25), 2.0, true)
	_outline(box, 2.8)


## Steel lattice girder between x0 and x1: two chords and a zig-zag web, bolted.
func _draw_girder(x0: float, x1: float, top: float, depth: float) -> void:
	var steel := Color(0.46, 0.42, 0.4)
	var bottom: float = top + depth
	var top_chord := _rect(Vector2(x0, top), Vector2(x1, top + 6))
	var bottom_chord := _rect(Vector2(x0, bottom - 5), Vector2(x1, bottom))
	var bays: int = maxi(int((x1 - x0) / 22.0), 2)
	for i in bays:
		var a: float = lerpf(x0 + 3, x1 - 3, float(i) / float(bays))
		var b2: float = lerpf(x0 + 3, x1 - 3, float(i + 1) / float(bays))
		var from := Vector2(a, top + 5) if i % 2 == 0 else Vector2(a, bottom - 4)
		var to := Vector2(b2, bottom - 4) if i % 2 == 0 else Vector2(b2, top + 5)
		draw_line(from, to, INK, 5.0, true)
		draw_line(from, to, steel.darkened(0.1), 3.0, true)
	for chord in [top_chord, bottom_chord]:
		draw_colored_polygon(chord, steel)
		_outline(chord, 2.2)
	for i in bays + 1:
		var x: float = lerpf(x0 + 3, x1 - 3, float(i) / float(bays))
		draw_circle(Vector2(x, top + 3), 1.4, STEEL_DARK)
		draw_circle(Vector2(x, bottom - 2.5), 1.4, STEEL_DARK)
	for i in 3:
		var x: float = lerpf(x0, x1, _rand(i + 760))
		draw_colored_polygon(_blob(Vector2(x, top + 3), Vector2(6, 2.4), 7, i + 770), Color(RUST_LIGHT, 0.7))
	draw_line(Vector2(x0 + 2, top + 1), Vector2(x1 - 2, top + 1), steel.lightened(0.3), 1.5, true)


## A short girder plate hanging from a crane hook on a long chain that sways a little.
func _draw_crane_hook() -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	_draw_girder(-half.x, half.x, top, maxf(size.y, 18.0))
	var sway: float = sin(_time * 0.9 + _rand(800) * TAU) * 6.0
	var hook := Vector2(sway * 0.5, top - 46.0)
	# Two slings from the plate's ends up to the hook.
	for side in [-1.0, 1.0]:
		var end := Vector2(side * (half.x - 10.0), top + 2.0)
		draw_line(end, hook + Vector2(side * 3.0, 6.0), INK, 3.6, true)
		draw_line(end, hook + Vector2(side * 3.0, 6.0), Color(0.55, 0.52, 0.48), 1.8, true)
	# The hook: a curved steel claw under a pulley block.
	draw_arc(hook + Vector2(0, 2), 7.0, 0.0, PI * 1.3, 12, INK, 5.5, true)
	draw_arc(hook + Vector2(0, 2), 7.0, 0.0, PI * 1.3, 12, Color(0.85, 0.65, 0.2), 3.0, true)
	var block := _rect(hook + Vector2(-9, -26), hook + Vector2(9, -8))
	draw_colored_polygon(block, Color(0.85, 0.62, 0.18))
	draw_line(hook + Vector2(-9, -17), hook + Vector2(9, -17), INK, 1.6, true)
	_outline(block, 2.2)
	# The chain up to the top of the world, bending with the sway.
	var chain_top: float = -global_position.y - 40.0
	var from := hook + Vector2(0, -26)
	var links: int = maxi(int((from.y - chain_top) / 9.0), 2)
	for i in links:
		var u: float = float(i) / float(links)
		var p := Vector2(from.x * (1.0 - u) + sin(u * PI) * sway * 0.4, lerpf(from.y, chain_top, u))
		var vertical: bool = i % 2 == 0
		var link := Rect2(p - (Vector2(3, 5) if vertical else Vector2(1.5, 5)), Vector2(6, 10) if vertical else Vector2(3, 10))
		draw_rect(link, INK, false, 2.2)
		draw_rect(link, Color(0.5, 0.48, 0.46), false, 1.0)

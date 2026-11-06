@tool
class_name BackdropFx
extends Node2D
## Animated pieces of a biome backdrop that a painted layer cannot hold:
## SMOKE  thick columns of smoke rising behind the ruins (child of a far Parallax2D),
## EYES   pairs of eyes blinking in the dark between the silhouettes (child of a mid Parallax2D),
## VIGNETTE dark screen edges, drawn in world space over the camera view.
## Visual only. Shapes repeat over BackdropLayer.WIDTH like the painted layers.

## MARSH: the live bits of the level 2 marsh among the middle trees (hanging moss swaying, house
## windows flickering, drops falling from the moss roofs). CREATURE_EYES: the acid-green eyes of
## the crouching moss creatures in the foreground, blinking.
enum Mode { SMOKE, EYES, VIGNETTE, MARSH, CREATURE_EYES }

const MOSS_ROOF := Color("7cc23a")
const WINDOW := Color("ffb84a")

const INK := Color(0.106, 0.098, 0.122)
const PUFFS: int = 16

@export var biome: Biome
@export var mode: Mode = Mode.SMOKE

var _time: float = 0.0


## Where the smoke columns start inside a backdrop tile (x, y of the source). The industrial
## biome stands its chimneys on these same points.
static func smoke_sources(b: Biome) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = 4 if b.kind == Biome.Kind.INDUSTRIAL else 3
	for i in n:
		var x: float = (float(i) + 0.25 + _hash(b.scenery_seed * 13 + i) * 0.5) / float(n) * BackdropLayer.WIDTH
		var y: float = 300.0 + _hash(b.scenery_seed * 7 + i * 5) * 60.0
		if b.kind != Biome.Kind.INDUSTRIAL:
			y += 110.0
		pts.append(Vector2(x, y))
	return pts


## Dark middle trees of the marsh: [x, height, lean] inside a tile.
static func marsh_trees(b: Biome) -> Array:
	var dense: bool = b.kind == Biome.Kind.SWAMP
	var n: int = 14 if dense else 11
	var out: Array = []
	for i in n:
		var x: float = (float(i) + 0.15 + _hash(b.scenery_seed * 5 + i) * 0.7) / float(n) * BackdropLayer.WIDTH
		out.append([x, 380.0 + _hash(b.scenery_seed * 9 + i) * 160.0, (_hash(b.scenery_seed + i * 13) - 0.5) * 0.12])
	return out


## Sunken houses hidden among the trees: [x, ground y, width, height, tilt].
static func marsh_houses(b: Biome) -> Array:
	var dense: bool = b.kind == Biome.Kind.SWAMP
	var n: int = 1 if dense else 3
	var out: Array = []
	for i in n:
		var x: float = (float(i) + 0.3 + _hash(b.scenery_seed * 3 + i + 40) * 0.4) / float(n) * BackdropLayer.WIDTH
		out.append([x, 598.0 + _hash(i + 50) * 14.0, 110.0 + _hash(i + 60) * 40.0, 80.0 + _hash(i + 70) * 30.0, (_hash(i + 80) - 0.5) * 0.18])
	return out


## Window centers of a house (house-local, before tilt).
static func house_windows(house: Array) -> Array:
	var w: float = house[2]
	var h: float = house[3]
	return [Vector2(-w * 0.24, -h * 0.55), Vector2(w * 0.2, -h * 0.5)]


## Crouching moss creatures in the foreground: [x, size].
static func marsh_creatures(b: Biome) -> Array:
	var out: Array = []
	for i in 3:
		out.append([(float(i) + 0.2 + _hash(b.scenery_seed + i * 21) * 0.5) / 3.0 * BackdropLayer.WIDTH, 50.0 + _hash(i + 90) * 30.0])
	return out


static func _hash(i: int) -> float:
	var v: float = sin(float(i) * 78.233 + 12.9898) * 43758.5453
	return v - floorf(v)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if biome == null:
		return
	match mode:
		Mode.SMOKE:
			_smoke()
		Mode.EYES:
			_eyes()
		Mode.VIGNETTE:
			_vignette()
		Mode.MARSH:
			_marsh()
		Mode.CREATURE_EYES:
			_creature_eyes()


func _smoke() -> void:
	var dark: Color = biome.smoke_color.darkened(biome.backdrop_dim * 0.4)
	var light: Color = dark.lerp(biome.haze, 0.45)
	var k: int = 0
	for src in smoke_sources(biome):
		for ox in [src.x - BackdropLayer.WIDTH, src.x, src.x + BackdropLayer.WIDTH]:
			# Oldest puffs (highest, widest) first, so the fresh ones at the source sit on top.
			for i in range(PUFFS - 1, -1, -1):
				var t: float = fposmod(_time * (0.045 + 0.01 * k) + float(i) / float(PUFFS), 1.0)
				var rise: float = t * 420.0
				var lean: float = t * t * 160.0 + sin(_time * 0.6 + i * 1.3 + k) * 10.0 * t
				var pos := Vector2(float(ox) + lean, src.y - rise)
				var r: float = lerpf(16.0, 74.0, sqrt(t))
				var alpha: float = clampf((1.0 - t) * 1.5, 0.0, 0.9) * clampf(t * 12.0, 0.0, 1.0)
				var col: Color = dark.lerp(light, t)
				draw_circle(pos, r, Color(col, alpha))
				if t < 0.55:
					draw_arc(pos, r, PI * 0.15, PI * 0.85, 10, Color(INK, 0.25 * alpha), 2.0, true)
		k += 1


func _eyes() -> void:
	var n: int = 9
	for i in n:
		var x: float = (float(i) + _hash(biome.scenery_seed * 3 + i) * 0.8) / float(n) * BackdropLayer.WIDTH
		var y: float = 470.0 + _hash(biome.scenery_seed + i * 11) * 105.0
		var sz: float = 0.8 + _hash(i * 17 + 2) * 0.6
		# Each pair fades in and out slowly, and blinks now and then while it is there.
		var presence: float = clampf(sin(_time * (0.18 + 0.05 * _hash(i + 40)) + i * 2.3) * 1.8, 0.0, 1.0)
		if presence <= 0.0:
			continue
		var cycle: float = fposmod(_time * (0.3 + 0.12 * _hash(i + 70)) + _hash(i + 90), 1.0)
		var open: float = 1.0
		if cycle > 0.92:
			open = absf(cycle - 0.96) / 0.04
		for ox in [x - BackdropLayer.WIDTH, x, x + BackdropLayer.WIDTH]:
			_eye_pair(Vector2(float(ox), y), sz, open, presence)


func _eye_pair(c: Vector2, sz: float, open: float, presence: float) -> void:
	var col: Color = biome.eye_color
	draw_circle(c, 16.0 * sz, Color(col, 0.07 * presence))
	for side in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(side * 6.5 * sz, 0.0)
		var lid := PackedVector2Array()
		for i in 12:
			var a: float = TAU * float(i) / 12.0
			# Slanted, a little angry: the inner corner sits higher.
			var slant: float = -side * cos(a) * 0.9 * sz
			lid.append(e + Vector2(cos(a) * 3.4 * sz, sin(a) * 2.2 * sz * maxf(open, 0.06) + slant))
		draw_colored_polygon(lid, Color(col, 0.95 * presence))
		if open > 0.35:
			draw_line(e + Vector2(0, -1.6 * sz * open), e + Vector2(0, 1.6 * sz * open), Color(INK, presence), 1.3, true)


func _marsh() -> void:
	var moss: Color = biome.near_color.lerp(Color(0.45, 0.6, 0.3), 0.35)
	for tree in marsh_trees(biome):
		var base_x: float = tree[0]
		var top: float = 600.0 - float(tree[1])
		for k in 4:
			var anchor := Vector2(base_x + (float(k) - 1.5) * 26.0 + float(tree[2]) * 200.0, top + 60.0 + float(k % 2) * 40.0)
			var length: float = 40.0 + _hash(int(base_x) + k) * 50.0
			for ox in [-BackdropLayer.WIDTH, 0.0, BackdropLayer.WIDTH]:
				var a: Vector2 = anchor + Vector2(float(ox), 0)
				var pts := PackedVector2Array()
				for j in 6:
					var u: float = float(j) / 5.0
					pts.append(a + Vector2(sin(_time * 1.1 + float(k) + base_x) * 5.0 * u * u, u * length))
				draw_polyline(pts, moss, 3.0, true)
				# A drop falls from the tip now and then.
				var fall: float = fposmod(_time * 0.35 + _hash(int(base_x) + k * 7), 1.0)
				if fall < 0.5:
					draw_circle(pts[5] + Vector2(0, fall * 2.0 * 120.0), 1.6, Color(0.75, 0.9, 0.6, 0.8 * (1.0 - fall * 2.0)))
	for house in marsh_houses(biome):
		var origin := Vector2(float(house[0]), float(house[1]))
		for i in house_windows(house).size():
			var win: Vector2 = house_windows(house)[i]
			var flicker: float = 0.75 + 0.25 * sin(_time * (7.0 + float(i) * 3.0)) * sin(_time * 3.1 + float(i))
			if i == 1 and fposmod(_time, 5.0) > 4.6:
				flicker = 0.2
			for ox in [-BackdropLayer.WIDTH, 0.0, BackdropLayer.WIDTH]:
				var p: Vector2 = origin + Vector2(float(ox), 0) + win.rotated(float(house[4]))
				draw_circle(p, 22.0, Color(WINDOW, 0.12 * flicker))
				draw_circle(p, 11.0, Color(WINDOW, 0.18 * flicker))
		# Drips off the mossy roof edge.
		for k in 3:
			var fall: float = fposmod(_time * 0.5 + float(k) * 0.33 + float(house[0]) * 0.001, 1.0)
			for ox in [-BackdropLayer.WIDTH, 0.0, BackdropLayer.WIDTH]:
				var edge: Vector2 = origin + Vector2(float(ox), 0) + Vector2((float(k) - 1.0) * float(house[2]) * 0.4, -float(house[3]) + 6.0).rotated(float(house[4]))
				draw_circle(edge + Vector2(0, fall * 60.0), 1.8, Color(MOSS_ROOF, 0.85 * (1.0 - fall)))


func _creature_eyes() -> void:
	for i in marsh_creatures(biome).size():
		var cr: Array = marsh_creatures(biome)[i]
		var period: float = 3.0 + _hash(i + 300) * 2.0
		if fposmod(_time + _hash(i + 310) * period, period) > period - 0.18:
			continue
		var s: float = cr[1]
		for ox in [-BackdropLayer.WIDTH, 0.0, BackdropLayer.WIDTH]:
			var c := Vector2(float(cr[0]) + float(ox) + s * 0.35, 760.0 - s * 1.05)
			for side in [-1.0, 1.0]:
				var e: Vector2 = c + Vector2(float(side) * s * 0.14, 0)
				draw_circle(e, s * 0.12, Color(0.75, 1.0, 0.2, 0.15))
				draw_circle(e, s * 0.05, Color(0.8, 1.0, 0.25))


## Dark frame over the camera view: four soft bands that meet in darker corners.
func _vignette() -> void:
	var view: Rect2 = _view()
	var a: float = biome.vignette_strength
	# A wide soft band, then a narrow stronger one right at the border, like an old burnt photo.
	_frame(view, view.size * Vector2(0.2, 0.26), a * 0.75)
	_frame(view, view.size * Vector2(0.06, 0.08), a * 0.5)


func _frame(view: Rect2, inset: Vector2, alpha: float) -> void:
	var o0: Vector2 = view.position
	var o1: Vector2 = view.end
	var i0: Vector2 = view.position + inset
	var i1: Vector2 = view.end - inset
	var tl := Vector2(o0.x, o0.y)
	var tr := Vector2(o1.x, o0.y)
	var br := Vector2(o1.x, o1.y)
	var bl := Vector2(o0.x, o1.y)
	var itl := Vector2(i0.x, i0.y)
	var itr := Vector2(i1.x, i0.y)
	var ibr := Vector2(i1.x, i1.y)
	var ibl := Vector2(i0.x, i1.y)
	var colors := PackedColorArray([Color(INK, alpha), Color(INK, alpha), Color(INK, 0.0), Color(INK, 0.0)])
	draw_polygon(PackedVector2Array([tl, tr, itr, itl]), colors)
	draw_polygon(PackedVector2Array([tr, br, ibr, itr]), colors)
	draw_polygon(PackedVector2Array([br, bl, ibl, ibr]), colors)
	draw_polygon(PackedVector2Array([bl, tl, itl, ibl]), colors)


## The world rectangle the active camera shows (or the viewport when there is none), in local space.
func _view() -> Rect2:
	var vp_size: Vector2 = get_viewport_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null or Engine.is_editor_hint():
		return Rect2(Vector2.ZERO, vp_size)
	var view_size: Vector2 = vp_size / cam.zoom
	var world := Rect2(cam.get_screen_center_position() - view_size * 0.5, view_size)
	var inv: Transform2D = get_global_transform().affine_inverse()
	return Rect2(inv * world.position, view_size)

class_name EndingScene
extends Node2D
## The picture of the two endings (Phase 15i), drawn by code with the existing duck rig and no art files. It knows nothing of the story: the
## cinematic tells it, every frame, where the camera is, which pose the duck is in and how far into it, how far the veins have crept, how
## much light the city has, and so on (see EndingBeat). Five depth layers move with parallax under a camera (focus + zoom); the duck is ONE
## composed drawing (Phase 15o): a single DuckRig whose pose parameters (head bow, wing, corruption stage) draw the veins, the clouded eye, the
## darker feathers and the wing INSIDE its own parts, with one soft halo behind it. Nothing is laid over the duck. BOTH endings stand on a cliff above the liberated city (Phase 15i-bis):
## "kept" («Estrellas que suben»: the city's lights come on while the duck is consumed by corruption) and "released" («El acantilado»: dusk).
## Nothing of the act is ever drawn: the endings cut away before it.
## In reduced mode the scene has no motion of its own (time stays 0): the cinematic draws one still per beat. Drawing only: no gameplay logic.

const SIZE := Vector2(1280.0, 720.0)
const CENTER := Vector2(640.0, 360.0)
const RIG_SCALE: float = 3.0
const INK := Color(0.106, 0.098, 0.122)
const HERO_KIMONO := Color(0.6, 0.21, 0.2)
## The duck's neck in actor space (feet at the origin, y up is negative): the head bows about it.
const NECK := Vector2(3.0, -28.0)
const CLIFF_Y: float = 520.0
const CLIFF_EDGE_X: float = 800.0
## Parallax depth of each layer: 0 is the sky (does not move), 1 the ground the duck stands on, above 1 the foreground.
const DEPTHS: Array[float] = [0.0, 0.25, 0.6, 1.0, 1.3]
## Where the hero's eye is in actor space.
const EYE := Vector2(10.0, -41.0)

# Fed by the cinematic every frame.
var style: String = "kept"
var reduced: bool = false
var corruption_scale: float = 1.0
var time: float = 0.0
var focus: Vector2 = CENTER
var zoom: float = 1.0
var pose: StringName = &"stand"
var pose_p: float = 0.0
var duck_visible: bool = true
var duck_from: Vector2 = Vector2(640.0, 600.0)
var duck_to: Vector2 = Vector2(640.0, 600.0)
var silhouette: bool = false
## The cliff ending: the duck's sword and hat are left at the edge (Phase 15r).
var items_left: bool = false
var breath: float = 0.0
var veins: float = 0.0
var drain: float = 0.0
var light: float = 1.0
var wind: float = 0.0
## The frame watchdog's light mode: the big layers stay as drawn (no twinkle, no halo discs).
var light_mode: bool = false
## How often the big background layers are redrawn (the camera moves them without a redraw).
var layer_redraw_hz: float = 12.0
## How many times the layers were redrawn (the tests read it).
var layer_redraws: int = 0
var _layer_clock: float = 0.0
var _layer_key: String = ""

var feet: Vector2 = Vector2(640.0, 600.0)
var actor: Node2D
var layers: Array[Node2D] = []

var _holders: Array[Node2D] = []
var _sil_k: float = 0.0
## The single drawing of the duck (the pose, the corruption and the wing are its parameters).
var figure: DuckRig
var _aura: _Overlay


class _Overlay extends Node2D:
	var kind: int = 0
	var scene: EndingScene = null

	func _draw() -> void:
		scene._draw_overlay(self, kind)


class _Layer extends Node2D:
	var kind: int = 0
	var scene: EndingScene = null

	func _draw() -> void:
		scene._draw_layer(self, kind)


func _ready() -> void:
	for kind in DEPTHS.size():
		var holder := Node2D.new()
		add_child(holder)
		_holders.append(holder)
		var layer := _Layer.new()
		layer.kind = kind
		layer.scene = self
		holder.add_child(layer)
		layers.append(layer)
		if kind == 3:
			_build_actor(holder)
	refresh()


func _build_actor(holder: Node2D) -> void:
	actor = Node2D.new()
	actor.name = "Duck"
	holder.add_child(actor)
	actor.scale = Vector2.ONE * RIG_SCALE
	# One soft halo BEHIND the figure (never over the face), then the figure itself.
	_aura = _make_overlay(0)
	actor.add_child(_aura)
	figure = DuckRig.new()
	figure.look = DuckRig.Look.HERO
	figure.position = Vector2(0.0, -26.0)
	figure.corruption_stage = 3
	actor.add_child(figure)


func _make_overlay(kind: int) -> _Overlay:
	var overlay := _Overlay.new()
	overlay.kind = kind
	overlay.scene = self
	return overlay


func set_light_mode(is_reduced: bool) -> void:
	reduced = is_reduced


func is_duck_drawn() -> bool:
	return actor != null and actor.visible


# ---------------------------------------------------------------------------------------------
# Camera and duck, once per frame
# ---------------------------------------------------------------------------------------------

func refresh() -> void:
	if actor == null:
		return
	_place_layers()
	_pose_duck()
	var key: String = "%s|%d|%s|%s|%d|%s" % [style, int(light * 30.0), str(reduced), str(light_mode), int(is_instance_valid(actor) and duck_visible), str(items_left)]
	var now: float = Time.get_ticks_msec() / 1000.0
	var due: bool = not reduced and not light_mode and now - _layer_clock >= 1.0 / maxf(layer_redraw_hz, 1.0)
	if key != _layer_key or due:
		_layer_key = key
		_layer_clock = now
		layer_redraws += 1
		for layer in layers:
			layer.queue_redraw()
	figure.corruption_reduced = reduced
	figure.corruption_stage = 3
	figure.corruption_growth = clampf(veins * corruption_scale, 0.0, 1.0)
	figure.corruption_strength = 1.0 if _sil_k < 0.5 else 0.0
	_aura.queue_redraw()


## Every layer moves with its own depth: a deeper layer follows the camera less (parallax) and zooms less.
func _place_layers() -> void:
	for i in _holders.size():
		var depth: float = DEPTHS[i]
		var s: float = 1.0 + (zoom - 1.0) * depth
		var eff: Vector2 = CENTER + (focus - CENTER) * depth
		_holders[i].scale = Vector2.ONE * s
		_holders[i].position = CENTER - eff * s


func _smooth(x: float, a: float, b: float) -> float:
	return smoothstep(a, b, x)


func _pose_duck() -> void:
	var p: float = clampf(pose_p, 0.0, 1.0)
	var t: float = 0.0 if reduced else time
	var b: float = breath
	var hz: float = 0.5 + 0.9 * b
	var heave: float = 0.0 if reduced else sin(t * TAU * hz)
	var shake := Vector2.ZERO if reduced else Vector2(sin(t * 43.0), cos(t * 37.0)) * 0.9 * b
	var pos: Vector2 = duck_from.lerp(duck_to, smoothstep(0.0, 1.0, p))
	var rot: float = 0.0
	var squash: float = 1.0
	var bow: float = 0.0
	var walking: float = 0.0
	var lift: float = 0.0
	var arm: float = NAN
	var head_shake: float = 0.0
	match pose:
		&"labored", &"stand":
			squash = 1.0 + 0.05 * b * heave
			rot = (0.0 if reduced else 0.06 * b * sin(t * 2.1)) + _cough(t, b)
			bow = 0.12 * b
		&"stagger":
			var sway: float = 0.0 if reduced else sin(p * PI * 3.0) * 0.2 * (1.0 - p * 0.4)
			var down: float = _smooth(p, 0.5, 1.0)
			rot = sway + 0.22 * down
			squash = lerpf(1.0, 0.72, down) + 0.03 * b * heave
			bow = 0.25 + 0.2 * down
			pos.x += sway * 70.0
		&"kneel":
			var rise: float = sin(clampf(p * 1.7, 0.0, 1.0) * PI) * 0.6
			var fail: float = _smooth(p, 0.55, 1.0)
			squash = 0.72 + 0.22 * rise - 0.07 * fail + 0.03 * b * heave
			rot = 0.2 + 0.12 * fail + (0.0 if reduced else sin(t * 19.0) * 0.012)
			bow = 0.35 + 0.2 * fail
		&"reach":
			squash = 0.66 + 0.03 * b * heave
			rot = 0.3 - 0.1 * _smooth(p, 0.0, 0.6)
			bow = 0.1
			arm = lerpf(1.2, -1.15, _smooth(p, 0.0, 0.5)) + (0.0 if reduced else sin(t * 17.0) * 0.06 + sin(t * 9.0) * 0.04)
		&"resist":
			# The corruption takes the hand: the duck kneels, its wing goes toward its hip and pulls back, it shakes its head.
			squash = 0.68 + 0.03 * b * heave
			rot = 0.26 + (0.0 if reduced else sin(t * 23.0) * 0.015)
			bow = 0.3
			var swing: float = 0.5 + 0.5 * sin(p * TAU * 1.25 - PI * 0.5)
			var tremble: float = 0.0 if reduced else sin(t * 26.0) * 0.1
			arm = lerpf(-1.1, 0.5, swing) + tremble
			head_shake = 0.0 if reduced else sin(t * 13.0) * 0.2
		&"kneel_edge":
			squash = 0.66
			rot = 0.3
			bow = lerpf(0.25, 0.7, _smooth(p, 0.0, 0.9))
		&"walk":
			walking = 0.0 if reduced else 1.0
			bow = 0.1
		&"head_down":
			bow = 0.6 * _smooth(p, 0.1, 0.8)
			rot = 0.04 * _smooth(p, 0.1, 0.8)
	feet = pos
	actor.visible = duck_visible
	actor.position = pos + shake - Vector2(0.0, lift)
	actor.rotation = rot
	actor.scale = Vector2(RIG_SCALE, RIG_SCALE * squash)
	figure.head_bow = bow + head_shake
	figure.wing_angle = arm
	figure.pose_name = pose
	var natural: Color = Color.WHITE.lerp(Color(0.5, 0.47, 0.58, 1.0), drain)
	var tone: Color = natural.lerp(Color(0.04, 0.04, 0.07, 1.0), _sil_k)
	figure.modulate = tone
	var painful: bool = pose in [&"kneel", &"reach", &"resist", &"kneel_edge"] or (pose == &"stagger" and p > 0.5)
	figure.hurt = painful and _sil_k < 0.5
	var speed: float = 90.0 * walking
	figure.ground_speed = speed


## The silhouette darkens the duck gradually as the light goes (at once in reduced mode).
func _process(delta: float) -> void:
	var target: float = 1.0 if silhouette else 0.0
	_sil_k = target if reduced else move_toward(_sil_k, target, delta * 0.7)


func _cough(t: float, b: float) -> float:
	var phase: float = fposmod(t, 3.4)
	if phase > 0.35 or b < 0.3:
		return 0.0
	return 0.14 * sin(phase / 0.35 * PI) * b


# ---------------------------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------------------------

func _hash(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


func _draw_layer(c: Node2D, kind: int) -> void:
	match kind:
		0:
			_cliff_sky(c)
		1:
			_cliff_far(c)
		2:
			_cliff_city(c)
		3:
			_cliff_rock(c)
		4:
			_cliff_front(c)


func _bands(c: Node2D, top: Color, bottom: Color, y0: float = -1200.0, y1: float = 1500.0, x0: float = -1800.0, x1: float = 3000.0) -> void:
	var steps: int = 30
	var h: float = (y1 - y0) / float(steps)
	for i in steps:
		var k: float = float(i) / float(steps - 1)
		c.draw_rect(Rect2(x0, y0 + h * float(i), x1 - x0, h + 1.0), top.lerp(bottom, k * k * 0.6 + k * 0.4))


func _rising_stars(c: Node2D, count: int, x0: float, x1: float, base_y: float, alpha: float, color: Color, seed_offset: int) -> void:
	for i in count:
		var x: float = x0 + _hash(i + seed_offset) * (x1 - x0)
		var travel: float = _hash(i + seed_offset + 40) * base_y
		var y: float = base_y - fposmod(travel + 34.0 * time * (0.5 + _hash(i + seed_offset + 80)), base_y)
		var r: float = 2.0 + _hash(i + seed_offset + 120) * 5.0
		var twinkle: float = 1.0 if reduced else 0.55 + 0.45 * sin(time * 2.2 + float(i))
		if not reduced:
			c.draw_circle(Vector2(x, y), r * 2.8, Color(color, 0.1 * twinkle * alpha))
		c.draw_circle(Vector2(x, y), r, Color(color, (0.45 + 0.4 * twinkle) * alpha))


func _draw_overlay(c: Node2D, kind: int) -> void:
	if kind != 0:
		return
	# A dark halo behind the duck that grows with the corruption: ONE backdrop under the figure, never over the face.
	var k: float = veins * corruption_scale
	if k > 0.02 and _sil_k < 0.5:
		for i in 5:
			c.draw_circle(Vector2(0.0, -22.0), 24.0 + float(i) * 6.0, Color(0.35, 0.08, 0.5, 0.05 * k))


# ---------------------------------------------------------------------------------------------
# The cliff (both endings)
# ---------------------------------------------------------------------------------------------

func _cliff_sky(c: Node2D) -> void:
	if style == "kept":
		# The night turns warm as the city's light returns.
		var bottom: Color = Color("2b2236").lerp(Color("f2b36a"), light)
		_bands(c, Color("0d0c20").lerp(Color("2d3f7a"), light), bottom, -1200.0, 700.0)
		c.draw_rect(Rect2(-1800.0, 700.0, 4800.0, 900.0), bottom)
		c.draw_circle(Vector2(1010.0, 560.0), 400.0, Color(1.0, 0.8, 0.5, 0.1 * light))
		c.draw_circle(Vector2(1010.0, 560.0), 220.0, Color(1.0, 0.85, 0.55, 0.12 * light))
		_rising_stars(c, 60, 20.0, 1260.0, 700.0, 0.2 + 0.8 * light, Color(1.0, 0.9, 0.55), 900)
	else:
		_bands(c, Color("171436"), Color("c9705e"), -1200.0, 700.0)
		c.draw_rect(Rect2(-1800.0, 700.0, 4800.0, 900.0), Color("c9705e"))
		c.draw_circle(Vector2(1010.0, 520.0), 360.0, Color(1.0, 0.55, 0.4, 0.12))
		c.draw_circle(Vector2(1010.0, 520.0), 190.0, Color(1.0, 0.65, 0.45, 0.14))
	for i in 70:
		var sx: float = 20.0 + _hash(i + 300) * 1240.0
		var sy: float = 10.0 + _hash(i + 340) * 380.0
		var twinkle: float = 1.0 if reduced else 0.6 + 0.4 * sin(time * 1.6 + float(i))
		c.draw_circle(Vector2(sx, sy), 1.4 + _hash(i + 380) * 1.8, Color(0.95, 0.95, 1.0, 0.7 * twinkle))
	if style != "kept":
		_rising_stars(c, 36, 760.0, 1270.0, 760.0, 0.85, Color(1.0, 0.9, 0.6), 1200)


func _cliff_far(c: Node2D) -> void:
	# Distant ridges in haze.
	for layer in 2:
		var pts := PackedVector2Array([Vector2(-1800.0, 900.0)])
		for i in 30:
			var x: float = -1800.0 + float(i) * 170.0
			pts.append(Vector2(x, 520.0 + float(layer) * 40.0 - _hash(i + layer * 50) * 110.0))
		pts.append(Vector2(3000.0, 900.0))
		c.draw_colored_polygon(pts, Color(0.28 - 0.06 * float(layer), 0.2, 0.34, 0.55 + 0.2 * float(layer)))


func _cliff_city(c: Node2D) -> void:
	# The city far below: small buildings whose windows come on with the light, a warm haze over them.
	var x: float = 940.0
	for i in 16:
		var width: float = 26.0 + _hash(i + 760) * 28.0
		var height: float = 40.0 + _hash(i + 780) * 80.0
		var rect := Rect2(x, 700.0 - height, width, height)
		c.draw_rect(rect, Color(0.13, 0.12, 0.2))
		var wy: float = rect.position.y + 6.0
		while wy < 696.0:
			var wx: float = rect.position.x + 5.0
			while wx < rect.end.x - 6.0:
				var lit: bool = _hash(int(wx) * 7 + int(wy)) < light * 1.05
				c.draw_rect(Rect2(wx, wy, 4.0, 6.0), Color(1.0, 0.9, 0.55, 0.95) if lit else Color(0.06, 0.06, 0.1, 0.9))
				wx += 9.0
			wy += 13.0
		x += width + 4.0
	c.draw_rect(Rect2(900.0, 660.0, 700.0, 40.0), Color(1.0, 0.8, 0.5, 0.2 * light))
	c.draw_rect(Rect2(-600.0, 700.0, 2700.0, 900.0), Color(0.07, 0.06, 0.11))


func _cliff_rock(c: Node2D) -> void:
	# Rock in layers, darker toward the bottom, with the top lip and a thin shadow of strata.
	var rock := PackedVector2Array([Vector2(-1800.0, 1600.0), Vector2(-1800.0, CLIFF_Y), Vector2(300.0, CLIFF_Y - 8.0), Vector2(640.0, CLIFF_Y + 2.0), Vector2(CLIFF_EDGE_X - 40.0, CLIFF_Y + 4.0),
			Vector2(CLIFF_EDGE_X, CLIFF_Y + 24.0), Vector2(CLIFF_EDGE_X + 6.0, CLIFF_Y + 130.0), Vector2(CLIFF_EDGE_X - 24.0, CLIFF_Y + 260.0), Vector2(CLIFF_EDGE_X + 10.0, CLIFF_Y + 420.0),
			Vector2(CLIFF_EDGE_X - 30.0, CLIFF_Y + 700.0), Vector2(CLIFF_EDGE_X + 20.0, 1600.0)])
	c.draw_colored_polygon(rock, Color(0.2, 0.16, 0.22))
	for i in 7:
		var y: float = CLIFF_Y + 30.0 + float(i) * 120.0
		c.draw_polyline(PackedVector2Array([Vector2(-1800.0, y + _hash(i) * 20.0), Vector2(200.0, y - 10.0), Vector2(CLIFF_EDGE_X - 40.0 + float(i % 2) * 20.0, y + 16.0)]), Color(0.1, 0.08, 0.13, 0.7), 5.0, true)
		c.draw_rect(Rect2(-1800.0, y + 6.0, 2400.0, 40.0), Color(0.0, 0.0, 0.0, 0.05 + 0.02 * float(i)))
	c.draw_polyline(PackedVector2Array([Vector2(-1800.0, CLIFF_Y), Vector2(300.0, CLIFF_Y - 8.0), Vector2(640.0, CLIFF_Y + 2.0), Vector2(CLIFF_EDGE_X - 40.0, CLIFF_Y + 4.0), Vector2(CLIFF_EDGE_X, CLIFF_Y + 24.0)]), INK, 5.0, true)
	_grass(c, 0.0)
	_left_items(c)
	_feather(c)


## The duck's sword and its straw hat left on the grass at the edge (the cliff ending, after the cut): lying flat, apart from each other. Flat shapes.
func _left_items(c: Node2D) -> void:
	if not items_left:
		return
	var y: float = CLIFF_Y - 1.0
	var steel := Color(0.74, 0.77, 0.8)
	# The sword lies on the ground, blade toward the edge.
	c.draw_line(Vector2(560.0, y), Vector2(668.0, y), INK, 7.0, true)
	c.draw_line(Vector2(566.0, y), Vector2(664.0, y), steel, 3.4, true)
	c.draw_line(Vector2(560.0, y - 9.0), Vector2(560.0, y + 9.0), INK, 6.0, true)
	c.draw_line(Vector2(538.0, y), Vector2(558.0, y), Color(0.3, 0.14, 0.14), 6.0, true)
	# The hat: a wide straw brim and a low cone.
	var hat := Vector2(CLIFF_EDGE_X - 78.0, y)
	var brim := PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		brim.append(hat + Vector2(cos(a) * 36.0, sin(a) * 7.0 - 5.0))
	c.draw_colored_polygon(brim, Color(0.74, 0.62, 0.38))
	c.draw_polyline(brim + PackedVector2Array([brim[0]]), INK, 2.4, true)
	var cone := PackedVector2Array([hat + Vector2(-22.0, -7.0), hat + Vector2(0.0, -30.0), hat + Vector2(22.0, -7.0)])
	c.draw_colored_polygon(cone, Color(0.82, 0.7, 0.44))
	c.draw_polyline(cone, INK, 2.4, true)


## Grass along the top of the cliff, bending in the wind.
func _grass(c: Node2D, extra: float) -> void:
	var gust: float = wind
	for i in 90:
		var x: float = -300.0 + float(i) * 9.0
		if x > CLIFF_EDGE_X - 6.0:
			break
		var sway: float = 0.0 if reduced else sin(time * (1.6 + gust) + float(i) * 0.4) * (4.0 + 14.0 * gust)
		var height: float = 14.0 + _hash(i + 17) * 22.0 + extra
		var base := Vector2(x, CLIFF_Y + 1.0)
		var tip := base + Vector2(sway + 6.0 * gust, -height)
		c.draw_line(base, tip, Color(0.2, 0.26, 0.22), 3.0, true)


func _cliff_front(c: Node2D) -> void:
	_grass(c, 18.0)
	var dark := Color(0.03, 0.03, 0.06, 0.95)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-300.0, 760.0), Vector2(-260.0, 640.0), Vector2(-150.0, 610.0), Vector2(-60.0, 700.0), Vector2(0.0, 760.0)]), dark)


## A small feather drifting in the wind over the empty edge of the cliff ending: a curved quill with barbs on both sides, soft cream
## (nothing else is left on the edge). Still in reduced mode.
func _feather(c: Node2D) -> void:
	if style != "released" or duck_visible:
		return
	var drift: float = 0.0 if reduced else fposmod(time * 0.07, 1.0)
	var at := Vector2(CLIFF_EDGE_X - 150.0 + drift * 190.0 + (0.0 if reduced else sin(time * 1.1) * 14.0), CLIFF_Y - 110.0 - drift * 90.0)
	var spin: float = -0.7 if reduced else -0.7 + sin(time * 0.9) * 0.45
	var length: float = 54.0
	var quill := PackedVector2Array()
	for i in 9:
		var k: float = float(i) / 8.0
		quill.append(Vector2(lerpf(-length * 0.5, length * 0.5, k), sin(k * PI) * -7.0).rotated(spin) + at)
	for i in range(1, 8):
		var k2: float = float(i) / 8.0
		var base: Vector2 = quill[i]
		var tangent: Vector2 = (quill[i + 1] - quill[i - 1]).normalized()
		var barb: float = 14.0 * sin(k2 * PI * 0.9 + 0.25)
		for side in [-1.0, 1.0]:
			var out: Vector2 = base + (tangent.rotated(float(side) * 1.0) * barb)
			c.draw_line(base, out, Color(0.93, 0.9, 0.78, 0.85), 2.4, true)
	c.draw_polyline(quill, Color(0.72, 0.66, 0.55, 0.95), 2.2, true)

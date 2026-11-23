class_name BouncePadArt
extends Node2D
## The drawing of a BouncePad (Phase 15c, raised in Phase 15d-bis): a floating lily pad with a pink flower held up by a
## curved green stem that works like a spring. The pad sits `config.pad_height` px over the floor; when it launches the
## player the stem compresses (the leaf drops and the stem bulges sideways) and then stretches back. Drawn in code; the
## stem is NOT solid (the drawing has no collision: the player walks beneath it). If the pad has a `texture` it is drawn
## instead of the leaf (the stem stays drawn in code). Presentation only: it listens to the pad signal `launched`.

const LEAF := Color(0.3, 0.62, 0.34)
const LEAF_DARK := Color(0.17, 0.4, 0.24)
const VEIN := Color(0.46, 0.78, 0.46)
const STEM := Color(0.24, 0.52, 0.28)
const STEM_LIGHT := Color(0.46, 0.78, 0.46)
const PETAL := Color(1.0, 0.7, 0.82)
const PETAL_DARK := Color(0.9, 0.45, 0.62)
const CORE := Color(1.0, 0.92, 0.45)
const OUTLINE := Color(0.106, 0.098, 0.122, 0.9)
## How far the leaf drops at the deepest point of the squash, and how far it stretches up on the rebound (px).
const SQUASH_DROP: float = 15.0
const STRETCH_RISE: float = 7.0

## 0 at rest, 1 at the deepest squash (negative while the stem stretches back); the tests read it.
var compression: float = 0.0

var _pad: BouncePad = null
var _squash_left: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_pad = get_parent() as BouncePad
	z_index = 1
	if _pad != null:
		_pad.launched.connect(func(_player: Player) -> void: _squash_left = _pad.config.squash_time)


## True when the pad has a texture and it is drawn instead of the code drawing of the leaf.
func uses_texture() -> bool:
	return _pad != null and _pad.texture != null


func _process(delta: float) -> void:
	_time += delta
	_squash_left = maxf(_squash_left - delta, 0.0)
	compression = _compression_now()
	queue_redraw()


## The squash curve: a quick press in the first 40% of the squash time, then a softer stretch back to rest.
func _compression_now() -> float:
	if _pad == null or _squash_left <= 0.0:
		return 0.0
	var progress: float = 1.0 - _squash_left / maxf(_pad.config.squash_time, 0.001)
	if progress < 0.4:
		return sin(progress / 0.4 * PI * 0.5)
	return -0.45 * sin((progress - 0.4) / 0.6 * PI)


func _draw() -> void:
	if _pad == null:
		return
	var config: BounceConfig = _pad.config
	var half_w: float = config.trigger_size.x * 0.5
	# Local coordinates: the node is the center of the trigger area. The top of the pad is `top_local` and the floor under
	# it `floor_local` (pad_height below the top).
	var top_local: float = -(config.trigger_size.y * 0.5 - config.top_margin)
	var floor_local: float = top_local + config.pad_height
	var bob: float = sin(_time * 2.0 + _pad.global_position.x * 0.05) * 1.1 * (1.0 - absf(compression))
	var offset: float = compression * SQUASH_DROP if compression >= 0.0 else compression * STRETCH_RISE
	var leaf_center := Vector2(0.0, top_local + 8.0 + offset + bob)
	_draw_stem(Vector2(0.0, floor_local), leaf_center + Vector2(0.0, 6.0), compression)
	var squash_x: float = 1.0 + 0.16 * maxf(compression, 0.0)
	var squash_y: float = 1.0 - 0.5 * maxf(compression, 0.0) + 0.1 * maxf(-compression, 0.0)
	draw_set_transform(leaf_center, 0.0, Vector2(squash_x, squash_y))
	if _pad.texture != null:
		var width: float = half_w * 2.0 + 16.0
		var height: float = _pad.texture.get_size().y * width / maxf(_pad.texture.get_size().x, 1.0)
		draw_texture_rect(_pad.texture, Rect2(Vector2(-width * 0.5, -height * 0.7), Vector2(width, height)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_colored_polygon(_ellipse(Vector2(0, 2), half_w + 8.0, 10.0), OUTLINE)
	draw_colored_polygon(_ellipse(Vector2.ZERO, half_w + 6.0, 9.0), LEAF_DARK)
	draw_colored_polygon(_ellipse(Vector2(0, -2), half_w + 2.0, 6.5), LEAF)
	for i in 5:
		var angle: float = -PI + float(i) * PI / 4.0
		draw_line(Vector2(0, -2), Vector2(cos(angle) * (half_w - 2.0), -2.0 + sin(angle) * 4.5), VEIN, 1.2)
	var flower := Vector2(half_w * 0.35, -9.0)
	for i in 6:
		var a: float = float(i) * TAU / 6.0 + 0.3
		draw_colored_polygon(_ellipse(flower + Vector2(cos(a) * 5.0, sin(a) * 2.6 - 1.0), 4.4, 2.8), PETAL_DARK)
	for i in 6:
		var a2: float = float(i) * TAU / 6.0 + 0.6
		draw_colored_polygon(_ellipse(flower + Vector2(cos(a2) * 3.4, sin(a2) * 1.8 - 3.0), 3.4, 2.2), PETAL)
	draw_circle(flower + Vector2(0, -4.0), 2.2, CORE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The curved stem, a spring: an S-shaped branch from the floor to the leaf that bulges sideways when it is compressed and
## straightens when it stretches. Two passes (ink, then green) with a light line along it.
func _draw_stem(base: Vector2, tip: Vector2, squeeze: float) -> void:
	var points := PackedVector2Array()
	var segments: int = 14
	var sway: float = 7.0 + 12.0 * maxf(squeeze, 0.0) - 4.0 * maxf(-squeeze, 0.0)
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var p: Vector2 = base.lerp(tip, t)
		p.x += sin(t * TAU) * sway * (1.0 - 0.25 * t)
		points.append(p)
	draw_polyline(points, OUTLINE, 7.0, true)
	draw_polyline(points, STEM, 4.5, true)
	draw_polyline(points, Color(STEM_LIGHT, 0.7), 1.4, true)
	# Small coils across the stem make it read as a spring.
	for i in range(1, segments, 2):
		var a: Vector2 = points[i]
		draw_line(a + Vector2(-4.5, 0.0), a + Vector2(4.5, 1.5), Color(OUTLINE, 0.55), 1.4, true)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		var a: float = float(i) * TAU / 24.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points

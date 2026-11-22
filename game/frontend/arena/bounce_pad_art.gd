class_name BouncePadArt
extends Node2D
## The drawing of a BouncePad (Phase 15c): a floating lily pad with a pink flower, drawn in code, that squashes
## when the pad launches the player. If the pad has a `texture` it is drawn instead of the code drawing.
## Presentation only: it listens to the pad signal `launched` and reads nothing else.

const LEAF := Color(0.3, 0.62, 0.34)
const LEAF_DARK := Color(0.17, 0.4, 0.24)
const VEIN := Color(0.46, 0.78, 0.46)
const PETAL := Color(1.0, 0.7, 0.82)
const PETAL_DARK := Color(0.9, 0.45, 0.62)
const CORE := Color(1.0, 0.92, 0.45)
const OUTLINE := Color(0.106, 0.098, 0.122, 0.9)

var _pad: BouncePad = null
var _squash_left: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_pad = get_parent() as BouncePad
	z_index = 1
	if _pad != null:
		_pad.launched.connect(func(_player: Player) -> void: _squash_left = _pad.config.squash_time)


## True when the pad has a texture and it is drawn instead of the code drawing.
func uses_texture() -> bool:
	return _pad != null and _pad.texture != null


func _process(delta: float) -> void:
	_time += delta
	_squash_left = maxf(_squash_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _pad == null:
		return
	# 1 at the start of the squash, 0 at rest; a quick press then a bounce back.
	var k: float = _squash_left / maxf(_pad.config.squash_time, 0.001)
	var press: float = sin(k * PI) if k > 0.0 else 0.0
	var scale_xy := Vector2(1.0 + 0.18 * press, 1.0 - 0.55 * press)
	var half_w: float = _pad.config.trigger_size.x * 0.5
	var bob: float = sin(_time * 2.0 + _pad.global_position.x * 0.05) * 1.2 * (1.0 - press)
	# The pad sits on the floor top: the leaf is a flat ellipse centered a little under the trigger area center.
	var base := Vector2(0.0, _pad.config.trigger_size.y * 0.5 - 6.0 + bob)
	draw_set_transform(base, 0.0, scale_xy)
	if _pad.texture != null:
		var size: Vector2 = Vector2(half_w * 2.0 + 16.0, _pad.texture.get_size().y * (half_w * 2.0 + 16.0) / maxf(_pad.texture.get_size().x, 1.0))
		draw_texture_rect(_pad.texture, Rect2(Vector2(-size.x * 0.5, -size.y * 0.7), size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var leaf := _ellipse(Vector2.ZERO, half_w + 6.0, 9.0)
	draw_colored_polygon(_ellipse(Vector2(0, 2), half_w + 8.0, 10.0), OUTLINE)
	draw_colored_polygon(leaf, LEAF_DARK)
	draw_colored_polygon(_ellipse(Vector2(0, -2), half_w + 2.0, 6.5), LEAF)
	# The notch of the lily pad and a few veins.
	draw_colored_polygon(PackedVector2Array([Vector2(0, -1), Vector2(half_w + 7.0, -5), Vector2(half_w + 7.0, 1)]), Color(0.1, 0.18, 0.16, 0.0))
	for i in 5:
		var angle: float = -PI + float(i) * PI / 4.0
		draw_line(Vector2(0, -2), Vector2(cos(angle) * (half_w - 2.0), -2.0 + sin(angle) * 4.5), VEIN, 1.2)
	# The flower.
	var flower := Vector2(half_w * 0.35, -9.0)
	for i in 6:
		var a: float = float(i) * TAU / 6.0 + 0.3
		draw_colored_polygon(_ellipse(flower + Vector2(cos(a) * 5.0, sin(a) * 2.6 - 1.0), 4.4, 2.8), PETAL_DARK)
	for i in 6:
		var a2: float = float(i) * TAU / 6.0 + 0.6
		draw_colored_polygon(_ellipse(flower + Vector2(cos(a2) * 3.4, sin(a2) * 1.8 - 3.0), 3.4, 2.2), PETAL)
	draw_circle(flower + Vector2(0, -4.0), 2.2, CORE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		var a: float = float(i) * TAU / 24.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points

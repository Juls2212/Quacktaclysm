@tool
class_name MarshWater
extends Node2D
## Stretches of dirty green water lying on the marsh floor, with soft ripples drifting along them.
## Visual only: it has no collision and never changes the game. While the player walks through
## one, rings spread from their feet (the player is only read, never touched).

const WATER := Color(0.3, 0.42, 0.3, 0.92)
const DEEP := Color(0.17, 0.25, 0.17, 0.92)
const SHINE := Color(0.8, 0.92, 0.6, 0.9)
const INK := Color(0.1, 0.12, 0.07, 0.9)
const RING_LIFE: float = 0.9

## Water stretches as [left x, right x], on the floor top.
@export var pools: Array[Vector2] = [Vector2(300, 760), Vector2(1080, 1420), Vector2(1900, 2300),
		Vector2(3250, 3460), Vector2(3560, 3860), Vector2(4250, 4560)]
## World y of the floor top the water lies on.
@export var floor_y: float = 600.0

var _time: float = 0.0
var _rings: Array[Vector3] = []
var _step: float = 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_time += delta
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].z += delta
		if _rings[i].z > RING_LIFE:
			_rings.remove_at(i)
	_step -= delta
	var player: Node2D = _player()
	if player != null and _step <= 0.0:
		var body := player as CharacterBody2D
		var moving: bool = body != null and body.is_on_floor() and absf(body.velocity.x) > 20.0
		var feet: Vector2 = player.global_position - global_position
		if moving and absf(feet.y + 26.0 - floor_y) < 40.0 and _in_pool(feet.x):
			_rings.append(Vector3(feet.x, floor_y, 0.0))
			_step = 0.16
	queue_redraw()


func _draw() -> void:
	var top: float = floor_y - 5.0
	for pool in pools:
		var l: float = pool.x
		var r: float = pool.y
		if r - l < 20.0:
			continue
		# Body of water with rounded ends, darker at the bottom.
		var pts := PackedVector2Array()
		var n: int = maxi(int((r - l) / 24.0), 4)
		for i in n + 1:
			var x: float = lerpf(l, r, float(i) / float(n))
			pts.append(Vector2(x, top + sin(x * 0.03 + _time * 1.6) * 1.2))
		pts.append(Vector2(r - 8.0, floor_y + 14.0))
		pts.append(Vector2(r - 30.0, floor_y + 22.0))
		pts.append(Vector2(l + 30.0, floor_y + 22.0))
		pts.append(Vector2(l + 8.0, floor_y + 14.0))
		draw_colored_polygon(pts, WATER)
		draw_rect(Rect2(l + 30.0, floor_y + 12.0, r - l - 60.0, 10.0), DEEP)
		var surface := pts.slice(0, n + 1)
		draw_polyline(surface, INK, 3.0, true)
		draw_polyline(Transform2D(0.0, Vector2(0, 3)) * surface, Color(SHINE, 0.55), 2.0, true)
		# Soft ripples drifting along the surface.
		var waves: int = maxi(int((r - l) / 90.0), 1)
		for k in waves:
			var x: float = l + 20.0 + fposmod(float(k) * 90.0 + _time * 14.0 * (1.0 if k % 2 == 0 else -1.0), r - l - 40.0)
			var a: float = 0.4 + 0.3 * sin(_time * 2.0 + float(k))
			draw_line(Vector2(x - 12.0, top + 5.0), Vector2(x + 12.0, top + 5.0), Color(SHINE, a), 2.0, true)
			draw_line(Vector2(x - 5.0, top + 10.0), Vector2(x + 7.0, top + 10.0), Color(SHINE, a * 0.6), 1.5, true)
	for ring in _rings:
		var u: float = ring.z / RING_LIFE
		_ellipse_ring(Vector2(ring.x, ring.y), 8.0 + u * 40.0, 2.0 + u * 5.0, Color(SHINE, 0.9 * (1.0 - u)))


func _ellipse_ring(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var a: float = TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, color, 2.0, true)


func _in_pool(x: float) -> bool:
	for pool in pools:
		if x > pool.x + 10.0 and x < pool.y - 10.0:
			return true
	return false


## The level's player, read only (null in the editor or outside a level).
func _player() -> Node2D:
	if Engine.is_editor_hint() or get_parent() == null:
		return null
	var p: Variant = get_parent().get(&"player")
	if p is Node2D and is_instance_valid(p):
		return p
	return null

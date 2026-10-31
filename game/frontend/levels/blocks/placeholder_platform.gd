@tool
class_name PlaceholderPlatform
extends StaticBody2D
## Colored rectangle with collision (world layer) used to lay out levels before the real art.
## The rectangle is centered on the node's origin. Each instance builds its own shape.

@export var size: Vector2 = Vector2(200.0, 32.0):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_refresh()
@export var one_way: bool = false:
	set(value):
		one_way = value
		_refresh()
@export var color: Color = Color(0.35, 0.3, 0.25, 1.0):
	set(value):
		color = value
		_refresh()

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	collision.shape = RectangleShape2D.new()
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var rect := collision.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		collision.shape = rect
	rect.size = size
	collision.one_way_collision = one_way
	var half: Vector2 = size * 0.5
	visual.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	visual.color = color

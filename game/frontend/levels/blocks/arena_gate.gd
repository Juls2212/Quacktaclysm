class_name ArenaGate
extends StaticBody2D
## Blocks the arena entrance while a boss fight runs. Starts open; close()/open() are idempotent.

signal state_changed(is_closed: bool)

@export var size: Vector2 = Vector2(40.0, 240.0):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_refresh_shape()
@export var color: Color = Color(0.55, 0.2, 0.2, 1.0)

var is_closed: bool = false

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	collision.shape = RectangleShape2D.new()
	_refresh_shape()
	visual.color = color
	_apply(false, true)


func close() -> void:
	_apply(true, false)


func open() -> void:
	_apply(false, false)


func _apply(closed: bool, force: bool) -> void:
	if closed == is_closed and not force:
		return
	is_closed = closed
	collision.set_deferred("disabled", not closed)
	visual.visible = closed
	state_changed.emit(closed)


func _refresh_shape() -> void:
	if not is_node_ready():
		return
	(collision.shape as RectangleShape2D).size = size
	var half: Vector2 = size * 0.5
	visual.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])

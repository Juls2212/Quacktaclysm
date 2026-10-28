class_name DamageZone
extends Node2D
## Visible hazard that damages the player repeatedly while overlapping.

@export var size: Vector2 = Vector2(160.0, 40.0)

@onready var hitbox: Hitbox = $Hitbox
@onready var shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	var half: Vector2 = size / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])

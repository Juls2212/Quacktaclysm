class_name BossPerch
extends StaticBody2D
## The perch above the platforms where only the boss stands (Phase 15j). It collides with the BOSS layer only: the player passes through
## it. It is drawn as a hanging iron ledge on chains with a dark underside and warning stripes, so it reads as «not for you» (shape and
## stripes, not color alone). The stage places, shows and hides it; it makes no decision.

const INK := Color(0.106, 0.098, 0.122)

@export var size: Vector2 = Vector2(170.0, 22.0)
## Chains up to the ceiling (px above the top of the perch); the stage sets it from the ceiling.
@export var chain_height: float = 120.0
@export var iron: Color = Color(0.24, 0.22, 0.3, 1.0)
@export var warning: Color = Color(0.95, 0.75, 0.2, 1.0)

var _shape: CollisionShape2D = null


func _ready() -> void:
	collision_layer = CombatLayers.layer_bit(CombatLayers.LAYER_BOSS_PERCH)
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	z_index = 2


## Switches the collision on or off (deferred: it may be called from a physics callback).
func set_solid(solid: bool) -> void:
	if _shape != null:
		_shape.set_deferred(&"disabled", not solid)


func is_solid() -> bool:
	return _shape != null and not _shape.disabled


func _draw() -> void:
	var half: Vector2 = size * 0.5
	var top: float = -half.y
	# Chains.
	for x: float in [-half.x * 0.7, half.x * 0.7]:
		var y: float = top
		while y > top - chain_height:
			draw_circle(Vector2(x, y - 6.0), 3.5, INK)
			draw_circle(Vector2(x, y - 6.0), 2.0, iron.lightened(0.15))
			y -= 11.0
	# The ledge: iron slab, darker underside, warning stripes along the front.
	var slab := Rect2(-half, size)
	draw_rect(slab, iron)
	draw_rect(Rect2(-half.x, half.y - 6.0, size.x, 6.0), iron.darkened(0.4))
	draw_rect(slab, INK, false, 3.0)
	var x: float = -half.x + 6.0
	while x < half.x - 10.0:
		draw_colored_polygon(PackedVector2Array([Vector2(x, -half.y + 4.0), Vector2(x + 9.0, -half.y + 4.0), Vector2(x + 3.0, half.y - 8.0), Vector2(x - 6.0, half.y - 8.0)]), warning)
		x += 22.0

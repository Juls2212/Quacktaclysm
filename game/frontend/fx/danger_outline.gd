class_name DangerOutline
extends Node2D
## A danger outline and glow for the ENEMY projectile scene (projectile.tscn): a dark outline round
## the diamond, a warm red-orange halo that pulses, and a bright ring. The player's sword wave is a
## different scene (blue, cyan or violet, no halo), so the two never look alike. Drawn in code; it
## only reads the projectile's size (`stats.size_scale`) to follow it, and changes no speed, no
## hitbox and no damage. The colors are checked against every background by phase14f_smoke_test.

const INK := Color(0.106, 0.098, 0.122)
## Warm red-orange (the sword waves are blue / cyan / violet).
const HALO := Color(1.0, 0.55, 0.45)
const RING := Color(1.0, 0.55, 0.45, 0.95)
## The projectile's own diamond (projectile.tscn Visual), grown a little for the outline.
const DIAMOND: PackedVector2Array = [Vector2(-8.5, 0.0), Vector2(0.0, -8.5), Vector2(8.5, 0.0), Vector2(0.0, 8.5), Vector2(-8.5, 0.0)]

var _clock: float = 0.0


func _ready() -> void:
	# Behind the projectile's own drawing.
	z_index = -1


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var projectile: Node = get_parent()
	var stats: Variant = projectile.get(&"stats")
	# Before launch there is nothing to warn about.
	if stats == null:
		return
	var k: float = float((stats as Object).get(&"size_scale"))
	var pulse: float = 0.5 + 0.5 * sin(_clock * 12.0)
	draw_circle(Vector2.ZERO, (12.0 + 3.0 * pulse) * k, Color(HALO, 0.28 + 0.2 * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	draw_polyline(DIAMOND, INK, 5.0, true)
	draw_polyline(DIAMOND, RING, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

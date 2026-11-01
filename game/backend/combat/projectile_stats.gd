class_name ProjectileStats
extends Resource
## Data-driven values for a projectile. Units: pixels and seconds.

@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var speed: float = 400.0
@export_range(1, 99, 1) var damage: int = 1
## x: push along the flight direction. y: vertical impulse (negative is up).
@export var knockback: Vector2 = Vector2(200.0, -100.0)
@export_range(0.1, 30.0, 0.1, "suffix:s") var lifetime: float = 3.0
## 0 flies straight. 1 falls with the project's default 2D gravity.
@export_range(0.0, 5.0, 0.05) var gravity_scale: float = 0.0
@export var destroy_on_hit: bool = true
@export var destroy_on_world: bool = true
## Enemies it can pass through before despawning. 0 = despawns on the first hit.
@export_range(0, 20, 1) var pierce_count: int = 0
## Scales the visual and the collision/hit shapes once, at launch.
@export_range(0.25, 4.0, 0.05) var size_scale: float = 1.0
## Visual tint. Transparent (default) keeps the scene's own color.
@export var tint: Color = Color(1.0, 1.0, 1.0, 0.0)

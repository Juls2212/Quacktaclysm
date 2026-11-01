class_name SwordWaveTier
extends Resource
## One power level of the sword wave. Units: pixels and seconds. Reach = speed * lifetime.

@export_range(1, 99, 1) var damage: int = 1
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var speed: float = 520.0
@export_range(0.1, 30.0, 0.05, "suffix:s") var lifetime: float = 0.9
@export_range(0.25, 4.0, 0.05) var size_scale: float = 1.0
## Enemies the wave can pass through before despawning on the next one.
@export_range(0, 20, 1) var pierce_count: int = 0
## x: push along the flight direction. y: vertical impulse (negative is up).
@export var knockback: Vector2 = Vector2(180.0, -60.0)
## Seconds before the next cast, counted from the moment the wave is spawned.
@export_range(0.0, 30.0, 0.05, "suffix:s") var cooldown: float = 1.0
@export var tint: Color = Color(0.55, 0.8, 1.0, 1.0)

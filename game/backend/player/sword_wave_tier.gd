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
## The color of the wave: tier 0 blue-white, tier 1 emerald, tier 2 violet with a dark core (never red or orange: those are
## the enemy projectiles). A stronger wave also has a longer trail and a brighter glow; none of it touches the hitbox.
@export var tint: Color = Color(0.8, 0.92, 1.0, 1.0)
@export var rim_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## A dark heart inside the wave (alpha 0 = none). Tier 2 uses it so the violet stays visible on violet backgrounds.
@export var core_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var glow_color: Color = Color(0.65, 0.85, 1.0, 1.0)
@export_range(0.0, 1.0, 0.05) var glow_strength: float = 0.3
@export_range(0.0, 400.0, 1.0, "suffix:px") var trail_length: float = 44.0
## How much bigger the burst where the wave hits is drawn (visual only: it never touches the hitbox).
@export_range(0.5, 3.0, 0.05) var impact_scale: float = 1.0

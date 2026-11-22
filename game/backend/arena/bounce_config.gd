class_name BounceConfig
extends Resource
## Tunable numbers of the lily-pad trampolines (default_bounce_config.tres). Units: pixels and seconds.

const DEFAULT_PATH: String = "res://backend/arena/default_bounce_config.tres"

## Vertical speed given to the player (negative is up). With the player gravity (1800) this rises about
## 300 px, enough for the high tier of the swamp arena (260 px above the floor).
@export_range(-3000.0, 0.0, 1.0, "suffix:px/s") var launch_velocity: float = -1030.0
## Seconds after a launch before the pad can launch again.
@export_range(0.0, 3.0, 0.05, "suffix:s") var cooldown: float = 0.35
## Seconds of the squash animation of the pad (visual only).
@export_range(0.05, 1.0, 0.01, "suffix:s") var squash_time: float = 0.28
## Size of the trigger area on top of the pad (tall on purpose: a player falling fast overlaps it for a few frames
## before touching the floor).
@export var trigger_size: Vector2 = Vector2(72.0, 44.0)


static func get_default() -> BounceConfig:
	return load(DEFAULT_PATH) as BounceConfig

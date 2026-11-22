class_name BounceConfig
extends Resource
## Tunable numbers of the lily-pad trampolines (default_bounce_config.tres). Units: pixels and seconds.

const DEFAULT_PATH: String = "res://backend/arena/default_bounce_config.tres"

## Vertical speed given to the player (negative is up). The pad is RAISED (`pad_height`), and the rise is counted from its
## top: with the player gravity (1800), -930 px/s rises 930^2 / (2 * 1800) = 240 px above the pad top, so the feet peak about
## 56 + 6 + 240 = 302 px over the floor, 52 px above the high tier of the swamp arena (250 px) and well under the
## ceiling (440 px).
@export_range(-3000.0, 0.0, 1.0, "suffix:px/s") var launch_velocity: float = -930.0
## Seconds after a launch before the pad can launch again.
@export_range(0.0, 3.0, 0.05, "suffix:s") var cooldown: float = 0.35
## Seconds of the squash animation of the pad (visual only).
@export_range(0.05, 1.0, 0.01, "suffix:s") var squash_time: float = 0.28
## How high the top of the pad is over the floor (px). The pad floats on a curved spring stem that is NOT solid, so the
## player can walk beneath it; to use it the player jumps (the jump rises 112 px) and comes down on it.
@export_range(0.0, 200.0, 1.0, "suffix:px") var pad_height: float = 56.0
## Size of the trigger area: it starts `top_margin` px above the top of the pad and reaches down into it (tall on purpose:
## a player falling fast overlaps it for a few frames before the pad throws it up).
@export var trigger_size: Vector2 = Vector2(72.0, 40.0)
@export_range(0.0, 30.0, 1.0, "suffix:px") var top_margin: float = 6.0


static func get_default() -> BounceConfig:
	return load(DEFAULT_PATH) as BounceConfig

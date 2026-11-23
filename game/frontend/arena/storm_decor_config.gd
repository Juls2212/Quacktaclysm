class_name StormDecorConfig
extends Resource
## Every number of the reactive scenery of level 3 (Phase 15g): puddles that splash, hanging lamps that flicker, chains that sway and
## background debris. Default instance: res://frontend/arena/default_storm_decor_config.tres. Decor never changes gameplay.

const DEFAULT_PATH: String = "res://frontend/arena/default_storm_decor_config.tres"

@export_group("Caps")
## Most splash particles alive at once in the whole decor (a hard cap).
@export_range(0, 200, 1) var max_particles: int = 40
## Most nodes the decor may have (it uses a handful of drawing layers, never one node per decoration).
@export_range(1, 32, 1) var max_nodes: int = 8
@export_group("Puddles")
@export_range(20.0, 300.0, 1.0, "suffix:px") var puddle_width: float = 90.0
@export_range(1, 30, 1) var splash_particles: int = 8
@export_range(0.1, 2.0, 0.05, "suffix:s") var splash_life: float = 0.5
@export_range(20.0, 400.0, 5.0, "suffix:px/s") var splash_speed: float = 150.0
## Least seconds between two splashes of the same puddle.
@export_range(0.0, 2.0, 0.05, "suffix:s") var splash_gap: float = 0.15
@export_group("Lamps")
## The player flickers a lamp when passing within this many px.
@export_range(20.0, 600.0, 5.0, "suffix:px") var lamp_range: float = 220.0
## Flickers per second: never above 3 (photosensitivity).
@export_range(0.5, 3.0, 0.1, "suffix:Hz") var flash_hz: float = 2.5
## Brightest the flicker may be (the possession cap is 0.3) and the steady glow underneath.
@export_range(0.05, 0.3, 0.01) var max_flash_alpha: float = 0.3
@export_range(0.0, 0.3, 0.01) var lamp_base_alpha: float = 0.12
@export_range(10.0, 200.0, 1.0, "suffix:px") var lamp_glow_radius: float = 70.0
@export_group("Chains")
@export_range(20.0, 600.0, 5.0, "suffix:px") var chain_range: float = 200.0
## How far a chain swings (radians) when the player passes and how fast it settles.
@export_range(0.05, 1.0, 0.01) var sway_amount: float = 0.35
@export_range(0.1, 5.0, 0.1) var sway_decay: float = 1.2
@export_range(0.5, 6.0, 0.1, "suffix:Hz") var sway_hz: float = 2.2
@export_group("Colors")
@export var water: Color = Color(0.45, 0.6, 0.8, 0.55)
@export var lamp: Color = Color(1.0, 0.97, 0.7)
@export var metal: Color = Color(0.2, 0.22, 0.3, 0.9)
@export var debris: Color = Color(0.1, 0.09, 0.14, 0.4)


static func get_default() -> StormDecorConfig:
	return load(DEFAULT_PATH) as StormDecorConfig

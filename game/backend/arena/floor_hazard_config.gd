class_name FloorHazardConfig
extends Resource
## Tunable numbers of the swamp floor spikes (default_floor_hazard_config.tres). Units: pixels and seconds.

const DEFAULT_PATH: String = "res://backend/arena/default_floor_hazard_config.tres"

## The floor glows red and bubbles and the spikes peek out: they do not hurt yet.
@export_range(0.1, 10.0, 0.1, "suffix:s") var warning_time: float = 1.2
## The spikes are out and hurt.
@export_range(0.1, 20.0, 0.1, "suffix:s") var active_time: float = 3.0
## Rest between cycles (no spikes).
@export_range(0.0, 30.0, 0.1, "suffix:s") var rest_time: float = 4.0
## Damage of a spike hit (hearts); it goes through the normal Hitbox / DamageInfo path.
@export_range(1, 5, 1) var damage: int = 1
@export var knockback: Vector2 = Vector2(140.0, -260.0)
## A player that stays on the spikes can be hit again after this long (the hurt invulnerability still applies).
@export_range(0.1, 5.0, 0.05, "suffix:s") var rehit_interval: float = 0.5
## Height of the dangerous band over the floor (platforms and pads sit above it or are cut out of it).
@export_range(4.0, 80.0, 1.0, "suffix:px") var band_height: float = 26.0
## Free space left on each side of a lily pad when `cut_out_pads` is on.
@export_range(0.0, 80.0, 1.0, "suffix:px") var pad_margin: float = 6.0
## Pads used to sit flush with the floor and were cut out of the spikes. Now they are raised: the pad itself is always safe
## (it is above the dangerous band) but the floor under it is not, so this is off.
@export var cut_out_pads: bool = false


static func get_default() -> FloorHazardConfig:
	return load(DEFAULT_PATH) as FloorHazardConfig

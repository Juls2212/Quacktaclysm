class_name ElectricPlateConfig
extends Resource
## Tunable numbers of the level 3 electric plates (Phase 15g, default_electric_plate_config.tres). Units: pixels and seconds.

const DEFAULT_PATH: String = "res://backend/arena/default_electric_plate_config.tres"

## The plate hums, sparks gather and its outline pulses: it does not hurt yet.
@export_range(0.1, 10.0, 0.1, "suffix:s") var warning_time: float = 1.2
@export_range(0.1, 20.0, 0.1, "suffix:s") var active_time: float = 2.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var rest_time: float = 3.0
## Damage of a shock (hearts); it goes through the normal Hitbox / DamageInfo path (the dash is fully immune, like the spikes).
@export_range(1, 5, 1) var damage: int = 1
@export var knockback: Vector2 = Vector2(140.0, -260.0)
@export_range(0.1, 5.0, 0.05, "suffix:s") var rehit_interval: float = 0.5
## Height of the dangerous band over the floor (platforms and everything raised sit above it).
@export_range(4.0, 80.0, 1.0, "suffix:px") var band_height: float = 22.0
## Most spark particles one plate may have at once.
@export_range(0, 60, 1) var max_particles: int = 14


static func get_default() -> ElectricPlateConfig:
	return load(DEFAULT_PATH) as ElectricPlateConfig

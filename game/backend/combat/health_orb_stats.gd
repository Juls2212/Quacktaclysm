class_name HealthOrbStats
extends Resource
## Data-driven values for the health orbs dropped by defeated enemies and bosses.
## How many drop is set per enemy (EnemyStats) and per boss (BossStats).

@export_group("Healing")
## Hearts restored on pickup.
@export_range(1, 99, 1) var heal_amount: int = 1
## Only a player below full health pulls and collects orbs; full-health players leave them.
@export var only_when_hurt: bool = true

@export_group("Burst")
## Launch speed range when the orbs pop out of the defeated foe.
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var launch_speed_min: float = 160.0
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var launch_speed_max: float = 300.0
## Spread of the launch around straight up.
@export_range(0.0, 180.0, 1.0, "suffix:°") var launch_spread: float = 55.0
## Seconds before an orb can be pulled or collected (lets the burst be seen).
@export_range(0.0, 3.0, 0.05, "suffix:s") var pickup_delay: float = 0.4

@export_group("Magnet")
@export_range(0.0, 1000.0, 1.0, "suffix:px") var magnet_radius: float = 120.0
@export_range(0.0, 3000.0, 10.0, "suffix:px/s") var magnet_speed: float = 520.0
## How fast the pull reaches full speed.
@export_range(0.0, 20000.0, 50.0, "suffix:px/s²") var magnet_acceleration: float = 2600.0

@export_group("Lifetime")
## Seconds before an uncollected orb disappears (0 = never).
@export_range(0.0, 120.0, 0.5, "suffix:s") var lifetime: float = 12.0
## The orb blinks during the last seconds of its lifetime.
@export_range(0.0, 10.0, 0.1, "suffix:s") var blink_time: float = 2.5

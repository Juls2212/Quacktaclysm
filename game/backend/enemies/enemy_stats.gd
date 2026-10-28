class_name EnemyStats
extends Resource
## Data-driven values for an enemy. Units: pixels and seconds.

@export_group("Health")
@export_range(1, 999, 1) var max_health: int = 3

@export_group("Movement")
@export_range(0.0, 600.0, 1.0, "suffix:px/s") var move_speed: float = 90.0
@export_range(0.0, 5000.0, 10.0, "suffix:px/s²") var acceleration: float = 800.0
@export_range(0.0, 5000.0, 10.0, "suffix:px/s²") var gravity: float = 1800.0
@export_range(0.0, 3000.0, 1.0, "suffix:px/s") var max_fall_speed: float = 900.0

@export_group("Patrol")
@export var patrol_enabled: bool = true
## Patrol speed as a fraction of move_speed.
@export_range(0.0, 1.0, 0.05) var patrol_speed_multiplier: float = 0.5
## Pause before patrolling and after each turn.
@export_range(0.0, 10.0, 0.1, "suffix:s") var patrol_wait_time: float = 1.0
@export var turn_on_ledge: bool = true
@export var turn_on_wall: bool = true

@export_group("Detection")
@export_range(0.0, 2000.0, 1.0, "suffix:px") var detection_range: float = 260.0
## The target is lost beyond this distance (treated as at least detection_range).
@export_range(0.0, 3000.0, 1.0, "suffix:px") var lose_target_range: float = 380.0
@export var detection_requires_line_of_sight: bool = false

@export_group("Attack")
## Center-to-center distance at which an attack can start.
@export_range(0.0, 500.0, 1.0, "suffix:px") var attack_range: float = 48.0
@export_range(1, 99, 1) var attack_damage: int = 1
## x: push away from the enemy. y: vertical impulse (negative is up).
@export var attack_knockback: Vector2 = Vector2(250.0, -150.0)
@export_range(0.0, 3.0, 0.01, "suffix:s") var attack_startup_time: float = 0.35
@export_range(0.0, 3.0, 0.01, "suffix:s") var attack_active_time: float = 0.15
@export_range(0.0, 3.0, 0.01, "suffix:s") var attack_recovery_time: float = 0.4
## Delay after a swing ends before the next one can start.
@export_range(0.0, 10.0, 0.05, "suffix:s") var attack_cooldown: float = 0.8

@export_group("Hurt and death")
@export_range(0.0, 3.0, 0.01, "suffix:s") var hurt_stun_time: float = 0.3
## 1.0 applies the incoming knockback in full.
@export_range(0.0, 3.0, 0.05) var knockback_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.01, "suffix:s") var hurt_invulnerability_time: float = 0.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var death_fade_time: float = 0.5

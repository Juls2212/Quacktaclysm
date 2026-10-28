class_name PlayerStats
extends Resource
## Tunable movement values for the player. Units: pixels and seconds.

@export_group("Horizontal movement")
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var max_speed: float = 300.0
@export_range(0.0, 10000.0, 10.0, "suffix:px/s²") var acceleration: float = 2400.0
@export_range(0.0, 10000.0, 10.0, "suffix:px/s²") var friction: float = 3000.0
@export_range(0.0, 10000.0, 10.0, "suffix:px/s²") var air_acceleration: float = 1800.0
@export_range(0.0, 10000.0, 10.0, "suffix:px/s²") var air_friction: float = 600.0

@export_group("Vertical movement")
@export_range(0.0, 10000.0, 10.0, "suffix:px/s²") var gravity: float = 1800.0
@export_range(0.0, 3000.0, 1.0, "suffix:px/s") var max_fall_speed: float = 900.0

@export_group("Jump")
## Initial vertical velocity of a jump (negative is up).
@export_range(-2000.0, 0.0, 1.0, "suffix:px/s") var jump_velocity: float = -620.0
## Multiplier applied to upward velocity when jump is released early.
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.4
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time: float = 0.1
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time: float = 0.12

@export_group("Dash")
@export_range(0.0, 3000.0, 1.0, "suffix:px/s") var dash_speed: float = 700.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var dash_duration: float = 0.18
@export_range(0.0, 3.0, 0.01, "suffix:s") var dash_cooldown: float = 0.4
@export_range(0.0, 1.0, 0.01, "suffix:s") var dash_invulnerability_time: float = 0.12
@export_range(0, 5, 1) var max_air_dashes: int = 1
@export var dash_disables_gravity: bool = true

@export_group("Attack")
@export_range(1, 99, 1) var attack_damage: int = 1
@export_range(0.0, 1.0, 0.01, "suffix:s") var attack_startup_time: float = 0.08
@export_range(0.0, 1.0, 0.01, "suffix:s") var attack_active_time: float = 0.12
@export_range(0.0, 1.0, 0.01, "suffix:s") var attack_recovery_time: float = 0.15
## Delay after a swing ends before the next one can start.
@export_range(0.0, 2.0, 0.01, "suffix:s") var attack_cooldown: float = 0.1
## How long an early attack press is remembered.
@export_range(0.0, 0.5, 0.01, "suffix:s") var attack_input_buffer_time: float = 0.15
## x: push away from the player. y: vertical impulse (negative is up).
@export var attack_knockback: Vector2 = Vector2(250.0, -120.0)
## Horizontal speed factor while swinging.
@export_range(0.0, 1.0, 0.05) var attack_move_speed_multiplier: float = 0.4
@export var can_attack_in_air: bool = true

@export_group("Respawn")
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_delay: float = 1.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_invulnerability_time: float = 1.5
@export var auto_respawn: bool = true

@export_group("Health")
@export_range(1, 99, 1) var max_health: int = 5
## Invulnerability after taking damage.
@export_range(0.0, 5.0, 0.05, "suffix:s") var hurt_invulnerability_time: float = 1.0
## Time the player cannot act after being hit.
@export_range(0.0, 2.0, 0.05, "suffix:s") var hurt_stun_time: float = 0.25
## Visual flicker period while invulnerable after a hit.
@export_range(0.01, 0.5, 0.01, "suffix:s") var hurt_blink_interval: float = 0.08

@export_group("Camera")
@export_range(0.0, 30.0, 0.5) var camera_smoothing_speed: float = 8.0

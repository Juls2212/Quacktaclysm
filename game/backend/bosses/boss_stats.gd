class_name BossStats
extends Resource
## Data-driven values for a boss. Units: pixels and seconds.

@export_group("Identity")
@export var boss_id: StringName = &"boss"
@export var display_name: String = "Boss"

@export_group("Body")
@export_range(1, 9999, 1) var max_health: int = 40
@export_range(0.0, 5000.0, 10.0, "suffix:px/s²") var gravity: float = 1800.0
@export_range(0.0, 3000.0, 1.0, "suffix:px/s") var max_fall_speed: float = 900.0

@export_group("Phases")
## Phase 2 starts when health <= max_health * this ratio.
@export_range(0.0, 1.0, 0.01) var phase_2_health_ratio: float = 0.5
## The boss is invulnerable and idle while changing phase.
@export_range(0.0, 10.0, 0.1, "suffix:s") var phase_transition_time: float = 1.5
## Scales pattern timings and movement speeds in phase 2.
@export_range(0.1, 5.0, 0.05) var phase_2_speed_multiplier: float = 1.3
## Scales the gap between patterns in phase 2 (below 1 means less pause).
@export_range(0.05, 5.0, 0.05) var phase_2_pattern_gap_multiplier: float = 0.6

@export_group("Patterns")
@export_range(0.0, 10.0, 0.05, "suffix:s") var pattern_gap_time: float = 1.2
@export var avoid_immediate_repeat: bool = true

@export_group("Contact damage")
## Damage dealt by touching the boss while it is fighting. 0 disables contact damage.
@export_range(0, 99, 1) var contact_damage: int = 1
@export var contact_knockback: Vector2 = Vector2(260.0, -140.0)
@export_range(0.05, 10.0, 0.05, "suffix:s") var contact_rehit_interval: float = 0.8

@export_group("Death and feedback")
@export_range(0.0, 10.0, 0.05, "suffix:s") var death_fade_time: float = 1.0
## Visual hit flash only.
@export_range(0.0, 1.0, 0.01, "suffix:s") var hit_flash_time: float = 0.08
@export_group("Drops")
## Health orbs popped out when phase 2 starts and when the boss is defeated
## (orb behavior: backend/combat/default_health_orb_stats.tres).
@export_range(0, 20, 1) var health_orbs_on_phase_2: int = 2
@export_range(0, 20, 1) var health_orbs_on_defeat: int = 4

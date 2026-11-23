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
## Health ratios (descending) at which phase 2, 3... begin (Phase 15e-1). Empty (bosses 1 and 2) = the single threshold
## `phase_2_health_ratio`. Boss 3 uses [0.451, 0.2255] of its 102 HP (Phase 15p).
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array()
## The boss is invulnerable and idle while changing phase.
@export_range(0.0, 10.0, 0.1, "suffix:s") var phase_transition_time: float = 1.5
## Scales pattern timings and movement speeds in phase 2.
@export_range(0.1, 5.0, 0.05) var phase_2_speed_multiplier: float = 1.3
## Scales the gap between patterns in phase 2 (below 1 means less pause).
@export_range(0.05, 5.0, 0.05) var phase_2_pattern_gap_multiplier: float = 0.6
## Phase 3 numbers (0 = use the phase 2 value). The cooldown factor scales the cooldown of EVERY pattern in phase 3 (below 1
## = shorter); it never touches a telegraph.
@export_range(0.0, 5.0, 0.05) var phase_3_speed_multiplier: float = 0.0
@export_range(0.0, 5.0, 0.05) var phase_3_pattern_gap_multiplier: float = 0.0
@export_range(0.1, 2.0, 0.05) var phase_3_cooldown_factor: float = 1.0

@export_group("Patterns")
@export_range(0.0, 10.0, 0.05, "suffix:s") var pattern_gap_time: float = 1.2
@export var avoid_immediate_repeat: bool = true
## The longest the boss may stand without starting an attack (0 = no guarantee). When no pattern of the rotation is
## eligible (for example on a platform) the boss falls back to its patterns with a `fallback_priority`.
@export_range(0.0, 10.0, 0.1, "suffix:s") var max_idle_time: float = 0.0

@export_group("Contact damage")
## Damage dealt by touching the boss while it is fighting. 0 disables contact damage.
@export_range(0, 99, 1) var contact_damage: int = 1
@export var contact_knockback: Vector2 = Vector2(260.0, -140.0)
@export_range(0.05, 10.0, 0.05, "suffix:s") var contact_rehit_interval: float = 0.8

@export_group("Death and feedback")
@export_range(0.0, 10.0, 0.05, "suffix:s") var death_fade_time: float = 1.0
## Visual hit flash only.
@export_range(0.0, 1.0, 0.01, "suffix:s") var hit_flash_time: float = 0.08


## The ratios of the phase thresholds, descending (always at least one: the phase 2 line).
func get_phase_thresholds() -> PackedFloat32Array:
	if phase_thresholds.is_empty():
		return PackedFloat32Array([phase_2_health_ratio])
	return phase_thresholds


## Number of phases the boss has (thresholds + 1).
func phase_count() -> int:
	return get_phase_thresholds().size() + 1


func speed_multiplier_for(phase: int) -> float:
	if phase >= 3 and phase_3_speed_multiplier > 0.0:
		return phase_3_speed_multiplier
	return phase_2_speed_multiplier if phase >= 2 else 1.0


func gap_multiplier_for(phase: int) -> float:
	if phase >= 3 and phase_3_pattern_gap_multiplier > 0.0:
		return phase_3_pattern_gap_multiplier
	return phase_2_pattern_gap_multiplier if phase >= 2 else 1.0


func cooldown_factor_for(phase: int) -> float:
	return phase_3_cooldown_factor if phase >= 3 else 1.0

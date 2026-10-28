class_name FastEnemyStats
extends EnemyStats
## Stats for FastEnemy. The telegraph is attack_startup_time, the recovery is
## attack_recovery_time. The lunge replaces the active window: attack_active_time is unused.

@export_group("Lunge")
@export_range(0.0, 1500.0, 1.0, "suffix:px/s") var lunge_speed: float = 420.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var lunge_duration: float = 0.25
## Stop the lunge at a ledge instead of leaping off the platform.
@export var lunge_stop_on_ledge: bool = true
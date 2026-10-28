class_name RangedEnemyStats
extends EnemyStats
## Stats for RangedEnemy. Attack timing is inherited: attack_startup_time is the
## aim/charge, attack_active_time the instant of firing, then recovery and cooldown.
## attack_range is how far away a shot may start; attack_damage and the melee hitbox
## are unused (the projectile stats define the damage).
## preferred_range and attack_range are coupled settings: change one, review the other.

@export_group("Spacing")
@export_range(0.0, 1500.0, 1.0, "suffix:px") var preferred_range: float = 180.0
## Retreat when the target is closer than this (clamped below preferred_range at runtime).
@export_range(0.0, 1500.0, 1.0, "suffix:px") var min_range: float = 90.0
@export_range(0.0, 3.0, 0.05) var retreat_speed_multiplier: float = 0.8

@export_group("Projectile")
@export var projectile_stats: ProjectileStats
@export var projectile_scene: PackedScene
## Spawn point relative to the enemy; x is mirrored by facing.
@export var projectile_spawn_offset: Vector2 = Vector2(28.0, -4.0)
## true aims at the target's current position (kept in the half-plane the enemy faces).
## false fires horizontally.
@export var aim_at_target: bool = true
@export var shoot_requires_line_of_sight: bool = true
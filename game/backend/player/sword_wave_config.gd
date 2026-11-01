class_name SwordWaveConfig
extends Resource
## Data of the player's ranged sword wave: its power tiers, cast timings and the rules that map
## fragment decisions to a tier. No scene or UI knowledge besides the projectile scene it spawns.

@export var tiers: Array[SwordWaveTier] = []
@export_range(0.0, 2.0, 0.01, "suffix:s") var startup_time: float = 0.12
@export_range(0.0, 2.0, 0.01, "suffix:s") var recovery_time: float = 0.2
## Factor applied to the player's horizontal speed while casting.
@export_range(0.0, 1.0, 0.05) var horizontal_speed_multiplier: float = 0.4
@export var can_cast_in_air: bool = true
## How long an early press is remembered (at least one physics frame is used at runtime).
@export_range(0.0, 0.5, 0.01, "suffix:s") var input_buffer_time: float = 0.12
## Spawn point relative to the player; x is mirrored by facing.
@export var spawn_offset: Vector2 = Vector2(28.0, -4.0)
@export var projectile_scene: PackedScene
## fragment id -> choice ("kept" / "released") that upgrades the wave by one tier.
@export var upgrade_rules: Dictionary = {}


## Tier index for a list of decisions ({fragment_id, choice, ...}). Pure and deterministic: each
## fragment id counts at most once, invalid entries and ids without a rule are ignored.
func resolve_tier(decisions: Array) -> int:
	var counted: Dictionary = {}
	var tier: int = 0
	for entry: Variant in decisions:
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var fragment_id: Variant = data.get("fragment_id")
		var choice: Variant = data.get("choice")
		if not fragment_id is String or not choice is String or counted.has(fragment_id):
			continue
		if upgrade_rules.has(fragment_id) and String(upgrade_rules[fragment_id]) == choice:
			counted[fragment_id] = true
			tier += 1
	return clampi(tier, 0, maxi(tiers.size() - 1, 0))


## Tier at `index`, clamped to the available ones. Null only if there are no tiers.
func get_tier(index: int) -> SwordWaveTier:
	if tiers.is_empty():
		return null
	return tiers[clampi(index, 0, tiers.size() - 1)]


## Projectile values of a tier. The team is set at launch.
func build_projectile_stats(tier_index: int) -> ProjectileStats:
	var tier: SwordWaveTier = get_tier(tier_index)
	var stats := ProjectileStats.new()
	if tier == null:
		return stats
	stats.speed = tier.speed
	stats.damage = tier.damage
	stats.knockback = tier.knockback
	stats.lifetime = tier.lifetime
	stats.size_scale = tier.size_scale
	stats.pierce_count = tier.pierce_count
	stats.tint = tier.tint
	stats.gravity_scale = 0.0
	stats.destroy_on_hit = true
	stats.destroy_on_world = true
	return stats

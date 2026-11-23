class_name RunTelemetry
extends RefCounted
## What the player did, per level, kept IN MEMORY only (Phase 16a). Never saved (the save keeps its seven keys), never sent
## anywhere. It is a field of the Director, which GameState owns, and resets on a new game or a loaded save. It only stores
## numbers; the observer that feeds it lives in the level (TelemetryObserver). `summarize()` returns categories only
## (low / mid / high), never counts.

const METRICS: PackedStringArray = [
	"deaths", "damage_taken", "melee_damage", "ranged_damage", "boss_damage", "hazard_damage", "fall_deaths",
	"light_use", "heavy_use", "dash_slash_use", "wave_use", "dash_use", "double_jump_use", "heals", "kills",
	"low_health_time", "time_in_level", "time_in_boss",
]

const SOURCE_MELEE: String = "melee"
const SOURCE_RANGED: String = "ranged"
const SOURCE_BOSS: String = "boss"
const SOURCE_HAZARD: String = "hazard"
const SOURCE_FALL: String = "fall"
const SOURCE_OTHER: String = "other"

## Level number -> {"metrics": {metric: float}, "pattern_damage": {pattern_id: float}}.
var levels: Dictionary = {}
## Level number -> {gap index: falls}. Counts the falls into each gap for the stuck-player assist (Phase 15h-bis). It is NOT a metric: it
## is not in METRICS and `summarize()` never reads it, so the assist is never treated as the player's skill. Cleared by `reset()`.
var gap_falls: Dictionary = {}
## While above 0 nothing is recorded (developer actions must not count as the player's play).
var suppressed: int = 0


func reset() -> void:
	levels.clear()
	gap_falls.clear()


## Counts one fall into a gap of a level and returns the new total.
func record_gap_fall(level: int, gap_index: int) -> int:
	var per_level: Dictionary = gap_falls.get(level, {})
	per_level[gap_index] = int(per_level.get(gap_index, 0)) + 1
	gap_falls[level] = per_level
	return int(per_level[gap_index])


func gap_fall_count(level: int, gap_index: int) -> int:
	return int((gap_falls.get(level, {}) as Dictionary).get(gap_index, 0))


func has_level(level: int) -> bool:
	return levels.has(level)


func _record(level: int) -> Dictionary:
	if not levels.has(level):
		levels[level] = {"metrics": {}, "pattern_damage": {}}
	return levels[level]


## Adds `amount` to a metric of a level. Unknown metrics and non-positive amounts are ignored.
func add(level: int, metric: String, amount: float = 1.0) -> void:
	if suppressed > 0 or not METRICS.has(metric) or amount <= 0.0 or not is_finite(amount):
		return
	var metrics: Dictionary = _record(level)["metrics"]
	metrics[metric] = float(metrics.get(metric, 0.0)) + amount


func get_value(level: int, metric: String) -> float:
	if not levels.has(level):
		return 0.0
	return float((levels[level]["metrics"] as Dictionary).get(metric, 0.0))


## A weapon use by its attack kind (light, heavy, dash_slash, wave).
func add_weapon(level: int, kind: StringName) -> void:
	match String(kind):
		"light":
			add(level, "light_use")
		"heavy":
			add(level, "heavy_use")
		"dash_slash":
			add(level, "dash_slash_use")
		"wave":
			add(level, "wave_use")


## Damage the player took, by the category of its source. A fall (kill zone) counts as a fall, not as hearts.
func record_damage(level: int, source: Node, amount: int) -> void:
	if suppressed > 0:
		return
	_record(level)
	var category: String = source_category(source)
	if category == SOURCE_FALL:
		add(level, "fall_deaths")
		return
	if amount <= 0:
		return
	add(level, "damage_taken", float(amount))
	match category:
		SOURCE_MELEE:
			add(level, "melee_damage", float(amount))
		SOURCE_RANGED:
			add(level, "ranged_damage", float(amount))
		SOURCE_HAZARD:
			add(level, "hazard_damage", float(amount))
		SOURCE_BOSS:
			add(level, "boss_damage", float(amount))
			var pattern: String = _active_pattern_of(source)
			if not pattern.is_empty():
				add_pattern_damage(level, pattern, float(amount))


func add_pattern_damage(level: int, pattern_id: String, amount: float) -> void:
	if suppressed > 0 or pattern_id.is_empty() or amount <= 0.0:
		return
	var damage: Dictionary = _record(level)["pattern_damage"]
	damage[pattern_id] = float(damage.get(pattern_id, 0.0)) + amount


## The boss pattern that hurt the player the most in a level ("" when none did). Ties go to the alphabetically first id.
func worst_pattern(level: int) -> String:
	if not levels.has(level):
		return ""
	var damage: Dictionary = levels[level]["pattern_damage"]
	var best: String = ""
	var best_value: float = 0.0
	var ids: Array = damage.keys()
	ids.sort()
	for id: Variant in ids:
		if float(damage[id]) > best_value:
			best_value = float(damage[id])
			best = String(id)
	return best


## Only categories (low / mid / high) per metric, from the thresholds of the config.
func summarize(level: int, config: TelemetryConfig = null) -> Dictionary:
	var cfg: TelemetryConfig = config if config != null else TelemetryConfig.get_default()
	var summary: Dictionary = {}
	for metric in METRICS:
		summary[metric] = cfg.categorize(metric, get_value(level, metric))
	return summary


## The category of the thing that hurt the player: the enemy, boss, hazard or kill zone that owns `source` (a projectile
## counts as its shooter, a hitbox as its owner).
static func source_category(source: Node) -> String:
	var node: Node = source
	for i in 6:
		if node == null:
			break
		if node is Projectile:
			node = (node as Projectile).source
			continue
		if node is BossBase:
			return SOURCE_BOSS
		if node is RangedEnemy:
			return SOURCE_RANGED
		if node is EnemyBase:
			return SOURCE_MELEE
		if node is FloorHazard or node is ElectricPlate:
			return SOURCE_HAZARD
		if node is KillZone:
			return SOURCE_FALL
		node = node.get_parent()
	return SOURCE_OTHER


static func _active_pattern_of(source: Node) -> String:
	var node: Node = source
	for i in 6:
		if node == null:
			return ""
		if node is Projectile:
			node = (node as Projectile).source
			continue
		if node is BossBase:
			return String((node as BossBase).current_pattern_id)
		node = node.get_parent()
	return ""

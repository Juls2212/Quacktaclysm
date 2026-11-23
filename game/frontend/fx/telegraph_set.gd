class_name TelegraphSet
extends Resource
## The telegraph styles of every enemy type and boss pattern (default_telegraphs.tres), one entry per
## kind. `entries` is an untyped Array on purpose (typed arrays of script classes leak at exit).

const DEFAULT_PATH: String = "res://frontend/fx/default_telegraphs.tres"
const KIND_MELEE: StringName = &"melee"
const KIND_MELEE_TOUGH: StringName = &"melee_tough"
const KIND_FAST: StringName = &"fast"
const KIND_RANGED: StringName = &"ranged"
const KIND_BOSS_SWIPE: StringName = &"boss_swipe"
const KIND_BOSS_CHARGE: StringName = &"boss_charge"
const KIND_BOSS_VOLLEY: StringName = &"boss_volley"
const KIND_BOSS_LEAP: StringName = &"boss_leap"
const KIND_BOSS_BEAM: StringName = &"boss_beam"
const KIND_BOSS_COLUMNS: StringName = &"boss_columns"
const KINDS: Array[StringName] = [KIND_MELEE, KIND_MELEE_TOUGH, KIND_FAST, KIND_RANGED, KIND_BOSS_SWIPE, KIND_BOSS_CHARGE, KIND_BOSS_VOLLEY, KIND_BOSS_LEAP, KIND_BOSS_BEAM, KIND_BOSS_COLUMNS]
## Max health from which a melee enemy counts as the tough variant (same rule as EnemyVisual).
const TOUGH_HEALTH: int = 6

@export var entries: Array = []


static func get_default() -> TelegraphSet:
	return load(DEFAULT_PATH) as TelegraphSet


## The style of `kind`, or null.
func get_style(kind: StringName) -> TelegraphStyle:
	for entry: Variant in entries:
		var style := entry as TelegraphStyle
		if style != null and style.kind == kind:
			return style
	return null


func has_all_kinds() -> bool:
	for kind in KINDS:
		if get_style(kind) == null:
			return false
	return true


## The kind of an enemy node (duck-typed: no reference to the enemy classes).
static func kind_of_enemy(enemy: Node) -> StringName:
	if enemy.get("fast_stats") != null:
		return KIND_FAST
	if enemy.get("ranged_stats") != null:
		return KIND_RANGED
	var stats: Variant = enemy.get("stats")
	if stats != null and int((stats as Object).get("max_health")) >= TOUGH_HEALTH:
		return KIND_MELEE_TOUGH
	return KIND_MELEE


## The kind of a boss pattern from its id (swipe, charge, volley, volley_light, volley_heavy...).
static func kind_of_pattern(pattern_id: StringName) -> StringName:
	var id: String = String(pattern_id)
	if id.begins_with("charge"):
		return KIND_BOSS_CHARGE
	if id.begins_with("volley"):
		return KIND_BOSS_VOLLEY
	if id.begins_with("leap"):
		return KIND_BOSS_LEAP
	if id.begins_with("beam"):
		return KIND_BOSS_BEAM
	if id.begins_with("columns"):
		return KIND_BOSS_COLUMNS
	return KIND_BOSS_SWIPE

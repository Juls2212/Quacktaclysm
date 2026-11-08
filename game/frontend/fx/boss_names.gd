class_name BossNames
extends RefCounted
## The names the player sees for each guardian (presentation and boss bar). Display only: the
## boss data keeps its own names.

## Level number -> {"name", "subtitle"}.
const BY_LEVEL: Dictionary = {
	1: {"name": "EL LEÑADOR", "subtitle": "El primer guardián"},
	2: {"name": "LA COSA DEL PANTANO", "subtitle": "El que respira bajo el lodo"},
	3: {"name": "EL OJO DE LA TORMENTA", "subtitle": "El último guardián"},
}


## The level number of the nearest ancestor of `node` that has one (0 when none).
static func level_number_of(node: Node) -> int:
	var n: Node = node
	while n != null:
		var value: Variant = n.get(&"level_number")
		if value != null and int(value) > 0:
			return int(value)
		n = n.get_parent()
	return 0


## The level number that matches a boss look (used when the level has no number).
static func level_for_look(look: int) -> int:
	match look:
		DuckRig.Look.BOSS_SWAMP:
			return 2
		DuckRig.Look.BOSS_STORM:
			return 3
	return 1


## The look of a boss's drawing, or -1 when it has none.
static func look_of(boss: Node) -> int:
	if boss == null or not is_instance_valid(boss):
		return -1
	var visual: Node = boss.get_node_or_null(^"Visual")
	if visual == null:
		return -1
	var look: Variant = visual.get(&"look")
	return int(look) if look != null else -1


## {"name", "subtitle"} for a boss: by the level `context` belongs to, else by the boss's look.
## Empty when neither is known.
static func info_for(boss: Node, context: Node, table: Dictionary = BY_LEVEL) -> Dictionary:
	var number: int = level_number_of(context)
	if not table.has(number):
		var look: int = look_of(boss)
		if look < 0:
			return {}
		number = level_for_look(look)
	var info: Variant = table.get(number, {})
	return info as Dictionary if info is Dictionary else {}

class_name EnemyLevelStyle
extends Node
## Gives the level's common enemies their per-level look (DuckRig.level_style), visual only.
## When the level starts it walks the enemies (the "enemies" group if anything uses it, plus every
## EnemyBase under the level's Content) and sets the style on their drawn duck (Visual/Rig). It
## never touches the enemy scenes, their stats or their behaviour; bosses are left alone.

@export var style: DuckRig.LevelStyle = DuckRig.LevelStyle.NONE


func _ready() -> void:
	# After the level's own _ready (it removes the variant enemies first).
	_apply.call_deferred()


func _apply() -> void:
	if style == DuckRig.LevelStyle.NONE or not is_inside_tree():
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	var content: Node = get_parent().get_node_or_null(^"Content") if get_parent() != null else null
	if content != null:
		for node in content.find_children("*", "", true, false):
			if node is EnemyBase and not enemies.has(node):
				enemies.append(node)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy is BossBase:
			continue
		for rig in enemy.find_children("*", "", true, false):
			if rig is DuckRig:
				(rig as DuckRig).level_style = style

class_name GapGuard
extends Node
## Rules for the gaps of a level (Phase 15h-bis), placed in the level scene beside its Content node. It finds the gaps between the
## named floors and (1) tells every ground enemy to keep `enemy_edge_keepout` px away from a missing floor, so none can stand at a
## takeoff point or knock the player off the last floor pixels; (2) counts, in memory only (the telemetry the Director owns: never saved,
## reset on a new game and on a loaded save), the falls into each gap and, at `assist_falls`, adds a one-way wreck platform in the
## middle of that gap for the rest of the session. The platform is not skill: nothing the telemetry sums or the Director reads counts it.

@export var config: GapSafetyConfig
@export var level_number: int = 3
@export var content_path: NodePath = ^"../Content"
## Names of the floors, left to right, under Content.
@export var floor_names: PackedStringArray = PackedStringArray()
@export var platform_scene: PackedScene

## [start x, end x] of every gap, from the floors.
var gaps: Array[Vector2] = []
## Gap index -> the assist platform node.
var assists: Dictionary = {}

var _player: Player = null


func _ready() -> void:
	if config == null:
		config = GapSafetyConfig.get_default()
	var content: Node = get_node_or_null(content_path)
	if content == null:
		return
	var previous: Node2D = null
	for floor_name in floor_names:
		var current := content.get_node_or_null(NodePath(floor_name)) as Node2D
		if current == null:
			continue
		if previous != null:
			gaps.append(Vector2(_right(previous), _left(current)))
		previous = current
	_setup.call_deferred()


func _left(platform: Node2D) -> float:
	return platform.position.x - float(platform.get("size").x) * 0.5


func _right(platform: Node2D) -> float:
	return platform.position.x + float(platform.get("size").x) * 0.5


func _setup() -> void:
	var content: Node = get_node_or_null(content_path)
	if content == null:
		return
	for child in content.get_children():
		if child is EnemyBase and (child as Node2D).position.y >= config.ground_enemy_min_y:
			(child as EnemyBase).set_edge_keepout(config.enemy_edge_keepout)
	var level: Node = get_parent()
	if level != null and level.get("player") is Player:
		_player = level.get("player") as Player
		_player.died.connect(_on_player_died)
	# A gap that already earned its platform in this session has it again when the level is entered again.
	for index in gaps.size():
		if GameState.director.telemetry.gap_fall_count(level_number, index) >= config.assist_falls:
			_add_assist(index)


## The index of the gap whose span (with a little margin) holds x, or -1.
func gap_index_at(x: float) -> int:
	for index in gaps.size():
		if x >= gaps[index].x - 80.0 and x <= gaps[index].y + 80.0:
			return index
	return -1


func _on_player_died() -> void:
	if _player == null or _player.global_position.y < config.fall_y:
		return
	var index: int = gap_index_at(_player.global_position.x)
	if index < 0:
		return
	var count: int = GameState.director.telemetry.record_gap_fall(level_number, index)
	if count >= config.assist_falls:
		_add_assist(index)


func _add_assist(index: int) -> void:
	if assists.has(index) or index < 0 or index >= gaps.size() or platform_scene == null:
		return
	var content: Node = get_node_or_null(content_path)
	if content == null:
		return
	var platform := platform_scene.instantiate() as Node2D
	platform.name = "AssistWreck%d" % (index + 1)
	platform.set("size", Vector2(config.assist_width, config.assist_thickness))
	platform.set("one_way", true)
	platform.set("color", config.assist_color)
	platform.set("skin", config.assist_skin)
	platform.position = Vector2((gaps[index].x + gaps[index].y) * 0.5, config.assist_top_y + config.assist_thickness * 0.5)
	assists[index] = platform
	# Phase 15q: the player's death arrives inside the kill zone's body_entered (a physics callback); adding a StaticBody2D there changes physics
	# state while queries flush, so the platform joins the tree deferred.
	_attach_assist.call_deferred(content, platform)


func _attach_assist(content: Node, platform: Node2D) -> void:
	if is_instance_valid(content) and content.is_inside_tree():
		content.add_child(platform)
	else:
		platform.free()

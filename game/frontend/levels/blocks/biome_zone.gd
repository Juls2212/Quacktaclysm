class_name BiomeZone
extends Area2D
## Line between two biomes of a level, standing at this node's x. Visual only.
## While the player is right of the line the level's Backdrop shows `biome`; left of it,
## `biome_before` (empty = the level's own biome). Walking across cross-fades over
## `transition_time`; a jump of position (spawn at a saved checkpoint, respawn) switches at once,
## so a player restored at a checkpoint past the line sees zone B straight away.
## Platforms whose center lies past the line are painted with `biome` too (their TerrainSkin only).
## The player is detected like Checkpoint and BossEncounter do (the player collision layer), or
## read from the level's `player`; nothing on the player is touched. No physics: the area is on no
## layer and is not monitorable, so nothing can hit or detect it.

## Teleports (respawn, checkpoint restore) move the player farther than this in one frame.
const TELEPORT_DISTANCE: float = 320.0

@export var biome: Biome
## Biome left of the line. Empty: the level's biome (LevelBase.biome).
@export var biome_before: Biome
@export var transition_time: float = 1.5
## Paint the platforms past the line with `biome` (ground, rocks, grass).
@export var retint_terrain: bool = true
## Pixels past the line before switching, so standing on it never flickers.
@export var hysteresis: float = 24.0

var _player: Node2D = null
var _backdrop: Backdrop = null
## -1 left of the line, 1 right of it, 0 not decided yet.
var _side: int = 0
var _last_x: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER)
	monitorable = false
	body_entered.connect(_on_body_entered)
	_backdrop = _find_backdrop()
	if retint_terrain and biome != null:
		# Deferred: every platform of the level has built its skin by then.
		_retint_terrain.call_deferred()


## The biome this zone wants on screen right now (null before the player is found).
func get_active_biome() -> Biome:
	if _side == 0:
		return null
	return biome if _side > 0 else _biome_before()


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
		_last_x = _player.global_position.x
	var px: float = _player.global_position.x
	var dx: float = px - global_position.x
	var side: int = _side
	if _side == 0:
		side = 1 if dx >= 0.0 else -1
	elif dx > hysteresis:
		side = 1
	elif dx < -hysteresis:
		side = -1
	var teleported: bool = absf(px - _last_x) > TELEPORT_DISTANCE
	_last_x = px
	if side == _side:
		return
	var instant: bool = _side == 0 or teleported
	_side = side
	if _backdrop == null or not is_instance_valid(_backdrop):
		_backdrop = _find_backdrop()
	if _backdrop != null:
		_backdrop.show_biome(get_active_biome(), 0.0 if instant else transition_time)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body


func _biome_before() -> Biome:
	if biome_before != null:
		return biome_before
	if _backdrop != null and _backdrop.biome != null:
		return _backdrop.biome
	var node: Node = get_parent()
	while node != null:
		var value: Variant = node.get(&"biome")
		if value is Biome:
			return value
		node = node.get_parent()
	return null


## The player of the level (read only): the nearest ancestor's `player`.
func _find_player() -> Node2D:
	var node: Node = get_parent()
	while node != null:
		var value: Variant = node.get(&"player")
		if value is Player:
			return value
		node = node.get_parent()
	return null


## The Backdrop the level draws behind its play field (a child of some ancestor).
func _find_backdrop() -> Backdrop:
	var node: Node = get_parent()
	while node != null:
		for child in node.get_children():
			if child is Backdrop:
				return child
		node = node.get_parent()
	return null


func _retint_terrain() -> void:
	var root: Node = get_parent()
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var platform := node as PlaceholderPlatform
		if platform != null and platform.terrain != null and platform.global_position.x > global_position.x:
			platform.terrain.biome = biome
		for child in node.get_children():
			stack.append(child)

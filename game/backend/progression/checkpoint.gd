class_name Checkpoint
extends Area2D
## On its FIRST activation sets the respawn point of the body that enters (anything with
## `set_respawn_point`), records itself in GameState and autosaves. Later touches do nothing,
## so an older checkpoint never moves the respawn point backwards. Emits `activated` once.

signal activated(checkpoint_id: StringName)

const GROUP: StringName = &"checkpoints"

@export var checkpoint_id: StringName = &""
## Future ordering hint among a level's checkpoints. Not used for any logic yet.
@export var order: int = 0
@export var respawn_offset: Vector2 = Vector2(0.0, -30.0)
@export var inactive_color: Color = Color(0.5, 0.5, 0.55, 1.0)
@export var active_color: Color = Color(0.3, 0.9, 0.4, 1.0)

var is_activated: bool = false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER)
	monitorable = false
	visual.color = inactive_color
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)


## First checkpoint in the "checkpoints" group with this id, or null.
static func find_checkpoint(tree: SceneTree, id: String) -> Checkpoint:
	for node in tree.get_nodes_in_group(GROUP):
		var candidate := node as Checkpoint
		if candidate != null and String(candidate.checkpoint_id) == id:
			return candidate
	return null


## World position where a player respawns for this checkpoint.
func get_respawn_position() -> Vector2:
	return global_position + respawn_offset


func _on_body_entered(body: Node2D) -> void:
	if is_activated or not body.has_method("set_respawn_point"):
		return
	body.set_respawn_point(get_respawn_position())
	GameState.set_checkpoint(String(checkpoint_id))
	GameState.autosave()
	is_activated = true
	visual.color = active_color
	activated.emit(checkpoint_id)

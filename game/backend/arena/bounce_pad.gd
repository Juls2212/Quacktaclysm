class_name BouncePad
extends Area2D
## A lily-pad trampoline (Phase 15c). When the player comes down onto it from above it launches the
## player straight up with `config.launch_velocity`, then waits `config.cooldown`. Enemies and bosses ignore it
## (its mask only sees the player). Gameplay only: the drawing is the child BouncePadArt, which listens to
## `launched`. `texture` is an optional replacement for the drawn pad (null = drawn in code).
## Phase 15d-bis: the pad is raised `config.pad_height` px above the floor on a spring stem (drawn by BouncePadArt, not
## solid). The node position is the CENTER of the trigger area: the top of the pad is at y - (trigger_size.y / 2 - top_margin)
## and the floor under it at that plus `pad_height`.

signal launched(player: Player)

const GROUP: StringName = &"bounce_pads"
## The player must be falling at least this fast to be launched (walking onto the pad does nothing).
const MIN_FALL_SPEED: float = 20.0

@export var config: BounceConfig
## Optional art: replaces the code drawing when set.
@export var texture: Texture2D

var cooldown_left: float = 0.0
var launch_count: int = 0


func _ready() -> void:
	if config == null:
		config = BounceConfig.get_default()
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER)
	monitorable = false
	monitoring = true
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var rect := RectangleShape2D.new()
		rect.size = config.trigger_size
		shape_node.shape = rect


## Global y of the top surface of the pad.
func top_y() -> float:
	return global_position.y - (config.trigger_size.y * 0.5 - config.top_margin)


## Global y of the floor the stem stands on.
func floor_y() -> float:
	return top_y() + config.pad_height


## Horizontal extent of the pad in global x (the floor hazard leaves pads safe).
func global_x_range() -> Vector2:
	var half: float = config.trigger_size.x * 0.5
	return Vector2(global_position.x - half, global_position.x + half)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if cooldown_left > 0.0:
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null and _lands_on_top(player) and player.launch_up(config.launch_velocity):
			cooldown_left = config.cooldown
			launch_count += 1
			launched.emit(player)
			return


## From above: the player is coming DOWN (not rising, not just walking over it) and its center is over the pad.
func _lands_on_top(player: Player) -> bool:
	return player.velocity.y > MIN_FALL_SPEED and player.global_position.y < global_position.y

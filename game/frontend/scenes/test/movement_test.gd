extends Node2D
## Sandbox for tuning player movement. Debug-only; not part of the player.

const RESPAWN_Y: float = 1400.0

@onready var player: Player = $Player
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	player.global_position = spawn_point.global_position


func _physics_process(_delta: float) -> void:
	if player.global_position.y > RESPAWN_Y:
		player.global_position = spawn_point.global_position
		player.velocity = Vector2.ZERO


func _process(_delta: float) -> void:
	debug_label.text = "state: %s\nvelocity: (%d, %d)\non_floor: %s\nair dashes left: %d\ndash invulnerable: %s" % [
		Player.State.keys()[player.state],
		player.velocity.x,
		player.velocity.y,
		player.is_on_floor(),
		player.air_dashes_left,
		player.is_dash_invulnerable,
	]

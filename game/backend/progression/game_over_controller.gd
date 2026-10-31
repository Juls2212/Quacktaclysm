class_name GameOverController
extends Node
## Replaces the player's automatic respawn with a Game Over panel (retry / main menu).
## With `show_game_over = false` the player keeps respawning automatically.

@export var player: Player
@export var panel: GameOverPanel
@export var show_game_over: bool = true
@export var open_delay: float = 0.8

var _delay_left: float = 0.0
var _waiting: bool = false


func _ready() -> void:
	set_physics_process(false)
	if player == null or panel == null:
		return
	player.set_auto_respawn(not show_game_over)
	player.died.connect(_on_player_died)
	panel.retry_requested.connect(_on_retry_requested)
	panel.menu_requested.connect(_on_menu_requested)


func _physics_process(delta: float) -> void:
	_delay_left -= delta
	if _delay_left > 0.0:
		return
	_waiting = false
	set_physics_process(false)
	if is_instance_valid(player) and player.is_dead and is_instance_valid(panel) and not panel.is_open():
		panel.open()


func _on_player_died() -> void:
	if not show_game_over or _waiting or not is_instance_valid(panel) or panel.is_open():
		return
	_waiting = true
	_delay_left = open_delay
	set_physics_process(true)


func _on_retry_requested() -> void:
	if is_instance_valid(panel):
		panel.close()
	if is_instance_valid(player):
		player.respawn()


func _on_menu_requested() -> void:
	if is_instance_valid(panel):
		panel.close()
	SceneManager.go_to_main_menu()

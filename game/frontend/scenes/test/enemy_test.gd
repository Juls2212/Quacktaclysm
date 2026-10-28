extends Node2D
## Sandbox for melee enemies. Debug keys are handled here only (not in the input map):
## R respawns the player, L reloads the scene, K kills all enemies.

@onready var player: Player = $Player
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var hud: PlayerHealthHud = $Hud
@onready var enemies_root: Node2D = $Enemies
@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	player.global_position = spawn_point.global_position
	player.set_respawn_point(spawn_point.global_position)
	hud.bind(player)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			player.respawn()
		KEY_L:
			get_tree().reload_current_scene()
		KEY_K:
			for enemy in enemies_root.get_children():
				(enemy as EnemyBase).health.kill()


func _process(_delta: float) -> void:
	var lines: PackedStringArray = ["[J/X/click] attack  [R] respawn  [L] reload  [K] kill enemies"]
	for child in enemies_root.get_children():
		var enemy := child as EnemyBase
		lines.append("%s (%s): %s  hp %d/%d" % [
			enemy.name,
			enemy.get_script().get_global_name(),
			EnemyBase.State.keys()[enemy.state],
			enemy.health.current_health,
			enemy.health.max_health,
		])
	debug_label.text = "\n".join(lines)

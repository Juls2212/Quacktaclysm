class_name BossEncounter
extends Area2D
## Starts the boss fight when the player enters, resets it when the player dies and
## stays disarmed once the boss is defeated. No arena locking or cutscenes.

signal encounter_started
signal encounter_won

@export var boss: BossBase

var _armed: bool = true
var _won: bool = false
var _player: Node2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER)
	body_entered.connect(_on_body_entered)
	if boss:
		boss.defeated.connect(_on_boss_defeated)


func _physics_process(_delta: float) -> void:
	# Also catches a player who was already inside (e.g. respawned in the trigger).
	if not _armed or _won:
		return
	for body in get_overlapping_bodies():
		_try_start(body)


## Debug helper: resets the boss and re-arms the trigger.
func reset() -> void:
	if is_instance_valid(boss):
		boss.reset_encounter()
	_disconnect_player()
	_armed = not _won


func _on_body_entered(body: Node2D) -> void:
	_try_start(body)


func _try_start(body: Node2D) -> void:
	if not _armed or _won or not is_instance_valid(boss) or boss.state != BossBase.State.INACTIVE:
		return
	if not body.has_signal("died") or body.get("is_dead") == true:
		return
	# The overlap list is stale for one physics frame after a teleport (respawn): require the
	# body to really be inside the trigger so a respawn outside it never starts the fight.
	if not _is_inside(body):
		return
	_armed = false
	_player = body
	body.connect("died", _on_player_died)
	boss.activate(body)
	encounter_started.emit()


func _is_inside(body: Node2D) -> bool:
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null and shape_node.shape != null:
			var local: Vector2 = shape_node.global_transform.affine_inverse() * body.global_position
			if shape_node.shape.get_rect().has_point(local):
				return true
	return false


func _on_player_died() -> void:
	if is_instance_valid(boss):
		boss.reset_encounter()
	_disconnect_player()
	_armed = not _won


func _disconnect_player() -> void:
	if is_instance_valid(_player) and _player.is_connected("died", _on_player_died):
		_player.disconnect("died", _on_player_died)
	_player = null


func _on_boss_defeated(_defeated_boss: BossBase) -> void:
	_won = true
	_armed = false
	_disconnect_player()
	encounter_won.emit()
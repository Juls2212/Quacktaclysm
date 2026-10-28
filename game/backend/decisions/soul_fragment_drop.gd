class_name SoulFragmentDrop
extends Node
## Spawns one soul fragment when the assigned boss is defeated (and only then).
## The fragment is added to the current scene, never under the boss.

signal fragment_spawned(fragment: SoulFragment)

@export var boss: BossBase
@export var fragment_data: SoulFragmentData
@export var fragment_scene: PackedScene
@export var spawn_delay: float = 0.8
@export var spawn_offset: Vector2 = Vector2(0.0, -40.0)

var _pending: bool = false
var _spawned: bool = false
var _time_left: float = 0.0
var _spawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_physics_process(false)
	if boss:
		boss.defeated.connect(_on_boss_defeated)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_spawn()


func _on_boss_defeated(defeated_boss: BossBase) -> void:
	if _pending or _spawned or fragment_data == null or fragment_scene == null:
		return
	if GameState.has_decision(fragment_data.fragment_id):
		return
	# Stored now: the boss node is freed shortly after its death fade.
	_spawn_position = defeated_boss.global_position + spawn_offset
	_time_left = spawn_delay
	_pending = true
	set_physics_process(true)


func _spawn() -> void:
	set_physics_process(false)
	_pending = false
	var scene: Node = get_tree().current_scene
	if _spawned or scene == null:
		return
	_spawned = true
	var fragment := fragment_scene.instantiate() as SoulFragment
	fragment.data = fragment_data
	scene.add_child(fragment)
	fragment.global_position = _spawn_position
	fragment_spawned.emit(fragment)

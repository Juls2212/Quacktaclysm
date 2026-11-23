class_name ElectricPlate
extends Node2D
## An electric floor plate (Phase 15g), the level 3 counterpart of the swamp spikes. A cycle of WARNING (it hums and sparks gather,
## nothing hurts) -> ACTIVE (it shocks) -> REST, timings from `config`, running from the start of the level. Damage goes through the
## normal Hitbox / DamageInfo path (ENEMY team: it can hurt only the player), so the hurt invulnerability and the dash invulnerability
## of the player apply; it is NOT a KillZone, the plate covers only part of a stretch and platforms above it are always safe.
## The node position is the LEFT end of the plate at the floor surface; `length` runs to the right. Gameplay only: the drawing is the
## child ElectricPlateArt (it listens to `state_changed`).

signal state_changed(new_state: int)

const GROUP: StringName = &"electric_plates"

enum State { REST, WARNING, ACTIVE }

@export var config: ElectricPlateConfig
@export_range(40.0, 1000.0, 1.0, "suffix:px") var length: float = 220.0
## Seconds into the cycle at the start (several plates out of step).
@export_range(0.0, 60.0, 0.1, "suffix:s") var start_offset: float = 0.0

var state: State = State.REST
var state_time: float = 0.0
var cycles_completed: int = 0

var _hitbox: Hitbox = null


func _ready() -> void:
	if config == null:
		config = ElectricPlateConfig.get_default()
	add_to_group(GROUP)
	_hitbox = get_node_or_null(^"Hitbox") as Hitbox
	if _hitbox != null:
		_hitbox.damage = config.damage
		_hitbox.knockback = config.knockback
		_hitbox.rehit_interval = config.rehit_interval
		var shape_node := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(length, config.band_height)
		shape_node.shape = rect
		shape_node.position = Vector2(length * 0.5, -config.band_height * 0.5)
		_hitbox.add_child(shape_node)
	_start_at(start_offset)


func cycle_length() -> float:
	return config.warning_time + config.active_time + config.rest_time


func state_duration(of_state: State) -> float:
	match of_state:
		State.WARNING:
			return config.warning_time
		State.ACTIVE:
			return config.active_time
	return config.rest_time


## The plate in global x (the part of the floor that can shock).
func global_x_range() -> Vector2:
	return Vector2(global_position.x, global_position.x + length)


func is_dangerous() -> bool:
	return state == State.ACTIVE


func _start_at(offset: float) -> void:
	var position_in_cycle: float = fmod(offset, maxf(cycle_length(), 0.001))
	if position_in_cycle < config.warning_time:
		_set_state(State.WARNING)
		state_time = position_in_cycle
	elif position_in_cycle < config.warning_time + config.active_time:
		_set_state(State.ACTIVE)
		state_time = position_in_cycle - config.warning_time
	else:
		_set_state(State.REST)
		state_time = position_in_cycle - config.warning_time - config.active_time


func _physics_process(delta: float) -> void:
	state_time += delta
	if state_time < state_duration(state):
		return
	match state:
		State.WARNING:
			_set_state(State.ACTIVE)
		State.ACTIVE:
			_set_state(State.REST)
		State.REST:
			cycles_completed += 1
			_set_state(State.WARNING)


func _set_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	if _hitbox != null:
		if new_state == State.ACTIVE:
			_hitbox.activate()
		else:
			_hitbox.deactivate()
	state_changed.emit(int(new_state))

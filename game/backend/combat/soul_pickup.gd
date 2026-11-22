class_name SoulPickup
extends Node2D
## The soul wisp that leaves a dead enemy or boss and flies to the player, who absorbs it (it replaces the
## health orbs). It always draws the existing SoulWisp effect; if the player is alive the wisp homes in on
## them and adds its amount to their Soul meter on arrival, or at the latest after
## SoulConfig.wisp_absorb_time. With nobody to absorb it, it only fades. It never heals and never blocks
## anything: no collision, no physics. `SoulPickup.spawn(container, position, amount)`.

var amount: int = 0
var absorb_time: float = 0.8

var _target: Player = null
var _age: float = 0.0
var _done: bool = false


static func spawn(container: Node, at: Vector2, soul_amount: int) -> SoulPickup:
	if container == null or not container.is_inside_tree():
		return null
	var pickup := SoulPickup.new()
	pickup.name = "SoulPickup"
	pickup.amount = soul_amount
	pickup.absorb_time = SoulConfig.get_default().wisp_absorb_time
	pickup.z_index = 6
	container.add_child(pickup)
	pickup.global_position = at
	var found := container.get_tree().get_first_node_in_group(&"player") as Player
	if found != null and not found.is_dead:
		pickup._target = found
	SoulWisp.spawn(pickup, at)
	return pickup


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var alive: bool = _target != null and is_instance_valid(_target) and not _target.is_dead
	if alive:
		var destination: Vector2 = _target.global_position + Vector2(0.0, -16.0)
		global_position = global_position.move_toward(destination, (220.0 + 1100.0 * _age) * delta)
		if global_position.distance_to(destination) < 18.0 or _age >= absorb_time:
			_absorb()
			return
	elif _age >= absorb_time:
		_finish()


func _absorb() -> void:
	var soul: SoulComponent = _target.get_node_or_null(^"Soul") as SoulComponent
	if soul != null and amount > 0:
		soul.add_soul(amount)
	_finish()


func _finish() -> void:
	_done = true
	queue_free()

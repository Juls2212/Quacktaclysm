class_name HealthComponent
extends Node
## Health with post-hit invulnerability frames. Generic: knows nothing about its owner.

signal health_changed(current: int, maximum: int)
signal damaged(info: DamageInfo)
signal invulnerability_started
signal invulnerability_ended
signal died

@export var max_health: int = 10
## Seconds of invulnerability after taking damage. 0 disables i-frames.
@export var invulnerability_time: float = 0.0

var current_health: int = 0
var is_dead: bool = false

var _invulnerable_left: float = 0.0


func _ready() -> void:
	current_health = max_health


func _physics_process(delta: float) -> void:
	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		if _invulnerable_left <= 0.0:
			_invulnerable_left = 0.0
			invulnerability_ended.emit()


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Returns true if damage was actually applied.
func apply_damage(info: DamageInfo) -> bool:
	if is_dead or is_invulnerable() or info.amount <= 0:
		return false
	current_health = maxi(current_health - info.amount, 0)
	health_changed.emit(current_health, max_health)
	damaged.emit(info)
	if current_health == 0:
		is_dead = true
		died.emit()
	elif invulnerability_time > 0.0:
		_invulnerable_left = invulnerability_time
		invulnerability_started.emit()
	return true


## Lethal damage that ignores invulnerability (kill zones). Returns true if it killed.
func kill(source: Node = null) -> bool:
	if is_dead:
		return false
	if is_invulnerable():
		_invulnerable_left = 0.0
		invulnerability_ended.emit()
	return apply_damage(DamageInfo.create(maxi(current_health, 1), Vector2.ZERO, source))


## Starts (or extends) invulnerability using the normal i-frame mechanism.
func grant_invulnerability(time: float) -> void:
	if time <= 0.0 or is_dead:
		return
	var was_invulnerable: bool = is_invulnerable()
	_invulnerable_left = maxf(_invulnerable_left, time)
	if not was_invulnerable:
		invulnerability_started.emit()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


## Restores full health and clears dead/invulnerable state.
func reset() -> void:
	var was_invulnerable: bool = is_invulnerable()
	current_health = max_health
	is_dead = false
	_invulnerable_left = 0.0
	health_changed.emit(current_health, max_health)
	if was_invulnerable:
		invulnerability_ended.emit()

class_name SoulFragment
extends Area2D
## Floating placeholder pickup. Emits `collected` once when the player touches it and
## plays a short effect on `Visual` when resolved. Replace the Visual to change the look.

signal collected(fragment: SoulFragment)

const EFFECT_TIME: float = 0.6
const RELEASE_RISE: float = 90.0
const BOB_AMPLITUDE: float = 6.0
const BOB_SPEED: float = 2.5

@export var data: SoulFragmentData

var _consumed: bool = false
var _resolved: bool = false
var _collector: Node2D = null
var _time: float = 0.0
var _tween: Tween = null

@onready var visual: Node2D = $Visual


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER)
	body_entered.connect(_on_body_entered)
	if data:
		visual.modulate = data.tint
	_time = randf() * TAU


func _exit_tree() -> void:
	if _tween:
		_tween.kill()
		_tween = null


func _process(delta: float) -> void:
	_time += delta
	visual.position.y = sin(_time * BOB_SPEED) * BOB_AMPLITUDE


func is_consumed() -> bool:
	return _consumed


## Plays the effect for `choice` and frees the fragment. Safe to call more than once.
func resolve(choice: String) -> void:
	if _resolved or not is_inside_tree():
		return
	_resolved = true
	_consumed = true
	set_process(false)
	_tween = create_tween()
	_tween.set_parallel(true)
	if choice == GameState.CHOICE_KEPT:
		var target_position: Vector2 = Vector2.ZERO
		if is_instance_valid(_collector):
			target_position = to_local(_collector.global_position)
		_tween.tween_property(visual, "position", target_position, EFFECT_TIME)
		_tween.tween_property(visual, "scale", Vector2.ZERO, EFFECT_TIME)
	else:
		_tween.tween_property(visual, "position:y", visual.position.y - RELEASE_RISE, EFFECT_TIME)
		_tween.tween_property(visual, "modulate:a", 0.0, EFFECT_TIME)
	_tween.chain().tween_callback(queue_free)


## Removes the fragment without any effect.
func dismiss() -> void:
	_resolved = true
	_consumed = true
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _consumed:
		return
	_consumed = true
	_collector = body
	set_deferred("monitoring", false)
	collected.emit(self)

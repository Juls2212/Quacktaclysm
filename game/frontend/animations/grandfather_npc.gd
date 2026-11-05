extends Node2D
## Grandfather standing in the tutorial: drives his DuckRig (`Visual`) from what is on screen.
## Visual only. When his speech Label gets new text he talks for a while (longer lines, longer
## talk), then goes back to idle, and he turns to face the player. The Label stays a child of this
## node with the same path (TutorialController writes it); this script only reads it.

## Seconds of beak movement per character of a new line (clamped below).
@export var talk_per_char: float = 0.055
@export var talk_min: float = 1.2
@export var talk_max: float = 4.5
@export var face_player: bool = true

var _rig: DuckRig
var _label: Label
var _last_text: String = ""
var _talk_left: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	_rig = get_node_or_null(^"Visual") as DuckRig
	_label = get_node_or_null(^"Label") as Label


func _process(delta: float) -> void:
	if _rig == null:
		return
	if _label != null and _label.text != _last_text:
		_last_text = _label.text
		if not _last_text.strip_edges().is_empty():
			_talk_left = clampf(float(_last_text.length()) * talk_per_char, talk_min, talk_max)
	_talk_left = maxf(_talk_left - delta, 0.0)
	_rig.gesture = DuckRig.Gesture.TALK if _talk_left > 0.0 else DuckRig.Gesture.IDLE
	if face_player:
		if _player == null or not is_instance_valid(_player):
			_player = _find_player()
		if _player != null:
			var dir: float = signf(_player.global_position.x - global_position.x)
			if dir != 0.0:
				_rig.scale.x = absf(_rig.scale.x) * dir


func _find_player() -> Node2D:
	var node: Node = get_parent()
	while node != null:
		var value: Variant = node.get(&"player")
		if value is Node2D:
			return value
		node = node.get_parent()
	return null

class_name PlayerHealthHud
extends CanvasLayer
## Placeholder health display: one square per health point. Bound to a player;
## the player knows nothing about this HUD.

@export var pip_size: Vector2 = Vector2(24.0, 24.0)
@export var full_color: Color = Color(0.9, 0.2, 0.25, 1.0)
@export var empty_color: Color = Color(0.2, 0.2, 0.25, 0.7)

var current_health: int = 0
var max_health: int = 0

var _health: HealthComponent

@onready var pips: HBoxContainer = $Pips


func bind(player: Player) -> void:
	if _health:
		_health.health_changed.disconnect(_on_health_changed)
	_health = player.health
	_health.health_changed.connect(_on_health_changed)
	_on_health_changed(_health.current_health, _health.max_health)


func filled_pips() -> int:
	var count: int = 0
	for pip in pips.get_children():
		if (pip as ColorRect).color == full_color:
			count += 1
	return count


func _on_health_changed(current: int, maximum: int) -> void:
	current_health = current
	max_health = maximum
	while pips.get_child_count() < maximum:
		var pip := ColorRect.new()
		pip.custom_minimum_size = pip_size
		pips.add_child(pip)
	while pips.get_child_count() > maximum:
		var extra: Node = pips.get_child(pips.get_child_count() - 1)
		pips.remove_child(extra)
		extra.queue_free()
	for i in pips.get_child_count():
		(pips.get_child(i) as ColorRect).color = full_color if i < current else empty_color

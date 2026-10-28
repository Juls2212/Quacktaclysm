extends Node2D
## Feedback for the player's placeholder art: hurt flicker and the sword swing.
## Visual only; it reads state and never changes gameplay.

@export var health: HealthComponent
@export var attack_hitbox: Hitbox
## Shown only while the attack hitbox is active.
@export var sword: CanvasItem
@export_range(0.0, 1.0, 0.05) var blink_alpha: float = 0.3

var _blinking: bool = false
var _blink_timer: float = 0.0
var _player: Player


func _ready() -> void:
	_player = get_parent() as Player
	if health:
		health.invulnerability_started.connect(_set_blinking.bind(true))
		health.invulnerability_ended.connect(_set_blinking.bind(false))


func _process(delta: float) -> void:
	if sword and attack_hitbox:
		sword.visible = attack_hitbox.is_active
	if not _blinking:
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = _player.stats.hurt_blink_interval
		modulate.a = 1.0 if is_equal_approx(modulate.a, blink_alpha) else blink_alpha


func _set_blinking(value: bool) -> void:
	_blinking = value
	_blink_timer = 0.0
	if not value:
		modulate.a = 1.0

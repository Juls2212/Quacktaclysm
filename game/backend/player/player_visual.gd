extends Node2D
## Feedback for the player's placeholder art: hurt flicker and the sword swing.
## Visual only; it reads state and never changes gameplay.

@export var health: HealthComponent
@export var attack_hitbox: Hitbox
## Shown only while the attack hitbox is active.
@export var sword: CanvasItem
## Placeholder per sword move so each can be replaced separately: shown while the shared attack
## hitbox is active and `Player.current_sword_kind` says whose move it is.
@export var heavy_sword: CanvasItem
@export var dash_trail: CanvasItem
## Body tint while the heavy attack winds up (readable telegraph).
@export var heavy_windup_color: Color = Color(1.0, 0.65, 0.25, 1.0)
@export_range(0.5, 1.0, 0.05) var heavy_windup_squash: float = 0.9
@export_range(0.0, 1.0, 0.05) var blink_alpha: float = 0.3

var _blinking: bool = false
var _blink_timer: float = 0.0
var _player: Player
var _body: Polygon2D
var _body_color: Color = Color.WHITE


func _ready() -> void:
	_player = get_parent() as Player
	_body = get_node_or_null("Body") as Polygon2D
	if _body != null:
		_body_color = _body.color
	if health:
		health.invulnerability_started.connect(_set_blinking.bind(true))
		health.invulnerability_ended.connect(_set_blinking.bind(false))


func _process(delta: float) -> void:
	if attack_hitbox and _player:
		var active: bool = attack_hitbox.is_active
		var kind: Player.SwordKind = _player.current_sword_kind
		if sword:
			sword.visible = active and kind == Player.SwordKind.LIGHT
		if heavy_sword:
			heavy_sword.visible = active and kind == Player.SwordKind.HEAVY
		if dash_trail:
			dash_trail.visible = active and kind == Player.SwordKind.DASH_SLASH
	_update_cast_cue()
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


## Short color flash on the body while the sword wave is being cast (tinted by the wave tier).
func _update_cast_cue() -> void:
	if _body == null or _player == null:
		return
	scale.y = 1.0
	if _player.state == Player.State.WAVE and _player.wave_caster != null:
		_body.color = _body_color.lerp(_player.wave_caster.get_tint(), 0.7)
	elif _player.is_heavy_windup():
		_body.color = heavy_windup_color
		scale.y = heavy_windup_squash
	else:
		_body.color = _body_color

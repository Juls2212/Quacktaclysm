extends Node2D
## Placeholder feedback for an enemy: attack telegraph, hit flash and death fade.
## Visual only; it reads signals and never changes gameplay state.

@export var health: HealthComponent
@export var flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.1
## Tint and vertical squash shown while the enemy winds up an attack (startup phase).
@export var telegraph_color: Color = Color(1.0, 0.95, 0.35, 1.0)
@export_range(0.1, 1.0, 0.05) var telegraph_squash: float = 0.85

var _base_modulate: Color = Color.WHITE
var _rest_modulate: Color = Color.WHITE
var _flash_left: float = 0.0
var _fade_total: float = 0.0
var _fade_left: float = 0.0
var _fading: bool = false
var _enemy: EnemyBase


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	_base_modulate = modulate
	_rest_modulate = modulate
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if _enemy:
		_enemy.attack_phase_changed.connect(_on_attack_phase_changed)
		_enemy.attack_ended.connect(_set_telegraph.bind(false))


func _process(delta: float) -> void:
	if _fading:
		_fade_left = maxf(_fade_left - delta, 0.0)
		var alpha: float = _fade_left / _fade_total if _fade_total > 0.0 else 0.0
		modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, _base_modulate.a * alpha)
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			modulate = _rest_modulate


func _on_attack_phase_changed(phase: EnemyBase.AttackPhase) -> void:
	_set_telegraph(phase == EnemyBase.AttackPhase.STARTUP)


func _set_telegraph(active: bool) -> void:
	_rest_modulate = telegraph_color if active else _base_modulate
	scale.y = telegraph_squash if active else 1.0
	if _flash_left <= 0.0 and not _fading:
		modulate = _rest_modulate


func _on_damaged(_info: DamageInfo) -> void:
	_flash_left = flash_time
	modulate = flash_color


func _on_died() -> void:
	_fading = true
	_fade_total = _enemy.stats.death_fade_time
	_fade_left = _fade_total

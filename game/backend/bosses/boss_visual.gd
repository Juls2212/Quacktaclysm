extends Node2D
## Placeholder feedback for a boss: hit flash, telegraph cue, phase 2 tint and death fade.
## Visual only; it reads boss signals and never changes gameplay state.

@export var health: HealthComponent
@export var flash_color: Color = Color(1.0, 0.5, 0.5, 1.0)
@export var telegraph_color: Color = Color(1.0, 0.95, 0.35, 1.0)
@export var phase_2_color: Color = Color(1.0, 0.6, 0.6, 1.0)
@export_range(0.1, 1.0, 0.05) var telegraph_squash: float = 0.9

var _base_modulate: Color = Color.WHITE
var _rest_modulate: Color = Color.WHITE
var _flash_left: float = 0.0
var _fade_total: float = 0.0
var _fade_left: float = 0.0
var _fading: bool = false
var _boss: BossBase


func _ready() -> void:
	_boss = get_parent() as BossBase
	_base_modulate = modulate
	_rest_modulate = modulate
	if health:
		health.damaged.connect(_on_damaged)
	if _boss:
		_boss.pattern_phase_changed.connect(_on_pattern_phase_changed)
		_boss.pattern_finished.connect(func(_id: StringName) -> void: _set_telegraph(false))
		_boss.pattern_cancelled.connect(func(_id: StringName) -> void: _set_telegraph(false))
		_boss.phase_changed.connect(_on_phase_changed)
		_boss.defeated.connect(_on_defeated)
		_boss.encounter_reset.connect(_on_reset)


func _process(delta: float) -> void:
	if _fading:
		_fade_left = maxf(_fade_left - delta, 0.0)
		var alpha: float = _fade_left / _fade_total if _fade_total > 0.0 else 0.0
		modulate = Color(_rest_modulate.r, _rest_modulate.g, _rest_modulate.b, _rest_modulate.a * alpha)
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			modulate = _rest_modulate


func _on_pattern_phase_changed(_pattern_id: StringName, phase_name: StringName) -> void:
	_set_telegraph(phase_name == BossPattern.PHASE_TELEGRAPH)


func _set_telegraph(active: bool) -> void:
	var resting: Color = phase_2_color if _boss and _boss.current_phase >= 2 else _base_modulate
	_rest_modulate = telegraph_color if active else resting
	scale.y = telegraph_squash if active else 1.0
	if _flash_left <= 0.0 and not _fading:
		modulate = _rest_modulate


func _on_phase_changed(_phase: int) -> void:
	_set_telegraph(false)


func _on_damaged(_info: DamageInfo) -> void:
	_flash_left = _boss.stats.hit_flash_time if _boss else 0.1
	modulate = flash_color


func _on_defeated(_defeated_boss: BossBase) -> void:
	_fading = true
	_fade_total = _boss.stats.death_fade_time
	_fade_left = _fade_total


func _on_reset() -> void:
	_fading = false
	_flash_left = 0.0
	scale.y = 1.0
	_rest_modulate = _base_modulate
	modulate = _base_modulate
extends Node2D
## Drives an enemy's DuckRig (walk, attack windup/strike/recover, hurt, death) and adds the
## attack telegraph tint, hit flash and death fade.
## Visual only; it reads signals and never changes gameplay state.

@export var health: HealthComponent
## The drawn duck. Its look comes from `look`, or `tough_look` for sturdy variants.
@export var rig: DuckRig
@export var look: DuckRig.Look = DuckRig.Look.BRUTE
## Look used when the enemy's max_health reaches `tough_health` (e.g. melee_tough_stats).
@export var tough_look: DuckRig.Look = DuckRig.Look.BRUTE_TOUGH
@export_range(1, 999, 1) var tough_health: int = 6
@export var flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.1
## Tint shown while the enemy winds up an attack (startup phase); the rig also crouches.
@export var telegraph_color: Color = Color(1.0, 0.95, 0.35, 1.0)

var _base_modulate: Color = Color.WHITE
var _rest_modulate: Color = Color.WHITE
var _flash_left: float = 0.0
var _fade_total: float = 0.0
var _fade_left: float = 0.0
var _fading: bool = false
var _enemy: EnemyBase
var _phase: EnemyBase.AttackPhase = EnemyBase.AttackPhase.STARTUP
var _phase_time: float = 0.0


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
	if rig:
		var tough: bool = _enemy != null and _enemy.stats != null and _enemy.stats.max_health >= tough_health
		rig.look = tough_look if tough else look


func _process(delta: float) -> void:
	_phase_time += delta
	_update_rig()
	if _fading:
		_fade_left = maxf(_fade_left - delta, 0.0)
		var alpha: float = _fade_left / _fade_total if _fade_total > 0.0 else 0.0
		modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, _base_modulate.a * alpha)
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			modulate = _rest_modulate


func _update_rig() -> void:
	if rig == null or _enemy == null:
		return
	rig.ground_speed = absf(_enemy.velocity.x)
	rig.grounded = _enemy.is_on_floor()
	rig.vertical_speed = _enemy.velocity.y
	rig.hurt = _enemy.state == EnemyBase.State.HURT
	rig.dead = _enemy.state == EnemyBase.State.DEAD
	if _enemy.state != EnemyBase.State.ATTACK:
		rig.action = DuckRig.Action.NONE
		return
	rig.action = DuckRig.Action.ATTACK
	match _phase:
		EnemyBase.AttackPhase.STARTUP:
			rig.phase = DuckRig.Phase.WINDUP
		EnemyBase.AttackPhase.ACTIVE:
			rig.phase = DuckRig.Phase.STRIKE
		_:
			rig.phase = DuckRig.Phase.RECOVER
	rig.phase_t = clampf(_phase_time / maxf(_phase_duration(), 0.01), 0.0, 1.0)
	# Legs stay planted during the lunge burst; the rig draws speed lines and afterimages instead.
	rig.ground_speed = 0.0 if _phase == EnemyBase.AttackPhase.ACTIVE else rig.ground_speed


func _phase_duration() -> float:
	var stats: EnemyStats = _enemy.stats
	match _phase:
		EnemyBase.AttackPhase.STARTUP:
			return stats.attack_startup_time
		EnemyBase.AttackPhase.ACTIVE:
			if stats is FastEnemyStats:
				return (stats as FastEnemyStats).lunge_duration
			return stats.attack_active_time
	return stats.attack_recovery_time


func _on_attack_phase_changed(phase: EnemyBase.AttackPhase) -> void:
	_phase = phase
	_phase_time = 0.0
	_set_telegraph(phase == EnemyBase.AttackPhase.STARTUP)


func _set_telegraph(active: bool) -> void:
	_rest_modulate = telegraph_color if active else _base_modulate
	if _flash_left <= 0.0 and not _fading:
		modulate = _rest_modulate


func _on_damaged(_info: DamageInfo) -> void:
	_flash_left = flash_time
	modulate = flash_color


func _on_died() -> void:
	_fading = true
	_fade_total = _enemy.stats.death_fade_time
	_fade_left = _fade_total

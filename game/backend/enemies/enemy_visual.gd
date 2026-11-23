extends Node2D
## Drives an enemy's DuckRig (walk, attack windup/strike/recover, hurt, death) and adds the
## attack telegraph (a TelegraphDrawer shape that fills during the windup, plus the yellow tint), a
## dim while it recovers, a white hit flash with a small pop, and a soul wisp when it dies (the wisp is the SoulPickup the enemy releases); the duck
## falls apart as a ragdoll. Visual only; it reads signals and never changes gameplay state.

@export var health: HealthComponent
## The drawn duck. Its look comes from `look`, or `tough_look` for sturdy variants.
@export var rig: DuckRig
@export var look: DuckRig.Look = DuckRig.Look.BRUTE
## Look used when the enemy's max_health reaches `tough_health` (e.g. melee_tough_stats).
@export var tough_look: DuckRig.Look = DuckRig.Look.BRUTE_TOUGH
@export_range(1, 999, 1) var tough_health: int = 6
## White-hot flash on a hit (values above 1 brighten the whole duck).
@export var flash_color: Color = Color(2.2, 2.2, 2.2, 1.0)
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.1
## Tint shown while the enemy winds up an attack (startup phase); the rig also crouches.
@export var telegraph_color: Color = Color(1.0, 0.95, 0.35, 1.0)
## Tint while it recovers from an attack (the punish window).
@export var recovery_color: Color = Color(0.7, 0.7, 0.8, 1.0)
## Seconds the hit pop (a short squash and stretch) lasts, and how strong it is.
@export_range(0.0, 0.5, 0.01, "suffix:s") var pop_time: float = 0.12
@export_range(0.0, 0.5, 0.01) var pop_strength: float = 0.16
## Seconds the death ragdoll stays before fading out.
@export_range(0.0, 30.0, 0.5, "suffix:s") var ragdoll_lifetime: float = 3.0

var _base_modulate: Color = Color.WHITE
var _rest_modulate: Color = Color.WHITE
var _flash_left: float = 0.0
var _last_knockback: Vector2 = Vector2.ZERO
var _enemy: EnemyBase
var _phase: EnemyBase.AttackPhase = EnemyBase.AttackPhase.STARTUP
var _phase_time: float = 0.0
var _telegraph: TelegraphDrawer = null
var _telegraph_style: TelegraphStyle = null
var _pop_left: float = 0.0
var _rig_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	_base_modulate = modulate
	_rest_modulate = modulate
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if _enemy:
		_enemy.attack_phase_changed.connect(_on_attack_phase_changed)
		_enemy.attack_ended.connect(_on_attack_ended)
	if rig:
		var tough: bool = _enemy != null and _enemy.stats != null and _enemy.stats.max_health >= tough_health
		rig.look = tough_look if tough else look
		get_tree().call_group(&"profile_presenter", "register_enemy_rig", rig)
		_rig_base_scale = rig.scale


func _process(delta: float) -> void:
	_phase_time += delta
	_update_rig()
	_update_telegraph(delta)
	_update_pop(delta)
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
	if phase == EnemyBase.AttackPhase.STARTUP:
		_ensure_telegraph()
		if _telegraph != null and _telegraph_style != null:
			_telegraph.aim_target = _enemy.target
			_telegraph.show_telegraph(_telegraph_style)
	else:
		_hide_telegraph()
	if phase == EnemyBase.AttackPhase.RECOVERY:
		# The punish window: a faint dim until the attack is over.
		_rest_modulate = recovery_color
		if _flash_left <= 0.0:
			modulate = _rest_modulate


## The attack is over (finished, or cancelled by a hit or by death).
func _on_attack_ended() -> void:
	_hide_telegraph()
	_set_telegraph(false)


func _hide_telegraph() -> void:
	if _telegraph != null:
		_telegraph.hide_telegraph()


## Builds the telegraph the first time this enemy winds up an attack (never earlier, so an enemy
## that is freed at once leaves nothing behind), placed from where its rig is drawn.
func _ensure_telegraph() -> void:
	if _telegraph != null or rig == null or _enemy == null:
		return
	var set_resource := TelegraphSet.get_default()
	_telegraph_style = set_resource.get_style(TelegraphSet.kind_of_enemy(_enemy))
	if _telegraph_style == null:
		return
	_telegraph = TelegraphDrawer.new()
	_telegraph.name = "Telegraph"
	_enemy.add_child(_telegraph)
	var offset: Vector2 = rig.global_position - _enemy.global_position
	var s: float = absf(rig.global_scale.y)
	_telegraph.ground_y = offset.y + rig.foot_y * s
	_telegraph.center = offset + Vector2(0.0, -12.0 * s)
	_telegraph.head_point = offset + rig.get_part_center(DuckRig.Part.HEAD) * s + Vector2(0.0, -rig.get_part_radius(DuckRig.Part.HEAD) * s)
	_telegraph.muzzle = _telegraph.center
	var ranged: Variant = _enemy.get("ranged_stats")
	if ranged != null:
		_telegraph.muzzle = (ranged as Object).get("projectile_spawn_offset") as Vector2
	var fast: Variant = _enemy.get("fast_stats")
	if fast != null:
		_telegraph.reach = float((fast as Object).get("lunge_speed")) * float((fast as Object).get("lunge_duration"))


## While the windup runs: the shape follows its progress, facing and aim.
func _update_telegraph(delta: float) -> void:
	if _telegraph == null or not _telegraph.active:
		return
	var duration: float = maxf(_phase_duration(), 0.01)
	_telegraph.update_windup(_phase_time / duration, _enemy.facing_direction, delta)


## A short squash-and-stretch after a hit (the rig only; no hitbox or timing is touched).
func _update_pop(delta: float) -> void:
	if _pop_left <= 0.0 or rig == null:
		return
	_pop_left = maxf(_pop_left - delta, 0.0)
	var k: float = _pop_left / maxf(pop_time, 0.001)
	rig.scale = _rig_base_scale * Vector2(1.0 + pop_strength * k, 1.0 - pop_strength * 0.75 * k)


func _set_telegraph(active: bool) -> void:
	_rest_modulate = telegraph_color if active else _base_modulate
	if _flash_left <= 0.0:
		modulate = _rest_modulate


func _on_damaged(info: DamageInfo) -> void:
	_last_knockback = info.knockback
	_flash_left = flash_time
	modulate = flash_color
	_pop_left = pop_time


## The duck comes apart with the killing blow; the enemy node itself is freed by EnemyBase.
## Deferred: the hit arrives inside a physics callback, where new bodies can't be added.
func _on_died() -> void:
	modulate = _base_modulate
	_hide_telegraph()
	_pop_left = 0.0
	if rig != null:
		rig.scale = _rig_base_scale
	if rig != null and _enemy != null:
		_spawn_ragdoll.call_deferred(_last_knockback + Vector2(0, -120), _enemy.velocity)


func _spawn_ragdoll(push: Vector2, inherited: Vector2) -> void:
	if not is_inside_tree():
		return
	if DuckRagdoll.spawn(rig, _enemy.get_parent(), push, inherited, ragdoll_lifetime) != null:
		rig.visible = false

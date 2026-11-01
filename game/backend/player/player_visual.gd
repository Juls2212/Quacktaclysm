extends Node2D
## Drives the hero's DuckRig from the player state: run cycle, jump, dash, the three sword
## moves, the wave cast, hurt and death, plus the hurt flicker.
## Visual only; it reads state and never changes gameplay.

@export var health: HealthComponent
@export var attack_hitbox: Hitbox
## The drawn duck (kimono, loose hair, katana). Every frame it gets the pose for the current state.
@export var rig: DuckRig
@export_range(0.0, 1.0, 0.05) var blink_alpha: float = 0.3

var _blinking: bool = false
var _blink_timer: float = 0.0
var _player: Player
## Seconds since the player entered its current state (drives the attack phases).
var _state_time: float = 0.0
## Seconds since the dash slash started, or -1 when none is playing.
var _slash_time: float = -1.0


func _ready() -> void:
	_player = get_parent() as Player
	if health:
		health.invulnerability_started.connect(_set_blinking.bind(true))
		health.invulnerability_ended.connect(_set_blinking.bind(false))
	if _player:
		_player.state_changed.connect(_on_state_changed)
		_player.dash_slash_started.connect(func() -> void: _slash_time = 0.0)


func _process(delta: float) -> void:
	_state_time += delta
	if _slash_time >= 0.0:
		_slash_time += delta
	_update_rig()
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


func _on_state_changed(_old_state: Player.State, _new_state: Player.State) -> void:
	_state_time = 0.0


func _update_rig() -> void:
	if rig == null or _player == null:
		return
	var state: Player.State = _player.state
	var stats: PlayerStats = _player.stats
	rig.ground_speed = absf(_player.velocity.x)
	rig.grounded = _player.is_on_floor()
	rig.vertical_speed = _player.velocity.y
	rig.dashing = state == Player.State.DASH
	rig.hurt = state == Player.State.HURT
	rig.dead = state == Player.State.DEAD
	rig.action = DuckRig.Action.NONE
	match state:
		Player.State.ATTACK:
			_set_timed(DuckRig.Action.SLASH, stats.attack_startup_time, stats.attack_active_time, stats.attack_recovery_time)
		Player.State.HEAVY:
			_set_timed(DuckRig.Action.HEAVY, stats.heavy_startup_time, stats.heavy_active_time, stats.heavy_recovery_time)
		Player.State.WAVE:
			if _player.wave_caster != null:
				var config: SwordWaveConfig = _player.wave_caster.config
				var recovery: float = config.recovery_time
				_set_timed(DuckRig.Action.CAST, config.startup_time, recovery * 0.35, recovery * 0.65)
				rig.cast_color = _player.wave_caster.get_tint()
	_update_dash_slash(stats)


## The dash slash rides on the dash: a strike while its hitbox is active, then a short recovery.
func _update_dash_slash(stats: PlayerStats) -> void:
	if _slash_time < 0.0:
		return
	var striking: bool = attack_hitbox != null and attack_hitbox.is_active \
			and _player.current_sword_kind == Player.SwordKind.DASH_SLASH
	var strike_time: float = stats.dash_duration + stats.dash_slash_extra_active_time
	if striking:
		rig.action = DuckRig.Action.DASH_SLASH
		rig.phase = DuckRig.Phase.STRIKE
		rig.phase_t = clampf(_slash_time / maxf(strike_time, 0.01), 0.0, 1.0)
		return
	var recover_time: float = maxf(stats.dash_slash_extra_recovery_time, 0.1)
	var recover_t: float = (_slash_time - strike_time) / recover_time
	if recover_t >= 1.0 or _player.state == Player.State.HURT or _player.state == Player.State.DEAD:
		_slash_time = -1.0
		return
	if rig.action == DuckRig.Action.NONE:
		rig.action = DuckRig.Action.DASH_SLASH
		rig.phase = DuckRig.Phase.RECOVER
		rig.phase_t = clampf(recover_t, 0.0, 1.0)


func _set_timed(action: DuckRig.Action, windup: float, strike: float, recover: float) -> void:
	rig.action = action
	var t: float = _state_time
	if t < windup:
		rig.phase = DuckRig.Phase.WINDUP
		rig.phase_t = t / maxf(windup, 0.001)
	elif t < windup + strike:
		rig.phase = DuckRig.Phase.STRIKE
		rig.phase_t = (t - windup) / maxf(strike, 0.001)
	else:
		rig.phase = DuckRig.Phase.RECOVER
		rig.phase_t = clampf((t - windup - strike) / maxf(recover, 0.001), 0.0, 1.0)

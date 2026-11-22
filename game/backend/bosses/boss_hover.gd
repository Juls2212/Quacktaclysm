class_name BossHover
extends Node
## Lets a boss float (Phase 15e-1): boss 3 is a floating eye in phases 1 and 3 and walks the floor as Kenzo in phase 2. Child
## of the boss; the boss asks `is_floating()` every physics frame and, if true, calls `drive` instead of applying gravity.
## The eye hovers `hover_height` px over the floor and DIPS to `dip_height` for `dip_hold` s every `dip_interval` s: the
## numbers come from the audited reach of the player (a jump from the floor lifts the sword 112 px, the double jump 189 px, a
## sword wave flies at floor level), so the eye is hittable by a wave during a dip, by the light sword from the apex of a single
## jump and by the double jump. `max_unhittable_time` is the longest the eye may go without a dip (a wave from the floor can
## only reach it then); the dip interval must not exceed it. The patterns may also ask for a dip (`request_dip`).
## Gameplay only: the eye drawing is DuckRig.eye_form, which BossVisual reads from `eye_form`.

signal dip_started
signal dip_ended

## Phases in which the boss floats.
@export var floating_phases: PackedInt32Array = PackedInt32Array([1, 3])
## Height of the CENTER of the boss over the floor when it hovers and when it dips (px).
@export_range(40.0, 400.0, 1.0, "suffix:px") var hover_height: float = 170.0
@export_range(20.0, 300.0, 1.0, "suffix:px") var dip_height: float = 80.0
## Seconds between the start of two dips, and how long each lasts.
@export_range(0.5, 20.0, 0.1, "suffix:s") var dip_interval: float = 3.0
@export_range(0.2, 6.0, 0.1, "suffix:s") var dip_hold: float = 1.2
## The eye may never be out of reach of a floor-level wave for longer than this.
@export_range(1.0, 20.0, 0.5, "suffix:s") var max_unhittable_time: float = 4.0
@export_range(20.0, 1500.0, 10.0, "suffix:px/s") var vertical_speed: float = 280.0
@export_range(0.0, 20.0, 0.5, "suffix:px") var bob_amplitude: float = 6.0
@export_range(0.1, 3.0, 0.1, "suffix:Hz") var bob_hz: float = 0.8
## The height of the center of the boss when it stands on the floor (px): half of its body.
@export_range(0.0, 100.0, 1.0, "suffix:px") var body_half_height: float = 44.0

## True while the boss is in a floating phase (the eye is drawn then).
var eye_form: bool = false
var dipping: bool = false
## Seconds the eye has gone without being at the dip height (the tests read it).
var seconds_since_dip: float = 0.0
var floor_y: float = 0.0

var _boss: BossBase = null
var _clock: float = 0.0
var _cycle: float = 0.0
var _dip_left: float = 0.0
var _forced_left: float = 0.0


func _ready() -> void:
	_boss = get_parent() as BossBase
	if _boss == null:
		return
	floor_y = _boss.global_position.y + body_half_height
	_boss.phase_changed.connect(func(_phase: int) -> void: _reset_cycle())
	_boss.encounter_reset.connect(_reset_cycle)
	_boss.activated.connect(_reset_cycle)


func is_floating() -> bool:
	if _boss == null:
		return false
	eye_form = floating_phases.has(_boss.current_phase)
	return eye_form


func _reset_cycle() -> void:
	_cycle = 0.0
	_dip_left = 0.0
	_forced_left = 0.0
	dipping = false
	seconds_since_dip = 0.0


## The patterns ask the eye to come down for `seconds` (the swoop).
func request_dip(seconds: float) -> void:
	_forced_left = maxf(_forced_left, seconds)


## The height (px over the floor) the eye aims for now, without the bob.
func target_height() -> float:
	return dip_height if dipping or _forced_left > 0.0 else hover_height


## Moves the boss vertically toward its hover height. Called by BossBase instead of gravity.
func drive(boss: BossBase, delta: float) -> void:
	_clock += delta
	var fighting: bool = boss.state != BossBase.State.INACTIVE and boss.state != BossBase.State.PHASE_TRANSITION
	if fighting:
		_cycle += delta
		if _forced_left > 0.0:
			_forced_left = maxf(_forced_left - delta, 0.0)
		if dipping:
			_dip_left -= delta
			if _dip_left <= 0.0:
				dipping = false
				_cycle = 0.0
				dip_ended.emit()
		elif _cycle >= dip_interval:
			dipping = true
			_dip_left = dip_hold
			dip_started.emit()
	var at_dip: bool = dipping or _forced_left > 0.0
	seconds_since_dip = 0.0 if at_dip else seconds_since_dip + delta
	var height: float = target_height() + sin(_clock * TAU * bob_hz) * bob_amplitude
	var target_y: float = floor_y - height
	boss.velocity.y = clampf((target_y - boss.global_position.y) * 6.0, -vertical_speed, vertical_speed)

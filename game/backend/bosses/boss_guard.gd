class_name BossGuard
extends Node
## Kenzo's guard (Phase 15e-1). While it is UP the light sword and the sword wave (any tier) are blocked: no damage, a spark and
## the clash sound (the hurtbox reports the hit as not applied). The heavy slash and the dash slash BREAK it: each one is
## absorbed until `guard_break_hits` of them have landed; the last one breaks the guard AND hurts. Then the boss is STAGGERED for
## `stagger_time` s (every attack damages) and after `regen_delay` more seconds the guard regenerates. The heavy slash and the
## dash slash exist from the start of the game, so the phase is always beatable. The guard only exists in `guard_phases`.
## Child of the boss; the boss hurtbox points at it with `hit_filter`. Gameplay only: GuardFx draws it.

signal state_changed(new_state: int)
signal deflected(info: DamageInfo)
signal broken
signal stagger_ended
signal regenerated

enum State { DOWN, UP, STAGGER, REGEN }

## Phases in which the guard exists (boss 3: phase 2, Kenzo on the floor).
@export var guard_phases: PackedInt32Array = PackedInt32Array([2])
## `DamageInfo.attack_kind` values that are blocked and that break the guard.
@export var blocked_kinds: PackedStringArray = PackedStringArray(["light", "wave"])
@export var breaking_kinds: PackedStringArray = PackedStringArray(["heavy", "dash_slash"])
@export_range(1, 9, 1) var guard_break_hits: int = 2
@export_range(0.5, 10.0, 0.1, "suffix:s") var stagger_time: float = 2.5
## Seconds after the stagger before the guard comes back.
@export_range(0.5, 20.0, 0.1, "suffix:s") var regen_delay: float = 3.0

var state: State = State.DOWN
## Breaking hits absorbed by the guard so far.
var break_hits: int = 0
## Seconds left of the stagger or of the regeneration.
var time_left: float = 0.0

var _boss: BossBase = null


func _ready() -> void:
	_boss = get_parent() as BossBase
	if _boss == null:
		return
	_boss.phase_changed.connect(_on_phase_changed)
	_boss.encounter_reset.connect(_reset)
	_boss.defeated.connect(func(_b: BossBase) -> void: _set_state(State.DOWN))
	_boss.activated.connect(_reset)


func _process(delta: float) -> void:
	match state:
		State.STAGGER:
			time_left -= delta
			if time_left <= 0.0:
				time_left = regen_delay
				_set_state(State.REGEN)
				stagger_ended.emit()
		State.REGEN:
			time_left -= delta
			if time_left <= 0.0:
				break_hits = 0
				_set_state(State.UP)
				regenerated.emit()


func is_up() -> bool:
	return state == State.UP


func is_staggered() -> bool:
	return state == State.STAGGER


## Hurtbox hook: true = the hit is blocked.
func filter_hit(info: DamageInfo) -> bool:
	if state != State.UP or info.team != CombatLayers.Team.PLAYER:
		return false
	var kind: String = String(info.attack_kind)
	if breaking_kinds.has(kind):
		break_hits += 1
		if break_hits >= guard_break_hits:
			time_left = stagger_time
			_set_state(State.STAGGER)
			broken.emit()
			return false
		deflected.emit(info)
		state_changed.emit(int(state))
		return true
	if blocked_kinds.has(kind):
		deflected.emit(info)
		return true
	return false


func _on_phase_changed(phase: int) -> void:
	break_hits = 0
	_set_state(State.UP if guard_phases.has(phase) else State.DOWN)


func _reset() -> void:
	break_hits = 0
	time_left = 0.0
	_set_state(State.UP if _boss != null and guard_phases.has(_boss.current_phase) else State.DOWN)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(int(state))

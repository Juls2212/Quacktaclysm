class_name BossPattern
extends Node
## Base class of every boss attack pattern. Patterns are children of the boss's
## `Patterns` node, so they can be added, removed and reordered in the editor.
##
## A pattern runs a fixed timeline: telegraph -> active -> recovery. Timers advance in
## `physics_update`, scaled by `boss.speed_multiplier` (no awaits).
##
## Virtual methods (override what you need):
##   can_start(boss) -> bool        phase, cooldown and distance conditions (extend with super)
##   start(boss)                    begins the timeline (extend with super)
##   physics_update(boss, delta)    advances the timeline
##   cancel(boss)                   stops at once; calls _on_cancel, which MUST deactivate
##                                  every hitbox and clear running timers
##   is_finished() -> bool
## Timeline hooks: _active_duration, _on_phase_entered, _on_phase_update, _on_phase_exited,
## _on_cancel.

signal started
signal phase_changed(phase_name: StringName)
signal finished

const PHASE_TELEGRAPH: StringName = &"telegraph"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_RECOVERY: StringName = &"recovery"

@export var pattern_id: StringName = &""
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export_range(1, 99, 1) var min_phase: int = 1
@export_range(1, 99, 1) var max_phase: int = 2
## Seconds before the pattern can be chosen again after it ends or is cancelled.
@export_range(0.0, 60.0, 0.1, "suffix:s") var cooldown: float = 0.0
## 0 ignores the condition.
@export_range(0.0, 3000.0, 1.0, "suffix:px") var min_distance_to_target: float = 0.0
@export_range(0.0, 3000.0, 1.0, "suffix:px") var max_distance_to_target: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var telegraph_time: float = 0.6
@export_range(0.0, 10.0, 0.05, "suffix:s") var recovery_time: float = 0.6

var cooldown_left: float = 0.0
var phase_name: StringName = &""

var _finished: bool = true
var _phase_left: float = 0.0


## 0..1 progress through the current phase (read by the boss visual to time its animation).
func get_phase_progress() -> float:
	var duration: float = _phase_duration(phase_name)
	if duration <= 0.0:
		return 1.0
	return clampf(1.0 - _phase_left / duration, 0.0, 1.0)


func tick_cooldown(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func can_start(boss: BossBase) -> bool:
	if boss.current_phase < min_phase or boss.current_phase > max_phase:
		return false
	if cooldown_left > 0.0:
		return false
	var distance: float = boss.distance_to_target()
	if min_distance_to_target > 0.0 and distance < min_distance_to_target:
		return false
	if max_distance_to_target > 0.0 and distance > max_distance_to_target:
		return false
	return true


func start(boss: BossBase) -> void:
	_finished = false
	started.emit()
	_enter_phase(boss, PHASE_TELEGRAPH, 0.0)


func physics_update(boss: BossBase, delta: float) -> void:
	if _finished:
		return
	_on_phase_update(boss, delta)
	_phase_left -= delta * boss.speed_multiplier
	while _phase_left <= 0.0 and not _finished:
		_on_phase_exited(boss, phase_name)
		var next_phase: StringName = _next_phase(phase_name)
		if next_phase == &"":
			_finished = true
			cooldown_left = cooldown
			phase_name = &""
			finished.emit()
			return
		_enter_phase(boss, next_phase, _phase_left)


func cancel(boss: BossBase) -> void:
	_on_cancel(boss)
	_finished = true
	phase_name = &""
	cooldown_left = cooldown


func is_finished() -> bool:
	return _finished


func _enter_phase(boss: BossBase, new_phase: StringName, carry: float) -> void:
	phase_name = new_phase
	_phase_left = _phase_duration(new_phase) + carry
	phase_changed.emit(new_phase)
	_on_phase_entered(boss, new_phase)


func _next_phase(current: StringName) -> StringName:
	match current:
		PHASE_TELEGRAPH:
			return PHASE_ACTIVE
		PHASE_ACTIVE:
			return PHASE_RECOVERY
	return &""


func _phase_duration(phase: StringName) -> float:
	match phase:
		PHASE_TELEGRAPH:
			return telegraph_time
		PHASE_ACTIVE:
			return _active_duration()
	return recovery_time


## Virtual: length of the active window.
func _active_duration() -> float:
	return 0.0


## Virtual.
func _on_phase_entered(_boss: BossBase, _entered: StringName) -> void:
	pass


## Virtual: called every frame while running, before the timer advances.
func _on_phase_update(_boss: BossBase, _delta: float) -> void:
	pass


## Virtual.
func _on_phase_exited(_boss: BossBase, _exited: StringName) -> void:
	pass


## Virtual: must deactivate every hitbox and clear timers.
func _on_cancel(_boss: BossBase) -> void:
	pass
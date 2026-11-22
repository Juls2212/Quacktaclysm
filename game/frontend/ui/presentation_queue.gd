class_name PresentationQueue
extends Node
## A small sequential queue for things shown to the player one after another (Phase 15b): the corruption
## animation, then an ability card, then the next card... Child of every level (level_base.tscn); it is not an
## autoload. A step is an id plus a "starter" Callable that starts the thing and returns a Signal to wait for (its
## arguments are ignored; an invalid / null Signal means "nothing to show": the step completes at once, which is what
## happens in headless runs). Steps never overlap: the next one starts only after the previous one emitted its
## signal or its safety timeout ran out. The queue only starts on a deferred call, so every other listener of
## the same event (for example the effect that spawns the animation) has already run when the first starter is
## called. It works with signal callbacks (no awaits), so freeing the level in the middle of a step leaves nothing
## behind and raises no error. Reusable for future cards (a double jump card is queued with it). Presentation only.

signal step_started(id: String)
signal step_finished(id: String, timed_out: bool)
signal drained

## Safety net: a step that never signals is abandoned after this many seconds (real time, pause-proof).
@export_range(1.0, 120.0, 0.5, "suffix:s") var step_timeout: float = 20.0

## Ids of the steps finished so far, in order (the tests read it).
var finished_ids: Array = []
var current_id: String = ""

var _steps: Array = []
var _running: bool = false
var _waiting: bool = false
var _token: int = 0


func is_busy() -> bool:
	return _running or not _steps.is_empty()


## Adds a step. `timeout` < 0 uses `step_timeout`. The starter is called when the step's turn comes.
func enqueue(id: String, starter: Callable, timeout: float = -1.0) -> void:
	_steps.append({"id": id, "starter": starter, "timeout": timeout if timeout >= 0.0 else step_timeout})
	if not _running:
		_running = true
		_advance.call_deferred()


func clear() -> void:
	_steps.clear()


func _advance() -> void:
	if _waiting or not is_inside_tree():
		return
	if _steps.is_empty():
		_running = false
		current_id = ""
		drained.emit()
		return
	var step: Dictionary = _steps.pop_front()
	current_id = String(step["id"])
	step_started.emit(current_id)
	var waiting: Variant = (step["starter"] as Callable).call()
	if typeof(waiting) == TYPE_SIGNAL and not (waiting as Signal).is_null():
		_waiting = true
		_token += 1
		var sig: Signal = waiting as Signal
		var receiver: Callable = Callable(self, &"_on_signal").bind(_token)
		var extra: int = _argument_count(sig)
		if extra > 0:
			receiver = receiver.unbind(extra)
		sig.connect(receiver, CONNECT_ONE_SHOT)
		get_tree().create_timer(float(step["timeout"]), true, false, true).timeout.connect(_on_timeout.bind(_token))
	else:
		_finish_step(false)


func _on_signal(token: int) -> void:
	if _waiting and token == _token:
		_finish_step(false)


func _on_timeout(token: int) -> void:
	if _waiting and token == _token:
		_finish_step(true)


func _finish_step(timed_out: bool) -> void:
	_waiting = false
	finished_ids.append(current_id)
	var finished_id: String = current_id
	current_id = ""
	step_finished.emit(finished_id, timed_out)
	# The next step starts on the next idle moment, never inside the signal that ended this one.
	_advance.call_deferred()


## How many arguments the signal passes (they are all ignored).
func _argument_count(sig: Signal) -> int:
	var source: Object = sig.get_object()
	if source == null:
		return 0
	for entry in source.get_signal_list():
		if String(entry["name"]) == String(sig.get_name()):
			return (entry["args"] as Array).size()
	return 0

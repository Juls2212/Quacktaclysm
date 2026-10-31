extends Node
## Target of the real scene-transition check in flow_phase11_smoke_test. Development only.
## After the transition finishes it verifies the tree is unpaused and SceneManager is idle,
## prints PASS/FAIL and quits with exit code 0 (or 1).

const MAX_WAIT_SECONDS: float = 10.0

var _done: bool = false


func _ready() -> void:
	print("flow target scene loaded (paused=%s, transitioning=%s)" % [get_tree().paused, SceneManager.is_transitioning()])
	if SceneManager.is_transitioning():
		SceneManager.transition_finished.connect(_on_finished)
		get_tree().create_timer(MAX_WAIT_SECONDS).timeout.connect(_on_timeout)
	else:
		_on_finished("")


func _on_finished(_scene_id: String) -> void:
	if _done:
		return
	_done = true
	var ok: bool = not get_tree().paused and not SceneManager.is_transitioning() and not PauseLock.is_locked()
	print("%s: real transition finished; tree unpaused, manager idle, lock cleared (paused=%s transitioning=%s holders=%d)" % [
		"PASS" if ok else "FAIL", get_tree().paused, SceneManager.is_transitioning(), PauseLock.holder_count()])
	get_tree().quit(0 if ok else 1)


func _on_timeout() -> void:
	if _done:
		return
	_done = true
	print("FAIL: transition_finished never arrived")
	get_tree().quit(1)

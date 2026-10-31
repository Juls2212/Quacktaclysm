extends Node
## Autoload. Scene changes with a fade, driven by a small state machine advanced in _process
## (no awaits, so nothing can outlive the node). Decoupled from gameplay: callers pass ids/levels.
## Sequence: fade out -> reset PauseLock + unpause -> change scene -> wait for the new current
## scene -> fade in -> emit transition_finished. A failed change fades back in; never stays black.

signal transition_started(scene_id: String)
signal transition_finished(scene_id: String)
signal scene_change_failed(scene_id: String, reason: String)

enum Phase { IDLE, FADE_OUT, CHANGE, WAIT_SCENE, FADE_IN }

const DEFAULT_REGISTRY_PATH: String = "res://backend/progression/default_scene_registry.tres"
const OVERLAY_LAYER: int = 100
## Safety net: give up waiting for the new scene after this many seconds.
const SCENE_WAIT_TIMEOUT: float = 5.0
## Frames to wait after the change before looking for the new scene.
const MIN_WAIT_FRAMES: int = 2

## Test hook: no real scene change or quit; only signals and the last_requested_* records.
var dry_run: bool = false
var last_requested_scene_id: String = ""
var last_requested_path: String = ""
var quit_requested: bool = false

var _registry: SceneRegistry = null
var _phase: Phase = Phase.IDLE
var _target_id: String = ""
var _target_path: String = ""
var _elapsed: float = 0.0
var _wait_frames: int = 0
var _old_scene_id: int = 0
var _failed: bool = false
var _fade_out_time: float = 0.0
var _fade_in_time: float = 0.0
var _overlay: ColorRect = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = OVERLAY_LAYER
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	_set_overlay_alpha(0.0)
	set_process(false)
	if _registry == null:
		_registry = load(DEFAULT_REGISTRY_PATH) as SceneRegistry


func _exit_tree() -> void:
	_set_gui_locked(false)


func get_registry() -> SceneRegistry:
	return _registry


func set_registry(registry: SceneRegistry) -> void:
	_registry = registry


func is_transitioning() -> bool:
	return _phase != Phase.IDLE


func go_to(scene_id: String) -> bool:
	if _registry == null:
		return _fail_request(scene_id, "no scene registry")
	if _phase != Phase.IDLE:
		return _fail_request(scene_id, "a transition is already running")
	if _registry.get_path_for(scene_id).is_empty():
		return _fail_request(scene_id, "unknown scene id")
	if not _registry.has_scene(scene_id):
		return _fail_request(scene_id, "scene file not found")
	_target_id = scene_id
	_target_path = _registry.get_path_for(scene_id)
	last_requested_scene_id = _target_id
	last_requested_path = _target_path
	_fade_out_time = _registry.fade_out_time
	_fade_in_time = _registry.fade_in_time
	_overlay.color = Color(_registry.fade_color.r, _registry.fade_color.g, _registry.fade_color.b, _overlay.color.a)
	_failed = false
	_set_gui_locked(true)
	_enter_phase(Phase.FADE_OUT)
	transition_started.emit(scene_id)
	return true


func go_to_level(level: int) -> bool:
	if _registry == null:
		return _fail_request("", "no scene registry")
	return go_to(_registry.scene_id_for_level(level))


func go_to_main_menu() -> bool:
	if _registry == null:
		return _fail_request("", "no scene registry")
	return go_to(_registry.main_menu_scene_id)


func quit_game() -> void:
	quit_requested = true
	if not dry_run:
		get_tree().quit()


func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		Phase.FADE_OUT:
			_set_overlay_alpha(_progress(_fade_out_time))
			if _elapsed >= _fade_out_time:
				_enter_phase(Phase.CHANGE)
		Phase.CHANGE:
			_do_change()
		Phase.WAIT_SCENE:
			_wait_frames += 1
			if _wait_frames >= MIN_WAIT_FRAMES and _new_scene_ready():
				_enter_phase(Phase.FADE_IN)
			elif _elapsed >= SCENE_WAIT_TIMEOUT:
				_abort("timed out waiting for the new scene")
		Phase.FADE_IN:
			_set_overlay_alpha(1.0 - _progress(_fade_in_time))
			if _elapsed >= _fade_in_time:
				_finish()


func _do_change() -> void:
	if dry_run:
		_enter_phase(Phase.FADE_IN)
		return
	var tree := get_tree()
	PauseLock.reset(tree)
	var old_scene: Node = tree.current_scene
	_old_scene_id = old_scene.get_instance_id() if old_scene != null else 0
	var error: Error = tree.change_scene_to_file(_target_path)
	if error != OK:
		_abort("change_scene_to_file failed (%s)" % error_string(error))
		return
	_enter_phase(Phase.WAIT_SCENE)


func _new_scene_ready() -> bool:
	var current: Node = get_tree().current_scene
	return current != null and current.get_instance_id() != _old_scene_id and current.is_inside_tree()


func _abort(reason: String) -> void:
	_failed = true
	scene_change_failed.emit(_target_id, reason)
	push_warning("SceneManager: " + reason)
	_enter_phase(Phase.FADE_IN)


func _finish() -> void:
	var finished_id: String = _target_id
	var failed: bool = _failed
	_phase = Phase.IDLE
	_set_overlay_alpha(0.0)
	_set_gui_locked(false)
	set_process(false)
	if not failed:
		transition_finished.emit(finished_id)


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	_elapsed = 0.0
	_wait_frames = 0
	set_process(true)
	if phase == Phase.FADE_OUT:
		_set_overlay_alpha(_progress(_fade_out_time))
	elif phase == Phase.FADE_IN:
		_set_overlay_alpha(1.0 - _progress(_fade_in_time))


func _progress(duration: float) -> float:
	return 1.0 if duration <= 0.0 else clampf(_elapsed / duration, 0.0, 1.0)


func _set_overlay_alpha(alpha: float) -> void:
	_overlay.color.a = alpha
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if _phase != Phase.IDLE else Control.MOUSE_FILTER_IGNORE


func _set_gui_locked(locked: bool) -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_disable_input = locked


func _fail_request(scene_id: String, reason: String) -> bool:
	push_warning("SceneManager: cannot go to '%s': %s" % [scene_id, reason])
	scene_change_failed.emit(scene_id, reason)
	return false

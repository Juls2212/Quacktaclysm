class_name GrandfatherVoice
extends Node
## The grandfather's line at level start (Phase 16c). Created by every numbered level (LevelBase, in code). It waits for the level
## title and intro to finish (LevelBase.intro_finished) and, in level 3, for his entry scene (ElderScene.scene_finished), then
## enqueues ONE step in the level PresentationQueue: a short panel with the line plus the sky reflection. Level 1 shows a remembered
## saying; levels 2 and 3 show the Director line for the theme of the plan applied to that level (a valid remote line, else a bank
## line); levels 1 and 2 present it as a memory ("Recuerdas su voz…"), level 3 as his direct voice. It never locks the player,
## dismisses itself after `show_time` or with the confirm action, and is dismissed at once when the boss encounter starts or the
## player dies, so it can never sit over the boss intro, a fight or a possession. Once per level per session. Automated
## (headless) runs skip it unless `play_when_headless` (a static switch the tests turn on). Nothing is saved.

signal line_started(text: String, memory: bool)
signal line_finished(skipped: bool)

## Headless runs show nothing unless this is on (the tests switch it).
static var play_when_headless: bool = false

@export var presentation: GrandfatherPresentation
@export var lines: GrandfatherLines

## The last line shown, whether it was presented as a memory, and where it came from (remote, bank or memory).
var shown_text: String = ""
var shown_memory: bool = false
var shown_source: String = ""
var shown_count: int = 0
var active: bool = false
var panel_layer: CanvasLayer = null
var reflection: GrandfatherFace = null

var _level: LevelBase = null
var _queue: PresentationQueue = null
var _elder: ElderScene = null
var _intro_done: bool = false
var _ready_done: bool = false
var _elder_done: bool = false
var _started: bool = false
var _remaining: float = 0.0
var _panel: PanelContainer = null
var _fading: bool = false
var _fade_left: float = 0.0


func _ready() -> void:
	if presentation == null:
		presentation = GrandfatherPresentation.get_default()
	if lines == null:
		lines = GrandfatherLines.get_default()
	_level = get_parent() as LevelBase
	if _level == null:
		return
	_queue = _level.get_node_or_null(^"PresentationQueue") as PresentationQueue
	_elder = _level.get_node_or_null(^"ElderScene") as ElderScene
	if _elder != null:
		_elder.scene_finished.connect(func(_skipped: bool) -> void:
			_elder_done = true
			_try_start())
	_level.level_ready.connect(func() -> void:
		_ready_done = true
		_try_start())
	_level.intro_finished.connect(func() -> void:
		_intro_done = true
		_try_start())
	if _level.encounter != null:
		_level.encounter.encounter_started.connect(func() -> void: dismiss(false))
	_level.player.died.connect(func() -> void: dismiss(false))


## True while his entry scene (level 3) is playing: the line waits for it.
func _elder_blocking() -> bool:
	return _elder != null and _elder.played and not _elder_done


func _try_start() -> void:
	if _started or not _ready_done or not _intro_done or _elder_blocking() or _queue == null:
		return
	_started = true
	if not should_show():
		return
	var delay: float = presentation.start_delay
	if delay <= 0.0:
		_enqueue()
	else:
		get_tree().create_timer(delay).timeout.connect(_enqueue)


## True when this level load may show the line.
func should_show() -> bool:
	if _level == null or _level.level_number < 1:
		return false
	if DisplayServer.get_name() == "headless" and not play_when_headless:
		return false
	if GameState.director.has_voiced(_level.level_number):
		return false
	return not _fight_active()


## A fight (or its intro) is on, or the level was entered at its arena checkpoint.
func _fight_active() -> bool:
	if _level.boss != null and _level.boss.state != BossBase.State.INACTIVE:
		return true
	# The arena closed (the boss intro may still be playing before the boss wakes).
	if _level.encounter != null and _level.encounter.get("_armed") == false:
		return true
	for checkpoint in _level.get_level_checkpoints():
		if String(checkpoint.checkpoint_id) == GameState.checkpoint and checkpoint.order == _arena_order():
			return true
	return false


func _arena_order() -> int:
	var best: int = -1
	for checkpoint in _level.get_level_checkpoints():
		best = maxi(best, checkpoint.order)
	return best


func _enqueue() -> void:
	if not is_inside_tree() or _queue == null or _fight_active():
		return
	_queue.enqueue("grandfather_line", _step, presentation.show_time + presentation.queue_timeout_margin)


## The queue starter: shows the line and returns the signal that ends the step (null = nothing to show now).
func _step() -> Variant:
	if not is_inside_tree() or active or _fight_active():
		return null
	_present()
	return line_finished


func _present() -> void:
	var level_number: int = _level.level_number
	var theme: String = _level.get_applied_plan().theme if _level.get_applied_plan() != null else lines.memory_theme
	var choice: Dictionary = GameState.director.choose_line(level_number, theme, GameState.decisions)
	if String(choice["text"]).is_empty():
		return
	GameState.director.mark_voiced(level_number)
	shown_text = String(choice["text"])
	shown_source = String(choice["source"])
	shown_memory = level_number < 3
	shown_count += 1
	active = true
	_fading = false
	_remaining = presentation.show_time
	var reduced: bool = not GameSettings.is_corruption_effects_enabled()
	reflection = GrandfatherFace.new()
	reflection.name = "GrandfatherFace"
	reflection.setup(presentation, level_number, reduced)
	add_child(reflection)
	_build_panel()
	AudioDirector.play_event(presentation.sound_event)
	line_started.emit(shown_text, shown_memory)


func _build_panel() -> void:
	panel_layer = CanvasLayer.new()
	panel_layer.layer = presentation.panel_layer
	add_child(panel_layer)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = presentation.panel_color
	box.set_corner_radius_all(8)
	box.set_content_margin_all(14.0)
	_panel.add_theme_stylebox_override(&"panel", box)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var screen_height: float = get_viewport().get_visible_rect().size.y
	_panel.position.y = screen_height * presentation.panel_top_ratio
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = (presentation.memory_format if shown_memory else presentation.direct_format) % shown_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(presentation.panel_width, 0.0)
	label.add_theme_font_override(&"font", GameFonts.BODY)
	label.add_theme_font_size_override(&"font_size", presentation.font_size)
	label.add_theme_color_override(&"font_color", presentation.text_color)
	label.add_theme_color_override(&"font_outline_color", presentation.outline_color)
	label.add_theme_constant_override(&"outline_size", 5)
	_panel.add_child(label)
	_panel.modulate.a = 0.0
	panel_layer.add_child(_panel)


func _process(delta: float) -> void:
	if not active:
		return
	if _fading:
		_fade_left -= delta
		_panel.modulate.a = clampf(_fade_left / presentation.panel_fade_time, 0.0, 1.0)
		if _fade_left <= 0.0:
			_free_panel()
		return
	_remaining -= delta
	var shown_for: float = presentation.show_time - _remaining
	_panel.modulate.a = clampf(shown_for / presentation.panel_fade_time, 0.0, 1.0)
	if _remaining <= 0.0:
		dismiss(false)


func _unhandled_input(event: InputEvent) -> void:
	if active and not _fading and event.is_action_pressed("ui_accept"):
		dismiss(true)


## Ends the line (the panel fades out, the reflection fades out, the queue step is released at once).
func dismiss(skipped: bool) -> void:
	if not active or _fading:
		return
	_fading = true
	_fade_left = presentation.panel_fade_time
	if reflection != null and is_instance_valid(reflection):
		reflection.fade_out()
	line_finished.emit(skipped)


func _free_panel() -> void:
	active = false
	_fading = false
	if panel_layer != null and is_instance_valid(panel_layer):
		panel_layer.queue_free()
	panel_layer = null
	_panel = null

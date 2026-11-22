class_name StoryReel
extends Node
## A short cinematic made of subtitle lines over one PrologueShots shot (the prologue's drawing
## system): cinema bars, typed subtitles, fades, an optional title card. Used for the grandfather's
## scene before the last boss (shot CAVE, press confirm to skip, pauses the game meanwhile) and for
## the four endings (shot EPILOGUE, hold confirm to skip). It never writes game state; it frees
## itself after `finished`. Works in headless runs too (nothing is drawn there), so tests can drive it.

signal finished(skipped: bool)

enum SkipMode { PRESS, HOLD }

const SHOTS_SCRIPT := preload("res://frontend/prologue/prologue_shots.gd")
const THEME := preload("res://frontend/ui/theme/quack_theme.tres")
const BAR_HEIGHT: float = 78.0
## Typewriter speed (characters per second); a typed line stays 1 s + 1 s per 15 characters (2.5-6 s).
const TYPE_SPEED: float = 35.0
const READ_BASE: float = 1.0
const READ_CHARS: float = 15.0
const READ_MIN: float = 2.5
const READ_MAX: float = 6.0
## Seconds before the first line (the title card, if any, plays in this time).
const TITLE_TIME: float = 3.6
const OPENING: float = 1.2
const TAIL: float = 2.0
const FADE_IN: float = 1.0
const FADE_OUT: float = 1.0
## Presses are ignored this long after the start (a stray press must not skip the scene).
const INPUT_GRACE: float = 0.5

@export var shot: PrologueShots.Shot = PrologueShots.Shot.EPILOGUE
@export var epilogue_style: String = "full"
@export var title_text: String = ""
@export var lines: Array[String] = []
@export var skip_mode: SkipMode = SkipMode.HOLD
@export var skip_hint_text: String = "Mantén Enter para saltar"
## Multiplier of the reading time of every line (1.0 = the prologue's pace).
@export var hold_scale: float = 1.0
## Seconds the confirm action must be held (HOLD mode).
@export var hold_seconds: float = 1.2
## Pauses the tree while it plays (the grandfather's scene) and gives it back at the end.
@export var pause_game: bool = false
## Darkness and torch light (the grandfather's cave).
@export var cave_light: bool = false

var elapsed: float = 0.0
var held: float = 0.0
var is_finished: bool = false
var was_skipped: bool = false

var _started: bool = false
var _ending: bool = false
var _line: int = -1
var _paused_by_reel: bool = false
var _shot_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _shots: PrologueShots
var _dark: CanvasModulate
var _light: PointLight2D
var _subtitle: Label
var _title: Label
var _hint: Label
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if pause_game:
		_paused_by_reel = true
		PauseLock.request(self, get_tree())


func _exit_tree() -> void:
	_release_pause()
	AudioDirector.release_music_duck(self)


func _process(delta: float) -> void:
	if _ending:
		return
	if not _started:
		# Black until the scene change is over (a level fades in under us).
		if SceneManager.is_transitioning():
			return
		_started = true
		_show_shot()
		_fade_to(0.0, FADE_IN)
	elapsed += delta
	_shots.t = elapsed
	_shots.advance(delta)
	_update_title()
	_update_lines()
	_update_light()
	_update_hold(delta)
	if elapsed >= total_length() - FADE_OUT:
		_finish(false)


func _input(event: InputEvent) -> void:
	if _ending or skip_mode != SkipMode.PRESS or elapsed < INPUT_GRACE:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


## Seconds the whole reel lasts when nobody skips it.
func total_length() -> float:
	var start: float = _lines_start()
	for text in lines:
		start += line_time(text)
	return start + TAIL


## Seconds a line takes to type and then stay readable (`hold_scale` shortens the reading part).
func line_time(text: String) -> float:
	return float(text.length()) / TYPE_SPEED + clampf(READ_BASE + float(text.length()) / READ_CHARS, READ_MIN, READ_MAX) * hold_scale


## The line on screen right now ("" between lines or before the first).
func current_line_text() -> String:
	return lines[_line] if _line >= 0 and _line < lines.size() else ""


func skip() -> void:
	if _ending:
		return
	_finish(true)


func _lines_start() -> float:
	return (TITLE_TIME if not title_text.is_empty() else OPENING)


func _line_start(k: int) -> float:
	var start: float = _lines_start()
	for j in mini(k, lines.size()):
		start += line_time(lines[j])
	return start


func _update_lines() -> void:
	var current: int = -1
	for k in lines.size():
		if elapsed >= _line_start(k):
			current = k
	if current != _line:
		_line = current
		_shots.line = current
		_subtitle.text = lines[current] if current >= 0 else ""
		_subtitle.visible_characters = 0
	if _line >= 0:
		var typed: int = int((elapsed - _line_start(_line)) * TYPE_SPEED)
		_subtitle.visible_characters = mini(typed, _subtitle.text.length())


func _update_title() -> void:
	if title_text.is_empty():
		return
	# Fades in, holds, fades out within TITLE_TIME.
	var k: float = clampf(elapsed / TITLE_TIME, 0.0, 1.0)
	_title.modulate.a = clampf(minf(k / 0.2, (1.0 - k) / 0.25), 0.0, 1.0)


func _update_light() -> void:
	if not cave_light:
		return
	var lit: float = clampf((elapsed - 0.8) / 0.8, 0.0, 1.0)
	var flicker: float = 0.85 + 0.1 * sin(elapsed * 11.0) * sin(elapsed * 7.3 + 1.0) + 0.05 * sin(elapsed * 23.0)
	_light.energy = 1.5 * lit * flicker
	_light.position = _shots.cave_torch()


func _update_hold(delta: float) -> void:
	if skip_mode != SkipMode.HOLD:
		return
	if elapsed >= INPUT_GRACE and Input.is_action_pressed("ui_accept"):
		held += delta
	else:
		held = maxf(held - delta * 2.0, 0.0)
	_hint.modulate.a = 0.45 + 0.55 * clampf(held / maxf(hold_seconds, 0.01), 0.0, 1.0)
	if held >= hold_seconds:
		skip()


func _finish(skipped: bool) -> void:
	if _ending:
		return
	_ending = true
	was_skipped = skipped
	_subtitle.text = ""
	_title.visible = false
	_fade_to(1.0, 0.4 if skipped else FADE_OUT)
	# A timer that ignores pause: the scene may be paused by us.
	get_tree().create_timer(0.45 if skipped else FADE_OUT + 0.05, true).timeout.connect(_end)


func _end() -> void:
	if not is_instance_valid(self):
		return
	is_finished = true
	_release_pause()
	finished.emit(was_skipped)
	queue_free()


func _release_pause() -> void:
	if _paused_by_reel:
		_paused_by_reel = false
		PauseLock.release(self, get_tree())


func _show_shot() -> void:
	# The music steps back while the story plays.
	AudioDirector.set_music_duck(self, AudioEvents.get_default().duck_story_db)
	_shots.length = total_length()
	_shots.epilogue_style = epilogue_style
	_shots.set_shot(shot)
	if cave_light:
		_dark.color = Color(0.05, 0.05, 0.07)
		_light.enabled = true
		_light.energy = 0.0


func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)


func _build() -> void:
	_shot_layer = CanvasLayer.new()
	_shot_layer.layer = 70
	add_child(_shot_layer)
	_shots = SHOTS_SCRIPT.new()
	_shots.size = Vector2(1280, 720)
	_shot_layer.add_child(_shots)
	_dark = CanvasModulate.new()
	_dark.color = Color.WHITE
	_shot_layer.add_child(_dark)
	_light = PointLight2D.new()
	_light.texture = _light_texture()
	_light.color = Color(1.0, 0.72, 0.4)
	_light.texture_scale = 3.2
	_light.energy = 0.0
	_light.enabled = false
	_light.range_layer_min = 70
	_light.range_layer_max = 70
	_shot_layer.add_child(_light)
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 71
	add_child(_ui_layer)
	var root := Control.new()
	root.theme = THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(root)
	var bars := Control.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bars.draw.connect(func() -> void:
		var s: Vector2 = bars.size
		bars.draw_rect(Rect2(0, 0, s.x, BAR_HEIGHT), Color.BLACK)
		bars.draw_rect(Rect2(0, s.y - BAR_HEIGHT, s.x, BAR_HEIGHT), Color.BLACK))
	root.add_child(bars)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"SceneLabel"
	_subtitle.add_theme_font_size_override("font_size", 26)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_top = 1.0
	_subtitle.anchor_bottom = 1.0
	_subtitle.offset_left = 120.0
	_subtitle.offset_right = -120.0
	_subtitle.offset_top = -BAR_HEIGHT
	_subtitle.offset_bottom = 0.0
	root.add_child(_subtitle)
	_title = Label.new()
	_title.theme_type_variation = &"SceneLabel"
	_title.add_theme_font_size_override("font_size", 56)
	_title.text = title_text
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.modulate.a = 0.0
	_title.visible = not title_text.is_empty()
	root.add_child(_title)
	_hint = Label.new()
	_hint.theme_type_variation = &"SceneLabel"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.text = skip_hint_text
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = -420.0
	_hint.offset_right = -30.0
	_hint.offset_top = 20.0
	_hint.offset_bottom = 56.0
	_hint.modulate.a = 0.45
	root.add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)


func _light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

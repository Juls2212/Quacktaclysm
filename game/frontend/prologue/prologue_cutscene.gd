class_name PrologueCutscene
extends Node
## Opening cinematic of a new game, played over the tutorial when it loads (~95 s unskipped):
## presenters' card, title, the hero's eye, the stars falling on the city, eyes in the forest, the
## grandfather's comic page and the prophecy in the cave, then a fade into the tutorial.
## Draws on its own canvas layers above the level (shots below, cinema bars / subtitles / skip on
## top). While it plays it keeps the player locked (player.set_input_locked(true) every frame) and
## hides the tutorial prompt and the grandfather's speech label; at the end or on skip it unlocks
## the player, shows them again and frees itself. Only calls public functions of the level, the
## player and SceneManager; never writes game state.
## Input: Esc skips (and never opens the pause menu meanwhile), Enter / Space / click advance the
## current line, the "Saltar" sign skips. Not played in headless runs (automated tests).

const SHOTS_SCRIPT := preload("res://frontend/prologue/prologue_shots.gd")
const THEME := preload("res://frontend/ui/theme/quack_theme.tres")
const BAR_HEIGHT: float = 78.0
const TYPE_SPEED: float = 38.0

signal finished

## Seconds each shot lasts (card, title, eye, fall, forest, comic, cave, out).
@export var shot_durations: PackedFloat32Array = PackedFloat32Array([5.0, 5.0, 13.0, 13.0, 14.0, 16.0, 26.0, 3.0])
## Seconds into each shot before its first subtitle line.
@export var line_leads: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 1.5, 1.6, 9.0, 1.0, 3.2, 0.0])
@export var eye_lines: Array[String] = [
	"Mi abuelo decía que cuando un pato muere, nace una estrella.",
	"Yo le creía. Todos le creíamos.",
	"Hasta la noche en que empezaron a caer.",
]
@export var fall_lines: Array[String] = [
	"No cayeron como piedras. Cayeron con hambre.",
	"Y de cada estrella se levantó algo que antes fue un pato.",
]
@export var forest_lines: Array[String] = [
	"Ojos donde no debía haber ojos. Picos que ya no eran picos.",
]
@export var comic_lines: Array[String] = [
	"Abuelo: Escúchame bien, nieto.",
	"Abuelo: No todos los que vuelven del cielo son monstruos.",
	"Abuelo: Esta hoja fue de tu bisabuelo. Y será tuya.",
]
@export var cave_lines: Array[String] = [
	"Cuando un pato muere, nace una estrella.",
	"Pero el alma que parte con arrepentimientos arde torcida.",
	"Llegará la noche en que el cielo no soporte su peso,",
	"y las estrellas caerán con cuerpos que no son suyos.",
	"Solo una hoja heredada podrá separar el alma de la ruina.",
	"Y quien la empuñe...",
	"Abuelo: El resto está borrado. No importa.",
	"Abuelo: Vamos afuera. Es hora de que aprendas a sostener esa katana.",
]
@export var skip_text: String = "Saltar"
## Automated runs (headless) never sit through the cinematic.
@export var skip_when_headless: bool = true

var _level: Node = null
var _player: Player = null
var _hidden: Array[CanvasItem] = []
var _prompt_layer: CanvasLayer = null
var _prompt_was_visible: bool = true
var _started: bool = false
var _ending: bool = false
var _index: int = 0
var _time: float = 0.0
var _line: int = -1
var _switch_left: float = -1.0
var _next_index: int = -1

var _shot_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _shots: PrologueShots
var _dark: CanvasModulate
var _light: PointLight2D
var _subtitle: Label
var _skip: Button
var _fade: ColorRect
var _wipe: UiFx


func _ready() -> void:
	if skip_when_headless and DisplayServer.get_name() == "headless":
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = get_parent()
	if _level != null:
		var value: Variant = _level.get(&"player")
		if value is Player:
			_player = value
		_prompt_layer = _level.get_node_or_null(^"PromptLayer") as CanvasLayer
		if _prompt_layer != null:
			_prompt_was_visible = _prompt_layer.visible
			_prompt_layer.visible = false
		var label := _level.get_node_or_null(^"Content/Grandfather/Label") as CanvasItem
		if label != null and label.visible:
			label.visible = false
			_hidden.append(label)
	_build()
	_lock_player()


func _process(delta: float) -> void:
	_lock_player()
	if not _started:
		# Black until the scene fade is over, then the first shot.
		if SceneManager.is_transitioning():
			return
		_started = true
		_show_shot(0)
		_fade_to(0.0, 0.6)
	if _ending:
		return
	_time += delta
	_shots.t = _time
	_shots.advance(delta)
	_update_lines()
	_update_cave(delta)
	if _switch_left >= 0.0:
		_switch_left -= delta
		if _switch_left < 0.0:
			_show_shot(_next_index)
	elif _time >= shot_durations[_index]:
		_go_next()


func _physics_process(_delta: float) -> void:
	_lock_player()


func _input(event: InputEvent) -> void:
	if _ending:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		skip()
		return
	var click := event as InputEventMouseButton
	var advance_pressed: bool = event.is_action_pressed("ui_accept")
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if _skip != null and _skip.get_global_rect().has_point(click.position):
			return
		advance_pressed = true
	if advance_pressed:
		get_viewport().set_input_as_handled()
		_advance_text()


## Ends the cinematic at once (fade to black, then the tutorial).
func skip() -> void:
	if _ending:
		return
	_finish()


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
	# Lights only reach their own canvas layer range: this one lives on the cinematic's layer.
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
	_subtitle.add_theme_font_size_override("font_size", 28)
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
	var skip_button := SignButton.new()
	skip_button.look = SignButton.Look.CARDBOARD
	skip_button.ropes = false
	skip_button.cap_height = 17.0
	skip_button.tilt = 1.5
	skip_button.custom_minimum_size = Vector2(150, 46)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.text = skip_text
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.offset_left = -186.0
	skip_button.offset_right = -36.0
	skip_button.offset_top = 16.0
	skip_button.offset_bottom = 62.0
	skip_button.pressed.connect(skip)
	root.add_child(skip_button)
	_skip = skip_button
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)
	_wipe = UiFx.new()
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_wipe)


func _show_shot(index: int) -> void:
	_index = index
	_time = 0.0
	_line = -1
	_switch_left = -1.0
	_subtitle.text = ""
	_shots.set_shot(index as PrologueShots.Shot)
	var cave: bool = index == PrologueShots.Shot.CAVE
	_dark.color = Color(0.05, 0.05, 0.07) if cave else Color.WHITE
	_light.enabled = cave
	_light.energy = 0.0


## Ink splash, brush wipe or fade to black between shots — never a hard cut.
func _go_next() -> void:
	var next: int = _index + 1
	if next >= shot_durations.size():
		_finish()
		return
	_next_index = next
	if next % 2 == 1:
		_wipe.play(Vector2(640, 360), 1100.0)
		_switch_left = 0.18
	else:
		_fade_to(1.0, 0.3)
		_switch_left = 0.32
		get_tree().create_timer(0.34, true).timeout.connect(func() -> void:
			if is_instance_valid(self) and not _ending:
				_fade_to(0.0, 0.4))


func _lines_of(index: int) -> Array[String]:
	match index:
		PrologueShots.Shot.EYE:
			return eye_lines
		PrologueShots.Shot.FALL:
			return fall_lines
		PrologueShots.Shot.FOREST:
			return forest_lines
		PrologueShots.Shot.COMIC:
			return comic_lines
		PrologueShots.Shot.CAVE:
			return cave_lines
	return []


func _line_start(index: int, k: int) -> float:
	var lines: Array[String] = _lines_of(index)
	var lead: float = line_leads[index] if index < line_leads.size() else 1.0
	var slot: float = (shot_durations[index] - lead - 1.0) / float(maxi(lines.size(), 1))
	return lead + slot * float(k)


func _update_lines() -> void:
	var lines: Array[String] = _lines_of(_index)
	var current: int = -1
	for k in lines.size():
		if _time >= _line_start(_index, k):
			current = k
	if current != _line:
		_line = current
		_shots.line = current
		_subtitle.text = lines[current] if current >= 0 else ""
		_subtitle.visible_characters = 0
	if _line >= 0:
		var typed: int = int((_time - _line_start(_index, _line)) * TYPE_SPEED)
		_subtitle.visible_characters = mini(typed, _subtitle.text.length())


## Enter / Space / click: finish typing the line, or jump to the next one (or the next shot).
func _advance_text() -> void:
	if not _started or _switch_left >= 0.0:
		return
	if _line >= 0 and _subtitle.visible_characters < _subtitle.text.length():
		_time = maxf(_time, _line_start(_index, _line) + float(_subtitle.text.length()) / TYPE_SPEED)
		return
	var lines: Array[String] = _lines_of(_index)
	if _line + 1 < lines.size():
		_time = maxf(_time, _line_start(_index, _line + 1))
	else:
		_time = shot_durations[_index]


## The cave: darkness, then the grandfather's torch lights up and flickers.
func _update_cave(_delta: float) -> void:
	if _index != PrologueShots.Shot.CAVE:
		return
	var lit: float = clampf((_time - 1.4) / 0.8, 0.0, 1.0)
	var flicker: float = 0.85 + 0.1 * sin(_time * 11.0) * sin(_time * 7.3 + 1.0) + 0.05 * sin(_time * 23.0)
	# Lowered before the last lines, so the end of the stone falls back into the dark.
	var lowered: float = 0.65 if _line >= 6 else 1.0
	_light.energy = 1.5 * lit * flicker * lowered
	_light.position = _shots.cave_torch()


func _finish() -> void:
	_ending = true
	_fade_to(1.0, 0.35)
	get_tree().create_timer(0.4, true).timeout.connect(_reveal)


## Black, then the tutorial shows through as the black fades away.
func _reveal() -> void:
	if not is_instance_valid(self):
		return
	_release()
	_shots.visible = false
	_light.enabled = false
	_dark.color = Color.WHITE
	_subtitle.text = ""
	_skip.visible = false
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 1.2)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _release() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_input_locked(false)
	if _prompt_layer != null and is_instance_valid(_prompt_layer):
		_prompt_layer.visible = _prompt_was_visible
	for item in _hidden:
		if is_instance_valid(item):
			item.visible = true
	_hidden.clear()
	_player = null


func _lock_player() -> void:
	if _ending:
		return
	if _player != null and is_instance_valid(_player):
		_player.set_input_locked(true)


func _fade_to(alpha: float, seconds: float) -> void:
	if _fade == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)


func _exit_tree() -> void:
	# Never leave the player locked, whatever ends the cinematic.
	if _player != null and is_instance_valid(_player):
		_player.set_input_locked(false)


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

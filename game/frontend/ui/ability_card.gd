class_name AbilityCard
extends CanvasLayer
## Full-screen "Nueva habilidad" card in the stone style (Hollow Knight style): the ability name, one line
## about it and the key(s) CURRENTLY bound to it, read live from the InputMap, plus where to change them.
## It pauses the game while it is on screen (PauseLock) and goes away with the confirm action (or a click).
## An event is shown once per run of the game: `present` refuses an event id already shown, and nothing is
## saved anywhere (the ids live in memory only). Text comes from AbilityTexts. Presentation only.

signal dismissed

## Presses are ignored this long after the card appears.
const INPUT_GRACE: float = 0.35
const INK := Color(0.106, 0.098, 0.122)
const CREAM := Color(0.98, 0.93, 0.8)
const SOFT := Color(0.72, 0.9, 1.0)
const THEME := preload("res://frontend/ui/theme/quack_theme.tres")

## Event ids already shown in this process (memory only: nothing is saved).
static var _shown: Dictionary = {}

var event_id: String = ""
var is_open: bool = false
var ability_name: String = ""
var description: String = ""
var key_text: String = ""
## The color of the sword wave shown in the card of the wave upgrade (alpha 0 = no swatch): the glyph left of the title.
var swatch_color: Color = Color(0.0, 0.0, 0.0, 0.0)

var _swatch: SwordWaveTier = null

var _texts: AbilityTexts = null
var _actions: PackedStringArray = PackedStringArray()
var _elapsed: float = 0.0
var _holds_pause: bool = false
var _panel: Control = null
var _title_label: Label
var _name_label: Label
var _description_label: Label
var _keys_label: Label
var _footer_label: Label
var _hint_label: Label


static func forget_all() -> void:
	_shown.clear()


static func was_shown(id: String) -> bool:
	return bool(_shown.get(id, false))


## Creates the card under `host` and shows it, unless `id` was already shown. Returns the card or null.
static func present(host: Node, id: String, name_text: String, description_text: String, actions: PackedStringArray, swatch: SwordWaveTier = null) -> AbilityCard:
	if host == null or was_shown(id):
		return null
	var card := AbilityCard.new()
	host.add_child(card)
	card.show_card(id, name_text, description_text, actions, swatch)
	return card


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_texts = AbilityTexts.get_default()
	_build()
	_panel.get_parent().visible = false


func _exit_tree() -> void:
	_release_pause()


func _process(delta: float) -> void:
	if is_open:
		_elapsed += delta
		_panel.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open or _elapsed < INPUT_GRACE:
		return
	var click := event as InputEventMouseButton
	var confirm: bool = event.is_action_pressed("ui_accept") or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT)
	if confirm:
		get_viewport().set_input_as_handled()
		dismiss()


## Shows the card. The key line is built NOW from the InputMap, so it follows any remap.
func show_card(id: String, name_text: String, description_text: String, actions: PackedStringArray, swatch: SwordWaveTier = null) -> void:
	_swatch = swatch
	swatch_color = swatch.tint if swatch != null else Color(0.0, 0.0, 0.0, 0.0)
	event_id = id
	_shown[id] = true
	ability_name = name_text
	description = description_text
	_actions = actions
	refresh_keys()
	_title_label.text = _texts.card_title
	_name_label.text = name_text
	_description_label.text = description_text
	_footer_label.text = _texts.footer
	_hint_label.text = _texts.dismiss_hint
	_elapsed = 0.0
	is_open = true
	_panel.get_parent().visible = true
	if not _holds_pause:
		_holds_pause = true
		PauseLock.request(self, get_tree())


## The key names of the actions right now (what the player would press), "Tecla: E / Q".
func refresh_keys() -> void:
	var names: PackedStringArray = PackedStringArray()
	for action in _actions:
		names.append(ControlsConfig.input_map_hint(StringName(action)))
	key_text = _texts.keys_format % " / ".join(names)
	if _keys_label != null:
		_keys_label.text = key_text


func dismiss() -> void:
	if not is_open:
		return
	is_open = false
	_panel.get_parent().visible = false
	_release_pause()
	dismissed.emit()
	queue_free()


func _release_pause() -> void:
	if _holds_pause:
		_holds_pause = false
		PauseLock.release(self, get_tree())


func _build() -> void:
	var root := Control.new()
	root.theme = THEME
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.06, 0.82)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 420)
	_panel.size = Vector2(760, 420)
	_panel.position = Vector2(-380, -210)
	_panel.draw.connect(_draw_panel)
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 36)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_title_label = _make_label(box, 24, SOFT)
	_name_label = _make_label(box, 52, CREAM)
	_description_label = _make_label(box, 24, CREAM)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(680, 0)
	_keys_label = _make_label(box, 34, Color(1.0, 0.86, 0.45))
	_footer_label = _make_label(box, 20, SOFT)
	_hint_label = _make_label(box, 17, Color(CREAM, 0.7))


func _make_label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SceneLabel"
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _draw_panel() -> void:
	var rect := Rect2(Vector2.ZERO, _panel.size)
	StoneUi.frame(_panel, rect, 8.0, 77)
	StoneUi.well(_panel, rect.grow(-6.0))
	# A soft glow behind the title that breathes.
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * 3.0)
	_panel.draw_circle(Vector2(rect.size.x * 0.5, 60.0), 90.0 + 8.0 * pulse, Color(SOFT, 0.05 + 0.05 * pulse))
	if _swatch != null:
		_draw_swatch(Vector2(112.0, 118.0), pulse)


## The sword wave of the upgrade, drawn at the size of the game's wave and a few times bigger: the glow, the trail, the body,
## the dark core (violet tier) and the light rim, in the colors of the tier the player just reached.
func _draw_swatch(at: Vector2, pulse: float) -> void:
	var tier: SwordWaveTier = _swatch
	var scale_up: float = 1.5
	for i in 8:
		var t: float = float(i) / 8.0
		_panel.draw_circle(at + Vector2(-t * tier.trail_length * 1.1, 0.0), 22.0 * (1.0 - 0.7 * t), Color(tier.glow_color, tier.glow_strength * 0.7 * (1.0 - t)))
	_panel.draw_circle(at, 34.0 + 3.0 * pulse, Color(tier.glow_color, tier.glow_strength * (0.45 + 0.2 * pulse)))
	_panel.draw_set_transform(at, 0.0, Vector2(scale_up, scale_up))
	_panel.draw_colored_polygon(PackedVector2Array([Vector2(-2, -22), Vector2(8, -14), Vector2(12, 0), Vector2(8, 14), Vector2(-2, 22), Vector2(2, 12), Vector2(5, 0), Vector2(2, -12)]), tier.tint)
	if tier.core_color.a > 0.0:
		_panel.draw_colored_polygon(PackedVector2Array([Vector2(2, -13), Vector2(7, -6), Vector2(9, 0), Vector2(7, 6), Vector2(2, 13), Vector2(4, 0)]), tier.core_color)
	_panel.draw_polyline(PackedVector2Array([Vector2(-2, -22), Vector2(8, -14), Vector2(12, 0), Vector2(8, 14), Vector2(-2, 22), Vector2(2, 12), Vector2(5, 0), Vector2(2, -12), Vector2(-2, -22)]), tier.rim_color, 1.2, true)
	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

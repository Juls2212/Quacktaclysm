class_name EndingCredits
extends Node
## The credits and statistics sequence after the grandfather's last line (Phase 15t): the white clears slowly into the night sky of the ending
## (EndingCreditsSky), the credits roll over it, then the statistics appear one by one as a summary card (the counters count up smoothly), and then
## the sequence ends: the final card (the line of support and the way back to the menu) is the one EndingController shows. Holding the confirm action
## skips it all; the tree pause stops it; in reduced mode the sky is still, the credits are static pages and the statistics appear without counting.
## It reads the credits from the ONE credits resource (CreditsContent), keeps the ending's music (a slow, quiet fade, never a swell) and plays
## nothing else: no sound event, no flashes. Drawing and timing only: no gameplay logic, and it never writes game state.

signal finished(skipped: bool)
signal phase_changed(phase: int)

enum Phase { SKY, CREDITS, STATS, DONE }

const THEME := preload("res://frontend/ui/theme/quack_theme.tres")
const COLUMN_WIDTH: float = 760.0
const VIEW_SIZE := Vector2(1280.0, 720.0)

@export var config: EndingCreditsConfig = null
@export var content: CreditsContent = null
## "kept" or "released".
@export var style: String = "kept"
@export var music_slot: EndingMusicSlot = null
## The summary card: its title, then rows {text: String} for static lines or {format: String, value: int} for counters.
@export var stats_title: String = ""
@export var stat_rows: Array = []
@export var skip_hint_text: String = "Mantén Enter para saltar"
## The veil starts white after the cut and the last line, or black after a skip.
@export var start_white: bool = true

var phase: Phase = Phase.SKY
var phase_t: float = 0.0
var elapsed: float = 0.0
var held: float = 0.0
var reduced: bool = false
var is_finished: bool = false
var was_skipped: bool = false
var sky: EndingCreditsSky = null
var roll: VBoxContainer = null
var roll_height: float = 0.0
var stats_box: VBoxContainer = null
var stat_labels: Array[Label] = []
var pages: Array[VBoxContainer] = []
var page_index: int = -1
var music_playing: bool = false

var _layer: CanvasLayer
var _veil: ColorRect
var _hint: Label
var _ending: bool = false
var _credits_clock: float = 0.0
var _page_t: float = 0.0
var _music_db: float = -60.0
var _music_target: float = -60.0
var _pause_token := RefCounted.new()
var _layout_wait: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reduced = not GameSettings.is_corruption_effects_enabled()
	if config == null:
		config = EndingCreditsConfig.get_default()
	if content == null:
		content = CreditsContent.get_default()
	_build()
	_start_music()


func _exit_tree() -> void:
	_stop_music()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and music_playing:
		AudioDirector.set_music_duck(_pause_token, -60.0)
	elif what == NOTIFICATION_UNPAUSED:
		AudioDirector.release_music_duck(_pause_token)


# ---------------------------------------------------------------------------------------------
# Music: the ending's slot, brought up slowly to a quiet level
# ---------------------------------------------------------------------------------------------

func _start_music() -> void:
	if music_slot == null or music_slot.file.is_empty():
		return
	music_playing = true
	_music_target = config.kept_music_db if style == "kept" else config.released_music_db
	AudioDirector.play_music(music_slot.file, true, music_slot.track_pitch)
	AudioDirector.set_music_profile(1.0, music_slot.cutoff_hz, 1.5, self)
	AudioDirector.set_music_duck(self, _music_db)


func _stop_music() -> void:
	AudioDirector.release_music_duck(self)
	AudioDirector.release_music_duck(_pause_token)
	if music_playing:
		AudioDirector.release_music_profile(self)
	music_playing = false


## Gives the music's volume a slow ramp (never faster than the configured fade) and follows it.
func _update_music(delta: float) -> void:
	if not music_playing:
		return
	var rate: float = (_music_target + 60.0) / maxf(config.music_fade_seconds, 0.1)
	_music_db = move_toward(_music_db, _music_target, rate * delta)
	AudioDirector.set_music_duck(self, _music_db)


# ---------------------------------------------------------------------------------------------
# Timing
# ---------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _ending or elapsed < config.input_grace or not event.is_action_pressed("ui_accept"):
		return
	press_confirm()


## One press: moves a static page on (reduced), or takes the finished statistics to the final card. Nothing else (a hold skips everything).
func press_confirm() -> void:
	if _ending:
		return
	if phase == Phase.CREDITS and reduced:
		_next_page()
	elif phase == Phase.STATS and _stats_complete():
		_finish(false)


func skip() -> void:
	_finish(true)


func _process(delta: float) -> void:
	if _ending:
		return
	elapsed += delta
	phase_t += delta
	_update_music(delta)
	if not reduced:
		sky.time += delta
	# The veil only ever clears (white or black into the sky): it never comes back.
	var veil_seconds: float = 0.6 if reduced else config.veil_seconds
	_veil.color.a = minf(_veil.color.a, 1.0 - smoothstep(0.0, 1.0, clampf(elapsed / veil_seconds, 0.0, 1.0)))
	match phase:
		Phase.SKY:
			_process_sky()
		Phase.CREDITS:
			_process_credits(delta)
		Phase.STATS:
			_process_stats()
	_update_hold(delta)


func _set_phase(next: Phase) -> void:
	phase = next
	phase_t = 0.0
	phase_changed.emit(int(next))


func _process_sky() -> void:
	if phase_t >= (0.6 if reduced else config.credits_lead_seconds):
		_begin_credits()


func _begin_credits() -> void:
	_set_phase(Phase.CREDITS)
	if reduced:
		_next_page()
		return
	roll.visible = true
	roll.position.y = VIEW_SIZE.y
	_credits_clock = 0.0
	_layout_wait = 2


func _process_credits(delta: float) -> void:
	if reduced:
		_page_t += delta
		if _page_t >= config.page_seconds:
			_next_page()
		return
	if _layout_wait > 0:
		_layout_wait -= 1
		roll_height = CreditsRoll.column_height(roll)
		return
	roll.position.y -= content.ending_speed * delta
	if roll.position.y + roll_height < 0.0:
		_credits_clock += delta
		if _credits_clock >= config.credits_tail_seconds:
			_begin_stats()


func _next_page() -> void:
	if page_index >= 0 and page_index < pages.size():
		pages[page_index].visible = false
	page_index += 1
	_page_t = 0.0
	if page_index >= pages.size():
		_begin_stats()
		return
	pages[page_index].visible = true


func _begin_stats() -> void:
	roll.visible = false
	for page in pages:
		page.visible = false
	stats_box.visible = true
	_set_phase(Phase.STATS)


func _stat_start(index: int) -> float:
	return 0.4 + index * (config.stat_fade_seconds + config.stat_gap_seconds)


func _process_stats() -> void:
	for i in stat_labels.size():
		var label: Label = stat_labels[i]
		var local: float = phase_t - _stat_start(i)
		if reduced:
			label.modulate.a = 1.0
		else:
			label.modulate.a = smoothstep(0.0, 1.0, clampf(local / config.stat_fade_seconds, 0.0, 1.0))
		var row: Dictionary = stat_rows[i] as Dictionary
		if row.has("format"):
			var target: int = int(row["value"])
			var shown: int = target if reduced else int(round(float(target) * smoothstep(0.0, 1.0, clampf(local / config.count_seconds, 0.0, 1.0))))
			label.text = String(row["format"]) % shown
	if not _stats_complete():
		return
	if phase_t >= _stats_done_time() + config.stats_hold_seconds:
		_finish(false)


## Every statistic is on screen with its counter at its final value.
func _stats_complete() -> bool:
	return phase_t >= _stats_done_time()


func _stats_done_time() -> float:
	if reduced or stat_labels.is_empty():
		return 0.0
	return _stat_start(stat_labels.size() - 1) + maxf(config.stat_fade_seconds, config.count_seconds)


func _update_hold(delta: float) -> void:
	if elapsed >= config.input_grace and Input.is_action_pressed("ui_accept"):
		held += delta
	else:
		held = maxf(held - delta * 2.0, 0.0)
	_hint.modulate.a = 0.4 + 0.5 * clampf(held / maxf(config.hold_seconds, 0.01), 0.0, 1.0)
	if held >= config.hold_seconds:
		skip()


func _finish(skipped: bool) -> void:
	if _ending:
		return
	_ending = true
	was_skipped = skipped
	_set_phase(Phase.DONE)
	_music_target = -60.0
	if music_playing:
		var tween := create_tween()
		tween.tween_method(func(db: float) -> void: AudioDirector.set_music_duck(self, db), _music_db, -60.0, config.skip_fade_seconds if skipped else config.closing_fade_seconds)
	var seconds: float = config.skip_fade_seconds if skipped else config.closing_fade_seconds
	_veil.color = Color(Color.BLACK, _veil.color.a)
	var fade := create_tween()
	fade.tween_property(_veil, "color:a", 1.0, seconds)
	# A timer that ignores pause: the sequence may be paused by us.
	get_tree().create_timer(seconds + 0.05, true).timeout.connect(_end)


func _end() -> void:
	if not is_instance_valid(self) or is_finished:
		return
	is_finished = true
	_layer.visible = false
	finished.emit(was_skipped)


# ---------------------------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------------------------

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 72
	add_child(_layer)
	var root := Control.new()
	root.theme = THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)
	sky = EndingCreditsSky.new()
	sky.name = "Sky"
	sky.style = style
	sky.reduced = reduced
	sky.config = config
	root.add_child(sky)
	var style_map: Dictionary = {
		"title_variation": "SceneLabel", "header_variation": "SceneLabel", "line_variation": "SceneLabel", "note_variation": "SceneLabel",
		"sizes": {"title": 64, "header": 32, "line": 26, "note": 20},
		"colors": {"title": Color(0.97, 0.94, 0.86), "header": Color(0.9, 0.78, 0.55), "line": Color(0.93, 0.93, 0.95), "note": Color(0.72, 0.76, 0.84)},
	}
	# The scrolling column (clipped to the screen so it never covers the hint).
	var view := Control.new()
	view.name = "CreditsView"
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	roll = VBoxContainer.new()
	roll.name = "CreditsRoll"
	roll.alignment = BoxContainer.ALIGNMENT_BEGIN
	roll.position = Vector2((VIEW_SIZE.x - COLUMN_WIDTH) * 0.5, VIEW_SIZE.y)
	roll.size = Vector2(COLUMN_WIDTH, 0.0)
	roll.visible = false
	view.add_child(roll)
	CreditsRoll.fill(roll, content, COLUMN_WIDTH, true, style_map)
	# The static pages of the reduced mode: one section each, centred.
	var notice: String = StoryTexts.get_default().content_notice
	for section: Dictionary in content.sections(notice, true):
		var page := VBoxContainer.new()
		page.name = "CreditsPage"
		page.visible = false
		page.alignment = BoxContainer.ALIGNMENT_CENTER
		page.position = Vector2((VIEW_SIZE.x - COLUMN_WIDTH) * 0.5, 0.0)
		page.size = Vector2(COLUMN_WIDTH, VIEW_SIZE.y)
		page.add_theme_constant_override(&"separation", 8)
		CreditsRoll.add_section(page, section, COLUMN_WIDTH, style_map)
		view.add_child(page)
		pages.append(page)
	_build_stats(root)
	_hint = Label.new()
	_hint.theme_type_variation = &"SceneLabel"
	_hint.add_theme_font_size_override(&"font_size", 18)
	_hint.text = skip_hint_text
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = -420.0
	_hint.offset_right = -30.0
	_hint.offset_top = 20.0
	_hint.offset_bottom = 56.0
	_hint.modulate.a = 0.4
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(Color.WHITE if start_white else Color.BLACK, 1.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_veil)


func _build_stats(root: Control) -> void:
	stats_box = VBoxContainer.new()
	stats_box.name = "StatsCard"
	stats_box.visible = false
	stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_box.position = Vector2((VIEW_SIZE.x - COLUMN_WIDTH) * 0.5, 0.0)
	stats_box.size = Vector2(COLUMN_WIDTH, VIEW_SIZE.y)
	stats_box.add_theme_constant_override(&"separation", 18)
	root.add_child(stats_box)
	if not stats_title.is_empty():
		stats_box.add_child(_stat_label(stats_title, 44, Color(0.97, 0.94, 0.86)))
	for i in stat_rows.size():
		var row: Dictionary = stat_rows[i] as Dictionary
		var text: String = String(row["format"]) % 0 if row.has("format") else String(row.get("text", ""))
		var label: Label = _stat_label(text, 30, Color(0.93, 0.93, 0.95))
		label.modulate.a = 0.0
		stats_box.add_child(label)
		stat_labels.append(label)


func _stat_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SceneLabel"
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

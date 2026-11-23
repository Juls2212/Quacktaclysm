class_name EndingCinematic
extends Node
## Plays one ending (Phase 15i): the beat list of the ending (EndingBeatList) over an EndingScene, with the grandfather's portrait, cinema bars,
## the typed subtitles, the sounds and a closing fade. TIMED beats run by themselves; a LINE beat shows its line with a typewriter and waits for
## the confirm action: the first press completes the line, the second moves on, and no timer ever advances a line. Holding the confirm action
## (`hold_seconds`) skips the whole ending; the tree pause stops it; a remapped confirm action works (it reads the action, not a key).
## In reduced mode ("Efectos de corrupción" off) the scene has no motion, no particles and no camera moves: every beat is one still,
## reached through a short fade, with the same text. Its music is built from an existing track processed by code (a lower pitch, a low-pass
## filter and a reverb on the Music bus: the EndingMusicSlot of the ending), ducked or silenced beat by beat, paused with the game and stopped
## cleanly on skip and exit. It never writes game state; it frees itself after `finished`.

signal finished(skipped: bool)
## A line of the ending came on screen (its index in `lines` and its text).
signal line_changed(index: int, text: String)
## A beat began (its index and the beat).
signal beat_started(index: int, beat: EndingBeat)

const THEME := preload("res://frontend/ui/theme/quack_theme.tres")
const BAR_HEIGHT: float = 78.0
const TYPE_SPEED: float = 35.0
## Seconds the title card takes over the opening beat.
const TITLE_TIME: float = 3.6
const FADE_IN: float = 1.2
## Presses are ignored this long after the start (a stray press must not skip the scene).
const INPUT_GRACE: float = 0.5
## The fade from black at every beat of a reduced (still) ending.
const STILL_FADE: float = 0.5
const GRANDFATHER_PREFIX: String = "Abuelo:"

@export var beats: EndingBeatList = null
@export var lines: Array[String] = []
@export var title_text: String = ""
## "kept" or "released": the look of the scene.
@export var style: String = "kept"
@export var skip_hint_text: String = "Mantén Enter para saltar"
## Seconds the confirm action must be held to skip the whole ending.
@export var hold_seconds: float = 1.2
## How much of the duck's corruption the scene shows (0 to 1, from the number of fragments kept).
@export_range(0.0, 1.0, 0.01) var corruption_scale: float = 1.0
## The ending's music slot (a track and how it is processed); null = no music.
@export var music_slot: EndingMusicSlot = null
## Seconds of the closing fade after a skip.
@export_range(0.1, 2.0, 0.05, "suffix:s") var skip_fade: float = 0.4

var elapsed: float = 0.0
var held: float = 0.0
var is_finished: bool = false
var was_skipped: bool = false
var beat_index: int = -1
var beat_t: float = 0.0
var line_index: int = -1
var typed_done: bool = false
var manual_line_time: float = 0.0
var reduced: bool = false
var scene: EndingScene = null
var portrait: GrandfatherSky = null
## The dark silhouette still shown over the white of the cut (Phase 15r).
var white_silhouette: EndingSilhouette = null

var _started: bool = false
var _ending: bool = false
var _scene_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _subtitle: Label
var _prompt: Label
var _title: Label
var _hint: Label
var _fade: ColorRect
var _texts: StoryTexts = null
var _fade_start: float = 0.0
var _dip: float = 0.0
var _loop_clock: float = 0.0
var _scene_time: float = 0.0
var _reverb: AudioEffectReverb = null
## Owners of the music duck while paused and while a beat asks for silence.
var _pause_token := RefCounted.new()
var music_playing: bool = false
## How many times a fail-safe moved the ending on (a beat that ran too long, the total limit); 0 in a healthy ending.
var failsafe_count: int = 0
## True once the frame watchdog switched the scene to its light mode.
var light_mode: bool = false
var _slow_time: float = 0.0
var _last_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_texts = StoryTexts.get_default()
	reduced = not GameSettings.is_corruption_effects_enabled()
	_build()


func _exit_tree() -> void:
	_stop_music()


func _notification(what: int) -> void:
	# The game pauses: the ending's music goes quiet with it and comes back when the game does.
	if what == NOTIFICATION_PAUSED and music_playing:
		AudioDirector.set_music_duck(_pause_token, -60.0)
	elif what == NOTIFICATION_UNPAUSED:
		AudioDirector.release_music_duck(_pause_token)


## Starts the ending's music: the slot's track, processed (pitch, low-pass, reverb) and ducked under the scene.
func _start_music() -> void:
	if music_slot == null or music_slot.file.is_empty() or music_playing:
		return
	music_playing = true
	AudioDirector.play_music(music_slot.file, true, music_slot.track_pitch)
	AudioDirector.set_music_profile(1.0, music_slot.cutoff_hz, 1.5, self)
	AudioDirector.set_music_duck(self, music_slot.base_duck_db)
	if music_slot.reverb_wet > 0.0:
		GameSettings.ensure_buses()
		var bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = music_slot.reverb_room
		_reverb.damping = 0.6
		_reverb.wet = music_slot.reverb_wet
		_reverb.dry = 1.0 - music_slot.reverb_wet * 0.5
		AudioServer.add_bus_effect(bus, _reverb)


## Gives everything back: the duck, the processing and the reverb (the bus has the same effects as before).
func _stop_music() -> void:
	AudioDirector.release_music_duck(self)
	AudioDirector.release_music_duck(_pause_token)
	if music_playing:
		AudioDirector.release_music_profile(self)
	music_playing = false
	if _reverb != null:
		var bus: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == _reverb:
				AudioServer.remove_bus_effect(bus, i)
				break
		_reverb = null


## The beat being played (null before the first or after the last).
func current_beat() -> EndingBeat:
	if beats == null or beat_index < 0 or beat_index >= beats.beats.size():
		return null
	return beats.beats[beat_index]


func current_line_text() -> String:
	var beat: EndingBeat = current_beat()
	if beat == null or not beat.is_line() or beat.line >= lines.size():
		return ""
	return lines[beat.line]


func _input(event: InputEvent) -> void:
	if _ending or elapsed < INPUT_GRACE or not event.is_action_pressed("ui_accept"):
		return
	var beat: EndingBeat = current_beat()
	if beat != null and beat.is_line():
		press_confirm()


func _process(delta: float) -> void:
	if _ending:
		return
	if not _started:
		if SceneManager.is_transitioning():
			return
		_started = true
		_fade.color.a = 1.0
		_start_music()
		_enter_beat(0)
	elapsed += delta
	beat_t += delta
	_watch_frame_cost()
	if elapsed > beats.max_total_seconds:
		failsafe_count += 1
		_finish(false)
		return
	var beat: EndingBeat = current_beat()
	if beat == null:
		return
	if not reduced:
		_scene_time += delta
	_update_title()
	if beat.is_line():
		_update_line(delta)
		if beat_t >= beats.max_line_seconds:
			failsafe_count += 1
			_next_beat()
			beat = current_beat()
			if beat == null:
				return
	elif beat_t >= minf(beat.seconds, beats.max_beat_seconds):
		if beat.seconds > beats.max_beat_seconds:
			failsafe_count += 1
		_next_beat()
		beat = current_beat()
		if beat == null:
			return
	_update_scene(beat)
	_update_sound(beat, delta)
	_update_hold(delta)


## One confirm press on a LINE beat: completes the line being typed, or moves on to the next beat.
func press_confirm() -> void:
	var beat: EndingBeat = current_beat()
	if _ending or beat == null or not beat.is_line():
		return
	if not typed_done:
		_complete_line()
		return
	_next_beat()


func skip() -> void:
	if _ending:
		return
	_finish(true)


func _next_beat() -> void:
	if beats == null or beat_index + 1 >= beats.beats.size():
		_finish(false)
		return
	_enter_beat(beat_index + 1)


func _enter_beat(index: int) -> void:
	if beats == null or index >= beats.beats.size():
		_finish(false)
		return
	var previous: EndingBeat = current_beat()
	_fade_start = previous.fade_to if previous != null else 1.0
	beat_index = index
	beat_t = 0.0
	_loop_clock = 0.0
	var beat: EndingBeat = beats.beats[index]
	_subtitle.text = ""
	_prompt.visible = false
	typed_done = false
	if beat.is_line() and beat.line < lines.size():
		line_index = beat.line
		_subtitle.text = lines[beat.line]
		_subtitle.visible_characters = 0
		manual_line_time = 0.0
		line_changed.emit(beat.line, lines[beat.line])
	if beat.expression != &"":
		portrait.set_expression(beat.expression)
	var base_duck: float = music_slot.base_duck_db if music_slot != null else AudioEvents.get_default().duck_story_db
	AudioDirector.set_music_duck(self, base_duck if beat.music_db >= -0.001 else beat.music_db)
	if beat.sfx != &"" and beat.sfx_at <= 0.001:
		_play(beat.sfx, beat.sfx_pitch, beat.sfx_volume_db)
	_dip = 1.0 if reduced else 0.0
	beat_started.emit(index, beat)


func _play(event_id: StringName, pitch: float, volume_db: float) -> void:
	AudioDirector.play_event(event_id, null, volume_db, pitch)


# ---------------------------------------------------------------------------------------------
# Per frame
# ---------------------------------------------------------------------------------------------

func _update_line(delta: float) -> void:
	manual_line_time += delta
	if not typed_done:
		var typed: int = int(manual_line_time * TYPE_SPEED)
		_subtitle.visible_characters = mini(typed, _subtitle.text.length())
		if typed >= _subtitle.text.length():
			_complete_line()
	else:
		_prompt.modulate.a = 1.0 if reduced else 0.65 + 0.35 * sin(manual_line_time * TAU * 1.2)


func _complete_line() -> void:
	typed_done = true
	_subtitle.visible_characters = -1
	_prompt.text = _texts.advance_prompt_format % BossDialogue.confirm_key_name()
	_prompt.visible = true


## A slow machine must never freeze the ending: when frames stay slow the scene goes to its light mode (static layers, no twinkle).
func _watch_frame_cost() -> void:
	var now: int = Time.get_ticks_usec()
	var wall_ms: float = (now - _last_usec) / 1000.0 if _last_usec > 0 else 0.0
	_last_usec = now
	if light_mode or beats == null:
		return
	_slow_time = _slow_time + wall_ms / 1000.0 if wall_ms > beats.slow_frame_ms else maxf(_slow_time - 0.02, 0.0)
	if _slow_time >= beats.slow_window_seconds:
		light_mode = true
		scene.light_mode = true


func _update_title() -> void:
	if title_text.is_empty():
		return
	var k: float = clampf(elapsed / TITLE_TIME, 0.0, 1.0)
	_title.modulate.a = clampf(minf(k / 0.2, (1.0 - k) / 0.25), 0.0, 1.0)


## Feeds the scene and the portrait from the beat and how far into it we are.
func _update_scene(beat: EndingBeat) -> void:
	var raw: float = clampf(beat_t / maxf(beat.seconds, 0.01), 0.0, 1.0)
	var progress: float = beat.reduced_progress if reduced else raw
	var k: float = smoothstep(0.0, 1.0, progress)
	scene.reduced = reduced
	scene.layer_redraw_hz = beats.layer_redraw_hz
	scene.style = style
	scene.corruption_scale = corruption_scale
	scene.time = _scene_time
	scene.focus = beat.focus_from.lerp(beat.focus_to, k)
	scene.zoom = lerpf(beat.zoom_from, beat.zoom_to, k)
	scene.pose = beat.duck_pose
	scene.pose_p = lerpf(beat.pose_p_from, beat.pose_p_to, progress)
	scene.duck_visible = beat.duck_visible
	scene.duck_from = beat.duck_from
	scene.duck_to = beat.duck_to
	scene.silhouette = beat.silhouette
	scene.breath = lerpf(beat.breath_from, beat.breath_to, progress)
	scene.veins = lerpf(beat.veins_from, beat.veins_to, progress)
	scene.drain = lerpf(beat.drain_from, beat.drain_to, progress)
	scene.light = lerpf(beat.light_from, beat.light_to, k)
	scene.wind = beat.wind
	scene.refresh()
	# The grandfather's portrait: where the beat puts it, looking at the duck.
	portrait.reduced = reduced
	portrait.position = Vector2(beat.portrait_at.x * 1280.0, beat.portrait_at.y * 720.0)
	portrait.scale = Vector2.ONE * beat.portrait_scale * GrandfatherPresentation.get_default().face_scale
	var wanted: float = beat.portrait_alpha if beat.expression != &"" else 0.0
	portrait.alpha = wanted if reduced else move_toward(portrait.alpha, wanted, get_process_delta_time() * 0.7)
	var duck_screen: Vector2 = Vector2(640.0, 360.0) + (scene.feet - scene.focus) * scene.zoom
	portrait.gaze = ((duck_screen - portrait.position) / 500.0).limit_length(1.0)
	portrait.talking = beat.is_line() and current_line_text().begins_with(GRANDFATHER_PREFIX) and not typed_done
	# The overlay: the beat's fade, plus the opening fade-in and (in reduced mode) the dip at each beat.
	var target: float = lerpf(_fade_start, beat.fade_to, raw)
	if elapsed < FADE_IN:
		target = maxf(target, 1.0 - elapsed / FADE_IN)
	if reduced:
		_dip = maxf(_dip - get_process_delta_time() / STILL_FADE, 0.0)
		target = maxf(target, _dip)
	_fade.color = Color(Color.WHITE if beat.fade_white else beats.fade_color, clampf(target, 0.0, 1.0))
	# The silhouette over the white: only while the screen is white (a beat that names one), in reduced mode as a still.
	white_silhouette.reduced = reduced
	white_silhouette.kind = beat.white_silhouette
	white_silhouette.alpha = lerpf(beat.white_silhouette_from, beat.white_silhouette_to, raw) if beat.white_silhouette != &"" else 0.0
	scene.items_left = beat.leave_items and style == "released"


func _update_sound(beat: EndingBeat, delta: float) -> void:
	var raw: float = clampf(beat_t / maxf(beat.seconds, 0.01), 0.0, 1.0)
	if beat.sfx != &"" and beat.sfx_at > 0.001 and raw >= beat.sfx_at and raw - delta / maxf(beat.seconds, 0.01) < beat.sfx_at:
		_play(beat.sfx, beat.sfx_pitch, beat.sfx_volume_db)
	if beat.loop_sfx == &"" or raw > beat.loop_until:
		return
	var rate: float = lerpf(beat.loop_hz_from, beat.loop_hz_to, raw)
	_loop_clock += delta * rate
	if _loop_clock >= 1.0:
		_loop_clock -= 1.0
		_play(beat.loop_sfx, lerpf(beat.loop_pitch_from, beat.loop_pitch_to, raw), beat.loop_volume_db)


func _update_hold(delta: float) -> void:
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
	_prompt.visible = false
	# Everything the ending plays stops now (the music fades to silence under the closing fade).
	AudioDirector.set_music_duck(self, -60.0)
	var seconds: float = skip_fade if skipped else 0.1
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, seconds)
	# A timer that ignores pause: the scene may be paused by us.
	get_tree().create_timer(seconds + 0.05, true).timeout.connect(_end)


func _end() -> void:
	if not is_instance_valid(self):
		return
	is_finished = true
	finished.emit(was_skipped)
	queue_free()


# ---------------------------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------------------------

func _build() -> void:
	_scene_layer = CanvasLayer.new()
	_scene_layer.layer = 70
	add_child(_scene_layer)
	scene = EndingScene.new()
	scene.style = style
	scene.reduced = reduced
	_scene_layer.add_child(scene)
	portrait = GrandfatherSky.new()
	portrait.reduced = reduced
	_scene_layer.add_child(portrait)
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
	_subtitle = _label(root, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.anchor_top = 1.0
	_subtitle.anchor_bottom = 1.0
	_subtitle.anchor_right = 1.0
	_subtitle.offset_left = 120.0
	_subtitle.offset_right = -120.0
	_subtitle.offset_top = -BAR_HEIGHT
	_subtitle.offset_bottom = 0.0
	_title = _label(root, 56, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = title_text
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.modulate.a = 0.0
	_title.visible = not title_text.is_empty()
	_hint = _label(root, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.text = skip_hint_text
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = -420.0
	_hint.offset_right = -30.0
	_hint.offset_top = 20.0
	_hint.offset_bottom = 56.0
	_hint.modulate.a = 0.45
	_prompt = _label(root, 22, HORIZONTAL_ALIGNMENT_RIGHT)
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.anchor_right = 1.0
	_prompt.offset_left = 120.0
	_prompt.offset_right = -120.0
	_prompt.offset_top = -BAR_HEIGHT - 34.0
	_prompt.offset_bottom = -BAR_HEIGHT
	_prompt.visible = false
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)
	white_silhouette = EndingSilhouette.new()
	white_silhouette.name = "WhiteSilhouette"
	white_silhouette.reduced = reduced
	root.add_child(white_silhouette)


func _label(parent: Control, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SceneLabel"
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

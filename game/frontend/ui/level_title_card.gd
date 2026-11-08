class_name LevelTitleCard
extends CanvasLayer
## The level's opening and closing, visual only. On load the screen starts black and opens in
## ~0.8 s while a big title appears in the middle ("NIVEL N" spaced out, the level name with an
## ink outline and a decorative line, and the intro line in italics). After ~2.2 s the title
## shrinks and rises slowly to the top center and stays there small (the boss bar is at the
## bottom, so they never overlap). The intro line is the text the level puts in IntroLayer/IntroLabel: that label
## keeps existing and the level keeps driving its visibility; it is only made see-through
## (self_modulate) and the line here fades out when the level hides it.
## At the end the screen darkens over ~0.8 s before the scene changes: it reads the public
## `DecisionFlow.decision_made` + `LevelBase.advance_delay` to start in time, and
## `LevelBase.level_completed` / `SceneManager.transition_started` as a fallback. Never pauses the
## game, never takes input, never changes any state.

const INK := Color(0.106, 0.098, 0.122)
const CREAM := Color(0.98, 0.93, 0.8)
const STAR := Color(1.0, 0.42, 0.16)
const OPEN_TIME: float = 0.8
const CLOSE_TIME: float = 0.8
const HOLD_TIME: float = 2.2
const SHRINK_TIME: float = 1.0
const SMALL_SCALE: float = 0.48
## Seconds a finished close may stay black waiting for the scene change before it reopens.
const CLOSE_GIVE_UP: float = 4.0

## The level's name shown under "NIVEL N" (set in each level scene).
@export var level_name: String = ""

var _level: Node = null
var _intro: Label = null
var _time: float = 0.0
var _phrase: String = ""
var _phrase_alpha: float = 0.0
## < 0 while not closing; else seconds since the close began.
var _closing: float = -1.0
## Countdown to start closing after the choice (< 0 when not scheduled).
var _close_in: float = -1.0
var _canvas: Control = null


func _ready() -> void:
	layer = 55
	_level = get_parent()
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_card)
	if _level == null:
		return
	_intro = _level.get_node_or_null(^"IntroLayer/IntroLabel") as Label
	var number: Variant = _level.get(&"level_number")
	if _intro != null and number != null and int(number) > 0:
		# Still there and still driven by the level (tests read it), just not drawn.
		_intro.self_modulate.a = 0.0
	if _level.has_signal(&"level_completed"):
		_level.connect(&"level_completed", _on_level_completed)
	var flow: Node = _level.get_node_or_null(^"DecisionFlow")
	if flow != null and flow.has_signal(&"decision_made"):
		flow.connect(&"decision_made", _on_decision_made)
	SceneManager.transition_started.connect(_on_transition_started)
	SceneManager.transition_finished.connect(_on_transition_finished)


func _exit_tree() -> void:
	if SceneManager.transition_started.is_connected(_on_transition_started):
		SceneManager.transition_started.disconnect(_on_transition_started)
	if SceneManager.transition_finished.is_connected(_on_transition_finished):
		SceneManager.transition_finished.disconnect(_on_transition_finished)


func _process(delta: float) -> void:
	_time += delta
	# The intro line: copied from the level's label while it shows, fades when the level hides it.
	if _intro != null and _intro.visible and not _intro.text.is_empty():
		_phrase = _intro.text
		_phrase_alpha = minf(_phrase_alpha + delta * 3.0, 1.0)
	else:
		_phrase_alpha = maxf(_phrase_alpha - delta * 2.0, 0.0)
	if _close_in >= 0.0:
		_close_in -= delta
		if _close_in < 0.0:
			_start_close()
	if _closing >= 0.0:
		_closing += delta
		if _closing > CLOSE_TIME + CLOSE_GIVE_UP and not SceneManager.is_transitioning():
			# The scene did not change after all: never leave the screen black.
			_closing = -1.0
			_time = OPEN_TIME * 0.5
	_canvas.queue_redraw()


func _on_decision_made(_fragment_id: String, _choice: String) -> void:
	var delay: Variant = _level.get(&"advance_delay")
	var wait: float = float(delay) if delay != null else 1.5
	_close_in = maxf(wait - CLOSE_TIME, 0.0)


func _on_level_completed(_level_number: int) -> void:
	_start_close()


func _on_transition_started(_scene_id: String) -> void:
	_start_close()


func _on_transition_finished(_scene_id: String) -> void:
	# Still here after a transition (a test's dry run or a failed change): open up again.
	if is_inside_tree() and _closing >= 0.0:
		_closing = -1.0
		_close_in = -1.0
		_time = maxf(_time, OPEN_TIME * 0.5)


func _start_close() -> void:
	_close_in = -1.0
	if _closing < 0.0:
		_closing = 0.0


func _black() -> float:
	var open: float = 1.0 - smoothstep(0.0, OPEN_TIME, _time)
	var close: float = smoothstep(0.0, CLOSE_TIME, _closing) if _closing >= 0.0 else 0.0
	return maxf(open, close)


func _draw_card() -> void:
	var s: Vector2 = _canvas.size
	var black: float = _black()
	# Title: pops in, holds in the middle, then shrinks and rises to the top center.
	var appear: float = smoothstep(0.15, 0.75, _time)
	var shrink: float = smoothstep(HOLD_TIME, HOLD_TIME + SHRINK_TIME, _time)
	shrink = shrink * shrink * (3.0 - 2.0 * shrink)
	var big_c := Vector2(s.x * 0.5, s.y * 0.42)
	var small_c := Vector2(s.x * 0.5, 46.0)
	var c: Vector2 = big_c.lerp(small_c, shrink)
	var sc: float = lerpf(1.0, SMALL_SCALE, shrink) * (0.9 + 0.1 * _ease_back(appear))
	var alpha: float = appear * lerpf(1.0, 0.85, shrink)
	if black > 0.001 and _closing < 0.0:
		# Opening: the black sits under the title.
		_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, black))
	if alpha > 0.01:
		_draw_title(c, sc, alpha)
	# The intro line under the title; it never shrinks into the corner.
	var number: Variant = _level.get(&"level_number") if _level != null else null
	if _phrase_alpha > 0.01 and not _phrase.is_empty() and number != null and int(number) > 0:
		var a: float = _phrase_alpha * appear
		var y: float = lerpf(big_c.y + 96.0, small_c.y + 44.0, shrink)
		# Italics: the default font has none, so the line is slanted by hand.
		_canvas.draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-0.2, 1.0), Vector2(0.2 * y, 0.0)))
		_text_centered(Vector2(s.x * 0.5, y), _phrase, 28, Color(CREAM, a), 6, Color(INK, 0.8 * a), GameFonts.BODY, s.x - 80.0)
		_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if black > 0.001 and _closing >= 0.0:
		# Closing: the black covers everything.
		_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, black))


func _draw_title(c: Vector2, sc: float, alpha: float) -> void:
	var font: Font = GameFonts.BODY
	var number: Variant = _level.get(&"level_number") if _level != null else null
	if number == null or int(number) <= 0:
		# The tutorial (level 0) only gets the fades.
		return
	_canvas.draw_set_transform(c, 0.0, Vector2(sc, sc))
	var header: String = "NIVEL %d" % int(number)
	_text_centered(Vector2(0, -56), _spaced(header), 26, Color(CREAM, 0.9 * alpha), 6, Color(INK, 0.85 * alpha), font)
	var title: String = level_name if not level_name.is_empty() else ""
	if not title.is_empty():
		# The level's name in the title face (Rubik Wet Paint).
		_text_centered(Vector2(0, 18), title, 70, Color(CREAM, alpha), 14, Color(INK, alpha), GameFonts.TITLE)
		var w: float = GameFonts.TITLE.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 70).x * 0.5 + 20.0
		# Decorative line: two ink-edged strokes and a small diamond star in the middle.
		for side in [-1.0, 1.0]:
			var a := Vector2(side * 22.0, 48.0)
			var b := Vector2(side * w, 48.0)
			_canvas.draw_line(a, b, Color(INK, alpha), 6.0, true)
			_canvas.draw_line(a, b, Color(CREAM, 0.9 * alpha), 2.5, true)
			_canvas.draw_circle(b, 4.0, Color(INK, alpha))
			_canvas.draw_circle(b, 2.2, Color(STAR, alpha))
		var d := PackedVector2Array([Vector2(0, 38), Vector2(10, 48), Vector2(0, 58), Vector2(-10, 48)])
		_canvas.draw_colored_polygon(d, Color(STAR, alpha))
		var ring := PackedVector2Array(d)
		ring.append(d[0])
		_canvas.draw_polyline(ring, Color(INK, alpha), 2.5, true)
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Draws `text` centred on `at` (baseline-ish), with an outline, optionally wrapped to `max_w`.
func _text_centered(at: Vector2, text: String, size: int, color: Color, outline: int, outline_color: Color, font: Font, max_w: float = -1.0) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if max_w > 0.0 and width > max_w:
		width = max_w
	var pos := Vector2(at.x - width * 0.5, at.y)
	if max_w > 0.0:
		_canvas.draw_multiline_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, outline, outline_color)
		_canvas.draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, color)
	else:
		_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
		_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _spaced(text: String) -> String:
	var out: String = ""
	for i in text.length():
		out += text[i]
		if i < text.length() - 1:
			out += " " if text[i] != " " else "  "
	return out


func _ease_back(t: float) -> float:
	var k: float = 1.70158
	var u: float = t - 1.0
	return 1.0 + (k + 1.0) * u * u * u + k * u * u

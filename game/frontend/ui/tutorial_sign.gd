class_name TutorialSign
extends Control
## How the tutorial's text looks, drawn over a Label that keeps receiving the text (the Label
## itself is made invisible; this node only reads it). SIGN: a broken cardboard sign hanging from
## two ropes that sways; when the text changes it drops in and bounces, the text types itself in
## (0.4 s at most) with every key drawn as a little cardboard key, and a cheer ("¡Bien!") gets an
## ink splash. BUBBLE: a small old-paper speech balloon with its tail pointing down at the speaker.
## Visual only. Hides itself whenever the Label is hidden (the prologue does that).

enum Mode { SIGN, BUBBLE }

const INK := Color(0.106, 0.098, 0.122)
const CARD := Color(0.74, 0.62, 0.43)
const PAPER := Color(0.92, 0.87, 0.74)

@export var mode: Mode = Mode.SIGN
@export var source: NodePath
@export var font_size: int = 26
## Text that earns an ink splash when it appears.
@export var cheer_text: String = "¡Bien!"

var _label: Label = null
var _text: String = ""
var _age: float = 99.0
var _time: float = 0.0
var _keys: Dictionary = {}
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = get_node_or_null(source) as Label
	_font = ThemeDB.fallback_font
	# Every key name bound in the input map, to draw them as keys inside the text.
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			var key := ev as InputEventKey
			if key != null:
				var code: Key = key.physical_keycode if key.keycode == KEY_NONE else key.keycode
				_keys[OS.get_keycode_string(code)] = true


func _process(delta: float) -> void:
	_time += delta
	_age += delta
	if _label == null:
		return
	visible = _label.is_visible_in_tree()
	if _label.text != _text:
		_text = _label.text
		_age = 0.0
	queue_redraw()


func _draw() -> void:
	if _text.strip_edges().is_empty():
		return
	var tokens: Array = _tokens(_text)
	var size_px: int = font_size if mode == Mode.SIGN else 17
	var lines: Array = _layout(tokens, size_px, 760.0 if mode == Mode.SIGN else 300.0)
	var line_h: float = float(size_px) * 1.5
	var width: float = 0.0
	for line in lines:
		width = maxf(width, float(line[1]))
	var pad := Vector2(34, 18) if mode == Mode.SIGN else Vector2(16, 10)
	var box := Vector2(width, line_h * float(lines.size())) + pad * 2.0
	var center: Vector2 = size * 0.5
	# Drop and bounce when the text changes; a slow sway the rest of the time.
	var drop: float = 0.0
	if mode == Mode.SIGN and _age < 0.5:
		var k: float = _age / 0.5
		drop = -48.0 * (1.0 - k) * absf(cos(k * PI * 2.2))
	var sway: float = sin(_time * 1.4) * 0.025 if mode == Mode.SIGN else 0.0
	var origin: Vector2 = center - box * 0.5 + Vector2(0, drop)
	draw_set_transform(center + Vector2(0, drop - box.y * 0.5), sway, Vector2.ONE)
	var local: Vector2 = origin - (center + Vector2(0, drop - box.y * 0.5))
	if mode == Mode.SIGN:
		_draw_sign(Rect2(local, box))
	else:
		_draw_bubble(Rect2(local, box))
	# Typewriter: 0.4 s at most for the whole line.
	var total: int = 0
	for tk in tokens:
		total += String(tk[0]).length()
	var shown: int = total if _age >= 0.4 else int(float(total) * _age / 0.4)
	var y: float = local.y + pad.y + float(size_px) * 1.05
	for line in lines:
		var x: float = local.x + (box.x - float(line[1])) * 0.5
		for tk in line[0]:
			var word: String = tk[0]
			if shown <= 0:
				break
			var part: String = word.substr(0, mini(shown, word.length()))
			shown -= word.length()
			var w: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			if bool(tk[1]):
				_draw_key(Vector2(x + 9.0, y), w, size_px)
				draw_string(_font, Vector2(x + 9.0, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.25, 0.14, 0.08))
				x += w + 18.0
			else:
				var color: Color = Color(0.99, 0.95, 0.84) if mode == Mode.SIGN else INK
				if mode == Mode.SIGN:
					draw_string_outline(_font, Vector2(x, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 8, INK)
				draw_string(_font, Vector2(x, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
				x += w
		y += line_h
	if mode == Mode.SIGN and _text.begins_with(cheer_text) and _age < 0.7:
		_splash(Vector2(local.x + box.x - 10.0, local.y + 6.0), _age / 0.7)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_sign(r: Rect2) -> void:
	for x in [r.position.x + 30.0, r.end.x - 30.0]:
		draw_line(Vector2(x, r.position.y - 70.0), Vector2(x, r.position.y + 6.0), INK, 4.0, true)
		draw_line(Vector2(x, r.position.y - 70.0), Vector2(x, r.position.y + 6.0), Color(0.66, 0.56, 0.38), 2.0, true)
	var pts := PackedVector2Array([r.position + Vector2(4, 6), Vector2(r.position.x + r.size.x * 0.3, r.position.y + 2),
			Vector2(r.position.x + r.size.x * 0.32, r.position.y + 9), Vector2(r.position.x + r.size.x * 0.36, r.position.y + 1),
			Vector2(r.end.x - 6, r.position.y + 3), Vector2(r.end.x, r.position.y + r.size.y * 0.5), Vector2(r.end.x - 4, r.end.y - 2),
			Vector2(r.position.x + r.size.x * 0.55, r.end.y + 2), Vector2(r.position.x + 2, r.end.y - 4)])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(4, 7))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	draw_colored_polygon(pts, CARD)
	for k in 3:
		var y: float = r.position.y + r.size.y * (0.25 + 0.25 * float(k))
		draw_line(Vector2(r.position.x + 10, y), Vector2(r.end.x - 12, y + 1), Color(CARD.darkened(0.18), 0.5), 1.4, true)
	draw_arc(r.end - Vector2(36, r.size.y * 0.55), 10.0, 0.3, 5.2, 12, Color(0.4, 0.28, 0.16, 0.3), 3.0, true)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, INK, 3.4, true)
	for x in [r.position.x + 30.0, r.end.x - 30.0]:
		var tape := PackedVector2Array([Vector2(x - 16, r.position.y - 2), Vector2(x + 16, r.position.y - 5), Vector2(x + 17, r.position.y + 12), Vector2(x - 15, r.position.y + 14)])
		draw_colored_polygon(tape, Color(0.88, 0.82, 0.62, 0.9))


func _draw_bubble(r: Rect2) -> void:
	var tail := PackedVector2Array([Vector2(r.position.x + r.size.x * 0.44, r.end.y - 2), Vector2(r.position.x + r.size.x * 0.5, r.end.y + 26),
			Vector2(r.position.x + r.size.x * 0.58, r.end.y - 2)])
	var body := PackedVector2Array()
	var c: Vector2 = r.get_center()
	for k in 32:
		var a: float = TAU * float(k) / 32.0
		var wob: float = 1.0 + 0.025 * sin(float(k) * 2.7)
		body.append(c + Vector2(cos(a) * r.size.x * 0.56, sin(a) * r.size.y * 0.62) * wob)
	draw_colored_polygon(body, Color(0, 0, 0, 0.0))
	draw_colored_polygon(tail, PAPER)
	draw_colored_polygon(body, PAPER)
	draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2]]), INK, 2.6, true)
	var closed := PackedVector2Array(body)
	closed.append(body[0])
	draw_polyline(closed, INK, 2.6, true)
	draw_circle(c + Vector2(r.size.x * 0.3, -r.size.y * 0.1), 5.0, Color(0.5, 0.36, 0.2, 0.2))


## A key drawn as a small cardboard keycap with a shadow.
func _draw_key(baseline: Vector2, w: float, size_px: int) -> void:
	var h: float = float(size_px) * 1.15
	var rect := Rect2(baseline + Vector2(-8, -float(size_px) * 0.95), Vector2(w + 16, h))
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.35))
	draw_rect(rect, Color(0.9, 0.82, 0.62))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 5), Vector2(rect.size.x, 5)), Color(0.7, 0.6, 0.42))
	draw_rect(rect, INK, false, 2.4)


func _splash(at: Vector2, k: float) -> void:
	var r: float = 10.0 + 28.0 * k
	var a: float = 1.0 - k
	for i in 8:
		var dir := Vector2.from_angle(TAU * float(i) / 8.0 + 0.3)
		draw_circle(at + dir * r, 4.0 * a + 1.0, Color(INK, a))
		draw_line(at + dir * r * 0.4, at + dir * r * 0.9, Color(1.0, 0.85, 0.35, a), 3.0, true)
	draw_circle(at, 7.0 * a + 2.0, Color(1.0, 0.85, 0.35, a))


## Words with their trailing space, each flagged when it is a key name.
func _tokens(text: String) -> Array:
	var out: Array = []
	for word in text.split(" ", false):
		var bare: String = word.strip_edges().trim_prefix("(").trim_suffix(")").trim_suffix(",").trim_suffix(".")
		if _keys.has(bare) and bare != word:
			# Punctuation around a key ("(Shift)"): split it so only the key gets the keycap.
			var head: String = word.substr(0, word.find(bare))
			var tail: String = word.substr(word.find(bare) + bare.length())
			if not head.is_empty():
				out.append([head, false])
			out.append([bare, true])
			out.append([tail + " ", false])
		else:
			out.append([word + " ", _keys.has(bare)])
	return out


## Breaks tokens into lines no wider than `max_w`: [[tokens], width].
func _layout(tokens: Array, size_px: int, max_w: float) -> Array:
	var lines: Array = []
	var current: Array = []
	var w: float = 0.0
	for tk in tokens:
		var tw: float = _font.get_string_size(String(tk[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x + (18.0 if bool(tk[1]) else 0.0)
		if w + tw > max_w and not current.is_empty():
			lines.append([current, w])
			current = []
			w = 0.0
		current.append(tk)
		w += tw
	if not current.is_empty():
		lines.append([current, w])
	return lines

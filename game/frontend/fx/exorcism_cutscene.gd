class_name ExorcismCutscene
extends CanvasLayer
## What keeping a soul fragment looks like: a full-screen exorcism (~6 s) and then the card of the
## power it gave. The hero (DuckRig) stands in the dark before the blue gem; it cracks and turns
## red, a red exorcism circle lights under him, he levitates and shakes while red soul threads
## spiral into his chest, the gem bursts inside him in a red-white flash, and he lands with a
## smoking red aura and a red eye. Then the card: the boss whose soul was devoured, the power,
## what it changes, a line of dread and the corruption meter.
## Holds the PauseLock while open (the game and the level's advance wait), consumes Esc so the pause
## menu never opens: Esc skips to the card; Enter, Space, click or Esc on the card fade back to the
## game. Visual only: reads GameState.souls_kept and the player's wave tier, writes nothing.

const RED := Color("c2331f")
const RING := Color("ff3a24")
const CARD_BG := Color("0d0607")
const CUT_LENGTH: float = 6.0

## fragment_id -> {"boss", "power", "quote"}.
@export var powers: Dictionary = {
	"fragment_level_1": {"boss": "EL LEÑADOR", "power": "FILO DEL LEÑADOR", "quote": "«Corta más lejos. Corta más hondo. Y algo dentro de ti sonríe.»"},
	"fragment_level_2": {"boss": "LA COSA DEL PANTANO", "power": "MAREA PODRIDA", "quote": "«El pantano no perdona. Ahora tampoco tú.»"},
	"fragment_level_3": {"boss": "EL OJO DE LA TORMENTA", "power": "CORAZÓN DE TORMENTA", "quote": "«Ya no oyes la lluvia. Oyes voces.»"},
}
## What the power does, by sword-wave tier (and for the last fragment, which leaves the wave alone).
@export var effects: Dictionary = {
	"tier_1": {"line": "Tu onda de espada se vuelve una cuchilla", "chips": ["ONDA +35%", "ATRAVIESA 1", "RECARGA RÁPIDA"]},
	"tier_2": {"line": "Tu onda pega el doble y no se detiene", "chips": ["DAÑO x2", "ONDA +70%", "ATRAVIESA 2"]},
	"fragment_level_3": {"line": "Algo te acompaña ahora. Para siempre.", "chips": ["EL FINAL CAMBIARÁ", "LA SOMBRA CRECE"]},
}
@export var header_text: String = "PODER ABSORBIDO"
@export var devoured_text: String = "Devoraste el alma de %s"
@export var corruption_text: String = "CORRUPCIÓN"
@export var continue_text: String = "[Intro] CONTINUAR"

var fragment_id: String = ""
var player: Node = null

var _t: float = 0.0
var _card_t: float = -1.0
var _leaving: float = -1.0
var _holds_lock: bool = false
var _hero: DuckRig
var _stage: Control
var _overlay: Control
var _card: Control
var _font: Font
var _italic: FontVariation
var _spaced: FontVariation
var _tier: int = 1


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_italic = FontVariation.new()
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_spaced = FontVariation.new()
	_spaced.spacing_glyph = 8
	var caster: Variant = player.get(&"wave_caster") if player != null and is_instance_valid(player) else null
	if caster is Object and (caster as Object).has_method(&"get_effective_tier"):
		_tier = int((caster as Object).call(&"get_effective_tier"))
	_stage = _full_control(_draw_stage)
	_hero = DuckRig.new()
	_hero.look = DuckRig.Look.HERO
	_hero.scale = Vector2.ONE * 3.0
	_hero.position = _hero_home()
	add_child(_hero)
	_overlay = _full_control(_draw_overlay)
	_card = _full_control(_draw_card)
	_holds_lock = true
	PauseLock.request(self, get_tree())


func _exit_tree() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func _process(delta: float) -> void:
	_t += delta
	if _card_t < 0.0 and _t >= CUT_LENGTH:
		_card_t = 0.0
	if _card_t >= 0.0:
		_card_t += delta
	if _leaving >= 0.0:
		_leaving += delta
		var a: float = 1.0 - clampf(_leaving / 0.5, 0.0, 1.0)
		for item in [_stage, _hero, _overlay, _card]:
			(item as CanvasItem).modulate.a = a
		if _leaving >= 0.5:
			_finish()
			return
	_animate_hero()
	_stage.queue_redraw()
	_overlay.queue_redraw()
	_card.queue_redraw()


func _input(event: InputEvent) -> void:
	var esc: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")
	var accept: bool = event.is_action_pressed("ui_accept")
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept = true
	if not (esc or accept):
		return
	get_viewport().set_input_as_handled()
	if _card_t < 0.0:
		if esc:
			# Skip straight to the card.
			_t = CUT_LENGTH
		return
	if _card_t > 0.3 and _leaving < 0.0:
		_leaving = 0.0


func _finish() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())
	queue_free()


# =====================================================================================
# The hero
# =====================================================================================

func _hero_home() -> Vector2:
	return Vector2(560, 470)


func _animate_hero() -> void:
	var t: float = _t
	var lift: float = smoothstep(2.2, 2.6, t) * (1.0 - smoothstep(4.5, 5.0, t))
	var shake: Vector2 = Vector2(sin(t * 80.0), cos(t * 67.0)) * 4.0 * smoothstep(2.4, 2.7, t) * (1.0 - smoothstep(3.9, 4.1, t))
	var red: float = smoothstep(2.2, 3.0, t) * (1.0 - 0.7 * smoothstep(4.5, 5.5, t))
	var pos: Vector2 = _hero_home() + Vector2(0, -36.0 * lift) + shake + _screen_shake()
	var s: float = 3.0
	if _card_t >= 0.0:
		# Steps aside, smaller, keeping his aura, to make room for the card.
		var k: float = smoothstep(0.0, 0.6, _card_t)
		pos = pos.lerp(Vector2(200, 560), k)
		s = lerpf(3.0, 2.0, k)
	_hero.position = pos
	_hero.scale = Vector2.ONE * s
	_hero.rotation = -0.18 * lift
	_hero.modulate = Color.WHITE.lerp(Color(0.6, 0.18, 0.16), red)


## Screen position of the hero's eye and of his chest.
func _eye() -> Vector2:
	return _hero.position + Vector2(11.5, -14.0).rotated(_hero.rotation) * _hero.scale.y


func _chest() -> Vector2:
	return _hero.position + Vector2(2, -2).rotated(_hero.rotation) * _hero.scale.y


func _screen_shake() -> Vector2:
	var k: float = smoothstep(4.0, 4.05, _t) * (1.0 - smoothstep(4.05, 4.5, _t))
	return Vector2(sin(_t * 95.0), cos(_t * 83.0)) * 9.0 * k


# =====================================================================================
# Stage (behind the hero): darkness, the circle, the gem, the soul threads
# =====================================================================================

func _draw_stage() -> void:
	var c: Control = _stage
	var t: float = _t
	var fade_in: float = clampf(t / 0.6, 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.03, 0.02, 0.025, fade_in))
	var tint: float = smoothstep(2.2, 3.2, t) * (1.0 - 0.6 * smoothstep(4.5, 5.5, t))
	if tint > 0.0:
		for k in 5:
			c.draw_circle(_hero_home(), 520.0 - float(k) * 90.0, Color(0.25, 0.02, 0.02, 0.06 * tint))
	if _card_t >= 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.0, 0.0, 0.0, 0.35 * smoothstep(0.0, 0.5, _card_t)))
		return
	# Exorcism circle under the hero.
	var circle: float = smoothstep(1.1, 1.8, t) * (1.0 - 0.5 * smoothstep(4.6, 5.6, t))
	if circle > 0.0:
		_draw_circle_of(c, _hero_home() + Vector2(0, 80), circle)
	# The gem: blue, then cracking red, then drained into him.
	var gem_pos := Vector2(820, 330) + Vector2(sin(t * 1.4) * 4.0, cos(t * 1.1) * 6.0)
	var red: float = smoothstep(1.2, 2.0, t)
	var crack: float = smoothstep(1.0, 1.6, t)
	var tremble: Vector2 = Vector2(sin(t * 60.0), cos(t * 55.0)) * 3.0 * smoothstep(1.0, 1.3, t)
	var size: float = 44.0 * (1.0 - 0.75 * smoothstep(2.4, 4.0, t))
	if t < 4.05:
		var travel: float = smoothstep(3.7, 4.05, t)
		GemDrawer.draw(c, gem_pos.lerp(_chest(), travel) + tremble, size, t, Color(0.6, 0.9, 1.0), red, crack)
	# Soul threads and sparks spiralling from the gem into his chest.
	var threads: float = smoothstep(2.2, 2.6, t) * (1.0 - smoothstep(3.9, 4.1, t))
	if threads > 0.0:
		for k in 4:
			var pts := PackedVector2Array()
			for i in 20:
				var u: float = float(i) / 19.0
				var p: Vector2 = gem_pos.lerp(_chest(), u)
				var wave: float = sin(u * PI) * (60.0 + float(k) * 20.0) * sin(t * 3.0 + float(k) * 1.6)
				pts.append(p + Vector2(0, -1).rotated(float(k) * 0.4) * wave)
			c.draw_polyline(pts, Color(RING, 0.25 * threads), 6.0, true)
			c.draw_polyline(pts, Color(1.0, 0.55, 0.4, 0.85 * threads), 2.0, true)
		for k in 14:
			var u: float = fposmod(t * 0.9 + float(k) / 14.0, 1.0)
			var p: Vector2 = gem_pos.lerp(_chest(), u)
			var spiral: Vector2 = Vector2.from_angle(u * TAU * 2.0 + float(k)) * 40.0 * (1.0 - u)
			c.draw_circle(p + spiral, 2.6, Color(1.0, 0.7, 0.55, threads * (1.0 - u * 0.5)))


func _draw_circle_of(c: Control, center: Vector2, k: float) -> void:
	var rx: float = 240.0
	var ry: float = 56.0
	var glow := Color(RING, 0.18 * k)
	var line := Color(RING, 0.95 * k)
	for ring in [[1.0, false], [0.82, true], [0.64, false]]:
		var s: float = ring[0]
		var pts := PackedVector2Array()
		for i in 73:
			var a: float = TAU * float(i) / 72.0
			pts.append(center + Vector2(cos(a) * rx * s, sin(a) * ry * s))
		c.draw_polyline(pts, glow, 9.0, true)
		if bool(ring[1]):
			for i in range(0, 72, 3):
				c.draw_line(pts[i], pts[i + 1], line, 2.4, true)
		else:
			c.draw_polyline(pts, line, 2.4, true)
	# Inverted five-pointed star.
	var star := PackedVector2Array()
	for i in 5:
		var a: float = PI * 0.5 + TAU * float(i * 2 % 5) / 5.0
		star.append(center + Vector2(cos(a) * rx * 0.62, sin(a) * ry * 0.62))
	star.append(star[0])
	c.draw_polyline(star, glow, 8.0, true)
	c.draw_polyline(star, line, 2.2, true)
	# Small runes turning between the rings.
	for i in 14:
		var a: float = _t * 0.5 + TAU * float(i) / 14.0
		var p: Vector2 = center + Vector2(cos(a) * rx * 0.91, sin(a) * ry * 0.91)
		match i % 3:
			0:
				c.draw_line(p + Vector2(0, -6), p + Vector2(0, 4), line, 1.6, true)
				c.draw_line(p + Vector2(0, -6), p + Vector2(4, -2), line, 1.6, true)
			1:
				c.draw_line(p + Vector2(-3, 4), p + Vector2(0, -5), line, 1.6, true)
				c.draw_line(p + Vector2(0, -5), p + Vector2(3, 4), line, 1.6, true)
			_:
				c.draw_arc(p, 3.0, 0.0, PI * 1.5, 8, line, 1.6, true)


# =====================================================================================
# Overlay (over the hero): the red eye, the burst, the aura, cinema bars, grain, vignette
# =====================================================================================

func _draw_overlay() -> void:
	var c: Control = _overlay
	var t: float = _t
	var eye: float = smoothstep(2.4, 2.8, t)
	if eye > 0.0:
		var e: Vector2 = _eye()
		var pulse: float = 0.8 + 0.2 * sin(t * 6.0)
		c.draw_circle(e, 18.0 * pulse * _hero.scale.y / 3.0, Color(RING, 0.25 * eye))
		c.draw_circle(e, 7.0 * _hero.scale.y / 3.0, Color(1.0, 0.25, 0.15, eye))
		c.draw_circle(e, 2.5 * _hero.scale.y / 3.0, Color(1.0, 0.9, 0.8, eye))
	# Smoking red aura once it is over.
	var aura: float = smoothstep(4.4, 5.0, t)
	if aura > 0.0:
		var base: Vector2 = _hero.position
		var s: float = _hero.scale.y / 3.0
		c.draw_colored_polygon(_ellipse(base + Vector2(0, 78) * s, 130.0 * s, 24.0 * s), Color(RED, 0.25 * aura))
		for k in 10:
			var u: float = fposmod(t * 0.5 + float(k) / 10.0, 1.0)
			var x: float = (float(k) - 4.5) * 22.0 * s
			var p: Vector2 = base + Vector2(x + sin(u * 6.0 + float(k)) * 8.0, (70.0 - u * 170.0) * s)
			c.draw_arc(p, 6.0 * s, PI * 0.2, PI * 1.2, 6, Color(1.0, 0.35, 0.25, aura * (1.0 - u) * 0.8), 2.0, true)
	# The burst: red-white flash, radial rays.
	var burst: float = smoothstep(3.95, 4.05, t) * (1.0 - smoothstep(4.1, 4.6, t))
	if burst > 0.0:
		var o: Vector2 = _chest()
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.85, 0.2, 0.12, 0.55 * burst))
		for k in 6:
			c.draw_circle(o, 60.0 + float(k) * 70.0, Color(1.0, 0.85, 0.8, 0.12 * burst))
		for k in 12:
			var dir := Vector2.from_angle(TAU * float(k) / 12.0 + 0.2)
			c.draw_line(o + dir * 60.0, o + dir * 900.0, Color(1.0, 0.9, 0.85, 0.5 * burst), 3.0, true)
	# Grain, vignette and cinema bars.
	var seed_step: int = int(t * 24.0)
	for i in 120:
		var p := Vector2(_h(i * 3 + seed_step) * 1280.0, _h(i * 3 + seed_step + 1) * 720.0)
		c.draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.03))
	var edge := Color(0, 0, 0, 0.7)
	var clear := Color(0, 0, 0, 0)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, 720), Vector2(0, 720)]), PackedColorArray([edge, clear, clear, edge]))
	c.draw_polygon(PackedVector2Array([Vector2(980, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(980, 720)]), PackedColorArray([clear, edge, edge, clear]))
	var bar: float = 70.0 * clampf(t / 0.5, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, 1280, bar), Color.BLACK)
	c.draw_rect(Rect2(0, 720.0 - bar, 1280, bar), Color.BLACK)


# =====================================================================================
# The power card
# =====================================================================================

func _draw_card() -> void:
	if _card_t < 0.0:
		return
	var c: Control = _card
	var appear: float = smoothstep(0.0, 0.35, _card_t)
	var k: float = clampf(_card_t / 0.5, 0.0, 1.0)
	var drop: float = -50.0 * (1.0 - k) * absf(cos(k * PI * 2.0))
	var r := Rect2(Vector2(470, 120 + drop), Vector2(720, 480))
	var data: Dictionary = powers.get(fragment_id, {"boss": "?", "power": "?", "quote": ""})
	var effect: Dictionary = _effect()
	# Dark card with ragged edges and glowing red cracks.
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2(lerpf(r.position.x, r.end.x, float(i) / 24.0), r.position.y + _h(i) * 8.0))
	for i in 16:
		pts.append(Vector2(r.end.x - _h(i + 30) * 8.0, lerpf(r.position.y, r.end.y, float(i) / 16.0)))
	for i in 24:
		pts.append(Vector2(lerpf(r.end.x, r.position.x, float(i) / 24.0), r.end.y - _h(i + 60) * 8.0))
	for i in 16:
		pts.append(Vector2(r.position.x + _h(i + 90) * 8.0, lerpf(r.end.y, r.position.y, float(i) / 16.0)))
	c.draw_colored_polygon(pts, Color(CARD_BG, 0.96 * appear))
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	c.draw_polyline(closed, Color(RED, 0.9 * appear), 2.4, true)
	var pulse: float = 0.6 + 0.4 * sin(_card_t * 3.0)
	for crack in [[Vector2(10, 10), Vector2(60, 40), Vector2(50, 70), Vector2(95, 95)], [Vector2(710, 30), Vector2(660, 55), Vector2(670, 90)], [Vector2(560, 470), Vector2(590, 420), Vector2(575, 395)]]:
		var line := PackedVector2Array()
		for p in crack:
			line.append(r.position + (p as Vector2))
		c.draw_polyline(line, Color(RING, 0.25 * pulse * appear), 6.0, true)
		c.draw_polyline(line, Color(RING, 0.9 * pulse * appear), 1.8, true)
	var cx: float = r.get_center().x
	_text(c, header_text, Vector2(cx, r.position.y + 60), 18, Color(0.75, 0.32, 0.28, appear), _spaced)
	_text(c, devoured_text % String(data["boss"]), Vector2(cx, r.position.y + 96), 18, Color(0.75, 0.73, 0.72, appear), _italic)
	_text(c, String(data["power"]), Vector2(cx, r.position.y + 160), 46, Color(1.0, 0.92, 0.9, appear), _font, Color(0.35, 0.03, 0.03, appear), 10)
	# The sword wave as a red crescent.
	var arc_c := Vector2(cx, r.position.y + 222)
	c.draw_arc(arc_c + Vector2(0, 30), 60.0, PI * 1.2, PI * 1.8, 16, Color(RING, 0.35 * appear), 12.0, true)
	c.draw_arc(arc_c + Vector2(0, 30), 60.0, PI * 1.2, PI * 1.8, 16, Color(1.0, 0.45, 0.32, appear), 5.0, true)
	_text(c, String(effect["line"]), Vector2(cx, r.position.y + 262), 20, Color(0.9, 0.88, 0.86, appear), _font)
	var chips: Array = effect["chips"]
	var widths: Array = []
	var total: float = 0.0
	for chip in chips:
		var w: float = _font.get_string_size(String(chip), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 30.0
		widths.append(w)
		total += w + 18.0
	var x: float = cx - (total - 18.0) * 0.5
	for i in chips.size():
		var w: float = widths[i]
		var chip_r := Rect2(Vector2(x, r.position.y + 290), Vector2(w, 36))
		c.draw_rect(chip_r, Color(0.3, 0.05, 0.05, appear))
		c.draw_rect(chip_r, Color(RING, appear), false, 2.0)
		_text(c, String(chips[i]), chip_r.get_center() + Vector2(0, 6), 17, Color(1.0, 0.88, 0.85, appear), _font)
		x += w + 18.0
	var quote: String = String(data["quote"])
	var lines: PackedStringArray = _split_quote(quote)
	for i in lines.size():
		_text(c, lines[i], Vector2(cx, r.position.y + 370 + float(i) * 28.0), 20, Color(0.82, 0.78, 0.78, appear), _italic)
	# Corruption meter.
	var kept: int = clampi(int(GameState.souls_kept), 0, 3)
	var mx: float = r.position.x + 120.0
	var my: float = r.end.y - 40.0
	c.draw_string(_font, Vector2(mx, my + 6), corruption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.6, 0.58, appear))
	for i in 3:
		var box := Rect2(Vector2(mx + 110.0 + float(i) * 30.0, my - 10), Vector2(24, 20))
		if i < kept:
			c.draw_rect(box, Color(RED, appear))
		c.draw_rect(box, Color(0.5, 0.12, 0.1, appear), false, 1.6)
	var btn := Rect2(Vector2(r.end.x - 230, my - 22), Vector2(200, 40))
	c.draw_rect(btn, Color(0.25, 0.04, 0.04, appear))
	c.draw_rect(btn, Color(RING, appear * (0.7 + 0.3 * pulse)), false, 2.0)
	_text(c, continue_text, btn.get_center() + Vector2(0, 6), 17, Color(1.0, 0.9, 0.88, appear), _font)


func _effect() -> Dictionary:
	if effects.has(fragment_id):
		return effects[fragment_id]
	return effects["tier_2"] if _tier >= 2 else effects["tier_1"]


func _split_quote(quote: String) -> PackedStringArray:
	if quote.length() <= 46:
		return PackedStringArray([quote])
	# Break at the sentence end closest to the middle.
	var best: int = -1
	var at: int = quote.find(". ")
	while at != -1:
		if best == -1 or absi(at - quote.length() / 2) < absi(best - quote.length() / 2):
			best = at
		at = quote.find(". ", at + 1)
	if best == -1:
		return PackedStringArray([quote])
	return PackedStringArray([quote.substr(0, best + 1), quote.substr(best + 2)])


func _text(c: Control, text: String, center: Vector2, size_px: int, color: Color, font: Font, outline: Color = Color(0, 0, 0, 0), outline_px: int = 0) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var p := Vector2(center.x - w * 0.5, center.y)
	if outline_px > 0:
		c.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, outline_px, outline)
	c.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


# =====================================================================================
# Helpers
# =====================================================================================

func _full_control(painter: Callable) -> Control:
	var ctl := Control.new()
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.position = Vector2.ZERO
	ctl.size = Vector2(1280, 720)
	ctl.draw.connect(painter)
	add_child(ctl)
	return ctl


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)

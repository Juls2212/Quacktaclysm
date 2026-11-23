class_name ExorcismCutscene
extends CanvasLayer
## What keeping a soul fragment looks like (Phase 15o: the dark background with RED touches and the emblem at the bottom are back, with much more
## animation; Phase 15l's purple vignette is gone). 3 to 4 s (AbsorptionConfig): near-black background, red embers rising from the edges, the
## emblem of the guardian at the bottom igniting and pulsing, the fragment darkening and trembling, and thin jagged RED lightning bolts (redrawn a
## few times a second, branching) that arc from the emblem, from the fragment and from the edges of the screen and ALL converge into the duck,
## together with dark-red particles and tendrils streaming into his chest. The duck is the rig itself: it convulses, its eyes flare red (the rig's
## own possession look) and its corruption stage visibly grows (veins clipped to its parts, a clouded iris, darker feathers: no overlays). A heavy
## heartbeat plays (an existing sound, lower pitch) and the music ducks. Photosensitivity: bolts are thin lines; the only full-screen tint is the
## heartbeat pulse (never above the config's cap, at most three a second). In reduced mode ("Efectos de corrupcion" off) it is a static red-tinted
## fade with the emblem and a few static bolts: no flicker, no particles, no convulsion.
## Then the card (levels 1 and 2 only): the boss whose soul was devoured, the power, what it changes, a line of dread and the corruption meter.
## Holds the PauseLock while open (the game and the level's advance wait), consumes Esc so the pause menu never opens: Esc skips to the card (or
## to the end for the last boss); Enter, Space, click or Esc on the card fade back to the game. Visual only: reads GameState.souls_kept and the
## player's wave tier, writes nothing.

const RED := Color("c2331f")
const RING := Color("ff3a24")
const CARD_BG := Color("0d0607")
const SCREEN := Vector2(1280.0, 720.0)

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
var config: AbsorptionConfig = null
var reduced: bool = false
## 0..1, how strong the last heartbeat still glows (it decays).
var pulse: float = 0.0
## How many heartbeat thumps played and the biggest full-screen tint drawn (the tests read them).
var thumps: int = 0
var peak_overlay_alpha: float = 0.0
## The corruption stage the duck ends the sequence at (the fragments kept, including this one).
var target_stage: int = 1
## The lightning bolts of this frame: {pts: PackedVector2Array, width: float, source: StringName, branch: bool}. The tests read them.
var bolts: Array[Dictionary] = []
var bolt_redraws: int = 0
var peak_bolts: int = 0
var sources_seen: Dictionary = {}
var particles: Array[Dictionary] = []
var embers: Array[Dictionary] = []
var _beat_clock: float = 99.0
var _second_thump_left: float = -1.0
var _bolt_clock: float = 99.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config == null:
		config = AbsorptionConfig.get_default()
	reduced = not GameSettings.is_corruption_effects_enabled()
	_rng.seed = 4242
	_font = ThemeDB.fallback_font
	_italic = FontVariation.new()
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_spaced = FontVariation.new()
	_spaced.spacing_glyph = 8
	var caster: Variant = player.get(&"wave_caster") if player != null and is_instance_valid(player) else null
	if caster is Object and (caster as Object).has_method(&"get_effective_tier"):
		_tier = int((caster as Object).call(&"get_effective_tier"))
	target_stage = clampi(int(GameState.souls_kept), 1, 3)
	_stage = _full_control(_draw_stage)
	_hero = DuckRig.new()
	_hero.look = DuckRig.Look.HERO
	_hero.scale = Vector2.ONE * 3.0
	_hero.position = _hero_home()
	# The corruption lives inside the rig: the previous stages are whole, the new one grows during the sequence.
	_hero.corruption_stage = target_stage
	_hero.corruption_growth = 0.0
	_hero.corruption_reduced = reduced
	add_child(_hero)
	AudioDirector.set_music_duck(self, config.music_duck_db)
	for i in config.edge_ember_count:
		embers.append({"p": Vector2(_rng.randf() * SCREEN.x, SCREEN.y + _rng.randf() * 80.0), "v": 30.0 + _rng.randf() * 70.0, "r": 1.2 + _rng.randf() * 2.2, "k": _rng.randf()})
	_overlay = _full_control(_draw_overlay)
	_card = _full_control(_draw_card)
	_holds_lock = true
	PauseLock.request(self, get_tree())
	if reduced:
		_build_bolts(true)


func _exit_tree() -> void:
	AudioDirector.release_music_duck(self)
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())
	_emit_finished()


func _process(delta: float) -> void:
	_t += delta
	if _card_t < 0.0:
		_heartbeat(delta)
		_update_bolts(delta)
		_update_particles(delta)
	if _card_t < 0.0 and _t >= config.length:
		if config.no_card_fragments.has(fragment_id):
			# The last boss: no card and no new power, the sequence goes straight on to the ending.
			_finish()
			return
		_card_t = 0.0
		bolts.clear()
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
	# The main bolts always end exactly in the chest, however much the duck shakes between two redraws of the bolts.
	var chest_now: Vector2 = _chest()
	for bolt in bolts:
		if not bool(bolt["branch"]):
			var pts: PackedVector2Array = bolt["pts"]
			pts[pts.size() - 1] = chest_now
			bolt["pts"] = pts
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
			# Skip straight to the card (or to the end when there is none).
			_t = config.length
		return
	if _card_t > 0.3 and _leaving < 0.0:
		_leaving = 0.0


## Emitted once when the cutscene is over (also if it is removed some other way): the presentation queue waits for it.
signal finished

var _finished_emitted: bool = false


func _emit_finished() -> void:
	if not _finished_emitted:
		_finished_emitted = true
		finished.emit()


func _finish() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())
	_emit_finished()
	queue_free()


# =====================================================================================
# The hero
# =====================================================================================

func _hero_home() -> Vector2:
	return Vector2(440, 450)


## The sequence's progress, 0..1.
func _u() -> float:
	return clampf(_t / config.length, 0.0, 1.0)


## A heavy double thump (lub-dub), an existing sound at a low pitch; the screen tint follows it. Silent after the sequence.
func _heartbeat(delta: float) -> void:
	pulse = maxf(pulse - delta * 3.0, 0.0)
	_beat_clock += delta
	if _beat_clock >= 1.0 / config.heartbeat_hz:
		_beat_clock = 0.0
		_thump()
		_second_thump_left = config.second_thump_delay
	elif _second_thump_left >= 0.0:
		_second_thump_left -= delta
		if _second_thump_left < 0.0:
			_thump()


func _thump() -> void:
	thumps += 1
	pulse = 1.0
	AudioDirector.play_event(config.heartbeat_event, null, config.heartbeat_db, config.heartbeat_pitch)


func _animate_hero() -> void:
	var u: float = _u()
	var convulse: float = 0.0 if reduced else smoothstep(0.25, 0.4, u) * (1.0 - smoothstep(0.85, 0.97, u))
	var shake: Vector2 = Vector2(sin(_t * 71.0), cos(_t * 59.0)) * config.convulsion_px * convulse
	var tint: float = smoothstep(0.1, 0.8, u) if not reduced else clampf(_t / config.reduced_fade, 0.0, 1.0)
	var pos: Vector2 = _hero_home() + shake
	var s: float = 3.0
	if _card_t >= 0.0:
		# Steps aside, smaller, keeping his tint, to make room for the card.
		var k: float = smoothstep(0.0, 0.6, _card_t)
		pos = pos.lerp(Vector2(200, 560), k)
		s = lerpf(3.0, 2.0, k)
	_hero.position = pos
	_hero.scale = Vector2.ONE * s
	_hero.rotation = sin(_t * 23.0) * config.convulsion_tilt * convulse
	_hero.modulate = Color.WHITE.lerp(config.hero_tint, tint)
	# The corruption stage advances inside the rig; its eyes flare red with the heartbeat (the rig's own possession look).
	_hero.corruption_growth = smoothstep(0.2, 0.85, u) if not reduced else (1.0 if u > 0.3 else 0.0)
	_hero.possession = 0.0 if reduced else smoothstep(0.35, 0.7, u) * (0.55 + 0.45 * pulse) * (1.0 - smoothstep(0.92, 1.0, u))
	_hero.possession_color = config.bolt_color
	_hero.possession_hz = config.heartbeat_hz


## Screen position of the hero's chest (where everything converges).
func _chest() -> Vector2:
	return _hero.position + Vector2(2, -18).rotated(_hero.rotation) * _hero.scale.y


func _emblem_center() -> Vector2:
	return Vector2(SCREEN.x * 0.5, SCREEN.y - config.emblem_lift)


func _fragment_pos() -> Vector2:
	var wobble: Vector2 = Vector2.ZERO if reduced else Vector2(sin(_t * 1.4) * 4.0, cos(_t * 1.1) * 6.0)
	var u: float = _u()
	var tremble: Vector2 = Vector2.ZERO if reduced else Vector2(sin(_t * 61.0), cos(_t * 53.0)) * 3.0 * smoothstep(0.1, 0.3, u)
	var travel: float = smoothstep(0.75, 1.0, u)
	return (Vector2(820, 330) + wobble).lerp(_chest(), travel) + tremble


# =====================================================================================
# Lightning and particles
# =====================================================================================

## Rebuilds the bolts a few times a second (never every frame: a bolt that jitters at 60 Hz would strobe).
func _update_bolts(delta: float) -> void:
	if reduced:
		return
	_bolt_clock += delta
	if _bolt_clock < 1.0 / config.bolt_refresh_hz:
		return
	_bolt_clock = 0.0
	_build_bolts(false)


func _build_bolts(static_ones: bool) -> void:
	bolts.clear()
	var u: float = _u()
	var rise: float = smoothstep(0.08, 0.35, u) if not static_ones else 1.0
	var fade: float = 1.0 - smoothstep(0.93, 1.0, u)
	var strength: float = rise * fade
	if strength <= 0.01:
		return
	var chest: Vector2 = _chest()
	var count_emblem: int = config.static_bolts if static_ones else int(round(float(config.bolts_from_emblem) * strength))
	var count_fragment: int = 0 if static_ones else int(round(float(config.bolts_from_fragment) * strength))
	var count_edges: int = 0 if static_ones else int(round(float(config.bolts_from_edges) * strength))
	for i in count_emblem:
		var from: Vector2 = _emblem_center() + Vector2(_rng.randf_range(-70.0, 70.0), -20.0)
		_add_bolt(from, chest, &"emblem", static_ones)
	for i in count_fragment:
		_add_bolt(_fragment_pos(), chest, &"fragment", false)
	for i in count_edges:
		var side: int = _rng.randi() % 3
		var from_edge: Vector2 = Vector2(0.0 if side == 0 else SCREEN.x, _rng.randf_range(70.0, 520.0)) if side < 2 else Vector2(_rng.randf_range(80.0, SCREEN.x - 80.0), 70.0)
		_add_bolt(from_edge, chest, &"edge", false)
	peak_bolts = maxi(peak_bolts, bolts.size())
	bolt_redraws += 1


func _add_bolt(from: Vector2, to: Vector2, source: StringName, static_bolt: bool) -> void:
	sources_seen[source] = int(sources_seen.get(source, 0)) + 1
	var pts: PackedVector2Array = _jagged(from, to, config.bolt_jaggedness)
	bolts.append({"pts": pts, "width": config.bolt_width, "source": source, "branch": false})
	if static_bolt:
		return
	# A short side branch from a random point of the bolt (it never reaches the duck on its own: the main bolt does).
	if pts.size() > 4 and _rng.randf() < config.bolt_branch_chance:
		var at: int = 1 + _rng.randi() % (pts.size() - 3)
		var dir: Vector2 = (to - from).normalized().rotated(_rng.randf_range(-0.9, 0.9))
		bolts.append({"pts": _jagged(pts[at], pts[at] + dir * _rng.randf_range(40.0, 110.0), config.bolt_jaggedness), "width": config.bolt_width * 0.55, "source": source, "branch": true})


## A jagged line from `a` to `b` (midpoint displacement, the last point is exactly `b`).
func _jagged(a: Vector2, b: Vector2, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var spread: float = a.distance_to(b) * jag
	for _round in 4:
		var next := PackedVector2Array([pts[0]])
		for i in pts.size() - 1:
			var mid: Vector2 = pts[i].lerp(pts[i + 1], 0.5)
			var normal: Vector2 = (pts[i + 1] - pts[i]).orthogonal().normalized()
			next.append(mid + normal * _rng.randf_range(-spread, spread))
			next.append(pts[i + 1])
		pts = next
		spread *= 0.5
	return pts


func _update_particles(delta: float) -> void:
	if reduced:
		return
	for ember in embers:
		ember["p"] = (ember["p"] as Vector2) + Vector2(sin(_t * 0.8 + float(ember["k"]) * 6.0) * 14.0, -float(ember["v"])) * delta
		if (ember["p"] as Vector2).y < -10.0:
			ember["p"] = Vector2(_rng.randf() * SCREEN.x, SCREEN.y + 10.0)
	var u: float = _u()
	if u > 0.1 and u < 0.93 and particles.size() < config.particle_count and _rng.randf() < 0.9:
		var angle: float = _rng.randf() * TAU
		var from: Vector2 = _chest() + Vector2.from_angle(angle) * _rng.randf_range(260.0, 620.0)
		particles.append({"p": from, "t": 0.0, "dur": _rng.randf_range(0.7, 1.3), "a": from, "r": _rng.randf_range(1.5, 3.4)})
	for particle in particles:
		particle["t"] = float(particle["t"]) + delta
		var k: float = clampf(float(particle["t"]) / float(particle["dur"]), 0.0, 1.0)
		particle["p"] = (particle["a"] as Vector2).lerp(_chest(), k * k)
	particles = particles.filter(func(q: Dictionary) -> bool: return float(q["t"]) < float(q["dur"]))


# =====================================================================================
# Stage (behind the hero): darkness with red touches, the emblem, the fragment, the tendrils
# =====================================================================================

func _draw_stage() -> void:
	var c: Control = _stage
	var u: float = _u()
	var fade_in: float = clampf(_t / (0.6 if not reduced else config.reduced_fade), 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(config.background_color, fade_in))
	var haze: float = smoothstep(0.1, 0.8, u)
	# Red touches: a glow at the bottom (where the emblem is), a deep red haze round the duck and a red glow along both edges.
	for k in 5:
		c.draw_circle(_hero_home(), 520.0 - float(k) * 90.0, Color(config.haze_color, 0.09 * haze))
	for k in 6:
		var w: float = 90.0 - float(k) * 14.0
		c.draw_rect(Rect2(0.0, 0.0, w, SCREEN.y), Color(config.edge_glow_color, 0.05 * haze))
		c.draw_rect(Rect2(SCREEN.x - w, 0.0, w, SCREEN.y), Color(config.edge_glow_color, 0.05 * haze))
	if _card_t >= 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.0, 0.0, 0.0, 0.35 * smoothstep(0.0, 0.5, _card_t)))
		return
	for ember in embers:
		var alpha: float = 0.25 + 0.55 * float(ember["k"])
		c.draw_circle(ember["p"], float(ember["r"]) * 2.2, Color(config.ember_color, 0.12 * alpha * haze))
		c.draw_circle(ember["p"], float(ember["r"]), Color(config.ember_color.lightened(0.3), alpha * haze))
	_draw_emblem(c, u)
	# The fragment: it darkens to red-black and trembles, then is drawn into his chest.
	var dark: float = smoothstep(0.0, 0.35, u)
	var size: float = 44.0 * (1.0 - 0.7 * smoothstep(0.55, 1.0, u))
	if u < 1.0:
		var at: Vector2 = _fragment_pos()
		GemDrawer.draw(c, at, size, _t, config.gem_color, 0.0, smoothstep(0.1, 0.6, u))
		c.draw_colored_polygon(_ellipse(at, size * 0.36, size * 0.82), Color(config.gem_dark_color, config.gem_dark_color.a * dark))
	# Tendrils of dark red light reach from the fragment and from the emblem to the duck (none in reduced mode).
	var reach: float = smoothstep(0.15, 0.6, u) * (1.0 - smoothstep(0.9, 1.0, u))
	if reach > 0.0 and not reduced:
		for source_index in 2:
			var origin: Vector2 = _fragment_pos() if source_index == 0 else _emblem_center()
			for k in config.tendrils:
				var pts := PackedVector2Array()
				for i in 20:
					var f: float = float(i) / 19.0
					var p: Vector2 = origin.lerp(_chest(), f * reach)
					var wave: float = sin(f * PI) * (40.0 + float(k) * 14.0) * sin(_t * 2.6 + float(k) * 1.7 + float(source_index))
					pts.append(p + Vector2(0, -1).rotated(float(k) * 0.55) * wave)
				c.draw_polyline(pts, Color(config.tendril_color, 0.28), 7.0, true)
				c.draw_polyline(pts, Color(0.12, 0.01, 0.02, 0.9), 3.4, true)
				c.draw_polyline(pts, Color(config.tendril_color.lightened(0.35), 0.8), 1.2, true)


## The emblem at the bottom of the screen: a ritual circle with a star and rune ticks that ignites (red glow, rings that pulse and turn) and the
## sign of the guardian whose soul is devoured in its middle (an axe, a drop, an eye), all drawn by code. Static in reduced mode.
func _draw_emblem(c: Control, u: float) -> void:
	var center: Vector2 = _emblem_center()
	var ignite: float = smoothstep(0.0, 0.3, u) if not reduced else 1.0
	var beat: float = 0.0 if reduced else pulse
	var spin: float = 0.0 if reduced else _t * 0.5
	var radius: float = config.emblem_radius
	for k in 4:
		c.draw_circle(center, radius * (1.5 - 0.25 * float(k)), Color(config.edge_glow_color, (0.05 + 0.04 * beat) * ignite))
	var ring_color: Color = Color(config.bolt_color, (0.5 + 0.4 * beat) * ignite)
	c.draw_arc(center, radius, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.8 * ignite), 7.0, true)
	c.draw_arc(center, radius, 0.0, TAU, 64, ring_color, 3.0, true)
	c.draw_arc(center, radius * 0.72, 0.0, TAU, 48, ring_color, 2.0, true)
	for i in 24:
		var a: float = spin + TAU * float(i) / 24.0
		var long_tick: bool = i % 3 == 0
		c.draw_line(center + Vector2.from_angle(a) * radius * (0.8 if long_tick else 0.9), center + Vector2.from_angle(a) * radius * 0.98, ring_color, 2.0 if long_tick else 1.2, true)
	var star := PackedVector2Array()
	for i in 8:
		star.append(center + Vector2.from_angle(-spin * 1.4 + TAU * float(i) / 8.0 * 3.0) * radius * 0.7)
	star.append(star[0])
	c.draw_polyline(star, Color(config.bolt_color, 0.55 * ignite), 1.6, true)
	_draw_sign(c, center, radius * 0.34, ring_color, ignite)


func _draw_sign(c: Control, center: Vector2, size_px: float, color: Color, ignite: float) -> void:
	var ink := Color(0.0, 0.0, 0.0, 0.85 * ignite)
	match fragment_id:
		"fragment_level_1":
			# An axe: a haft and a curved blade.
			c.draw_line(center + Vector2(-size_px * 0.5, size_px * 0.8), center + Vector2(size_px * 0.35, -size_px * 0.8), ink, 7.0, true)
			c.draw_line(center + Vector2(-size_px * 0.5, size_px * 0.8), center + Vector2(size_px * 0.35, -size_px * 0.8), color, 3.0, true)
			var blade := PackedVector2Array([center + Vector2(size_px * 0.2, -size_px * 0.85), center + Vector2(size_px * 0.95, -size_px * 0.5), center + Vector2(size_px * 0.8, size_px * 0.05), center + Vector2(size_px * 0.2, -size_px * 0.2)])
			c.draw_colored_polygon(blade, Color(color, 0.7 * ignite))
			c.draw_polyline(blade + PackedVector2Array([blade[0]]), color, 2.0, true)
		"fragment_level_2":
			# A drop over two waves.
			var drop := PackedVector2Array([center + Vector2(0.0, -size_px)])
			for i in 13:
				var a: float = -PI / 3.0 + (PI * 4.0 / 3.0) * float(i) / 12.0
				drop.append(center + Vector2(0.0, size_px * 0.25) + Vector2(cos(a), sin(a)) * size_px * 0.62)
			c.draw_colored_polygon(drop, Color(color, 0.55 * ignite))
			c.draw_polyline(drop + PackedVector2Array([drop[0]]), color, 2.0, true)
			for w in 2:
				var wave := PackedVector2Array()
				for i in 9:
					wave.append(center + Vector2(-size_px + size_px * 2.0 * float(i) / 8.0, size_px * (0.95 + 0.25 * float(w)) + sin(float(i) * 1.6 + float(w)) * 4.0))
				c.draw_polyline(wave, color, 2.0, true)
		_:
			# An eye with a pupil and a bolt through it.
			var lid_top := PackedVector2Array()
			var lid_bottom := PackedVector2Array()
			for i in 11:
				var x: float = -size_px + size_px * 2.0 * float(i) / 10.0
				var y: float = sin(float(i) / 10.0 * PI) * size_px * 0.62
				lid_top.append(center + Vector2(x, -y))
				lid_bottom.append(center + Vector2(x, y))
			c.draw_polyline(lid_top, color, 2.4, true)
			c.draw_polyline(lid_bottom, color, 2.4, true)
			c.draw_circle(center, size_px * 0.34, ink)
			c.draw_circle(center, size_px * 0.24, Color(color, 0.9 * ignite))
			c.draw_line(center + Vector2(size_px * 0.15, -size_px * 0.9), center + Vector2(-size_px * 0.1, size_px * 0.05), ink, 4.0, true)
			c.draw_line(center + Vector2(-size_px * 0.1, size_px * 0.05), center + Vector2(size_px * 0.2, size_px * 0.9), ink, 4.0, true)


# =====================================================================================
# Overlay (over the hero): the red lightning, the particles, the heartbeat tint, grain and cinema bars
# =====================================================================================

func _draw_overlay() -> void:
	var c: Control = _overlay
	var u: float = _u()
	if _card_t < 0.0:
		for bolt in bolts:
			var pts: PackedVector2Array = bolt["pts"]
			var w: float = float(bolt["width"])
			var a: float = 1.0 if not reduced else 0.7
			c.draw_polyline(pts, Color(config.bolt_color, 0.16 * a), w * 4.0, true)
			c.draw_polyline(pts, Color(config.bolt_color, 0.85 * a), w * 1.6, true)
			c.draw_polyline(pts, Color(config.bolt_core_color, a), w * 0.7, true)
		for particle in particles:
			var life: float = float(particle["t"]) / float(particle["dur"])
			c.draw_circle(particle["p"], float(particle["r"]) * 2.0, Color(config.ember_color, 0.14 * life))
			c.draw_circle(particle["p"], float(particle["r"]) * (1.0 - 0.5 * life), Color(config.tendril_color.lightened(0.25), 0.4 + 0.5 * life))
	# The heartbeat tint: the only full-screen flash, never above the config's cap (static and absent in reduced mode).
	var tint: float = 0.0
	if not reduced:
		tint = minf(config.flare_cap * pulse * smoothstep(0.2, 0.6, u), config.flare_cap)
	else:
		tint = config.flare_cap * 0.5 * clampf(_t / config.reduced_fade, 0.0, 1.0) * (0.0 if _card_t >= 0.0 else 1.0)
	if tint > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(config.bolt_color, tint))
		peak_overlay_alpha = maxf(peak_overlay_alpha, tint)
	# Grain and cinema bars.
	var seed_step: int = int(_t * 24.0)
	for i in 120:
		var p := Vector2(_h(i * 3 + seed_step) * 1280.0, _h(i * 3 + seed_step + 1) * 720.0)
		c.draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.03))
	var bar: float = 70.0 * clampf(_t / 0.5, 0.0, 1.0)
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

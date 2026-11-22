class_name BossHealthBar
extends CanvasLayer
## Boss bar: a long chipped stone bar at the bottom centre with a purple fill, the boss's name
## above in spaced capitals with an ink outline, and a notch at the phase 2 threshold. When the boss
## is hit the lost piece stays white for a moment before it drains away. Visible only while the
## encounter is active. The boss does not know about this bar. The name label, the fill and the
## marker keep their values (tests read them); the stone drawing on top replaces their look.
## The drawn name is the one of the presentation (BossNames), not the boss data's.

const PURPLE_LIGHT := Color("a66ae8")
const PURPLE := Color("7a3ac2")
const PURPLE_DARK := Color("43177a")
const PURPLE_SHINE := Color("c2a0ff")
## The possessed bar of phase 2 (Phase 15d) and the lit mid-line.
const RED_LIGHT := Color("ff6a50")
const RED := Color("d42a1e")
const RED_DARK := Color("6e0f0c")
const RED_SHINE := Color("ffb0a0")
## The mid-line pulses for this long when the line is crossed, at a calm rate (well under the flash limit).
const MARKER_PULSE_TIME: float = 3.0
const MARKER_PULSE_HZ: float = 1.6
const CREAM := Color(0.98, 0.93, 0.8)
## Seconds the lost piece stays white before draining.
const GHOST_HOLD: float = 0.4

var displayed_name: String = ""
## The name drawn on the bar (the presentation's name; the data name when there is none).
var shown_name: String = ""
var displayed_ratio: float = 0.0
var marker_ratio: float = 0.0
## Every phase line of the boss (Phase 15e-1: boss 3 has two), and the pulse time left of each (the first one is `marker_pulse_left`).
var marker_ratios: PackedFloat32Array = PackedFloat32Array()
var mark_pulses: Array[float] = []
## Seconds left of the mid-line pulse, and how possessed the bar looks (0 = purple, 1 = red; phase 2 of the fight).
var marker_pulse_left: float = 0.0
var possession_k: float = 0.0
var possessed: bool = false

## Guard feedback (Phase 15e-3). The hint shows the first time a hit is blocked in a fight and never again until the next fight.
const GUARD_HINT: String = "Rompe la guardia con golpe pesado o tajo de dash"
const GUARD_HINT_TIME: float = 4.5
var guard_hint_left: float = 0.0
var guard_hint_shown: bool = false
var guard_hint_count: int = 0
var _guard: BossGuard = null
var _boss: BossBase
var _ghost_ratio: float = 0.0
var _ghost_hold: float = 0.0
var _drawer: Control = null

@onready var name_label: Label = $Root/NameLabel
@onready var fill: ColorRect = $Root/Background/Fill
@onready var marker: ColorRect = $Root/Background/Marker
@onready var _background: ColorRect = $Root/Background


func _ready() -> void:
	visible = false
	name_label.self_modulate.a = 0.0
	_background.self_modulate.a = 0.0
	fill.self_modulate.a = 0.0
	marker.self_modulate.a = 0.0
	_drawer = Control.new()
	_drawer.name = "StoneBar"
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_drawer)
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.draw.connect(_draw_bar)


func bind(boss: BossBase) -> void:
	_boss = boss
	displayed_name = boss.stats.display_name
	name_label.text = displayed_name
	var info: Dictionary = BossNames.info_for(boss, self)
	shown_name = String(info.get("name", ""))
	if shown_name.is_empty():
		shown_name = displayed_name
	marker_ratios = boss.stats.get_phase_thresholds()
	marker_ratio = marker_ratios[0]
	mark_pulses.clear()
	for i in marker_ratios.size():
		mark_pulses.append(0.0)
	marker.anchor_left = marker_ratio
	marker.anchor_right = marker_ratio
	_update_ratio(boss.health.current_health, boss.health.max_health)
	boss.activated.connect(_on_activated)
	boss.health_changed.connect(_update_ratio)
	boss.encounter_reset.connect(_hide)
	boss.defeated.connect(_on_defeated)
	boss.phase_transition_started.connect(_on_phase_transition)
	boss.phase_changed.connect(_on_phase_changed)
	_guard = boss.get_node_or_null(^"Guard") as BossGuard
	if _guard != null:
		_guard.deflected.connect(_on_guard_deflected)


func _process(delta: float) -> void:
	if not visible:
		return
	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	else:
		_ghost_ratio = move_toward(_ghost_ratio, displayed_ratio, delta * 0.8)
	for i in mark_pulses.size():
		mark_pulses[i] = maxf(mark_pulses[i] - delta, 0.0)
	marker_pulse_left = mark_pulses.max() if not mark_pulses.is_empty() else maxf(marker_pulse_left - delta, 0.0)
	possession_k = move_toward(possession_k, 1.0 if possessed else 0.0, delta * 1.5)
	guard_hint_left = maxf(guard_hint_left - delta, 0.0)
	if _drawer != null:
		_drawer.queue_redraw()


## The line was crossed: the mid-line lights up and pulses.
func _on_phase_transition(next_phase: int) -> void:
	marker_pulse_left = MARKER_PULSE_TIME
	var index: int = next_phase - 2
	if index >= 0 and index < mark_pulses.size():
		mark_pulses[index] = MARKER_PULSE_TIME


## Phase 2 begins: the bar keeps a possessed tint for the rest of the fight.
func _on_phase_changed(new_phase: int) -> void:
	if new_phase >= 2:
		possessed = true


## A hit was blocked by the guard: the first one of the fight shows the hint.
func _on_guard_deflected(_info: DamageInfo) -> void:
	if guard_hint_shown:
		return
	guard_hint_shown = true
	guard_hint_count += 1
	guard_hint_left = GUARD_HINT_TIME


func _on_activated() -> void:
	guard_hint_shown = false
	guard_hint_left = 0.0
	possessed = false
	possession_k = 0.0
	marker_pulse_left = 0.0
	for i in mark_pulses.size():
		mark_pulses[i] = 0.0
	_update_ratio(_boss.health.current_health, _boss.health.max_health)
	_ghost_ratio = displayed_ratio
	visible = true


func _update_ratio(current: int, maximum: int) -> void:
	var before: float = displayed_ratio
	displayed_ratio = float(current) / float(maximum) if maximum > 0 else 0.0
	fill.anchor_right = displayed_ratio
	if displayed_ratio < before:
		# The lost piece stays white a moment before draining.
		_ghost_ratio = maxf(_ghost_ratio, before)
		_ghost_hold = GHOST_HOLD
	else:
		_ghost_ratio = displayed_ratio


func _hide() -> void:
	visible = false
	guard_hint_shown = false
	guard_hint_left = 0.0
	possessed = false
	possession_k = 0.0
	marker_pulse_left = 0.0
	for i in mark_pulses.size():
		mark_pulses[i] = 0.0


func _on_defeated(_defeated_boss: BossBase) -> void:
	visible = false
	possessed = false
	possession_k = 0.0
	marker_pulse_left = 0.0


func _draw_bar() -> void:
	var bar: Rect2 = Rect2(_background.position, _background.size)
	if bar.size.x <= 0.0:
		return
	StoneUi.spaced_text(_drawer, Vector2(bar.get_center().x, bar.position.y - 12.0), shown_name.to_upper(), 20, CREAM, 6)
	StoneUi.frame(_drawer, bar, 8.0, 77)
	StoneUi.well(_drawer, bar)
	var ghost_w: float = bar.size.x * clampf(_ghost_ratio, 0.0, 1.0)
	var fill_w: float = bar.size.x * clampf(displayed_ratio, 0.0, 1.0)
	if ghost_w > fill_w + 0.5:
		var fade: float = 1.0 if _ghost_hold > 0.0 else 0.75
		_drawer.draw_rect(Rect2(bar.position + Vector2(fill_w, 0.0), Vector2(ghost_w - fill_w, bar.size.y)), Color(1.0, 0.97, 0.92, fade))
	StoneUi.fill(_drawer, Rect2(bar.position, Vector2(fill_w, bar.size.y)), PURPLE_LIGHT.lerp(RED_LIGHT, possession_k), PURPLE.lerp(RED, possession_k), PURPLE_DARK.lerp(RED_DARK, possession_k), Color(PURPLE_SHINE.lerp(RED_SHINE, possession_k), 0.85))
	# The phase lines: a chip in the frame and a thin line through the bar for each (boss 3 has two), pulsing when crossed.
	for index in marker_ratios.size():
		var mx: float = bar.position.x + bar.size.x * clampf(marker_ratios[index], 0.0, 1.0)
		var lit: float = 0.0
		var pulse_left: float = mark_pulses[index] if index < mark_pulses.size() else 0.0
		if pulse_left > 0.0:
			lit = 0.5 + 0.5 * sin((MARKER_PULSE_TIME - pulse_left) * TAU * MARKER_PULSE_HZ)
		_drawer.draw_line(Vector2(mx, bar.position.y + 1.0), Vector2(mx, bar.end.y - 1.0), Color(StoneUi.INK, 0.8), 2.0, true)
		if lit > 0.0:
			_drawer.draw_line(Vector2(mx, bar.position.y - 3.0), Vector2(mx, bar.end.y + 3.0), Color(RED_LIGHT, 0.35 + 0.4 * lit), 7.0, true)
			_drawer.draw_line(Vector2(mx, bar.position.y - 1.0), Vector2(mx, bar.end.y + 1.0), Color(1.0, 0.85, 0.75, 0.55 + 0.45 * lit), 2.5, true)
		var notch := PackedVector2Array([Vector2(mx - 5.0, bar.position.y - 8.5), Vector2(mx + 5.0, bar.position.y - 8.5), Vector2(mx, bar.position.y - 1.0)])
		_drawer.draw_colored_polygon(notch, PURPLE_SHINE)
		var ring := PackedVector2Array(notch)
		ring.append(notch[0])
		_drawer.draw_polyline(ring, StoneUi.INK, 1.8, true)
	_draw_guard(bar)


## The guard meter under the bar while the guard is up (one shield box per breaking hit left), the stagger label while it is
## broken, and the one-time hint. Shapes and words, not color alone.
func _draw_guard(bar: Rect2) -> void:
	var font: Font = GameFonts.BODY
	var below: float = bar.end.y + 18.0
	if _guard != null and _guard.state != BossGuard.State.DOWN:
		var total: int = _guard.guard_break_hits
		var left: int = total - _guard.break_hits
		var label: String = "GUARDIA"
		if _guard.state == BossGuard.State.STAGGER:
			label = "ATURDIDO: ¡GOLPEA!"
		elif _guard.state == BossGuard.State.REGEN:
			label = "GUARDIA VOLVIENDO"
		var box: float = 14.0
		var gap: float = 6.0
		var width: float = float(total) * (box + gap) - gap
		var start_x: float = bar.position.x
		for i in total:
			var rect := Rect2(start_x + float(i) * (box + gap), bar.end.y + 6.0, box, box + 2.0)
			_drawer.draw_rect(rect.grow(2.0), Color(StoneUi.INK, 0.9))
			var up: bool = _guard.state == BossGuard.State.UP and i < left
			_drawer.draw_rect(rect, Color(0.78, 0.9, 1.0, 0.95) if up else Color(0.2, 0.3, 0.5, 0.9))
			if up:
				_drawer.draw_line(rect.position + Vector2(box * 0.5, 2.0), rect.position + Vector2(box * 0.5, box), Color(StoneUi.INK, 0.7), 1.5)
		var at := Vector2(start_x + width + 12.0, bar.end.y + 6.0 + 13.0)
		_drawer.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, StoneUi.INK)
		_drawer.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CREAM)
		below += 14.0
	if guard_hint_left > 0.0:
		var alpha: float = clampf(guard_hint_left / 0.6, 0.0, 1.0)
		StoneUi.spaced_text(_drawer, Vector2(bar.get_center().x, below + 12.0), GUARD_HINT, 15, Color(CREAM, alpha), 4)

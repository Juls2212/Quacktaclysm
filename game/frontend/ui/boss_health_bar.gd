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
const CREAM := Color(0.98, 0.93, 0.8)
## Seconds the lost piece stays white before draining.
const GHOST_HOLD: float = 0.4

var displayed_name: String = ""
## The name drawn on the bar (the presentation's name; the data name when there is none).
var shown_name: String = ""
var displayed_ratio: float = 0.0
var marker_ratio: float = 0.0

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
	marker_ratio = boss.stats.phase_2_health_ratio
	marker.anchor_left = marker_ratio
	marker.anchor_right = marker_ratio
	_update_ratio(boss.health.current_health, boss.health.max_health)
	boss.activated.connect(_on_activated)
	boss.health_changed.connect(_update_ratio)
	boss.encounter_reset.connect(_hide)
	boss.defeated.connect(_on_defeated)


func _process(delta: float) -> void:
	if not visible:
		return
	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	else:
		_ghost_ratio = move_toward(_ghost_ratio, displayed_ratio, delta * 0.8)
	if _drawer != null:
		_drawer.queue_redraw()


func _on_activated() -> void:
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


func _on_defeated(_defeated_boss: BossBase) -> void:
	visible = false


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
	StoneUi.fill(_drawer, Rect2(bar.position, Vector2(fill_w, bar.size.y)), PURPLE_LIGHT, PURPLE, PURPLE_DARK, Color(PURPLE_SHINE, 0.85))
	# Phase 2 notch: a chip in the frame and a thin line through the bar.
	var mx: float = bar.position.x + bar.size.x * clampf(marker_ratio, 0.0, 1.0)
	_drawer.draw_line(Vector2(mx, bar.position.y + 1.0), Vector2(mx, bar.end.y - 1.0), Color(StoneUi.INK, 0.8), 2.0, true)
	var notch := PackedVector2Array([Vector2(mx - 5.0, bar.position.y - 8.5), Vector2(mx + 5.0, bar.position.y - 8.5), Vector2(mx, bar.position.y - 1.0)])
	_drawer.draw_colored_polygon(notch, PURPLE_SHINE)
	var ring := PackedVector2Array(notch)
	ring.append(notch[0])
	_drawer.draw_polyline(ring, StoneUi.INK, 1.8, true)

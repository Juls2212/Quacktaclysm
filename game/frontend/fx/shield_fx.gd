class_name ShieldFx
extends Node2D
## The SHIELD bubble of boss 3's summoner stage and the "BLOQUEADO" tag of a blocked hit, drawn by code (Phase 15o: the armor shell of Phase 15f is
## gone, this node only draws the shield). A blocked hit shows sparks and the tag; with «Efectos de corrupción» off (reduced) there are no sparks and
## no pulse. Child of the boss; it reads the BossShield next to it and changes no gameplay value.

const INK := Color(0.106, 0.098, 0.122)
const BLOCK_TEXT: String = "BLOQUEADO"
const BLOCK_TIME: float = 0.8
const CENTER := Vector2(0.0, -14.0)

## The "BLOQUEADO" tags floating over a blocked hit (position, seconds left): kept in reduced mode too (it is information).
var block_tags: Array = []
var blocked_count: int = 0
var reduced: bool = false
## How visible the SHIELD bubble of the summoner stage is (0 to 1): it fades in and out (a plain fade in reduced mode).
var shield_amount: float = 0.0

var _guard: BossShield = null
var _boss: BossBase = null
var _clock: float = 0.0
var _sparks: Array = []


func _ready() -> void:
	_boss = get_parent() as BossBase
	z_index = 12
	reduced = not GameSettings.is_corruption_effects_enabled()
	_guard = _boss.get_node_or_null(^"Shield") as BossShield if _boss != null else null
	if _guard != null:
		_guard.deflected.connect(_on_deflected)


func _side_of(info: DamageInfo) -> float:
	if info.source is Node2D and _boss != null:
		return 1.0 if (info.source as Node2D).global_position.x >= _boss.global_position.x else -1.0
	return 1.0


func _on_deflected(info: DamageInfo) -> void:
	blocked_count += 1
	var side: float = _side_of(info)
	block_tags.append({"pos": Vector2(side * 34.0, -34.0), "life": BLOCK_TIME})
	if reduced:
		return
	for i in 7:
		_sparks.append({"pos": Vector2(side * 30.0, -14.0 + randf_range(-14.0, 14.0)), "vel": Vector2(side * randf_range(60.0, 190.0), randf_range(-150.0, 80.0)), "life": 0.3})


func _process(delta: float) -> void:
	_clock += delta
	shield_amount = move_toward(shield_amount, 1.0 if _guard != null and _guard.shield_up else 0.0, delta * 4.0)
	for spark in _sparks:
		spark["pos"] += (spark["vel"] as Vector2) * delta
		spark["life"] = float(spark["life"]) - delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)
	for tag in block_tags:
		tag["life"] = float(tag["life"]) - delta
		if not reduced:
			tag["pos"] = (tag["pos"] as Vector2) + Vector2(0.0, -30.0) * delta
	block_tags = block_tags.filter(func(t: Dictionary) -> bool: return float(t["life"]) > 0.0)
	queue_redraw()


func _draw() -> void:
	if _guard == null:
		return
	if shield_amount > 0.01:
		_draw_shield()
	for tag in block_tags:
		_draw_block_tag(tag["pos"], clampf(float(tag["life"]) / 0.3, 0.0, 1.0))
	for spark in _sparks:
		var life: float = float(spark["life"]) / 0.3
		var at: Vector2 = spark["pos"]
		draw_line(at, at - (spark["vel"] as Vector2) * 0.03, Color(1.0, 1.0, 0.85, life), 3.0)


## The shield: a translucent bubble round the whole body with a honeycomb of cells and a dark outline (shape, not color alone).
func _draw_shield() -> void:
	var pulse: float = 1.0 if reduced else 0.85 + 0.15 * sin(_clock * 6.0)
	var radius: float = 70.0
	var center: Vector2 = CENTER
	draw_circle(center, radius, Color(0.65, 0.88, 1.0, 0.16 * shield_amount * pulse))
	draw_arc(center, radius, 0.0, TAU, 48, INK, 6.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.85, 0.96, 1.0, 0.9 * shield_amount * pulse), 3.0, true)
	for row in range(-2, 3):
		for col in range(-2, 3):
			var cell := center + Vector2(float(col) * 26.0 + (13.0 if row % 2 != 0 else 0.0), float(row) * 22.0)
			if cell.distance_to(center) > radius - 10.0:
				continue
			var hex := PackedVector2Array()
			for k in 6:
				hex.append(cell + Vector2.from_angle(TAU * float(k) / 6.0 + PI / 6.0) * 12.0)
			hex.append(hex[0])
			draw_polyline(hex, Color(0.85, 0.96, 1.0, 0.4 * shield_amount * pulse), 1.6, true)


## A small shield with a bar across it and the word BLOQUEADO (shape and text, not color alone).
func _draw_block_tag(at: Vector2, alpha: float) -> void:
	var font: Font = GameFonts.BODY
	var shield := PackedVector2Array([at + Vector2(-9.0, -18.0), at + Vector2(9.0, -18.0), at + Vector2(9.0, -6.0), at + Vector2(0.0, 2.0), at + Vector2(-9.0, -6.0)])
	draw_colored_polygon(shield, Color(0.88, 0.93, 1.0, 0.95 * alpha))
	draw_polyline(shield + PackedVector2Array([shield[0]]), Color(INK, alpha), 2.0, true)
	draw_line(at + Vector2(-9.0, -10.0), at + Vector2(9.0, -10.0), Color(INK, alpha), 2.0)
	var text_at: Vector2 = at + Vector2(14.0, -6.0)
	draw_string_outline(font, text_at, BLOCK_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(INK, alpha))
	draw_string(font, text_at, BLOCK_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 1.0, alpha))

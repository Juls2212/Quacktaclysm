class_name FragmentFx
extends Node2D
## The soul fragment's gem in the level and what happens to it after the choice. Visual only:
## it listens to the public signals `fragment_spawned` (of DecisionFlow's `drop`) and
## `decision_made` (of DecisionFlow) and never changes the game. While the fragment floats it
## draws the gem over it (the fragment's own Visual is hidden at run time).
## LIBERAR (~2 s): the gem rises turning among dotted rings of light, a beam shoots up to the top
## of the screen with rings climbing it, the gem rides it up and a blue four-pointed star is born.
## CONSERVAR: a full-screen exorcism cinematic and the card of the absorbed power
## (ExorcismCutscene, which pauses the game while it plays; skipped in headless runs). The short
## red-thread effect (State.KEPT) stays available but is no longer started by the choice.
## Cleans itself up when the fragment goes away.
## When the fragment appears the gem is born as a small spark in the chest of the fallen boss,
## grows and rises slowly (~1.5 s) to the fragment while its halo lights up, then floats. Touching
## the fragment before that ends completes it at once (skipped in headless runs).

enum State { IDLE, FLOATING, RELEASED, KEPT }

const SKY := Color("9fe8ff")
const BLUE := Color("2c7fe0")
const RED := Color("c2331f")
const GEM_SIZE: float = 26.0
const EXORCISM := preload("res://frontend/fx/exorcism_cutscene.tscn")
const EMERGE_TIME: float = 1.5

var _state: State = State.IDLE
var _fragment: Node2D = null
var _tint: Color = Color(0.6, 0.9, 1.0)
var _at: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _time: float = 0.0
var _level: Node = null
## 0..1 progress of the gem rising out of the boss (1 = floating normally).
var _emerge: float = 1.0
var _emerge_from: Vector2 = Vector2.ZERO
var _boss_chest: Vector2 = Vector2.ZERO
var _has_chest: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 60
	_level = get_parent()
	var flow: Node = _level.get_node_or_null(^"DecisionFlow") if _level != null else null
	if flow == null:
		return
	var drop: Variant = flow.get(&"drop")
	if drop is Node and (drop as Node).has_signal(&"fragment_spawned"):
		(drop as Node).connect(&"fragment_spawned", _on_fragment_spawned)
	if flow.has_signal(&"decision_made"):
		flow.connect(&"decision_made", _on_decision_made)
	var boss: Variant = _level.get(&"boss")
	if boss is Node and (boss as Node).has_signal(&"defeated"):
		(boss as Node).connect(&"defeated", _on_boss_defeated)


func _on_boss_defeated(boss: Node) -> void:
	if boss is Node2D:
		_boss_chest = (boss as Node2D).global_position + Vector2(0, 8)
		_has_chest = true


func _on_fragment_spawned(fragment: Node2D) -> void:
	_fragment = fragment
	_state = State.FLOATING
	_t = 0.0
	var visual := fragment.get_node_or_null(^"Visual") as CanvasItem
	if visual != null:
		visual.visible = false
	var data: Variant = fragment.get(&"data")
	if data is Resource and (data as Resource).get(&"tint") is Color:
		_tint = (data as Resource).get(&"tint")
	_emerge = 1.0
	if DisplayServer.get_name() != "headless":
		_emerge = 0.0
		_emerge_from = _boss_chest if _has_chest else fragment.global_position + Vector2(0, 50)
		if fragment.has_signal(&"collected"):
			fragment.connect(&"collected", _finish_emerge, CONNECT_ONE_SHOT)


func _finish_emerge(_fragment_node: Variant = null) -> void:
	_emerge = 1.0


func _on_decision_made(fragment_id: String, choice: String) -> void:
	if is_instance_valid(_fragment):
		_at = _fragment.global_position
	_t = 0.0
	if choice == "released":
		_state = State.RELEASED
		return
	_state = State.IDLE
	# Automated runs choose Keep too and must not wait for a cinematic.
	if DisplayServer.get_name() == "headless" or _level == null:
		return
	var cut: ExorcismCutscene = EXORCISM.instantiate()
	cut.fragment_id = fragment_id
	cut.player = _level.get(&"player")
	_level.add_child(cut)


func _process(delta: float) -> void:
	_time += delta
	_t += delta
	match _state:
		State.FLOATING:
			if not is_instance_valid(_fragment) or not _fragment.is_inside_tree():
				_state = State.IDLE
				_fragment = null
			else:
				_at = _fragment.global_position
				_emerge = minf(_emerge + delta / EMERGE_TIME, 1.0)
		State.RELEASED:
			if _t > 2.2:
				_state = State.IDLE
		State.KEPT:
			if _t > 1.3:
				_state = State.IDLE
	queue_redraw()


func _draw() -> void:
	match _state:
		State.FLOATING:
			if _emerge < 1.0:
				_draw_emerge()
			else:
				GemDrawer.draw(self, to_local(_at) + Vector2(0, sin(_time * 2.0) * 4.0), GEM_SIZE, _time, _tint)
		State.RELEASED:
			_draw_release()
		State.KEPT:
			_draw_keep()


## The gem leaves the fallen boss's chest as a spark, grows and rises slowly to the fragment.
func _draw_emerge() -> void:
	var u: float = _emerge
	var from: Vector2 = to_local(_emerge_from)
	var to: Vector2 = to_local(_at) + Vector2(0, sin(_time * 2.0) * 4.0 * smoothstep(0.75, 1.0, u))
	var rise: float = smoothstep(0.08, 1.0, u)
	var pos: Vector2 = from.lerp(to, rise) + Vector2(sin(u * TAU * 1.5) * 7.0 * (1.0 - u), 0)
	var size: float = lerpf(3.0, GEM_SIZE, smoothstep(0.0, 0.85, u))
	var halo: float = smoothstep(0.1, 1.0, u)
	# A thin trail of light back to where it was born.
	for i in 10:
		var k: float = float(i) / 9.0
		var p: Vector2 = from.lerp(pos, k) + Vector2(sin(k * 7.0 + _time * 4.0) * 4.0, 0)
		draw_circle(p, 1.2 + k * 1.6, Color(SKY, 0.35 * k * (1.0 - u)))
	# The halo lights up softly.
	for k in 4:
		draw_circle(pos, size * (1.1 + float(k) * 0.45), Color(BLUE.lerp(SKY, 0.4), 0.06 * halo))
	# The first spark, twinkling.
	var spark: float = 1.0 - smoothstep(0.0, 0.35, u)
	if spark > 0.0:
		var r: float = 6.0 + 4.0 * sin(_time * 18.0)
		draw_circle(pos, r * 1.6, Color(SKY, 0.3 * spark))
		draw_line(pos - Vector2(r * 2.2, 0), pos + Vector2(r * 2.2, 0), Color(1, 1, 1, spark), 1.6, true)
		draw_line(pos - Vector2(0, r * 2.2), pos + Vector2(0, r * 2.2), Color(1, 1, 1, spark), 1.6, true)
		draw_circle(pos, 2.6, Color(1, 1, 1, spark))
	# Tiny shapes would make degenerate polygons: the crystal only once it has some size.
	if size >= 8.0:
		GemDrawer.draw(self, pos, size, _time, _tint)
	else:
		draw_circle(pos, size * 0.6, Color(1, 1, 1, 0.9))


func _draw_release() -> void:
	var base: Vector2 = to_local(_at)
	var ground: Vector2 = base + Vector2(0, 36)
	var top_y: float = to_local(_screen_top()).y - 40.0
	var t: float = _t
	# a. Rise turning among dotted rings; a big ring on the ground; threads spiral up.
	var rise: float = minf(t / 0.5, 1.0)
	var gem_pos: Vector2 = base + Vector2(0, -50.0 * rise)
	if t > 1.2:
		gem_pos.y = lerpf(base.y - 50.0, top_y + 60.0, smoothstep(1.2, 1.7, t))
	var fade_out: float = 1.0 - smoothstep(1.7, 2.1, t)
	_dotted_ellipse(ground, 120.0 * minf(t / 0.3, 1.0), 26.0, _time * 1.5, Color(SKY, 0.85 * fade_out))
	for k in 3:
		var y: float = gem_pos.y + (float(k) - 1.0) * 26.0
		_dotted_ellipse(Vector2(base.x, y), (64.0 - float(k) * 10.0) * rise, 13.0, _time * (2.0 + float(k)) * (1.0 if k % 2 == 0 else -1.0), Color(SKY, 0.8 * rise * fade_out))
	for k in 2:
		var pts := PackedVector2Array()
		for i in 16:
			var u: float = float(i) / 15.0
			pts.append(ground.lerp(gem_pos, u) + Vector2(sin(u * 9.0 + _time * 5.0 + float(k) * PI) * 26.0 * (1.0 - u * 0.5), 0))
		draw_polyline(pts, Color(SKY, 0.6 * rise * fade_out), 2.0, true)
	# b. The beam, from the floor to the top of the screen, with rings climbing it and sparks.
	var beam: float = smoothstep(0.45, 0.75, t) * (1.0 - smoothstep(1.6, 2.0, t))
	var reach_y: float = lerpf(ground.y, top_y, smoothstep(0.45, 0.85, t))
	if beam > 0.0 and ground.y - reach_y > 4.0:
		var width: float = (1.0 - smoothstep(1.5, 2.0, t) * 0.8)
		for layer in [[110.0, 0.08], [70.0, 0.12], [36.0, 0.25], [10.0, 0.85]]:
			var w: float = float(layer[0]) * width * 0.5
			var a: float = float(layer[1]) * beam
			var col: Color = Color(1.0, 1.0, 1.0) if float(layer[0]) < 20.0 else BLUE.lerp(SKY, 0.4)
			draw_polygon(PackedVector2Array([Vector2(ground.x - w, ground.y), Vector2(ground.x + w, ground.y), Vector2(ground.x + w * 0.8, reach_y), Vector2(ground.x - w * 0.8, reach_y)]),
					PackedColorArray([Color(col, a), Color(col, a), Color(col, a * 0.3), Color(col, a * 0.3)]))
		for k in 5:
			var u: float = fposmod((t - 0.5) * 0.9 + float(k) / 5.0, 1.0)
			_dotted_ellipse(Vector2(ground.x, lerpf(ground.y, reach_y, u)), 46.0 * (1.0 - u * 0.4), 11.0, _time * 3.0, Color(SKY, 0.8 * beam * (1.0 - u)))
		for k in 16:
			var u: float = fposmod(_time * (0.6 + 0.04 * float(k)) + float(k) * 0.37, 1.0)
			var p := Vector2(ground.x + sin(float(k) * 2.3 + _time * 3.0) * 60.0, lerpf(ground.y, reach_y, u))
			draw_circle(p, 2.0, Color(1, 1, 1, beam * (1.0 - u)))
	# c. The gem rides the beam up; up high a blue star is born with a flash.
	if t < 1.75:
		GemDrawer.draw(self, gem_pos, GEM_SIZE * (1.0 - smoothstep(1.4, 1.75, t) * 0.6), _time, _tint, 0.0, 0.0, t * 4.0 * rise)
	var star: float = smoothstep(1.15, 1.4, t)
	# Tiny shapes would make degenerate polygons: only draw once they have some size.
	if star > 0.08:
		var sc := Vector2(base.x, top_y + 60.0)
		var flash: float = 1.0 - smoothstep(1.2, 1.7, t)
		draw_circle(sc, 80.0 * flash + 20.0, Color(1, 1, 1, 0.35 * flash))
		for k in 4:
			draw_circle(sc, 18.0 + float(k) * 16.0, Color(BLUE.lerp(SKY, 0.5), 0.1 * star))
		var r: float = 34.0 * star
		var pts := PackedVector2Array()
		for i in 8:
			var rr: float = r if i % 2 == 0 else r * 0.22
			if i == 0 or i == 4:
				rr = r * 1.2
			pts.append(sc + Vector2.from_angle(TAU * float(i) / 8.0 - PI * 0.5) * rr)
		draw_colored_polygon(pts, Color(0.85, 0.95, 1.0, star))
		draw_circle(sc, 6.0 * star, Color(1, 1, 1, star))


func _draw_keep() -> void:
	var base: Vector2 = to_local(_at)
	var t: float = _t
	var red: float = smoothstep(0.0, 0.3, t)
	var crack: float = smoothstep(0.15, 0.45, t)
	var shake := Vector2(sin(_time * 70.0), cos(_time * 63.0)) * 3.0 * smoothstep(0.2, 0.4, t) * (1.0 - smoothstep(0.55, 0.6, t))
	var blade: Vector2 = _katana_point()
	if t < 0.6:
		GemDrawer.draw(self, base + shake, GEM_SIZE, _time, _tint, red, crack)
	elif t < 0.95:
		# Darts into the katana as a thread of red light.
		var u: float = smoothstep(0.6, 0.9, t)
		var head: Vector2 = base.lerp(blade, u)
		var pts := PackedVector2Array()
		for i in 12:
			var k: float = float(i) / 11.0
			pts.append(base.lerp(head, k) + Vector2(0, sin(k * PI) * -30.0))
		draw_polyline(pts, Color(RED.lightened(0.2), 0.35), 9.0, true)
		draw_polyline(pts, Color(1.0, 0.55, 0.45, 0.95), 3.0, true)
		draw_circle(head, 6.0, Color(1.0, 0.6, 0.5))
	var flash: float = smoothstep(0.85, 0.95, t) * (1.0 - smoothstep(0.95, 1.25, t))
	if flash > 0.0:
		draw_circle(blade, 34.0 * flash + 6.0, Color(RED, 0.35 * flash))
		draw_line(blade - Vector2(28, 0), blade + Vector2(28, 0), Color(1.0, 0.6, 0.5, flash), 3.0, true)
		draw_line(blade - Vector2(0, 18), blade + Vector2(0, 18), Color(1.0, 0.6, 0.5, flash), 2.0, true)


## Where the player's katana is (read only): beside the player, on the side he faces.
func _katana_point() -> Vector2:
	var player: Variant = _level.get(&"player") if _level != null else null
	if player is Node2D and is_instance_valid(player):
		var facing: Variant = (player as Node2D).get(&"facing_direction")
		var dir: float = float(facing) if facing != null else 1.0
		return to_local((player as Node2D).global_position + Vector2(22.0 * dir, -14.0))
	return to_local(_at) + Vector2(60, 20)


## Top of the visible screen in world space.
func _screen_top() -> Vector2:
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	return inverse * Vector2(get_viewport_rect().size.x * 0.5, 0.0)


func _dotted_ellipse(c: Vector2, rx: float, ry: float, rot: float, color: Color) -> void:
	if rx < 2.0 or color.a <= 0.01:
		return
	var dashes: int = 22
	for i in dashes:
		var a0: float = rot + TAU * float(i) / float(dashes)
		var a1: float = a0 + TAU / float(dashes) * (0.55 if i % 3 != 0 else 0.15)
		var pts := PackedVector2Array()
		for k in 4:
			var a: float = lerpf(a0, a1, float(k) / 3.0)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(pts, color, 2.4, true)

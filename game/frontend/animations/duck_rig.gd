@tool
class_name DuckRig
extends Node2D
## Hand-drawn duck drawn in code: thick ink outline, flat fills, procedural animation.
## Visual only. A controller (player_visual.gd / enemy_visual.gd / boss_visual.gd) writes the
## pose inputs below every frame; the rig turns them into a run cycle, squash, weapon arcs, hair...
## Origin is the body center of the owner; `foot_y` is where the feet touch the floor.
## Facing is handled by the parent (Visual.scale.x); the rig always draws facing +x.
## `part` draws a single piece (body, head or weapon): DuckRagdoll uses it for the death ragdoll.

enum Look { HERO, BRUTE, BRUTE_TOUGH, BANDIT, SLINGER, BOSS_WOODCUTTER, BOSS_SWAMP, BOSS_STORM }
## What the duck is doing with its weapon. Enemies use ATTACK (its look decides the move);
## bosses use ATTACK (swipe), CHARGE and CAST (projectile volley).
enum Action { NONE, SLASH, HEAVY, DASH_SLASH, CAST, ATTACK, CHARGE }
enum Phase { WINDUP, STRIKE, RECOVER }
## ALL draws the whole duck; the others draw one ragdoll piece. FX (shadow, smears) is never a piece.
enum Part { ALL, BODY, HEAD, WEAPON, FX }

const INK := Color(0.106, 0.098, 0.122)
const PAPER := Color(0.984, 0.976, 0.957)
const BEAK := Color(0.957, 0.635, 0.227)
const BEAK_DARK := Color(0.851, 0.49, 0.173)
const STEEL := Color(0.91, 0.93, 0.95)
const EMBER := Color(1.0, 0.72, 0.26)
const WOOD := Color(0.56, 0.37, 0.21)
const INK_W := 2.6
const HERO_KIMONO := Color(0.69, 0.2, 0.22)
const BOSS_SCALE: float = 1.7

@export var look: Look = Look.HERO:
	set(value):
		look = value
		_strands.clear()
		queue_redraw()
## Distance from the origin down to the floor (half the collision height).
@export var foot_y: float = 26.0
@export var part: Part = Part.ALL
## Color of the sword smear for the light slash (heavy and dash slash use their own).
@export var slash_color: Color = Color(1.0, 1.0, 1.0, 0.92)
@export var heavy_color: Color = Color(1.0, 0.65, 0.25, 0.92)
@export var dash_slash_color: Color = Color(0.4, 0.95, 1.0, 0.85)

# --- Pose inputs (written by the controller each frame) ---
var ground_speed: float = 0.0
var grounded: bool = true
var vertical_speed: float = 0.0
var dashing: bool = false
var action: Action = Action.NONE
var phase: Phase = Phase.WINDUP
## Progress 0..1 inside `phase`.
var phase_t: float = 0.0
var hurt: bool = false
var dead: bool = false
## Bosses in phase 2: hotter eyes and steam.
var enraged: bool = false
## Limp piece of a ragdoll: no body animation, rest pose, X eyes.
var ragdoll: bool = false
## Tint of the sword glow while casting the wave (comes from the wave tier).
var cast_color: Color = Color(0.6, 0.9, 1.0, 1.0)

# --- Animation state ---
var _time: float = 0.0
var _run_phase: float = 0.0
var _lean: float = 0.0
var _squash: Vector2 = Vector2.ONE
var _land_kick: float = 0.0
var _was_grounded: bool = true
var _dead_t: float = 0.0
var _ghosts: Array = []
var _ghost_clock: float = 0.0
var _strands: Array = []
var _root: Transform2D = Transform2D.IDENTITY
## Piece the current draw calls belong to (compared with `part`).
var _cur: Part = Part.BODY
## Where the weapon ends this frame (rig space), for effects drawn at the tip.
var _tip: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	_time += delta
	_advance_body(delta)
	_advance_ghosts(delta)
	_advance_strands(delta)
	queue_redraw()


# =====================================================================================
# Ragdoll support: where each piece sits, in this node's local space, at rest.
# =====================================================================================

func is_boss() -> bool:
	return look == Look.BOSS_WOODCUTTER or look == Look.BOSS_SWAMP or look == Look.BOSS_STORM


func get_rest_transform() -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * _look_scale(), 0.0, Vector2(0.0, foot_y))


func get_part_center(p: Part) -> Vector2:
	var rest: Transform2D = get_rest_transform()
	match p:
		Part.HEAD:
			return rest * _head_center()
		Part.WEAPON:
			return rest * _hand_point(_idle_weapon_pose(false))
	return rest * Vector2(-1, -15)


func get_part_radius(p: Part) -> float:
	match p:
		Part.HEAD:
			return _head_radius() * _look_scale()
		Part.WEAPON:
			return 4.0 * _look_scale()
	return 14.0 * _look_scale()


## Weapon from the hand to its tip (local space, at rest).
func get_weapon_vector() -> Vector2:
	var pose: Vector2 = _idle_weapon_pose(false)
	return Vector2.from_angle(pose.y) * _weapon_length() * _look_scale()


func get_neck_point() -> Vector2:
	var rest: Transform2D = get_rest_transform()
	return rest * Vector2(-1, -15).lerp(_head_center(), 0.62)


# =====================================================================================
# Motion
# =====================================================================================

func _advance_body(delta: float) -> void:
	if ragdoll:
		_lean = 0.0
		_squash = Vector2.ONE
		return
	if grounded and not _was_grounded and not dashing:
		_land_kick = 1.0
	_was_grounded = grounded
	_land_kick = move_toward(_land_kick, 0.0, delta * 6.0)
	if grounded and ground_speed > 5.0:
		_run_phase += ground_speed * delta * 0.085 / _look_scale()
	else:
		_run_phase = lerpf(_run_phase, roundf(_run_phase / PI) * PI, minf(delta * 10.0, 1.0))
	_dead_t = minf(_dead_t + delta * 3.5, 1.0) if dead else 0.0

	var target_lean: float = _base_lean()
	var target_squash := Vector2.ONE
	if dashing:
		target_lean += 0.32
		target_squash = Vector2(1.14, 0.9)
	elif not grounded:
		target_squash = Vector2(0.94, 1.07) if vertical_speed < 0.0 else Vector2(0.97, 1.03)
	elif ground_speed > 5.0:
		target_lean += 0.1
	if hurt:
		target_lean = -0.28
		if is_boss():
			target_lean = -0.12 + sin(_time * 40.0) * 0.04
	target_lean += _action_lean()
	target_squash *= _action_squash()
	if dead:
		target_lean = -1.45 * _ease_out(_dead_t)

	var rate: float = minf(delta * 16.0, 1.0)
	_lean = lerpf(_lean, target_lean, rate)
	_squash = _squash.lerp(target_squash, rate)


func _base_lean() -> float:
	match look:
		Look.BANDIT:
			return 0.12
		Look.BOSS_STORM:
			return 0.05
	return 0.0


func _breath() -> float:
	if ragdoll or dead or dashing or not grounded or ground_speed > 5.0:
		return 0.0
	return sin(_time * (1.8 if is_boss() else 2.6)) * 0.025


func _bob() -> float:
	if not ragdoll and grounded and ground_speed > 5.0 and not dashing:
		return -absf(sin(_run_phase)) * 2.6 * _look_scale()
	return 0.0


func _build_root() -> Transform2D:
	var kick: float = _land_kick * _land_kick
	var sq := Vector2(_squash.x * (1.0 + kick * 0.14), _squash.y * (1.0 - kick * 0.16 + _breath()))
	return Transform2D(_lean, sq * _look_scale(), 0.0, Vector2(0.0, foot_y + _bob()))


func _look_scale() -> float:
	match look:
		Look.BRUTE:
			return 1.1
		Look.BRUTE_TOUGH:
			return 1.2
		Look.BANDIT:
			return 0.95
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			return BOSS_SCALE
	return 1.0


func _head_center() -> Vector2:
	match look:
		Look.HERO:
			return Vector2(7, -37)
		Look.BANDIT:
			return Vector2(5, -33)
		Look.SLINGER:
			return Vector2(5, -36)
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			return Vector2(7, -38)
	return Vector2(6, -37)


func _head_radius() -> float:
	match look:
		Look.HERO:
			return 12.5
		Look.BANDIT:
			return 10.0
	return 11.5


func _shoulder() -> Vector2:
	match look:
		Look.HERO:
			return Vector2(0, -22)
		Look.BANDIT:
			return Vector2(-1, -20)
		Look.SLINGER:
			return Vector2(0, -21)
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			return Vector2(-2, -25)
	return Vector2(-2, -24)


func _arm_length() -> float:
	match look:
		Look.BANDIT:
			return 12.0
		Look.HERO, Look.SLINGER:
			return 13.0
	return 14.0


func _hand_point(pose: Vector2) -> Vector2:
	return _shoulder() + Vector2.from_angle(pose.x) * _arm_length()


func _weapon_length() -> float:
	match look:
		Look.HERO:
			return 38.0
		Look.BRUTE:
			return 30.0
		Look.BRUTE_TOUGH:
			return 34.0
		Look.BANDIT:
			return 19.0
		Look.SLINGER:
			return 12.0
		Look.BOSS_WOODCUTTER:
			return 40.0
		Look.BOSS_SWAMP:
			return 42.0
		Look.BOSS_STORM:
			return 48.0
	return 30.0


# =====================================================================================
# Afterimages (dash, lunge, charge) and loose strands (hair, tails, cape, moss)
# =====================================================================================

func _advance_ghosts(delta: float) -> void:
	for ghost in _ghosts:
		ghost["life"] -= delta * 4.0
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return g["life"] > 0.0)
	var lunging: bool = phase == Phase.STRIKE and (
			(look == Look.BANDIT and action == Action.ATTACK) or action == Action.CHARGE)
	if ragdoll or not (dashing or lunging) or not is_inside_tree():
		return
	_ghost_clock -= delta
	if _ghost_clock <= 0.0:
		_ghost_clock = 0.03
		_ghosts.append({ "xf": global_transform * _root, "life": 1.0 })


func _strand_specs() -> Array:
	# Anchor (rig space), segments, segment length, root width, color, rest direction, piece.
	match look:
		Look.HERO:
			# Shoulder-length and fanned out so the tips separate into loose locks.
			var hair: Color = _hair_color()
			return [
				[Vector2(-5, -44), 4, 4.5, 4.5, hair, Vector2(-1.0, 0.45), Part.HEAD],
				[Vector2(-6, -38), 4, 4.5, 5.0, hair, Vector2(-0.8, 0.8), Part.HEAD],
				[Vector2(-3, -33), 3, 4.5, 4.5, hair, Vector2(-0.35, 1.0), Part.HEAD],
				[Vector2(1, -48), 4, 4.0, 3.8, hair, Vector2(-1.0, 0.2), Part.HEAD],
			]
		Look.BANDIT:
			var red := Color(0.77, 0.26, 0.23)
			return [[Vector2(-6, -38), 4, 4.5, 4.0, red, Vector2(-1.0, 0.3), Part.HEAD],
					[Vector2(-6, -36), 3, 5.0, 3.5, red, Vector2(-1.0, 0.6), Part.HEAD]]
		Look.BOSS_WOODCUTTER:
			var rope := Color(0.78, 0.66, 0.42)
			# Rope ends of the sack hood, knotted at the nape.
			return [[Vector2(-5, -31), 3, 4.0, 2.4, rope, Vector2(-1.0, 0.5), Part.HEAD],
					[Vector2(-5, -31), 3, 3.5, 2.4, rope, Vector2(-1.0, 0.9), Part.HEAD]]
		Look.BOSS_SWAMP:
			# Weed hanging off its back and tail.
			var moss := Color(0.31, 0.42, 0.27)
			return [[Vector2(-14, -22), 4, 4.0, 3.5, moss, Vector2(-0.7, 1.0), Part.BODY],
					[Vector2(-17, -13), 4, 4.0, 3.5, moss, Vector2(-0.5, 1.0), Part.BODY],
					[Vector2(-10, -28), 3, 4.0, 3.0, moss, Vector2(-1.0, 0.6), Part.BODY]]
		Look.BOSS_STORM:
			# Tattered cape strips streaming from the shoulders.
			var cape := Color(0.17, 0.18, 0.28)
			return [[Vector2(-14, -27), 6, 5.0, 7.0, cape, Vector2(-1.0, 0.45), Part.BODY],
					[Vector2(-18, -20), 6, 5.0, 7.5, cape, Vector2(-1.0, 0.7), Part.BODY],
					[Vector2(-11, -29), 5, 5.0, 6.0, cape, Vector2(-0.8, 0.9), Part.BODY]]
	return []


func _hair_color() -> Color:
	return Color(0.16, 0.14, 0.2)


func _advance_strands(delta: float) -> void:
	if not is_inside_tree():
		return
	_root = _build_root()
	var specs: Array = _strand_specs()
	if _strands.size() != specs.size():
		_strands.clear()
		for spec in specs:
			_strands.append({ "spec": spec, "p": PackedVector2Array(), "prev": PackedVector2Array() })
	var to_world: Transform2D = global_transform * _root
	var dt: float = clampf(delta, 0.001, 0.05)
	for strand in _strands:
		var spec: Array = strand["spec"]
		var count: int = spec[1]
		var rest_dir: Vector2 = global_transform.basis_xform(spec[5] as Vector2).normalized()
		var seg: float = spec[2] * _look_scale() * absf(global_transform.get_scale().y)
		var anchor: Vector2 = to_world * (spec[0] as Vector2)
		var p: PackedVector2Array = strand["p"]
		var prev: PackedVector2Array = strand["prev"]
		if p.size() != count + 1 or p[0].distance_to(anchor) > 200.0:
			p.resize(count + 1)
			prev.resize(count + 1)
			for i in count + 1:
				p[i] = anchor + rest_dir * seg * i
				prev[i] = p[i]
		p[0] = anchor
		prev[0] = anchor
		for i in range(1, count + 1):
			var velocity: Vector2 = (p[i] - prev[i]) * 0.86
			prev[i] = p[i]
			var sway := Vector2(sin(_time * 3.1 + i * 0.7) * 6.0, 0.0)
			p[i] += velocity + ((Vector2(0, 520) + sway) * dt * dt + rest_dir * 0.35 * i) * seg / spec[2]
		for _pass in 2:
			for i in range(1, count + 1):
				var d: Vector2 = p[i] - p[i - 1]
				p[i] = p[i - 1] + d.normalized() * seg if d.length() > 0.001 else p[i - 1] + rest_dir * seg
		strand["p"] = p
		strand["prev"] = prev


# =====================================================================================
# Drawing
# =====================================================================================

func _draw() -> void:
	_root = _build_root()
	_cur = Part.FX
	_draw_shadow()
	_draw_ghosts()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if look != Look.HERO:
		_draw_strands()
	draw_set_transform_matrix(_root)
	match look:
		Look.HERO:
			_draw_hero()
		Look.BRUTE, Look.BRUTE_TOUGH:
			_draw_brute()
		Look.BANDIT:
			_draw_bandit()
		Look.SLINGER:
			_draw_slinger()
		Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
			_draw_boss()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_shadow() -> void:
	if ragdoll:
		return
	var w: float = 17.0 * _look_scale()
	var alpha: float = 0.85 if grounded else 0.35
	if dead:
		w *= 1.4
	draw_set_transform(Vector2(0, foot_y), 0.0, Vector2(1.0 if grounded else 0.65, 1.0))
	_poly(_ellipse(Vector2.ZERO, w, 3.6 * sqrt(_look_scale()), 18), Color(INK, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_ghosts() -> void:
	var tint := Color(0.45, 0.4, 0.55)
	match look:
		Look.HERO:
			tint = Color(0.85, 0.3, 0.32)
		Look.BOSS_SWAMP:
			tint = Color(0.45, 0.6, 0.35)
		Look.BOSS_STORM:
			tint = Color(0.45, 0.8, 0.95)
	var inv: Transform2D = global_transform.affine_inverse()
	for ghost in _ghosts:
		draw_set_transform_matrix(inv * (ghost["xf"] as Transform2D))
		var c := Color(tint, 0.35 * float(ghost["life"]))
		_poly(_ellipse(Vector2(-1, -14), 16, 13), c)
		_poly(_ellipse(_head_center(), 11, 11), c)


func _draw_strands() -> void:
	# Ink pass first, then fill, so neighbouring strands merge into one mass of hair.
	for ink_pass in [true, false]:
		for strand in _strands:
			var spec: Array = strand["spec"]
			_cur = spec[6]
			var p: PackedVector2Array = strand["p"]
			var root_w: float = spec[3] * _look_scale()
			var color: Color = spec[4]
			for i in range(p.size() - 1):
				var a: Vector2 = to_local(p[i])
				var b: Vector2 = to_local(p[i + 1])
				var w: float = lerpf(root_w, root_w * 0.25, float(i) / float(maxi(p.size() - 2, 1)))
				if ink_pass:
					_line(a, b, INK, w + INK_W * 1.2 * _ink_scale(), true)
					_dot(b, (w + INK_W * 1.2 * _ink_scale()) * 0.5, INK)
				else:
					_line(a, b, color, w, true)
					_dot(b, w * 0.5, color)
			if not ink_pass and p.size() > 2:
				var h0: Vector2 = to_local(p[0])
				var h1: Vector2 = to_local(p[2])
				_line(h0 + Vector2(1, 0), h1 + Vector2(1, 0), Color(color.lightened(0.3), 0.7), 1.2, true)


## Strands are drawn in node space, so their outline follows the look's scale like the rest.
func _ink_scale() -> float:
	return _look_scale()


# --- Hero: kimono, long loose hair, katana ---

func _draw_hero() -> void:
	var arm: Vector2 = _weapon_pose()
	var kimono := HERO_KIMONO
	var obi := Color(0.17, 0.2, 0.36)
	_cur = Part.BODY
	_draw_feet(Color(BEAK))
	_draw_tail(Vector2(-13, -15), PAPER)
	# Robe: the top of the body egg flaring into a short skirt that leaves the legs visible.
	var robe := PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * float(i) / 12.0
		robe.append(Vector2(-1, -15) + Vector2(cos(a) * 14.0, sin(a) * 11.0))
	robe.append_array([Vector2(15, -9), Vector2(12, -6), Vector2(-14, -6), Vector2(-17, -9)])
	_shape(robe, kimono)
	_shape(PackedVector2Array([Vector2(-16.2, -9), Vector2(14.2, -9), Vector2(12, -6), Vector2(-14, -6)]),
			HERO_KIMONO.darkened(0.3), 1.8)
	_line(Vector2(-5, -12), Vector2(-7, -7), INK, 1.3, true)
	_line(Vector2(5, -12), Vector2(6, -7), INK, 1.3, true)
	_draw_neck(Vector2(2, -24))
	# Crossed collar over the chest.
	_shape(PackedVector2Array([Vector2(-3, -26), Vector2(3, -26), Vector2(10, -15), Vector2(5.5, -13)]),
			Color(0.95, 0.91, 0.8), 2.0)
	# Obi with its knot and tails at the back.
	_shape(PackedVector2Array([Vector2(-14.5, -17), Vector2(12.5, -17), Vector2(13.6, -12.5), Vector2(-15.2, -12.5)]),
			obi, 2.2)
	var flutter: float = sin(_time * 7.0) * 1.5 if ground_speed > 5.0 or dashing else 0.0
	_shape(PackedVector2Array([Vector2(-15, -14), Vector2(-21, -8 + flutter), Vector2(-17, -8.5 + flutter)]), obi, 1.8)
	_shape(PackedVector2Array([Vector2(-15, -14), Vector2(-24, -11 + flutter), Vector2(-20, -9 + flutter)]), obi, 1.8)
	_shape(_ellipse(Vector2(-15.5, -14.8), 3.6, 2.8), obi, 2.0)
	# The loose hair falls over the back of the kimono, then the head covers its roots.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_strands()
	draw_set_transform_matrix(_root)
	var head: Vector2 = _head_center()
	_cur = Part.HEAD
	_draw_head(head, 12.5)
	_draw_hero_hair_cap(head, 12.5)
	_draw_face_hero(head)
	_cur = Part.FX
	_draw_smear(Vector2(4, -24))
	_draw_sleeve_and_katana(_shoulder(), arm)


func _draw_hero_hair_cap(c: Vector2, r: float) -> void:
	# Crown of hair from the forehead over to the nape; strands carry on from the back.
	var cap := PackedVector2Array()
	for i in 15:
		var a: float = deg_to_rad(-55.0 - 155.0 * float(i) / 14.0)
		cap.append(c + Vector2(cos(a), sin(a)) * (r + 2.0))
	for i in 15:
		var a: float = deg_to_rad(-210.0 + 155.0 * float(i) / 14.0)
		var rr: float = r - 2.5 - 3.0 * sin(PI * float(i) / 14.0)
		cap.append(c + Vector2(-1.0, 0.5) + Vector2(cos(a), sin(a)) * rr)
	_shape(cap, _hair_color())
	# Loose bangs falling over the forehead.
	var hair: Color = _hair_color()
	_shape(PackedVector2Array([c + Vector2(1, -12), c + Vector2(6, -3), c + Vector2(6.5, -11)]), hair, 2.0)
	_shape(PackedVector2Array([c + Vector2(5, -12.5), c + Vector2(11, -5), c + Vector2(10.5, -10.5)]), hair, 2.0)
	_line(c + Vector2(-8, -8), c + Vector2(-2, -11.5), Color(0.42, 0.42, 0.56, 0.85), 1.5, true)


func _draw_face_hero(c: Vector2) -> void:
	_draw_beak(c + Vector2(7.5, 0.0), 1.0)
	_draw_eye(c + Vector2(4.5, -3.5), false)
	if not dead and not hurt and not ragdoll:
		_line(c + Vector2(1.5, -8.5), c + Vector2(8, -6.5), INK, 2.0, true)


func _draw_sleeve_and_katana(shoulder: Vector2, arm: Vector2) -> void:
	var dir := Vector2.from_angle(arm.x)
	var hand: Vector2 = shoulder + dir * _arm_length()
	var side: Vector2 = dir.orthogonal()
	# Wide kimono sleeve: always droops toward the floor, whatever the arm angle (hull keeps it valid).
	var sleeve := Geometry2D.convex_hull(PackedVector2Array([
		shoulder - side * 5.0, hand - side * 4.5, hand + side * 5.5,
		shoulder.lerp(hand, 0.6) + Vector2(0, 10), shoulder + side * 6.0 + Vector2(0, 5)]))
	sleeve.remove_at(sleeve.size() - 1)
	var behind: bool = sin(arm.y) < -0.55 and action != Action.NONE and phase == Phase.WINDUP
	if behind:
		_draw_katana(hand, arm.y, 34.0)
	_cur = Part.BODY
	_shape(sleeve, HERO_KIMONO)
	_line(hand - side * 4.5, hand + side * 5.5, Color(0.95, 0.91, 0.8), 2.0, true)
	if not behind:
		_draw_katana(hand, arm.y, 34.0)
	_cur = Part.BODY
	_shape(_ellipse(hand, 3.4, 3.0), PAPER, 2.2)


func _draw_katana(hand: Vector2, angle: float, length: float) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	# Handle (tsuka) behind the hand, guard (tsuba), then a gently curved blade.
	var grip_a: Vector2 = hand - d * 9.0
	_line(grip_a, hand + d * 2.0, INK, 6.4, true)
	_line(grip_a, hand + d * 2.0, Color(0.32, 0.13, 0.15), 3.6, true)
	for i in 3:
		var p: Vector2 = grip_a + d * (2.0 + i * 3.0)
		_line(p - n * 1.6, p + d * 1.5 + n * 1.6, Color(0.85, 0.75, 0.55), 0.9, true)
	var blade := PackedVector2Array()
	var edge := PackedVector2Array()
	var base: Vector2 = hand + d * 4.0
	for i in 9:
		var u: float = float(i) / 8.0
		var curve: float = -u * u * 3.2
		blade.append(base + d * (length * u) + n * (curve - 1.6 * (1.0 - u * 0.4)))
		edge.append(base + d * (length * u) + n * (curve + 1.8 * (1.0 - u * 0.6)))
	var tip: Vector2 = base + d * (length + 4.0) + n * -3.6
	_tip = tip
	var poly := PackedVector2Array(blade)
	poly.append(tip)
	edge.reverse()
	poly.append_array(edge)
	_shape(poly, STEEL, 2.0)
	_line(base + n * 0.2, base + d * length * 0.9 + n * -2.4, Color(0.62, 0.74, 0.86), 1.0, true)
	_shape(_ellipse(hand + d * 3.0, 2.2, 4.6, 12, angle), Color(0.25, 0.23, 0.27), 1.8)
	_cur = Part.FX
	if action == Action.CAST:
		var glow: float = phase_t if phase == Phase.WINDUP else 1.0 - phase_t
		_line(base, tip, Color(cast_color, 0.55 * glow), 7.0, true)
	if action == Action.HEAVY and phase == Phase.WINDUP and phase_t > 0.55:
		_draw_glint(tip, (phase_t - 0.55) / 0.45)


func _draw_glint(at: Vector2, k: float) -> void:
	var s: float = 7.0 * sin(PI * clampf(k, 0.0, 1.0))
	if s < 0.5:
		return
	var star := PackedVector2Array([at + Vector2(0, -s), at + Vector2(s * 0.25, -s * 0.25), at + Vector2(s, 0),
			at + Vector2(s * 0.25, s * 0.25), at + Vector2(0, s), at + Vector2(-s * 0.25, s * 0.25),
			at + Vector2(-s, 0), at + Vector2(-s * 0.25, -s * 0.25)])
	_shape(star, Color(1, 0.97, 0.8), 1.4)


## Weapon smear for the attacks: a tapered crescent around the shoulder.
func _draw_smear(center: Vector2) -> void:
	_cur = Part.FX
	if action == Action.NONE or phase == Phase.WINDUP:
		return
	var fade: float = 1.0 if phase == Phase.STRIKE else 1.0 - phase_t
	if fade <= 0.02:
		return
	match action:
		Action.SLASH:
			_crescent(center, deg_to_rad(-80), deg_to_rad(65), 42.0, 12.0, _strike_k(), Color(slash_color, slash_color.a * fade))
		Action.HEAVY:
			_crescent(center, deg_to_rad(-95), deg_to_rad(80), 50.0, 17.0, _strike_k(), Color(heavy_color, heavy_color.a * fade))
		Action.DASH_SLASH:
			var c := Color(dash_slash_color, dash_slash_color.a * fade)
			var streak := PackedVector2Array([Vector2(-72, -20), Vector2(38, -26), Vector2(58, -19),
					Vector2(36, -12), Vector2(-60, -16)])
			_shape(streak, c, 2.0)
			_line(Vector2(-50, -18), Vector2(40, -20), Color(1, 1, 1, 0.8 * fade), 2.0, true)
		Action.CAST:
			if look == Look.HERO:
				var tip: Vector2 = center + Vector2(54, -2)
				var r: float = 6.0 + 14.0 * _strike_k()
				_arc(tip, r, 0.0, TAU, 24, Color(INK, fade), INK_W + 2.0, true)
				_arc(tip, r, 0.0, TAU, 24, Color(cast_color, fade), INK_W, true)
		Action.ATTACK:
			if look == Look.BRUTE or look == Look.BRUTE_TOUGH:
				_crescent(center, deg_to_rad(-120), deg_to_rad(60), 46.0, 14.0, _strike_k(), Color(1.0, 0.86, 0.6, 0.9 * fade))
			elif is_boss():
				_crescent(center, deg_to_rad(-125), deg_to_rad(55), 50.0, 15.0, _strike_k(), Color(_boss_fx_color(), 0.85 * fade))


func _strike_k() -> float:
	return _ease_out(phase_t) if phase == Phase.STRIKE else 1.0


func _crescent(center: Vector2, a0: float, a1: float, radius: float, thickness: float, k: float, color: Color) -> void:
	var end: float = lerpf(a0, a1, clampf(k, 0.05, 1.0))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps: int = 14
	for i in steps + 1:
		var u: float = float(i) / float(steps)
		var a: float = lerpf(a0, end, u)
		var dir := Vector2.from_angle(a)
		outer.append(center + dir * radius)
		inner.append(center + dir * (radius - thickness * sin(PI * clampf(u * 1.05, 0.0, 1.0)) - 0.5))
	inner.reverse()
	var poly := PackedVector2Array(outer)
	poly.append_array(inner)
	_shape(poly, color, 2.0)


# --- Enemies ---

func _enemy_body_color() -> Color:
	match look:
		Look.BRUTE:
			return Color(0.66, 0.62, 0.71)
		Look.BRUTE_TOUGH:
			return Color(0.5, 0.46, 0.56)
		Look.BANDIT:
			return Color(0.76, 0.73, 0.8)
		Look.BOSS_WOODCUTTER:
			return Color(0.6, 0.55, 0.58)
		Look.BOSS_SWAMP:
			return Color(0.5, 0.57, 0.44)
		Look.BOSS_STORM:
			return Color(0.38, 0.42, 0.55)
	return Color(0.7, 0.67, 0.74)


func _draw_brute() -> void:
	var arm: Vector2 = _weapon_pose()
	var tough: bool = look == Look.BRUTE_TOUGH
	var body: Color = _enemy_body_color()
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-15, -13), body)
	_shape(_ellipse(Vector2(-1, -15), 17.0, 14.5), body)
	# Soot speckles: the corruption creeping through the feathers.
	for s in [Vector2(-9, -20), Vector2(-4, -9), Vector2(5, -17), Vector2(-12, -12)]:
		_dot(s, 1.4, Color(INK, 0.55))
	_shape(_ellipse(Vector2(5, -10), 7.0, 5.0, 14), body.lightened(0.18), 1.8)
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	var club_len: float = _weapon_length()
	# A club resting back over the shoulder hides behind the head; a swinging one is in front.
	if cos(arm.y) < -0.3:
		_draw_club(hand, arm.y, club_len, tough)
	_cur = Part.BODY
	_draw_neck(Vector2(2, -26), body)
	var head: Vector2 = _head_center()
	_cur = Part.HEAD
	_draw_head(head, 11.5, body)
	_draw_beak(head + Vector2(7.5, 2.5), 1.15)
	if tough:
		# Iron pot helmet with a side handle.
		_shape(PackedVector2Array([head + Vector2(-13, -1), head + Vector2(13, -1), head + Vector2(12, -15),
				head + Vector2(-12, -15)]), Color(0.3, 0.32, 0.36))
		_shape(PackedVector2Array([head + Vector2(-15, -1), head + Vector2(15, -1), head + Vector2(15, 2),
				head + Vector2(-15, 2)]), Color(0.22, 0.23, 0.27), 2.0)
		_arc(head + Vector2(-15, -8), 4.0, PI * 0.5, PI * 1.5, 10, INK, 2.4, true)
		_draw_glow_eye(head + Vector2(5, 4.5))
	else:
		# Dented tin pail with an eye slit.
		_shape(PackedVector2Array([head + Vector2(-11, 1), head + Vector2(13, 1), head + Vector2(10, -16),
				head + Vector2(-9, -16)]), Color(0.62, 0.66, 0.7))
		_line(head + Vector2(-10, -12), head + Vector2(11.5, -12), INK, 1.6, true)
		_arc(head + Vector2(-2, -6), 3.0, -0.4, 1.6, 6, INK, 1.4, true)
		_shape(PackedVector2Array([head + Vector2(1, -5), head + Vector2(12.5, -5), head + Vector2(12, -2),
				head + Vector2(1, -2)]), Color(0.12, 0.11, 0.14), 1.4)
		_draw_glow_eye(head + Vector2(7, -3.5))
		_arc(head + Vector2(1, -16), 9.0, PI * 1.1, PI * 1.9, 10, INK, 1.6, true)
	_draw_smear(Vector2(0, -24))
	if cos(arm.y) >= -0.3:
		_draw_club(hand, arm.y, club_len, tough)
	_cur = Part.BODY
	_draw_wing(shoulder, hand, body)
	if tough:
		# Boards lashed over the shoulder.
		_shape(PackedVector2Array([Vector2(-9, -30), Vector2(6, -32), Vector2(8, -23), Vector2(-8, -21)]),
				Color(0.55, 0.38, 0.22), 2.2)
		_line(Vector2(-4, -31), Vector2(-3, -21.5), Color(0.86, 0.78, 0.55), 1.4, true)
		_line(Vector2(3, -32), Vector2(4, -22.5), Color(0.86, 0.78, 0.55), 1.4, true)


func _draw_club(hand: Vector2, angle: float, length: float, spiked: bool) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	var poly := PackedVector2Array([hand - d * 6.0 - n * 2.6, hand + d * length - n * 5.2,
			hand + d * (length + 3.0), hand + d * length + n * 5.2, hand - d * 6.0 + n * 2.6])
	_shape(poly, WOOD)
	_line(hand + d * 8.0, hand + d * (length - 4.0), Color(0.38, 0.24, 0.13), 1.2, true)
	var nails: int = 3 if spiked else 2
	for i in nails:
		var p: Vector2 = hand + d * (length - 4.0 - i * 6.0)
		_line(p + n * 4.0, p + n * 8.0, INK, 1.8, true)
		_line(p - n * 4.0, p - n * 8.0, INK, 1.8, true)


func _draw_bandit() -> void:
	var arm: Vector2 = _weapon_pose()
	var body: Color = _enemy_body_color()
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-12, -11), body)
	_shape(_ellipse(Vector2(-1, -13), 13.5, 11.0), body)
	for s in [Vector2(-7, -17), Vector2(-2, -8), Vector2(-10, -10)]:
		_dot(s, 1.2, Color(INK, 0.5))
	_draw_neck(Vector2(1, -22), body)
	var head: Vector2 = _head_center()
	_cur = Part.HEAD
	_draw_head(head, 10.0, body)
	_draw_beak(head + Vector2(6.5, 1.5), 0.95)
	# Burglar mask band with eye holes.
	_shape(PackedVector2Array([head + Vector2(-10, -6), head + Vector2(10.5, -6), head + Vector2(10, -1),
			head + Vector2(-10, -1)]), Color(0.77, 0.26, 0.23), 2.0)
	_shape(_ellipse(head + Vector2(-10.5, -3.5), 2.4, 2.8), Color(0.77, 0.26, 0.23), 1.8)
	_draw_glow_eye(head + Vector2(5, -3.5))
	_draw_smear(Vector2(0, -20))
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	_draw_shiv(hand, arm.y)
	_cur = Part.BODY
	_draw_wing(shoulder, hand, body)
	_cur = Part.FX
	if action == Action.ATTACK and phase == Phase.STRIKE:
		for i in 3:
			var y: float = -30.0 + i * 9.0
			_line(Vector2(-34 - i * 4, y), Vector2(-18 - i * 2, y), INK, 2.0, true)


func _draw_shiv(hand: Vector2, angle: float) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	_line(hand - d * 5.0, hand + d * 2.0, INK, 5.4, true)
	_line(hand - d * 5.0, hand + d * 2.0, Color(0.45, 0.3, 0.2), 2.6, true)
	_shape(PackedVector2Array([hand + d * 2.0 - n * 2.4, hand + d * 15.0 - n * 1.0, hand + d * 19.0,
			hand + d * 13.0 + n * 2.2, hand + d * 2.0 + n * 2.4]), Color(0.78, 0.76, 0.72), 1.8)


func _draw_slinger() -> void:
	var arm: Vector2 = _weapon_pose()
	var cloak := Color(0.33, 0.27, 0.47)
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	# Cloak covers the body; the hood frames a dark face with two glowing eyes.
	_shape(PackedVector2Array([Vector2(-4, -30), Vector2(10, -28), Vector2(16, -12), Vector2(17, -3),
			Vector2(-17, -3), Vector2(-18, -10), Vector2(-14, -22)]), cloak)
	_line(Vector2(-6, -22), Vector2(-9, -5), INK, 1.4, true)
	_line(Vector2(4, -20), Vector2(6, -5), INK, 1.4, true)
	_shape(PackedVector2Array([Vector2(-16, -6.5), Vector2(16.4, -6.5), Vector2(17, -3), Vector2(-17, -3)]),
			Color(0.23, 0.19, 0.34), 1.8)
	var head: Vector2 = _head_center()
	_cur = Part.HEAD
	_shape(PackedVector2Array([head + Vector2(-13, 8), head + Vector2(-14, -6), head + Vector2(-6, -15),
			head + Vector2(2, -18), head + Vector2(9, -12), head + Vector2(13, -2), head + Vector2(11, 9)]), cloak)
	_shape(_ellipse(head + Vector2(4, 0), 7.5, 8.0), Color(0.09, 0.08, 0.12), 2.0)
	_draw_beak(head + Vector2(9.5, 3.0), 1.0)
	_draw_glow_eye(head + Vector2(2, -2))
	_draw_glow_eye(head + Vector2(7, -2.5))
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	_draw_slingshot(hand, shoulder)
	_cur = Part.BODY
	_shape(_ellipse(hand, 4.0, 3.6), cloak.lightened(0.15), 2.0)


func _draw_slingshot(hand: Vector2, shoulder: Vector2) -> void:
	_cur = Part.WEAPON
	var fork_l: Vector2 = hand + Vector2(1, -12)
	var fork_r: Vector2 = hand + Vector2(7, -11)
	_line(hand + Vector2(0, 4), hand + Vector2(3, -5), INK, 6.0, true)
	_line(hand + Vector2(0, 4), hand + Vector2(3, -5), WOOD, 3.0, true)
	for tip in [fork_l, fork_r]:
		_line(hand + Vector2(3, -5), tip, INK, 5.2, true)
		_line(hand + Vector2(3, -5), tip, WOOD, 2.4, true)
	# The pouch is pulled back toward the shoulder during the windup and snaps on release.
	var pull: float = 0.0
	if action == Action.ATTACK:
		match phase:
			Phase.WINDUP:
				pull = _ease_out(phase_t)
			Phase.STRIKE:
				pull = 1.0 - _ease_out(phase_t * 3.0)
	var rest: Vector2 = (fork_l + fork_r) * 0.5 + Vector2(-1, 1)
	var pouch: Vector2 = rest.lerp(shoulder + Vector2(-8, 0), pull)
	_line(fork_l, pouch, Color(0.85, 0.82, 0.74), 1.6, true)
	_line(fork_r, pouch, Color(0.85, 0.82, 0.74), 1.6, true)
	if pull > 0.1 or (action == Action.ATTACK and phase == Phase.WINDUP):
		_shape(_ellipse(pouch, 3.2, 3.0, 10), Color(0.55, 0.53, 0.5), 1.8)


# --- Bosses: three guardians built on the same duck ---

func _boss_eye_color() -> Color:
	match look:
		Look.BOSS_SWAMP:
			return Color(0.72, 1.0, 0.36)
		Look.BOSS_STORM:
			return Color(0.56, 0.95, 1.0)
	return EMBER


## Color of the boss's swipe smear and volley flash.
func _boss_fx_color() -> Color:
	match look:
		Look.BOSS_SWAMP:
			return Color(0.62, 0.8, 0.42)
		Look.BOSS_STORM:
			return Color(0.6, 0.92, 1.0)
	return Color(1.0, 0.8, 0.52)


func _draw_boss() -> void:
	var arm: Vector2 = _weapon_pose()
	var body: Color = _enemy_body_color()
	var shoulder: Vector2 = _shoulder()
	var hand: Vector2 = _hand_point(arm)
	var head: Vector2 = _head_center()
	_cur = Part.BODY
	_draw_feet(BEAK_DARK)
	_draw_tail(Vector2(-15, -13), body)
	if look == Look.BOSS_SWAMP:
		# Cattail reeds growing out of its back.
		for r in [[Vector2(-10, -24), Vector2(-17, -44)], [Vector2(-6, -26), Vector2(-9, -48)], [Vector2(-13, -20), Vector2(-24, -36)]]:
			_line(r[0], r[1], INK, 3.4, true)
			_line(r[0], r[1], Color(0.48, 0.58, 0.3), 1.6, true)
			_shape(_ellipse(r[1], 2.2, 4.5, 10, (r[1] - r[0]).angle() + PI * 0.5), Color(0.45, 0.3, 0.18), 1.6)
	_shape(_ellipse(Vector2(-1, -15), 17.5, 15.0), body)
	match look:
		Look.BOSS_WOODCUTTER:
			# Plaid work vest over the chest.
			var vest := PackedVector2Array([Vector2(-12, -26), Vector2(8, -27), Vector2(15, -16), Vector2(13, -5),
					Vector2(-14, -4), Vector2(-17, -14)])
			_shape(vest, Color(0.64, 0.24, 0.22))
			for x in [-9.0, -3.0, 3.0, 9.0]:
				_line(Vector2(x, -26), Vector2(x + 1.5, -5), Color(0.34, 0.12, 0.12, 0.8), 1.4, true)
			for y in [-20.0, -12.0]:
				_line(Vector2(-16, y), Vector2(14, y), Color(0.34, 0.12, 0.12, 0.8), 1.4, true)
		Look.BOSS_SWAMP:
			# Moss blobs and dripping mud.
			for m in [[Vector2(-8, -22), 5.5], [Vector2(4, -10), 4.5], [Vector2(-12, -9), 4.0]]:
				_shape(_ellipse(m[0], m[1], m[1] * 0.7, 12), Color(0.31, 0.42, 0.27), 1.6)
			for d in [Vector2(-3, -2), Vector2(7, -4)]:
				_shape(PackedVector2Array([d + Vector2(-2, -3), d + Vector2(2, -3), d + Vector2(0, 3 + sin(_time * 3.0 + d.x))]),
						Color(0.36, 0.3, 0.2), 1.4)
		Look.BOSS_STORM:
			# Jagged scar that glows like a bolt across the chest.
			var bolt := PackedVector2Array([Vector2(2, -27), Vector2(-4, -17), Vector2(1, -17), Vector2(-5, -6),
					Vector2(6, -19), Vector2(1, -19), Vector2(6, -27)])
			_shape(bolt, Color(_boss_eye_color(), 0.75 + 0.25 * sin(_time * 9.0)), 1.6)
	if cos(arm.y) < -0.3:
		_draw_boss_weapon(hand, arm.y)
	_cur = Part.BODY
	_draw_neck(Vector2(2, -27), body)
	_cur = Part.HEAD
	_draw_head(head, 11.5, body)
	_draw_beak(head + Vector2(7.5, 2.5), 1.2)
	match look:
		Look.BOSS_WOODCUTTER:
			# Burlap sack hood with stitched seams and two ragged eye holes.
			var sack := PackedVector2Array([head + Vector2(-13, 6), head + Vector2(-14, -6), head + Vector2(-9, -14),
					head + Vector2(0, -17), head + Vector2(9, -14), head + Vector2(13, -5), head + Vector2(12, 3),
					head + Vector2(5, 2), head + Vector2(-3, 7)])
			_shape(sack, Color(0.78, 0.66, 0.44))
			for i in 5:
				var p: Vector2 = head + Vector2(-7 + i * 2.5, -15 + i * 4.0)
				_line(p - Vector2(1.5, 1), p + Vector2(1.5, 1), INK, 1.2, true)
			_shape(_ellipse(head + Vector2(3, -4), 3.4, 3.0), Color(0.08, 0.07, 0.1), 1.6)
			_shape(_ellipse(head + Vector2(9.5, -3.5), 2.6, 3.0), Color(0.08, 0.07, 0.1), 1.6)
			_draw_glow_eye(head + Vector2(3, -4), _boss_eye_color())
			_draw_glow_eye(head + Vector2(9.5, -3.5), _boss_eye_color())
			_line(head + Vector2(-12, 6), head + Vector2(6, 8), Color(0.62, 0.5, 0.3), 3.0, true)
		Look.BOSS_SWAMP:
			_draw_glow_eye(head + Vector2(5, -3.5), _boss_eye_color())
			# Lily pad hat with a notch and a small flower.
			var pad := PackedVector2Array()
			for i in 17:
				var a: float = deg_to_rad(25.0 + 310.0 * float(i) / 16.0)
				pad.append(head + Vector2(-1, -11) + Vector2(cos(a) * 15.0, sin(a) * 4.5))
			pad.append(head + Vector2(-1, -11))
			_shape(pad, Color(0.42, 0.62, 0.34))
			_shape(_ellipse(head + Vector2(-4, -15), 3.0, 2.4), Color(0.96, 0.62, 0.72), 1.6)
			_dot(head + Vector2(-4, -15.5), 1.0, Color(1.0, 0.9, 0.5))
		Look.BOSS_STORM:
			_draw_glow_eye(head + Vector2(5, -3.5), _boss_eye_color())
			_line(head + Vector2(1, -8), head + Vector2(9, -6), INK, 2.4, true)
			_draw_storm_cloud(head + Vector2(-1, -21))
	_cur = Part.FX
	if enraged and not dead and not ragdoll:
		for i in 2:
			var k: float = fmod(_time * 0.8 + i * 0.5, 1.0)
			_shape(_ellipse(head + Vector2(-8 + i * 12, -18 - k * 14), 2.5 + k * 3.0, 2.0 + k * 2.5, 10),
					Color(0.85, 0.85, 0.88, 0.7 * (1.0 - k)), 1.2)
	_draw_smear(shoulder + Vector2(2, 0))
	if cos(arm.y) >= -0.3:
		_draw_boss_weapon(hand, arm.y)
	_cur = Part.BODY
	_draw_wing(shoulder, hand, body)
	_draw_boss_cast_fx()


func _draw_storm_cloud(at: Vector2) -> void:
	var bob: float = sin(_time * 2.0) * 1.5
	var c := at + Vector2(0, bob)
	var grey := Color(0.5, 0.52, 0.6)
	for puff in [[Vector2(-7, 1), 5.0], [Vector2(0, -2), 6.5], [Vector2(7, 1), 5.0], [Vector2(0, 3), 5.0]]:
		_shape(_ellipse(c + puff[0], puff[1], puff[1] * 0.8, 14), grey, 2.0)
	_poly(_ellipse(c + Vector2(0, 1), 9.0, 3.2, 14), grey)
	# A bolt flickers out of the cloud now and then (more often when enraged).
	var flick: float = fmod(_time * (3.0 if enraged else 1.4), 1.0)
	if flick < 0.18 and not ragdoll:
		_cur = Part.FX
		_zigzag(c + Vector2(4, 4), c + Vector2(10, 18), 3, _boss_eye_color())
		_cur = Part.HEAD


func _draw_boss_weapon(hand: Vector2, angle: float) -> void:
	_cur = Part.WEAPON
	var d := Vector2.from_angle(angle)
	var n: Vector2 = d.orthogonal()
	var length: float = _weapon_length()
	_tip = hand + d * length
	match look:
		Look.BOSS_WOODCUTTER:
			# Long-handled axe with a half-moon head.
			_line(hand - d * 8.0, _tip, INK, 6.4, true)
			_line(hand - d * 8.0, _tip, WOOD, 3.6, true)
			var h: Vector2 = hand + d * (length - 6.0)
			var blade := PackedVector2Array([h - d * 5.0 + n * 2.0, h - d * 7.0 + n * 12.0, h + d * 1.0 + n * 15.0,
					h + d * 8.0 + n * 11.0, h + d * 6.0 + n * 2.0])
			_shape(blade, STEEL)
			_line(h - d * 5.0 + n * 12.5, h + d * 7.0 + n * 11.5, Color(0.62, 0.7, 0.78), 1.2, true)
		Look.BOSS_SWAMP:
			# Gnarled root staff topped with a glowing bulb of swamp light.
			var pts := PackedVector2Array()
			for i in 6:
				var u: float = float(i) / 5.0
				pts.append(hand - d * 10.0 + d * (length + 10.0) * u + n * sin(u * 9.0) * 2.2)
			_line_strip(pts, INK, 7.0)
			_line_strip(pts, Color(0.42, 0.3, 0.2), 4.0)
			_shape(_ellipse(_tip, 5.0, 5.0, 14), Color(0.72, 1.0, 0.36, 0.95), 2.0)
			_dot(_tip + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 0.9))
		Look.BOSS_STORM:
			# Lightning rod spear with a forked head.
			_line(hand - d * 12.0, _tip, INK, 5.6, true)
			_line(hand - d * 12.0, _tip, Color(0.62, 0.66, 0.74), 2.8, true)
			for side in [-1.0, 0.0, 1.0]:
				var base: Vector2 = _tip - d * 2.0
				var prong: Vector2 = _tip + d * (8.0 - absf(side) * 2.0) + n * side * 5.0
				_line(base + n * side * 4.0, prong, INK, 4.4, true)
				_line(base + n * side * 4.0, prong, STEEL, 2.0, true)
			_line(_tip - d * 2.0 - n * 4.0, _tip - d * 2.0 + n * 4.0, INK, 4.0, true)
			_cur = Part.FX
			if action != Action.NONE and not ragdoll:
				_zigzag(_tip + d * 6.0, _tip + d * 6.0 + n * 10.0 - d * 8.0, 3, _boss_eye_color())
				_zigzag(_tip + d * 6.0, _tip + d * 6.0 - n * 10.0 - d * 6.0, 3, _boss_eye_color())


## Volley flash: a ring bursting from the weapon tip as the boss throws its projectiles.
func _draw_boss_cast_fx() -> void:
	_cur = Part.FX
	if action != Action.CAST or ragdoll:
		return
	var color: Color = _boss_fx_color()
	if phase == Phase.WINDUP:
		_dot(_tip, 3.0 + 6.0 * phase_t, Color(color, 0.35 + 0.4 * phase_t))
		return
	var fade: float = 1.0 if phase == Phase.STRIKE else 1.0 - phase_t
	var r: float = 6.0 + 12.0 * _strike_k()
	_arc(_tip, r, 0.0, TAU, 24, Color(INK, fade), INK_W + 2.0, true)
	_arc(_tip, r, 0.0, TAU, 24, Color(color, fade), INK_W, true)


func _zigzag(from: Vector2, to: Vector2, kinks: int, color: Color) -> void:
	var seed_step: int = int(_time * 18.0)
	var pts := PackedVector2Array([from])
	var n: Vector2 = (to - from).orthogonal().normalized()
	for i in range(1, kinks + 1):
		var u: float = float(i) / float(kinks + 1)
		var jitter: float = sin(float(seed_step * 13 + i * 7)) * 3.5
		pts.append(from.lerp(to, u) + n * jitter)
	pts.append(to)
	_line_strip(pts, INK, 3.6)
	_line_strip(pts, color, 1.8)


func _draw_glow_eye(at: Vector2, color: Color = EMBER) -> void:
	if dead or ragdoll:
		_draw_x_eye(at, 2.4)
		return
	var halo: float = 5.5 if enraged else 4.2
	_dot(at, halo, Color(color, 0.3))
	_dot(at, 2.2, INK)
	_dot(at, 1.5, color)


# --- Shared parts ---

func _draw_feet(color: Color) -> void:
	var tuck: bool = (not grounded or dashing) and not ragdoll
	for side in [-1.0, 1.0]:
		var ph: float = _run_phase + (0.0 if side > 0.0 else PI)
		var base_x: float = 5.0 * side
		var foot := Vector2(base_x, 0.0)
		if tuck:
			foot = Vector2(base_x - 2.0, -4.0 + (1.5 if side < 0.0 else 0.0))
		elif ground_speed > 5.0 and not ragdoll:
			foot = Vector2(base_x + sin(ph) * 6.5, -maxf(0.0, cos(ph)) * 4.5)
		var hip := Vector2(base_x * 0.6, -6.0)
		_line(hip, foot, INK, 5.0, true)
		_line(hip, foot, color, 2.4, true)
		var shade: Color = color if side > 0.0 else color.darkened(0.12)
		_shape(PackedVector2Array([foot + Vector2(-3, 0), foot + Vector2(7, 0), foot + Vector2(8, -2),
				foot + Vector2(1.5, -3.6), foot + Vector2(-3, -2.6)]), shade, 2.0)


func _draw_tail(at: Vector2, color: Color) -> void:
	var wag: float = sin(_time * 5.0) * 1.2 if ground_speed < 5.0 else sin(_run_phase * 2.0) * 1.6
	if ragdoll:
		wag = 0.0
	# Short upturned tuft: one curled tip, the way a duck tail flicks up.
	_shape(PackedVector2Array([at + Vector2(3, -5), at + Vector2(-4, -8), at + Vector2(-9, -13 + wag),
			at + Vector2(-8, -7 + wag * 0.5), at + Vector2(-6, -1), at + Vector2(3, 4)]), color, 2.4)


func _draw_neck(base: Vector2, color: Color = PAPER) -> void:
	_shape(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(7, 0), base + Vector2(10, -11),
			base + Vector2(-1, -13)]), color)


func _draw_head(c: Vector2, r: float, color: Color = PAPER) -> void:
	_shape(_ellipse(c, r, r * 0.98, 22), color)


func _draw_beak(at: Vector2, s: float) -> void:
	var open: float = 0.0
	if hurt or ragdoll:
		open = 2.5
	elif action != Action.NONE and phase == Phase.STRIKE:
		open = 1.5
	_shape(PackedVector2Array([at + Vector2(-1, -4) * s, at + Vector2(10, -3) * s, at + Vector2(12.5, -0.5) * s,
			at + Vector2(10, 1.5) * s, at + Vector2(-1, 1.5) * s]), BEAK, 2.2)
	_shape(PackedVector2Array([at + Vector2(-1, 1.5) * s, at + Vector2(9, 1.5) * s,
			at + Vector2(8, 3.5 + open) * s, at + Vector2(-1, 3.5 + open * 0.6) * s]), BEAK_DARK, 2.0)


func _draw_eye(at: Vector2, glow: bool) -> void:
	if dead or ragdoll:
		_draw_x_eye(at, 2.4)
	elif hurt:
		_line(at + Vector2(-2.4, -2), at + Vector2(1.6, 0), INK, 1.8, true)
		_line(at + Vector2(1.6, 0), at + Vector2(-2.4, 2), INK, 1.8, true)
	elif glow:
		_draw_glow_eye(at)
	else:
		var blink: bool = fmod(_time, 3.7) > 3.58
		if blink:
			_line(at + Vector2(-2, 0), at + Vector2(2, 0), INK, 1.8, true)
		else:
			_poly(_ellipse(at, 1.9, 2.7, 10), INK)
			_dot(at + Vector2(0.5, -1.0), 0.6, PAPER)


func _draw_x_eye(at: Vector2, s: float) -> void:
	_line(at + Vector2(-s, -s), at + Vector2(s, s), INK, 1.8, true)
	_line(at + Vector2(-s, s), at + Vector2(s, -s), INK, 1.8, true)


func _draw_wing(shoulder: Vector2, hand: Vector2, color: Color) -> void:
	var d: Vector2 = (hand - shoulder).normalized()
	var n: Vector2 = d.orthogonal()
	_shape(PackedVector2Array([shoulder - n * 5.0, hand - n * 3.5, hand + d * 4.5, hand + n * 4.0,
			shoulder + n * 6.0 + Vector2(0, 3)]), color, 2.4)
	_line(hand - n * 1.0, hand + d * 3.0 - n * 0.5, Color(INK, 0.6), 1.2, true)


# =====================================================================================
# Pose curves
# =====================================================================================

## Returns (arm angle, weapon angle) in radians, rig space (0 = forward, -PI/2 = up).
func _weapon_pose() -> Vector2:
	if ragdoll:
		return _idle_weapon_pose(false)
	var idle: Vector2 = _idle_weapon_pose()
	if dead:
		return Vector2(deg_to_rad(150), deg_to_rad(95))
	if hurt:
		return Vector2(deg_to_rad(125), deg_to_rad(150))
	if action == Action.NONE:
		return idle
	var windup: Vector2
	var strike: Vector2
	match action:
		Action.SLASH:
			windup = _deg(-120, -150)
			strike = _deg(55, 35)
		Action.HEAVY:
			windup = _deg(-100, -92)
			strike = _deg(70, 85)
		Action.DASH_SLASH:
			windup = _deg(150, 175)
			strike = _deg(5, 2)
		Action.CAST:
			if is_boss():
				windup = _deg(-105, -100)
				strike = _deg(-15, -20)
			else:
				windup = _deg(160, 182)
				strike = _deg(-5, -2)
		Action.CHARGE:
			windup = _deg(25, 10)
			strike = _deg(5, -5)
		_:
			match look:
				Look.BRUTE, Look.BRUTE_TOUGH, Look.BOSS_WOODCUTTER, Look.BOSS_SWAMP, Look.BOSS_STORM:
					windup = _deg(-135, -165)
					strike = _deg(35, 22)
				Look.BANDIT:
					windup = _deg(160, 185)
					strike = _deg(0, -4)
				_:
					windup = _deg(5, 0)
					strike = _deg(0, 0)
	match phase:
		Phase.WINDUP:
			return _lerp_angles(idle, windup, _ease_out(phase_t))
		Phase.STRIKE:
			return _lerp_angles(windup, strike, _ease_out(minf(phase_t * 1.6, 1.0)))
	return _lerp_angles(strike, idle, _ease_in_out(phase_t))


func _idle_weapon_pose(animated: bool = true) -> Vector2:
	var sway: float = sin(_time * 2.6) * 0.04 if animated else 0.0
	var running: bool = animated and grounded and ground_speed > 5.0
	match look:
		Look.HERO:
			if animated and dashing:
				return _deg(150, 172)
			if animated and not grounded:
				return _deg(30, -40)
			if running:
				return _deg(105, 160) + Vector2(sin(_run_phase) * 0.12, 0.0)
			return _deg(62, -18) + Vector2(sway, sway)
		Look.BRUTE, Look.BRUTE_TOUGH, Look.BOSS_WOODCUTTER:
			return _deg(-40, -145) + Vector2(sway, sway)
		Look.BANDIT:
			return _deg(45, 5) + Vector2(sin(_run_phase) * 0.15 if running else sway, 0.0)
		Look.BOSS_SWAMP, Look.BOSS_STORM:
			# Staff or spear planted upright beside the body.
			return _deg(55, -82) + Vector2(sway, sway * 0.5)
	return _deg(15, 0) + Vector2(sway, 0.0)


func _action_lean() -> float:
	if action == Action.NONE or dead or hurt:
		return 0.0
	var windup_lean: float = -0.1
	var strike_lean: float = 0.12
	match action:
		Action.HEAVY:
			windup_lean = -0.16
			strike_lean = 0.22
		Action.ATTACK:
			if look == Look.BANDIT:
				windup_lean = -0.14
				strike_lean = 0.42
			elif look == Look.SLINGER:
				windup_lean = -0.08
				strike_lean = 0.05
		Action.DASH_SLASH:
			windup_lean = 0.0
			strike_lean = 0.1
		Action.CHARGE:
			windup_lean = -0.12
			strike_lean = 0.36
		Action.CAST:
			if is_boss():
				windup_lean = -0.14
				strike_lean = 0.1
	match phase:
		Phase.WINDUP:
			return windup_lean * _ease_out(phase_t)
		Phase.STRIKE:
			return strike_lean
	return strike_lean * (1.0 - _ease_in_out(phase_t))


func _action_squash() -> Vector2:
	if action == Action.NONE or dead or hurt:
		return Vector2.ONE
	var crouch := Vector2(1.06, 0.92)
	if action == Action.HEAVY or action == Action.CHARGE:
		crouch = Vector2(1.1, 0.86)
	match phase:
		Phase.WINDUP:
			return Vector2.ONE.lerp(crouch, _ease_out(phase_t))
		Phase.STRIKE:
			if (look == Look.BANDIT and action == Action.ATTACK) or action == Action.CHARGE:
				return Vector2(1.16, 0.9)
			return Vector2(0.95, 1.05)
	return Vector2.ONE


# =====================================================================================
# Helpers: every draw call goes through these so a single ragdoll piece can be drawn.
# =====================================================================================

func _ok() -> bool:
	return part == Part.ALL or part == _cur


func _shape(points: PackedVector2Array, fill: Color, width: float = INK_W) -> void:
	if not _ok():
		return
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, INK, width, true)


func _line(a: Vector2, b: Vector2, color: Color, width: float, antialiased: bool = false) -> void:
	if _ok():
		draw_line(a, b, color, width, antialiased)


func _line_strip(points: PackedVector2Array, color: Color, width: float) -> void:
	if _ok():
		draw_polyline(points, color, width, true)


func _dot(at: Vector2, radius: float, color: Color) -> void:
	if _ok():
		draw_circle(at, radius, color)


func _arc(center: Vector2, radius: float, a0: float, a1: float, steps: int, color: Color, width: float,
		antialiased: bool = false) -> void:
	if _ok():
		draw_arc(center, radius, a0, a1, steps, color, width, antialiased)


func _poly(points: PackedVector2Array, color: Color) -> void:
	if _ok():
		draw_colored_polygon(points, color)


func _ellipse(c: Vector2, rx: float, ry: float, steps: int = 20, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


func _deg(arm_deg: float, weapon_deg: float) -> Vector2:
	return Vector2(deg_to_rad(arm_deg), deg_to_rad(weapon_deg))


func _lerp_angles(a: Vector2, b: Vector2, t: float) -> Vector2:
	return Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t))


func _ease_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


func _ease_in_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

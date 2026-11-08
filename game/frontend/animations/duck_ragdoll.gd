class_name DuckRagdoll
extends Node2D
## Death ragdoll for a DuckRig: the body, the head (pinned at the neck, floppy) and the weapon
## (loose) become rigid bodies that tumble with the killing blow and collide with the world only.
## Visual only: spawned beside the dead character, never touches gameplay.
## `lifetime` > 0 frees it after that many seconds (with a fade); 0 keeps it until freed.
## A boss is not taken apart: it plays a death (3 s) instead. It staggers back while its aura
## flickers out, sinks to its knees with the head hanging, falls flat on its face in a puff of
## dust (with a short screen shake) and crumbles into dark ash and small souls that float away.
## Skipped in headless runs (the boss then gets the plain ragdoll).

const FADE_TIME: float = 0.6
const BOSS_DEATH_TIME: float = 3.0
const AURA := Color(0.42, 0.16, 0.62)
const ASH := Color(0.12, 0.1, 0.13)
const SOUL := Color(0.96, 0.95, 1.0)
const DUST := Color(0.55, 0.5, 0.46)

var lifetime: float = 0.0
var _age: float = 0.0

# Boss death: the pose is driven on `_pivot` (at the feet, mirrored by facing), the head hangs
# from `_head_pivot` and the weapon drops from `_weapon_pivot`. Particles are in local space.
var _boss_death: bool = false
var _pivot: Node2D = null
var _head_pivot: Node2D = null
var _weapon_pivot: Node2D = null
var _rigs: Array[DuckRig] = []
var _front: Node2D = null
var _facing: float = 1.0
var _size: float = 1.0
var _foot: Vector2 = Vector2.ZERO
var _foot_y: float = 26.0
var _head_rest: Vector2 = Vector2.ZERO
var _hand_rest: Vector2 = Vector2.ZERO
var _weapon_at: Vector2 = Vector2.ZERO
var _weapon_rot: float = 0.0
var _weapon_turn: float = 0.0
var _bits: Array = []
var _rng := RandomNumberGenerator.new()
var _landed: bool = false
var _shake_left: float = 0.0
var _shake_ok: bool = true
var _ash_clock: float = 0.0


## Builds the ragdoll from `source` (which should be hidden afterwards) inside `container`.
## `impulse` is the push in pixels per second (e.g. the knockback of the killing hit).
static func spawn(source: DuckRig, container: Node, impulse: Vector2, inherited_velocity: Vector2,
		life: float) -> DuckRagdoll:
	if source == null or container == null or not source.is_inside_tree():
		return null
	var ragdoll := DuckRagdoll.new()
	ragdoll.name = "DuckRagdoll"
	ragdoll.lifetime = life
	container.add_child(ragdoll)
	ragdoll.global_position = Vector2.ZERO
	if source.is_boss() and DisplayServer.get_name() != "headless":
		ragdoll._build_boss_death(source)
	else:
		ragdoll._build(source, impulse, inherited_velocity)
	return ragdoll


func _exit_tree() -> void:
	if _shake_left > 0.0:
		_shake_left = 0.0
		_set_shake(Vector2.ZERO)


func _process(delta: float) -> void:
	if _boss_death:
		_update_boss_death(delta)
		return
	if lifetime <= 0.0:
		return
	_age += delta
	if _age >= lifetime:
		modulate.a = clampf(1.0 - (_age - lifetime) / FADE_TIME, 0.0, 1.0)
		if _age >= lifetime + FADE_TIME:
			queue_free()


func _build(source: DuckRig, impulse: Vector2, inherited_velocity: Vector2) -> void:
	var xf: Transform2D = source.global_transform
	var facing: float = signf(xf.x.x) if xf.x.x != 0.0 else 1.0
	var scale_y: float = absf(xf.get_scale().y)
	var velocity: Vector2 = inherited_velocity + impulse

	var body := _make_piece(source, DuckRig.Part.BODY, xf, facing, 2.0)
	body.add_child(_circle(source.get_part_radius(DuckRig.Part.BODY) * scale_y))
	body.linear_velocity = velocity
	body.angular_velocity = -facing * signf(impulse.x if impulse.x != 0.0 else 1.0) * 3.0

	var head := _make_piece(source, DuckRig.Part.HEAD, xf, facing, 0.8)
	head.add_child(_circle(source.get_part_radius(DuckRig.Part.HEAD) * scale_y))
	head.linear_velocity = velocity * 1.15 + Vector2(0, -60)
	head.angular_velocity = randf_range(-6.0, 6.0)

	var neck := PinJoint2D.new()
	neck.global_position = xf * source.get_neck_point()
	add_child(neck)
	neck.node_a = neck.get_path_to(body)
	neck.node_b = neck.get_path_to(head)
	neck.angular_limit_enabled = true
	neck.angular_limit_lower = -0.9
	neck.angular_limit_upper = 0.9

	var weapon := _make_piece(source, DuckRig.Part.WEAPON, xf, facing, 0.6)
	var reach: Vector2 = source.get_weapon_vector() * Vector2(facing, 1.0) * scale_y
	var blade := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(reach.length(), 6.0), 5.0 * scale_y)
	blade.shape = rect
	blade.position = reach * 0.5
	blade.rotation = reach.angle()
	weapon.add_child(blade)
	weapon.linear_velocity = velocity * 0.8 + Vector2(0, -220)
	weapon.angular_velocity = randf_range(8.0, 14.0) * (1.0 if randf() > 0.5 else -1.0)


## A rigid body at the piece's spot, carrying a DuckRig that draws only that piece.
func _make_piece(source: DuckRig, piece: DuckRig.Part, xf: Transform2D, facing: float, mass: float) -> RigidBody2D:
	var center: Vector2 = source.get_part_center(piece)
	var rb := RigidBody2D.new()
	rb.collision_layer = 0
	rb.collision_mask = 1
	rb.mass = mass
	var material := PhysicsMaterial.new()
	material.bounce = 0.25
	material.friction = 0.9
	rb.physics_material_override = material
	rb.angular_damp = 1.5
	add_child(rb)
	rb.global_position = xf * center
	# Mirror for facing, then shift the rig so the piece's center sits on the body's origin.
	var holder := Node2D.new()
	holder.scale = Vector2(facing, 1.0) * absf(xf.get_scale().y)
	rb.add_child(holder)
	var rig := DuckRig.new()
	rig.look = source.look
	rig.copy_style_from(source)
	rig.foot_y = source.foot_y
	rig.part = piece
	rig.ragdoll = true
	rig.dead = true
	rig.position = -center
	holder.add_child(rig)
	return rb


func _circle(radius: float) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(radius, 2.0)
	shape.shape = circle
	return shape


# =====================================================================================
# Boss death
# =====================================================================================

func _build_boss_death(source: DuckRig) -> void:
	_boss_death = true
	_rng.randomize()
	var xf: Transform2D = source.global_transform
	_facing = signf(xf.x.x) if xf.x.x != 0.0 else 1.0
	_size = absf(xf.get_scale().y)
	_foot_y = source.foot_y
	_foot = to_local(xf * Vector2(0.0, source.foot_y))
	_shake_ok = GameSettings.is_camera_shake_enabled()
	_pivot = Node2D.new()
	_pivot.name = "Pose"
	_pivot.position = _foot
	_pivot.scale = Vector2(_facing, 1.0) * _size
	add_child(_pivot)
	# Rig space -> pivot space: the rig's feet sit on the pivot's origin.
	var to_pivot := Vector2(0.0, -_foot_y)
	_head_rest = source.get_neck_point() + to_pivot
	_hand_rest = source.get_part_center(DuckRig.Part.WEAPON) + to_pivot
	_pivot.add_child(_piece(source, DuckRig.Part.BODY, to_pivot))
	_head_pivot = Node2D.new()
	_head_pivot.position = _head_rest
	_pivot.add_child(_head_pivot)
	_head_pivot.add_child(_piece(source, DuckRig.Part.HEAD, to_pivot - _head_rest))
	# The weapon is not a child of the pose: once dropped it stays on the ground.
	_weapon_pivot = Node2D.new()
	add_child(_weapon_pivot)
	_weapon_pivot.add_child(_piece(source, DuckRig.Part.WEAPON, to_pivot - _hand_rest))
	var aim: float = source.get_weapon_vector().angle()
	var flat_angle: float = 0.0 if cos(aim) >= 0.0 else PI
	_weapon_turn = wrapf(flat_angle - aim, -PI, PI)
	_front = Node2D.new()
	_front.name = "Ash"
	add_child(_front)
	_front.draw.connect(_draw_front)


## A whole-duck rig that draws only `piece`, standing (not limp), placed at `offset`.
func _piece(source: DuckRig, piece: DuckRig.Part, offset: Vector2) -> DuckRig:
	var rig := DuckRig.new()
	rig.look = source.look
	rig.copy_style_from(source)
	rig.foot_y = source.foot_y
	rig.part = piece
	rig.position = offset
	_rigs.append(rig)
	return rig


func _update_boss_death(delta: float) -> void:
	_age += delta
	var t: float = _age
	# a. Staggers back, shuddering (0 - 0.6).
	var back: float = _ease_out(clampf(t / 0.6, 0.0, 1.0))
	var shudder: float = sin(t * 47.0) * 0.035 * (1.0 - smoothstep(0.4, 0.7, t))
	var rot: float = -0.26 * back + shudder
	var slide: float = -9.0 * back
	var squash: float = 1.0
	var head: float = -0.15 * back
	# b. Sinks to its knees, head hanging, and stays still for a moment (0.6 - 1.4).
	var kneel: float = _ease_in_out(clampf((t - 0.6) / 0.6, 0.0, 1.0))
	rot = lerpf(rot, 0.2, kneel)
	squash = lerpf(1.0, 0.7, kneel)
	head = lerpf(head, 0.6, kneel)
	var lift: float = 0.0
	# c. Falls flat on its face, hard (1.4 - 1.7), with a small bounce on landing.
	var fall: float = clampf((t - 1.4) / 0.3, 0.0, 1.0)
	fall *= fall
	if t >= 1.4:
		rot = lerpf(0.2, 1.36, fall)
		head = lerpf(0.6, 0.25, fall)
		lift = 20.0 * fall
		if t > 1.7:
			rot -= sin(clampf((t - 1.7) / 0.18, 0.0, 1.0) * PI) * 0.06
	_pivot.position = _foot + Vector2(slide * _facing * _size, -lift * _size)
	_pivot.rotation = rot * _facing
	_pivot.scale = Vector2(_facing, squash) * _size
	_head_pivot.rotation = head
	# The weapon slips out of the hand while it kneels and lies flat on the ground.
	if t < 0.55:
		_weapon_rot = _pivot.rotation
		_weapon_at = _pivot.transform * _hand_rest
		_weapon_pivot.position = _weapon_at
		_weapon_pivot.rotation = _weapon_rot
		_weapon_pivot.scale = _pivot.scale
	else:
		var drop: float = _ease_in(clampf((t - 0.55) / 0.45, 0.0, 1.0))
		var ground: Vector2 = _foot + Vector2((_hand_rest.x + 16.0) * _facing, -4.0) * _size
		_weapon_pivot.position = _weapon_at.lerp(ground, drop)
		_weapon_pivot.rotation = lerp_angle(_weapon_rot, _weapon_turn * _facing, drop)
		_weapon_pivot.scale = Vector2(_facing, 1.0) * _size
	_weapon_pivot.modulate = _pivot.modulate
	if t >= 1.7 and not _landed:
		_land()
	# d. Crumbles into ash and small souls (1.7 - 3).
	var crumble: float = smoothstep(1.8, 2.85, t)
	_pivot.modulate = Color(1.0 - 0.75 * crumble, 1.0 - 0.8 * crumble, 1.0 - 0.7 * crumble, 1.0 - crumble)
	if t >= 1.75 and t < 2.8:
		_ash_clock -= delta
		while _ash_clock <= 0.0:
			_ash_clock += 0.012
			_spawn_ash()
	_update_bits(delta)
	if _shake_left > 0.0:
		_shake_left -= delta
		var k: float = maxf(_shake_left / 0.28, 0.0)
		_set_shake(Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 9.0 * k if _shake_left > 0.0 else Vector2.ZERO)
	queue_redraw()
	_front.queue_redraw()
	if t >= BOSS_DEATH_TIME:
		if _shake_left > 0.0:
			_shake_left = 0.0
			_set_shake(Vector2.ZERO)
		queue_free()


func _land() -> void:
	_landed = true
	var nose: Vector2 = _pivot.transform * (_head_rest + Vector2(14.0, -8.0))
	for i in 26:
		var dir: float = -1.0 if i % 2 == 0 else 1.0
		_bits.append({"kind": 0, "p": nose + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-4.0, 6.0)) * _size,
				"v": Vector2(dir * _rng.randf_range(40.0, 170.0), -_rng.randf_range(20.0, 110.0)) * _size,
				"life": 0.0, "max": _rng.randf_range(0.5, 0.9), "r": _rng.randf_range(6.0, 13.0) * _size})
	if _shake_ok:
		_shake_left = 0.28


## Ash flakes rise from all over the lying body; now and then a small soul leaves it.
func _spawn_ash() -> void:
	var local := Vector2(_rng.randf_range(-28.0, 28.0), _rng.randf_range(-78.0, -6.0))
	var at: Vector2 = _pivot.transform * local
	_bits.append({"kind": 1, "p": at, "v": Vector2(_rng.randf_range(-30.0, 30.0), -_rng.randf_range(30.0, 90.0)) * _size,
			"life": 0.0, "max": _rng.randf_range(0.6, 1.1), "r": _rng.randf_range(1.6, 3.6) * _size, "spin": _rng.randf() * TAU})
	if _rng.randf() < 0.06:
		_bits.append({"kind": 2, "p": at, "v": Vector2(0.0, -_rng.randf_range(55.0, 85.0)) * _size,
				"life": 0.0, "max": _rng.randf_range(1.0, 1.3), "r": _rng.randf_range(6.0, 9.0) * _size,
				"spin": _rng.randf() * TAU, "trail": PackedVector2Array()})


func _update_bits(delta: float) -> void:
	for i in range(_bits.size() - 1, -1, -1):
		var bit: Dictionary = _bits[i]
		bit["life"] = float(bit["life"]) + delta
		if float(bit["life"]) >= float(bit["max"]):
			_bits.remove_at(i)
			continue
		var v: Vector2 = bit["v"]
		match int(bit["kind"]):
			0:
				v *= 1.0 - minf(delta * 4.0, 1.0)
				v.y -= 20.0 * delta
			1:
				v.x += sin(_age * 5.0 + float(bit["spin"])) * 40.0 * delta
			2:
				v.x = sin(_age * 4.0 + float(bit["spin"])) * 40.0 * _size
				var trail: PackedVector2Array = bit["trail"]
				trail.append(bit["p"])
				if trail.size() > 10:
					trail.remove_at(0)
				bit["trail"] = trail
		bit["v"] = v
		bit["p"] = (bit["p"] as Vector2) + v * delta


func _set_shake(offset: Vector2) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam != null:
		cam.offset = offset


func _draw() -> void:
	if not _boss_death:
		return
	var t: float = _age
	# Shadow under the body, stretched once it lies down.
	var flat: float = smoothstep(1.4, 1.7, t)
	var fade: float = 1.0 - smoothstep(1.9, 2.9, t)
	draw_set_transform(_foot, 0.0, Vector2(1.0 + flat * 1.2, 1.0))
	draw_colored_polygon(_ellipse(Vector2(flat * 22.0 * _facing * _size, 0.0), 30.0 * _size, 6.0 * _size), Color(0.05, 0.04, 0.06, 0.5 * fade))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# The dark aura flickers out while it staggers.
	var aura: float = 1.0 - smoothstep(0.0, 0.65, t)
	if aura > 0.0:
		var flick: float = 1.0 if sin(t * 55.0) > -0.2 else 0.25
		var c: Vector2 = _pivot.transform * Vector2(-2.0, -40.0)
		for k in 6:
			var r: float = (42.0 + float(k) * 9.0 + sin(t * 9.0 + float(k)) * 3.0) * _size
			draw_colored_polygon(_ellipse(c, r * 0.8, r, 24), Color(AURA, 0.09 * aura * flick))


func _draw_front() -> void:
	for bit in _bits:
		var u: float = float(bit["life"]) / float(bit["max"])
		var p: Vector2 = bit["p"]
		var r: float = bit["r"]
		match int(bit["kind"]):
			0:
				_front.draw_circle(p, r * (0.6 + u), Color(DUST, 0.55 * (1.0 - u)))
			1:
				var a: float = float(bit["spin"]) + u * 6.0
				var pts := PackedVector2Array([p + Vector2(r, 0).rotated(a), p + Vector2(0, r * 0.6).rotated(a),
						p + Vector2(-r, 0).rotated(a), p + Vector2(0, -r * 0.6).rotated(a)])
				_front.draw_colored_polygon(pts, Color(ASH.lerp(Color(0.35, 0.2, 0.4), u), 0.9 * (1.0 - u * u)))
			2:
				_draw_soul(_front, p, r, (1.0 - u) * smoothstep(0.0, 0.15, u), bit["trail"])


## A small see-through duck ghost with a tail of smoke.
static func _draw_soul(canvas: CanvasItem, p: Vector2, r: float, alpha: float, trail: PackedVector2Array) -> void:
	if alpha <= 0.01:
		return
	for i in trail.size():
		var k: float = float(i) / float(maxi(trail.size(), 1))
		canvas.draw_circle(trail[i] + Vector2(0, r * 0.5), r * 0.5 * k, Color(SOUL, 0.18 * alpha * k))
	canvas.draw_circle(p, r * 0.75, Color(SOUL, 0.45 * alpha))
	canvas.draw_circle(p + Vector2(r * 0.45, -r * 0.65), r * 0.45, Color(SOUL, 0.5 * alpha))
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.8, -r * 0.7), p + Vector2(r * 1.25, -r * 0.55), p + Vector2(r * 0.8, -r * 0.45)]), Color(SOUL, 0.5 * alpha))
	canvas.draw_circle(p + Vector2(r * 0.55, -r * 0.75), maxf(r * 0.09, 0.8), Color(0.1, 0.05, 0.15, 0.6 * alpha))


func _ellipse(c: Vector2, rx: float, ry: float, steps: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_in(x: float) -> float:
	return x * x


static func _ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

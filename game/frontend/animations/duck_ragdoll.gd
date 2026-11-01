class_name DuckRagdoll
extends Node2D
## Death ragdoll for a DuckRig: the body, the head (pinned at the neck, floppy) and the weapon
## (loose) become rigid bodies that tumble with the killing blow and collide with the world only.
## Visual only: spawned beside the dead character, never touches gameplay.
## `lifetime` > 0 frees it after that many seconds (with a fade); 0 keeps it until freed.

const FADE_TIME: float = 0.6

var lifetime: float = 0.0
var _age: float = 0.0


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
	ragdoll._build(source, impulse, inherited_velocity)
	return ragdoll


func _process(delta: float) -> void:
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

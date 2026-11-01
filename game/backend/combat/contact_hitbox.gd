class_name ContactHitbox
extends Hitbox
## Body-contact damage for enemies and bosses: a Hitbox of the ENEMY team that follows the owner's
## body. Its shape is a UNIQUE, slightly inset copy of the body shape (never shared between
## instances). The owner switches it on and off through `set_contact_active`; damage, knockback
## and re-hit interval come from the owner's stats resource.


## Copies `body_shape` (inset on every side) into this hitbox's CollisionShape2D and applies the
## stats. `damage <= 0` leaves the hitbox permanently disabled.
func configure(body: Node2D, body_shape: Shape2D, inset: float, contact_damage: int, contact_knockback: Vector2, contact_rehit: float) -> void:
	owner_body = body
	damage = contact_damage
	knockback = contact_knockback
	rehit_interval = contact_rehit
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and body_shape != null:
		shape_node.shape = _inset_copy(body_shape, inset)
		shape_node.position = Vector2.ZERO


## Active only when requested and when it can deal damage at all. Calls activate/deactivate only on
## a change, so the re-hit memory of the Hitbox is not reset every frame.
func set_contact_active(wanted: bool) -> void:
	var should_be_active: bool = wanted and damage > 0
	if should_be_active and not is_active:
		activate()
	elif not should_be_active and is_active:
		deactivate()


static func _inset_copy(shape: Shape2D, inset: float) -> Shape2D:
	var copy: Shape2D = shape.duplicate() as Shape2D
	if copy is RectangleShape2D:
		var rect := copy as RectangleShape2D
		rect.size = Vector2(maxf(rect.size.x - inset * 2.0, 2.0), maxf(rect.size.y - inset * 2.0, 2.0))
	elif copy is CircleShape2D:
		var circle := copy as CircleShape2D
		circle.radius = maxf(circle.radius - inset, 1.0)
	elif copy is CapsuleShape2D:
		var capsule := copy as CapsuleShape2D
		capsule.radius = maxf(capsule.radius - inset, 1.0)
		capsule.height = maxf(capsule.height - inset * 2.0, capsule.radius * 2.0)
	return copy

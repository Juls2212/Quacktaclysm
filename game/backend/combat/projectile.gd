class_name Projectile
extends Area2D
## Straight-flying (optionally falling) projectile. Damage is dealt by the child Hitbox,
## so each target is hit at most once and only the opposite team is affected.

signal despawned(reason: StringName)

const REASON_HIT: StringName = &"hit"
const REASON_WORLD: StringName = &"world"
const REASON_LIFETIME: StringName = &"lifetime"

var stats: ProjectileStats
var source: Node = null
var velocity: Vector2 = Vector2.ZERO

var _lifetime_left: float = 0.0
var _launched: bool = false
var _despawned: bool = false
var _hits: int = 0

@onready var hitbox: Hitbox = $Hitbox
@onready var visual: Node2D = get_node_or_null("Visual") as Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	# monitorable stays true: with it off, this area stopped reporting static bodies.
	body_entered.connect(_on_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)
	set_physics_process(false)


## Call after adding the projectile to the scene tree.
func launch(direction: Vector2, team: CombatLayers.Team, projectile_stats: ProjectileStats, shooter: Node) -> void:
	stats = projectile_stats
	source = shooter
	velocity = direction.normalized() * stats.speed
	_lifetime_left = stats.lifetime
	hitbox.set_team(team)
	hitbox.damage = stats.damage
	hitbox.knockback = stats.knockback
	hitbox.knockback_direction_override = 0 if is_zero_approx(direction.x) else (1 if direction.x > 0.0 else -1)
	_apply_size_and_tint()
	hitbox.activate()
	_launched = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * stats.gravity_scale * delta
	global_position += velocity * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_despawn(REASON_LIFETIME)


func _on_body_entered(_body: Node2D) -> void:
	if _launched and stats.destroy_on_world:
		_despawn(REASON_WORLD)


## The hitbox handles the damage first (it connected earlier); this only despawns. Without
## piercing the first overlap despawns it (as always); with piercing see _on_hitbox_hit_landed.
func _on_hitbox_area_entered(_area: Area2D) -> void:
	if _launched and stats.destroy_on_hit and stats.pierce_count <= 0:
		_despawn(REASON_HIT)


## Piercing: every landed hit counts; it despawns once the hits exceed `pierce_count`.
func _on_hitbox_hit_landed(_hurtbox: Hurtbox, _info: DamageInfo) -> void:
	_hits += 1
	if _launched and stats.destroy_on_hit and stats.pierce_count > 0 and _hits > stats.pierce_count:
		_despawn(REASON_HIT)


## Applied once from launch(). Shapes are duplicated first so the shared scene resources (and other
## projectiles) are never modified. Default stats (scale 1, no tint) change nothing.
func _apply_size_and_tint() -> void:
	if not is_equal_approx(stats.size_scale, 1.0):
		for holder: Node in [self, hitbox]:
			for child in holder.get_children():
				var shape_node := child as CollisionShape2D
				if shape_node != null and shape_node.shape != null:
					shape_node.shape = _scaled_shape(shape_node.shape, stats.size_scale)
					shape_node.position *= stats.size_scale
		if visual != null:
			visual.scale *= stats.size_scale
	if stats.tint.a > 0.0 and visual != null:
		if visual is Polygon2D:
			(visual as Polygon2D).color = stats.tint
		else:
			visual.self_modulate = stats.tint


static func _scaled_shape(shape: Shape2D, factor: float) -> Shape2D:
	var copy: Shape2D = shape.duplicate() as Shape2D
	if copy is CircleShape2D:
		(copy as CircleShape2D).radius *= factor
	elif copy is RectangleShape2D:
		(copy as RectangleShape2D).size *= factor
	elif copy is CapsuleShape2D:
		(copy as CapsuleShape2D).radius *= factor
		(copy as CapsuleShape2D).height *= factor
	return copy


func _despawn(reason: StringName) -> void:
	if _despawned:
		return
	_despawned = true
	hitbox.deactivate()
	set_physics_process(false)
	despawned.emit(reason)
	queue_free()

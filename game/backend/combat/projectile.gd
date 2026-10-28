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

@onready var hitbox: Hitbox = $Hitbox


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	# monitorable stays true: with it off, this area stopped reporting static bodies.
	body_entered.connect(_on_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
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


## The hitbox handles the damage first (it connected earlier); this only despawns.
func _on_hitbox_area_entered(_area: Area2D) -> void:
	if _launched and stats.destroy_on_hit:
		_despawn(REASON_HIT)


func _despawn(reason: StringName) -> void:
	if _despawned:
		return
	_despawned = true
	hitbox.deactivate()
	set_physics_process(false)
	despawned.emit(reason)
	queue_free()

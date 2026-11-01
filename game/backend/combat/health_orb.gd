class_name HealthOrb
extends RigidBody2D
## Health orb: pops out of a defeated enemy or boss, bounces on the floor, flies to a hurt
## player who comes near and heals them on touch. Values come from `stats`.
## Collides with the world only; the child `Magnet` area finds the player and `Pickup` collects.

signal collected(player: Player, amount: int)

const INK := Color(0.106, 0.098, 0.122)
const CORE := Color(0.93, 0.27, 0.33)
const SHINE := Color(1.0, 0.86, 0.86)

@export var stats: HealthOrbStats
## Drawn radius of the orb in pixels (visual only; the shapes live in the scene).
@export var radius: float = 7.0

var _age: float = 0.0
var _pulled: bool = false
var _pull_velocity: Vector2 = Vector2.ZERO
var _done: bool = false
var _target: Player = null

@onready var pickup: Area2D = $Pickup
@onready var magnet: Area2D = $Magnet
@onready var magnet_shape: CollisionShape2D = $Magnet/CollisionShape2D


func _ready() -> void:
	if stats == null:
		stats = HealthOrbStats.new()
	pickup.body_entered.connect(_on_body_entered)
	# Unique circle per orb sized from the stats, so the shared scene resource never changes.
	var circle := CircleShape2D.new()
	circle.radius = stats.magnet_radius
	magnet_shape.shape = circle


## Sends the orb flying from a burst: `direction` is a unit vector, `speed` in px/s.
func launch(direction: Vector2, speed: float) -> void:
	linear_velocity = direction * speed
	angular_velocity = randf_range(-6.0, 6.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if stats.lifetime > 0.0 and _age >= stats.lifetime:
		queue_free()
		return
	if _done or _age < stats.pickup_delay:
		return
	var player: Player = _closest_player()
	if player == null:
		_release()
		return
	var to_player: Vector2 = player.global_position - global_position
	if not _pulled and to_player.length() > stats.magnet_radius * 1.05:
		return
	_pulled = true
	freeze = true
	_pull_velocity = _pull_velocity.move_toward(to_player.normalized() * stats.magnet_speed, stats.magnet_acceleration * delta)
	global_position += _pull_velocity * delta
	# Overlap checks lag behind a frozen body moved by hand, so collect on proximity too.
	if to_player.length() < radius + 18.0:
		_collect(player)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var blink_from: float = stats.lifetime - stats.blink_time if stats != null and stats.lifetime > 0.0 else INF
	if _age > blink_from and fmod(_age * 8.0, 1.0) < 0.35:
		return
	var bob: float = sin(_age * 5.0) * 0.12
	var r: float = radius * (1.0 + bob * 0.3)
	# Counter the body's spin so the heart and highlight stay upright.
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_circle(Vector2.ZERO, r + 4.0, Color(CORE, 0.22))
	draw_circle(Vector2.ZERO, r + 1.3, INK)
	draw_circle(Vector2.ZERO, r, CORE)
	var s: float = r * 0.5
	var heart := PackedVector2Array([Vector2(0, s * 0.9), Vector2(-s, -s * 0.1), Vector2(-s * 0.9, -s * 0.7),
			Vector2(-s * 0.4, -s * 0.85), Vector2(0, -s * 0.45), Vector2(s * 0.4, -s * 0.85),
			Vector2(s * 0.9, -s * 0.7), Vector2(s, -s * 0.1)])
	draw_colored_polygon(heart, SHINE)
	draw_circle(Vector2(-r * 0.45, -r * 0.5), r * 0.18, Color(1, 1, 1, 0.9))


func _on_body_entered(body: Node) -> void:
	if body is Player and _age >= stats.pickup_delay:
		_collect(body as Player)


func _collect(player: Player) -> void:
	if _done or not _wants_health(player):
		return
	_done = true
	player.health.heal(stats.heal_amount)
	collected.emit(player, stats.heal_amount)
	queue_free()


## The player being pulled, else the nearest one inside the magnet area that can use this orb.
func _closest_player() -> Player:
	if _pulled and is_instance_valid(_target) and _wants_health(_target):
		return _target
	_target = null
	var best_distance: float = INF
	for body in magnet.get_overlapping_bodies():
		var player := body as Player
		if player == null or not _wants_health(player):
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			_target = player
			best_distance = distance
	return _target


func _wants_health(player: Player) -> bool:
	if player.is_dead or player.health.is_dead:
		return false
	return not stats.only_when_hurt or player.health.current_health < player.health.max_health


## Back to normal physics when nobody is pulling (e.g. the player healed up meanwhile).
func _release() -> void:
	if _pulled:
		_pulled = false
		_pull_velocity = Vector2.ZERO
		freeze = false

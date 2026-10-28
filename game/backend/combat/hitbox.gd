class_name Hitbox
extends Area2D
## Deals damage to hurtboxes of the opposing team while active.

signal hit_landed(hurtbox: Hurtbox, info: DamageInfo)

## Team that OWNS this attack. It only hits the opposing team.
@export var team: CombatLayers.Team = CombatLayers.Team.PLAYER
@export var damage: int = 1
## x: magnitude pushed away from the hitbox owner. y: vertical impulse (negative is up).
@export var knockback: Vector2 = Vector2.ZERO
## 0: each hurtbox is hit once per activation. >0: it can be hit again after this many seconds.
@export var rehit_interval: float = 0.0
## Used to resolve knockback direction. Falls back to this hitbox's own position.
@export var owner_body: Node2D
@export var active_on_ready: bool = false
## 0 resolves the knockback side from positions. 1 or -1 forces it (e.g. projectiles).
@export_range(-1, 1, 1) var knockback_direction_override: int = 0

var is_active: bool = false

var _clock: float = 0.0
## Hurtbox -> clock time of its last hit during this activation.
var _hit_times: Dictionary = {}


func _ready() -> void:
	collision_layer = CombatLayers.hitbox_layer(team)
	collision_mask = CombatLayers.hitbox_mask(team)
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)
	if active_on_ready:
		activate()


func _physics_process(delta: float) -> void:
	_clock += delta
	# `monitoring` is switched deferred, so it can lag behind `is_active` by a frame.
	if not is_active or not monitoring:
		return
	for area in get_overlapping_areas():
		_try_hit(area)


## Changes the owning team (and the layer/mask derived from it) after _ready.
func set_team(new_team: CombatLayers.Team) -> void:
	team = new_team
	collision_layer = CombatLayers.hitbox_layer(team)
	collision_mask = CombatLayers.hitbox_mask(team)


func activate() -> void:
	_hit_times.clear()
	is_active = true
	set_deferred("monitoring", true)


func deactivate() -> void:
	is_active = false
	set_deferred("monitoring", false)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(area: Area2D) -> void:
	if not is_active:
		return
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox.team == team:
		return
	if _hit_times.has(hurtbox):
		if rehit_interval <= 0.0 or _clock - float(_hit_times[hurtbox]) < rehit_interval:
			return
	var info := DamageInfo.create(damage, _resolve_knockback(hurtbox), owner_body if owner_body else self, team)
	var applied: bool = hurtbox.receive_hit(info)
	# With a rehit interval, a blocked hit (i-frames) is retried on the next frame.
	if applied or rehit_interval <= 0.0:
		_hit_times[hurtbox] = _clock
	if applied:
		hit_landed.emit(hurtbox, info)


func _resolve_knockback(hurtbox: Hurtbox) -> Vector2:
	var origin: Vector2 = owner_body.global_position if owner_body else global_position
	var direction: float = 1.0 if hurtbox.global_position.x >= origin.x else -1.0
	if knockback_direction_override != 0:
		direction = float(knockback_direction_override)
	return Vector2(knockback.x * direction, knockback.y)

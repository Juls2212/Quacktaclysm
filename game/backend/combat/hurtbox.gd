class_name Hurtbox
extends Area2D
## Receives hits for its owner. Forwards them to a HealthComponent.
## If the owner (or `invulnerability_provider`) has `is_invulnerable() -> bool`,
## hits are ignored while it returns true.

signal hit_received(info: DamageInfo, applied: bool)

## Team that OWNS this hurtbox.
@export var team: CombatLayers.Team = CombatLayers.Team.PLAYER
@export var health: HealthComponent
## Optional node with `is_invulnerable()`. Falls back to the scene owner.
@export var invulnerability_provider: Node

var enabled: bool = true


func _ready() -> void:
	collision_layer = CombatLayers.hurtbox_layer(team)
	collision_mask = 0
	monitoring = false
	monitorable = true
	if health == null and owner != null:
		for child in owner.get_children():
			if child is HealthComponent:
				health = child
				break
	if invulnerability_provider == null:
		invulnerability_provider = owner


func set_enabled(value: bool) -> void:
	enabled = value
	set_deferred("monitorable", value)


## Returns true if the hit damaged the owner.
func receive_hit(info: DamageInfo) -> bool:
	if not enabled or health == null or info.team == team:
		return false
	var applied: bool = false
	if not _provider_is_invulnerable():
		applied = health.apply_damage(info)
	hit_received.emit(info, applied)
	return applied


func _provider_is_invulnerable() -> bool:
	return invulnerability_provider != null \
			and invulnerability_provider.has_method("is_invulnerable") \
			and invulnerability_provider.is_invulnerable()

class_name DamageInfo
extends RefCounted
## Describes one hit. `knockback` is already resolved (signed) for the target.

var amount: int = 0
var knockback: Vector2 = Vector2.ZERO
var source: Node = null
var team: CombatLayers.Team = CombatLayers.Team.ENEMY
## What attacked (Phase 15e-1): &"light", &"heavy", &"dash_slash" or &"wave" for the player's attacks, empty otherwise.
## A guard (BossShield) reads it to block or to break.
var attack_kind: StringName = &""


static func create(
		p_amount: int,
		p_knockback: Vector2 = Vector2.ZERO,
		p_source: Node = null,
		p_team: CombatLayers.Team = CombatLayers.Team.ENEMY,
		p_kind: StringName = &"") -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.knockback = p_knockback
	info.source = p_source
	info.team = p_team
	info.attack_kind = p_kind
	return info

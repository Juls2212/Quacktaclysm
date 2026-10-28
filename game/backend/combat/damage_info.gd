class_name DamageInfo
extends RefCounted
## Describes one hit. `knockback` is already resolved (signed) for the target.

var amount: int = 0
var knockback: Vector2 = Vector2.ZERO
var source: Node = null
var team: CombatLayers.Team = CombatLayers.Team.ENEMY


static func create(
		p_amount: int,
		p_knockback: Vector2 = Vector2.ZERO,
		p_source: Node = null,
		p_team: CombatLayers.Team = CombatLayers.Team.ENEMY) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.knockback = p_knockback
	info.source = p_source
	info.team = p_team
	return info

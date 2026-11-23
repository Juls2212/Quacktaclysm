class_name BossShield
extends Node
## The SHIELD of the summoner stage of boss 3 (Phase 15j). Since Phase 15o it is only that: the old armor shell of Phase 15e/15f (blocking, stagger,
## regeneration) is gone and the boss takes damage normally in every phase. While `shield_up` is true EVERY player hit is blocked (no damage, a spark
## and the clash sound: the hurtbox reports the hit as not applied). The boss stage raises and drops it; it never rises by itself.
## Child of the boss; the boss hurtbox points at it with `hit_filter`. Gameplay only: ShieldFx draws the bubble.

signal deflected(info: DamageInfo)

var shield_up: bool = false

var _boss: BossBase = null


func _ready() -> void:
	_boss = get_parent() as BossBase
	if _boss == null:
		return
	_boss.phase_changed.connect(_on_phase_changed)
	_boss.encounter_reset.connect(_reset)
	_boss.defeated.connect(func(_b: BossBase) -> void: shield_up = false)
	_boss.activated.connect(_reset)


## The shield is the only thing that blocks (used by the boss health bar for the one-time hint).
var last_block_was_shield: bool = true


## Hurtbox hook: true = the hit is blocked.
func filter_hit(info: DamageInfo) -> bool:
	if info.team != CombatLayers.Team.PLAYER or not shield_up:
		return false
	deflected.emit(info)
	return true


func is_shield_up() -> bool:
	return shield_up


## The stage raises and drops the shield.
func set_shield(up: bool) -> void:
	shield_up = up


func _on_phase_changed(_phase: int) -> void:
	shield_up = false


func _reset() -> void:
	shield_up = false

class_name SoulComponent
extends Node
## The player's Soul meter. Child of the Player (node "Soul"). It is gained by hitting enemies and bosses
## (sword moves and the sword wave, each with its own amount) and by absorbing soul wisps (SoulPickup);
## the heal action spends it. The heal cost is DERIVED from GameState.souls_kept every time it is asked
## for. Runtime state only: it starts at 0 whenever a level loads and goes back to 0 when the player dies
## and respawns; nothing is saved. Emits signals for the HUD and the audio (no polling anywhere).

signal soul_changed(current: int, maximum: int)
## Emitted with the amount that actually went in (never more than the room left).
signal soul_gained(amount: int)
signal soul_full
## The heal action was pressed but could not start: reason is &"full_health" or &"not_enough_soul".
signal heal_denied(reason: StringName)

@export var config: SoulConfig

var soul: int = 0
## Totals since the level loaded (the balance measurement reads them).
var gained_total: int = 0
var wasted_total: int = 0

var _player: Player = null


func _ready() -> void:
	if config == null:
		config = SoulConfig.get_default()
	_player = get_parent() as Player
	if _player == null:
		return
	var sword_hitbox := _player.get_node_or_null(^"AttackPivot/Hitbox") as Hitbox
	if sword_hitbox != null:
		sword_hitbox.hit_landed.connect(_on_sword_hit)
	var caster := _player.get_node_or_null(^"SwordWaveCaster") as SwordWaveCaster
	if caster != null:
		caster.wave_hit.connect(_on_wave_hit)


func get_max() -> int:
	return config.max_soul


## Heal cost right now: base + per-kept increment, from the fragments kept so far.
func heal_cost() -> int:
	return config.heal_cost(GameState.souls_kept)


func can_afford() -> bool:
	return soul >= heal_cost()


## Adds soul (clamped to the maximum). Returns how much went in; the rest is counted as wasted.
func add_soul(amount: int) -> int:
	if amount <= 0:
		return 0
	var room: int = config.max_soul - soul
	var gained: int = mini(amount, room)
	wasted_total += amount - gained
	if gained <= 0:
		return 0
	soul += gained
	gained_total += gained
	soul_changed.emit(soul, config.max_soul)
	soul_gained.emit(gained)
	if soul >= config.max_soul:
		soul_full.emit()
	return gained


## Spends `amount`; false (and nothing changes) if there is not enough.
func spend(amount: int) -> bool:
	if amount < 0 or soul < amount:
		return false
	soul -= amount
	soul_changed.emit(soul, config.max_soul)
	return true


func reset() -> void:
	soul = 0
	soul_changed.emit(soul, config.max_soul)


func deny(reason: StringName) -> void:
	heal_denied.emit(reason)


func _on_sword_hit(hurtbox: Hurtbox, _info: DamageInfo) -> void:
	add_soul(_override_for(hurtbox, config.gain_for_sword(_player.current_sword_kind)))


func _on_wave_hit(hurtbox: Hurtbox, _info: DamageInfo) -> void:
	add_soul(_override_for(hurtbox, config.gain_wave))


## What a hit is worth: an enemy with `soul_gain_override()` (a duckling) fixes the value itself, so a summoned crowd cannot fill the meter.
func _override_for(hurtbox: Hurtbox, normal: int) -> int:
	var owner_node: Node = hurtbox.get_parent() if hurtbox != null else null
	if owner_node != null and owner_node.has_method(&"soul_gain_override"):
		return int(owner_node.call(&"soul_gain_override"))
	return normal

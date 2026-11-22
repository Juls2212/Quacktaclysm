class_name AbilityIntro
extends Node
## Shows the "Nueva habilidad" card when the player KEEPS a fragment and the sword wave gets stronger: it
## names the new wave level and the new heal cost. Child of every level (level_base.tscn). It reads the
## decision from DecisionFlow.decision_made (no polling) and works out the event from the decision itself,
## so nothing is saved. Phase 15b: the work goes through the level's PresentationQueue (decision -> corruption
## animation, if one plays -> card), so the card can never open over the animation: it waits for the
## cutscene's `finished` signal (with the queue's safety timeout). Automated (headless) runs skip the card
## unless `play_when_headless`.

## The fragment whose decision (released or kept) unlocks the double jump: boss 2's.
const DOUBLE_JUMP_FRAGMENT: String = "fragment_level_2"

signal card_shown(card: AbilityCard)

@export var play_when_headless: bool = false

## The last card this node showed (the tests read it).
var card: AbilityCard = null

var _level: Node = null
var _decision_flow: DecisionFlow = null
var _wave_tier: int = 0


func _ready() -> void:
	_level = get_parent()
	_decision_flow = _level.get_node_or_null(^"DecisionFlow") as DecisionFlow
	var caster := _level.get_node_or_null(^"Player/SwordWaveCaster") as SwordWaveCaster
	_wave_tier = caster.get_effective_tier() if caster != null else 0
	if _decision_flow != null:
		_decision_flow.decision_made.connect(_on_decision_made)


func _on_decision_made(fragment_id: String, choice: String) -> void:
	var caster := _level.get_node_or_null(^"Player/SwordWaveCaster") as SwordWaveCaster
	var tier: int = caster.get_effective_tier() if caster != null else 0
	var improved: bool = choice == GameState.CHOICE_KEPT and tier > _wave_tier
	_wave_tier = tier
	var unlocks_double_jump: bool = fragment_id == DOUBLE_JUMP_FRAGMENT
	if not improved and not unlocks_double_jump:
		return
	if DisplayServer.get_name() == "headless" and not play_when_headless:
		return
	var queue: PresentationQueue = get_queue()
	# 1. The corruption animation, if keeping the fragment plays one (whoever spawns it has run by the time the
	#    queue starts, and a release has none, so this step ends at once).
	queue.enqueue("corruption_%s" % fragment_id, _wait_for_corruption)
	# 2. The improved sword wave (kept).
	if improved:
		queue.enqueue("card_wave_%s" % fragment_id, _show.bind(fragment_id, tier))
	# 3. The double jump (boss 2's decision, released or kept).
	if unlocks_double_jump:
		queue.enqueue("card_double_jump", _show_double_jump)


## The level's queue (created here if a level scene has none).
func get_queue() -> PresentationQueue:
	var queue := _level.get_node_or_null(^"PresentationQueue") as PresentationQueue
	if queue == null:
		queue = PresentationQueue.new()
		queue.name = "PresentationQueue"
		_level.add_child(queue)
	return queue


## Queue step: returns the cutscene's `finished` signal while it plays (null signal if none).
func _wait_for_corruption() -> Variant:
	var exorcism: Node = _find_exorcism()
	if exorcism != null and exorcism.has_signal(&"finished"):
		return Signal(exorcism, &"finished")
	return Signal()


## Queue step: shows the card and returns its `dismissed` signal.
func _show(fragment_id: String, tier: int) -> Variant:
	if not is_inside_tree():
		return Signal()
	var texts := AbilityTexts.get_default()
	var player := _level.get_node_or_null(^"Player") as Player
	var cost: int = player.soul.heal_cost() if player != null and player.soul != null else SoulConfig.get_default().heal_cost(GameState.souls_kept)
	var description: String = texts.wave_description_format % [tier, cost]
	var wave_caster := _level.get_node_or_null(^"Player/SwordWaveCaster") as SwordWaveCaster
	if wave_caster != null and wave_caster.config != null:
		description += "\n" + wave_damage_text(wave_caster.config, tier)
	# The card shows the color of the wave the player just reached.
	var caster := _level.get_node_or_null(^"Player/SwordWaveCaster") as SwordWaveCaster
	var swatch: SwordWaveTier = caster.config.get_tier(tier) if caster != null and caster.config != null else null
	card = AbilityCard.present(self, "wave_%s" % fragment_id, texts.wave_name_format % tier, description, PackedStringArray(["wave", "heal"]), swatch)
	if card != null:
		card_shown.emit(card)
		return Signal(card, &"dismissed")
	return Signal()


## Queue step: the "Nueva habilidad: Doble salto" card (it names the Jump key read live from the InputMap).
func _show_double_jump() -> Variant:
	if not is_inside_tree():
		return Signal()
	var texts := AbilityTexts.get_default()
	card = AbilityCard.present(self, "double_jump", texts.double_jump_name, texts.double_jump_description, PackedStringArray(["jump"]))
	if card != null:
		card_shown.emit(card)
		return Signal(card, &"dismissed")
	return Signal()


## The damage line of a wave tier, computed from the resource: the multiplier over tier 0 and the damage per hit.
static func wave_damage_text(config: SwordWaveConfig, tier: int) -> String:
	var base: SwordWaveTier = config.get_tier(0)
	var current: SwordWaveTier = config.get_tier(tier)
	if base == null or current == null:
		return ""
	return AbilityTexts.get_default().wave_damage_format % [float(current.damage) / float(maxi(base.damage, 1)), base.damage, current.damage]


func _find_exorcism() -> Node:
	if _level == null:
		return null
	var found: Array[Node] = _level.find_children("*", "ExorcismCutscene", true, false)
	return found[0] if not found.is_empty() else null

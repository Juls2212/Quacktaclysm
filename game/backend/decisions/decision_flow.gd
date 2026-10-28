class_name DecisionFlow
extends Node
## Coordinator: fragment collected -> decision panel -> GameState -> fragment effect.
## Boss, player and UI never reference each other; everything goes through this node.

signal decision_made(fragment_id: String, choice: String)

@export var drop: SoulFragmentDrop
@export var panel: DecisionPanel
## Optional: asks the AI service to refine the profile after the local result. Never blocks.
@export var refiner: AdaptiveRefiner

var _active: SoulFragment = null
var _resolving: bool = false


func _ready() -> void:
	if drop:
		drop.fragment_spawned.connect(_on_fragment_spawned)
	if panel:
		panel.choice_selected.connect(_on_choice_selected)


func _on_fragment_spawned(fragment: SoulFragment) -> void:
	fragment.collected.connect(_on_fragment_collected)


func _on_fragment_collected(fragment: SoulFragment) -> void:
	if _active != null or fragment.data == null:
		fragment.dismiss()
		return
	_active = fragment
	_resolving = false
	panel.open(fragment.data)


func _on_choice_selected(choice: String) -> void:
	if _active == null or _resolving:
		return
	_resolving = true
	var fragment: SoulFragment = _active
	_active = null
	# Close first so the tree is unpaused before the effect tween starts.
	panel.close()
	if is_instance_valid(fragment):
		var data: SoulFragmentData = fragment.data
		if GameState.record_decision(data.fragment_id, data.boss_id, data.level, choice):
			# Immediate local profile first, so the autosave already contains it. In the next
			# phase remote refinement runs asynchronously AFTER this and must never block the flow.
			GameState.refresh_adaptive_profile(AdaptiveInput.POINT_AFTER_DECISION)
			GameState.autosave()
			fragment.resolve(choice)
			decision_made.emit(data.fragment_id, choice)
			if refiner != null:
				refiner.request_refinement()
		else:
			fragment.dismiss()
	_resolving = false

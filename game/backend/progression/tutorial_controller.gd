class_name TutorialController
extends Node
## Ordered, data-driven tutorial. Each step completes once, in order, from a real player signal
## (steps are dictionaries: id, kind, text). Text may contain "{action}" placeholders that are
## replaced with the first key bound to that input action. After the last step the exit opens;
## entering it sets GameState to level 1 and goes to `exit_scene_id`.
## Autosave is suspended while the tutorial scene is alive so a checkpoint touched here cannot
## overwrite an existing save; it is restored before the exit saves.

signal step_completed(step_id: String)
signal tutorial_completed

const KIND_MOVE: String = "move"
const KIND_JUMP: String = "jump"
const KIND_DASH: String = "dash"
const KIND_ATTACK: String = "attack"
const KIND_HIT_DUMMY: String = "hit_dummy"
const KIND_WAVE: String = "wave"
const KIND_HEAVY: String = "heavy"
const KIND_DASH_SLASH: String = "dash_slash"
const KIND_HEAL: String = "heal"

@export var player: Player
@export var dummy: TrainingDummy
@export var exit_area: Area2D
@export var prompt_label: Label
@export var grandfather_label: Label
@export var steps: Array[Dictionary] = []
@export var move_distance_threshold: float = 150.0
## Seconds between checks of the key names shown in the prompt.
const HINT_CHECK_INTERVAL: float = 0.25

var _hint_check_left: float = HINT_CHECK_INTERVAL

## The "Nueva habilidad" card shown when the heal step begins (skipped in headless runs).
@export var show_ability_card: bool = true
@export var show_card_when_headless: bool = false
@export var feedback_text: String = "¡Bien!"
@export var feedback_time: float = 0.8
@export var final_text: String = "Muy bien. Sigue a la derecha para salir."
@export var exit_hint_text: String = "Completa el entrenamiento antes de salir."
@export var greeting_text: String = "Abuelo: Ven, te enseñaré lo básico."
@export var exit_scene_id: String = "level_1"
@export var exit_level: int = 1
@export var exit_checkpoint_id: String = "level_1_start"

var current_index: int = 0
var is_completed: bool = false

var _moved: float = 0.0
var _last_x: float = 0.0
var _feedback_left: float = 0.0
var _exiting: bool = false
var _previous_autosave: bool = true
var _card_shown: bool = false


func _ready() -> void:
	_previous_autosave = GameState.autosave_enabled
	GameState.autosave_enabled = false
	if grandfather_label != null:
		grandfather_label.text = greeting_text
	if player == null:
		return
	_last_x = player.global_position.x
	player.state_changed.connect(_on_state_changed)
	player.dash_started.connect(_on_action.bind(KIND_DASH))
	player.attack_started.connect(_on_action.bind(KIND_ATTACK))
	player.wave_cast.connect(func(_tier: int) -> void: _on_action(KIND_WAVE))
	player.heavy_attack_started.connect(_on_action.bind(KIND_HEAVY))
	player.dash_slash_started.connect(_on_action.bind(KIND_DASH_SLASH))
	player.focus_completed.connect(func(_healed: int) -> void: _on_action(KIND_HEAL))
	# In the tutorial the focus may finish at full health: it spends the soul and heals nothing.
	player.focus_practice = true
	if dummy != null:
		dummy.health.damaged.connect(_on_dummy_damaged)
	if exit_area != null:
		exit_area.body_entered.connect(_on_exit_entered)
	_show_current_prompt()


func _exit_tree() -> void:
	GameState.autosave_enabled = _previous_autosave
	if player != null and is_instance_valid(player):
		player.focus_practice = false


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_hint_check_left -= delta
	if _hint_check_left <= 0.0:
		_hint_check_left = HINT_CHECK_INTERVAL
		_refresh_hints()
	var x: float = player.global_position.x
	if not is_completed and _current_kind() == KIND_MOVE:
		_moved += absf(x - _last_x)
		if _moved >= move_distance_threshold:
			_complete_step()
	_last_x = x
	if _feedback_left > 0.0:
		_feedback_left -= delta
		if _feedback_left <= 0.0:
			_show_current_prompt()


## Re-reads the key names of the step on screen, so a remap made in the pause menu shows up.
func _refresh_hints() -> void:
	if is_completed or _feedback_left > 0.0 or current_index >= steps.size() or prompt_label == null:
		return
	var fresh: String = build_text(String(steps[current_index].get("text", "")))
	if fresh != prompt_label.text and prompt_label.visible:
		_set_prompt(fresh)


func get_current_step_id() -> String:
	return String(steps[current_index].get("id", "")) if current_index < steps.size() else ""


## Replaces "{action}" tokens with the first key bound to that action (plain action name as fallback).
func build_text(template: String) -> String:
	var result: String = template
	for action in InputMap.get_actions():
		var token: String = "{%s}" % action
		if result.contains(token):
			result = result.replace(token, _key_hint(action))
	return result


## What the player reads for an action right now ("J o Clic izquierdo"); follows remaps.
func _key_hint(action: StringName) -> String:
	return ControlsConfig.input_map_hint(action)


func _current_kind() -> String:
	return String(steps[current_index].get("kind", "")) if current_index < steps.size() else ""


func _on_state_changed(_old_state: Player.State, new_state: Player.State) -> void:
	if new_state == Player.State.JUMP:
		_on_action(KIND_JUMP)


func _on_dummy_damaged(_info: DamageInfo) -> void:
	_on_action(KIND_HIT_DUMMY)


func _on_action(kind: String) -> void:
	if not is_completed and _current_kind() == kind:
		_complete_step()


func _complete_step() -> void:
	var finished_id: String = get_current_step_id()
	current_index += 1
	_moved = 0.0
	step_completed.emit(finished_id)
	if current_index >= steps.size():
		is_completed = true
		_set_prompt(final_text)
		tutorial_completed.emit()
		return
	_set_prompt(feedback_text)
	_feedback_left = feedback_time


func _show_current_prompt() -> void:
	if is_completed:
		_set_prompt(final_text)
	elif current_index < steps.size():
		_set_prompt(build_text(String(steps[current_index].get("text", ""))))
		_maybe_show_heal_card()


## When the heal step comes up, a full-screen card announces the new ability with its current key(s).
func _maybe_show_heal_card() -> void:
	if _card_shown or not show_ability_card or _current_kind() != KIND_HEAL:
		return
	if DisplayServer.get_name() == "headless" and not show_card_when_headless:
		return
	_card_shown = true
	var queue := get_parent().get_node_or_null(^"PresentationQueue") as PresentationQueue if get_parent() != null else null
	if queue != null:
		queue.enqueue("card_heal_tutorial", _present_heal_card)
	else:
		_present_heal_card()


## One card per tutorial run (the id carries this node's id; nothing is saved). Returns the `dismissed` signal.
func _present_heal_card() -> Variant:
	var texts := AbilityTexts.get_default()
	var card: AbilityCard = AbilityCard.present(self, "heal_tutorial_%d" % get_instance_id(), texts.heal_name, texts.heal_description, PackedStringArray(["heal"]))
	return Signal(card, &"dismissed") if card != null else Signal()


func _set_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text


func _on_exit_entered(body: Node2D) -> void:
	if _exiting or body != player:
		return
	if not is_completed:
		_set_prompt(exit_hint_text)
		_feedback_left = feedback_time
		return
	if SceneManager.is_transitioning():
		return
	_exiting = true
	GameState.autosave_enabled = _previous_autosave
	GameState.set_current_level(exit_level)
	GameState.set_checkpoint(exit_checkpoint_id)
	GameState.autosave()
	if not SceneManager.go_to(exit_scene_id):
		_exiting = false
		GameState.autosave_enabled = false

class_name TutorialController
extends Node
## The tutorial (Phase 15m), built so that NOTHING can block it: the steps are independent checks, not a chain. Any action counts the moment
## the player does it, even before it is asked for (the dummy acknowledges it); the dummy comes back by itself after it dies; dying, falling,
## pausing and spamming inputs change nothing in what is done. The exit opens when every REQUIRED step is done, or at any time when the player
## holds the confirm action for `config.skip_hold_seconds` (returning players). Entering the open exit sets GameState to level 1 and goes to
## `exit_scene_id`. Autosave is suspended while the tutorial scene is alive so a checkpoint touched here cannot overwrite a save.
## Texts come from TutorialTexts, numbers from TutorialConfig; the checklist and the signs are drawn by TutorialHud / TutorialStation.

signal step_completed(step_id: String)
signal tutorial_completed
## A step was done before it was the one on screen.
signal step_credited_early(step_id: String)
signal dummy_respawned

const KIND_MOVE: String = "move"
const KIND_JUMP: String = "jump"
const KIND_DASH: String = "dash"
const KIND_ATTACK: String = "attack"
const KIND_HEAVY: String = "heavy"
const KIND_SOUL: String = "soul"
const KIND_HEAL: String = "heal"
const KIND_PAUSE: String = "pause"
## Seconds between checks of the key names shown in the prompt.
const HINT_CHECK_INTERVAL: float = 0.25

@export var player: Player
@export var dummy: TrainingDummy
@export var exit_area: Area2D
@export var prompt_label: Label
@export var grandfather_label: Label
@export var dummy_label: Label
## The checklist and skip hint panel (TutorialHud): duck-typed so this script never depends on a visual class.
@export var hud: Control
@export var texts: TutorialTexts = null
@export var config: TutorialConfig = null
## Filled from `texts` when empty.
@export var steps: Array[Dictionary] = []
## The "Nueva habilidad" card shown when the heal step comes up (skipped in headless runs).
@export var show_ability_card: bool = true
@export var show_card_when_headless: bool = false
@export var exit_scene_id: String = "level_1"
@export var exit_level: int = 1
@export var exit_checkpoint_id: String = "level_1_start"

## Step id -> true once done. Steps are independent of each other.
var done: Dictionary = {}
## The first REQUIRED step not done yet (steps.size() when all are).
var current_index: int = 0
var is_completed: bool = false
var skipped: bool = false
var skip_held: float = 0.0
## How many times the dummy came back.
var respawns: int = 0
## Texts the controller shows (the tests read them).
var feedback_text: String = ""
var final_text: String = ""
var exit_hint_text: String = ""

var _moved: float = 0.0
var _last_x: float = 0.0
var _feedback_left: float = 0.0
var _exiting: bool = false
var _previous_autosave: bool = true
var _card_shown: bool = false
var _hint_check_left: float = HINT_CHECK_INTERVAL
var _respawn_left: float = -1.0
var _speech_left: float = 0.0
var _hit_line_left: float = 0.0
var _idle_for: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if texts == null:
		texts = TutorialTexts.get_default()
	if config == null:
		config = TutorialConfig.get_default()
	if steps.is_empty():
		steps = texts.steps.duplicate(true)
	feedback_text = texts.feedback_text
	final_text = texts.final_text
	_previous_autosave = GameState.autosave_enabled
	GameState.autosave_enabled = false
	if grandfather_label != null:
		grandfather_label.text = texts.greeting
	if hud != null and hud.has_method(&"setup"):
		hud.call(&"setup", texts, steps)
	_recompute()
	if player == null:
		return
	_last_x = player.global_position.x
	player.state_changed.connect(_on_state_changed)
	player.dash_started.connect(_on_action.bind(KIND_DASH))
	player.attack_started.connect(_on_action.bind(KIND_ATTACK))
	player.heavy_attack_started.connect(_on_action.bind(KIND_HEAVY))
	player.focus_completed.connect(func(_healed: int) -> void: _on_action(KIND_HEAL))
	if player.soul != null:
		player.soul.soul_gained.connect(func(_amount: int) -> void: _on_action(KIND_SOUL))
	# In the tutorial the focus may finish at full health: it spends the soul and heals nothing.
	player.focus_practice = true
	if dummy != null:
		dummy.health.damaged.connect(_on_dummy_damaged)
		dummy.health.died.connect(_on_dummy_died)
	if exit_area != null:
		exit_area.body_entered.connect(_on_exit_entered)
	_speak("greet")
	_show_current_prompt()


func _exit_tree() -> void:
	GameState.autosave_enabled = _previous_autosave
	if player != null and is_instance_valid(player):
		player.focus_practice = false


func _input(event: InputEvent) -> void:
	# Opening the pause menu is the "pause" step: it counts even if the player is not asked yet.
	if event.is_action_pressed("pause"):
		_on_action(KIND_PAUSE)


func _physics_process(_delta: float) -> void:
	if player == null or get_tree().paused:
		return
	var x: float = player.global_position.x
	var step: float = absf(x - _last_x)
	# A respawn or a fall is a jump of position, not walking.
	if step <= config.max_step_px:
		_moved += step
	if _moved >= config.move_distance:
		_on_action(KIND_MOVE)
	_last_x = x


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_hint_check_left -= delta
	if _hint_check_left <= 0.0:
		_hint_check_left = HINT_CHECK_INTERVAL
		_refresh_hints()
	if _feedback_left > 0.0:
		_feedback_left -= delta
		if _feedback_left <= 0.0:
			_show_current_prompt()
	if _respawn_left >= 0.0:
		_respawn_left -= delta
		if _respawn_left < 0.0:
			_respawn_dummy()
	if _speech_left > 0.0:
		_speech_left -= delta
		if _speech_left <= 0.0 and dummy_label != null:
			dummy_label.text = ""
	_hit_line_left = maxf(_hit_line_left - delta, 0.0)
	_idle_for += delta
	if _idle_for >= config.idle_line_after and not is_completed:
		_idle_for = 0.0
		_speak("idle")
	_update_skip_hold(delta)


# ---------------------------------------------------------------------------------------------
# The steps: independent checks
# ---------------------------------------------------------------------------------------------

## Any step of this kind that is not done yet is done now, whatever the order.
func _on_action(kind: String) -> void:
	for step in steps:
		if String(step.get("kind", "")) == kind and not done.has(String(step["id"])):
			_mark_done(step)


func _mark_done(step: Dictionary) -> void:
	var step_id: String = String(step["id"])
	var was_current: bool = get_current_step_id() == step_id
	var was_open: bool = is_completed
	done[step_id] = true
	_idle_for = 0.0
	if String(step.get("kind", "")) == KIND_MOVE:
		_moved = 0.0
	_recompute()
	if hud != null and hud.has_method(&"set_done"):
		hud.call(&"set_done", step_id, true)
	for station in get_tree().get_nodes_in_group(&"tutorial_station"):
		if station.get(&"step_id") == step_id:
			station.set(&"done", true)
	step_completed.emit(step_id)
	if not was_current and not was_open:
		step_credited_early.emit(step_id)
		_speak("early")
	elif not is_completed:
		_speak("done")
	if is_completed and not was_open:
		_open_gate()
	elif not is_completed:
		_set_prompt(feedback_text)
		_feedback_left = config.feedback_time


## Recomputes where the player is from what is actually done (never from a counter).
func _recompute() -> void:
	current_index = steps.size()
	var all_required: bool = true
	for i in steps.size():
		if bool(steps[i].get("required", true)) and not done.has(String(steps[i]["id"])):
			all_required = false
			if current_index == steps.size():
				current_index = i
	is_completed = all_required or skipped


func get_current_step_id() -> String:
	return String(steps[current_index].get("id", "")) if current_index < steps.size() else ""


func is_step_done(step_id: String) -> bool:
	return done.has(step_id)


## The short names of the required steps still missing.
func missing_steps() -> PackedStringArray:
	var out := PackedStringArray()
	for step in steps:
		if bool(step.get("required", true)) and not done.has(String(step["id"])):
			out.append(build_text(String(step.get("short", step["id"]))))
	return out


func _open_gate() -> void:
	is_completed = true
	_set_prompt(final_text)
	_speak("skipped" if skipped else "all_done")
	tutorial_completed.emit()


# ---------------------------------------------------------------------------------------------
# Skip hold
# ---------------------------------------------------------------------------------------------

func _update_skip_hold(delta: float) -> void:
	if is_completed:
		skip_held = 0.0
	elif Input.is_action_pressed("ui_accept"):
		skip_held += delta
	else:
		skip_held = maxf(skip_held - delta * 2.0, 0.0)
	if hud != null and hud.has_method(&"set_hold"):
		hud.call(&"set_hold", 0.0 if is_completed else skip_held / config.skip_hold_seconds)
	if not is_completed and skip_held >= config.skip_hold_seconds:
		skip_now()


## Opens the gate at once (the skip hold calls it).
func skip_now() -> void:
	if skipped or is_completed:
		return
	skipped = true
	skip_held = 0.0
	_recompute()
	_open_gate()


# ---------------------------------------------------------------------------------------------
# The dummy: it never stays dead
# ---------------------------------------------------------------------------------------------

func _on_dummy_damaged(info: DamageInfo) -> void:
	_idle_for = 0.0
	if info.attack_kind == &"heavy":
		_on_action(KIND_HEAVY)
	if _hit_line_left <= 0.0:
		_hit_line_left = config.hit_line_interval
		_speak("heavy_hit" if info.attack_kind == &"heavy" else "hit")


func _on_dummy_died() -> void:
	_respawn_left = config.respawn_seconds
	_speak("killed")


func _respawn_dummy() -> void:
	_respawn_left = -1.0
	if dummy == null or not is_instance_valid(dummy):
		return
	dummy.reset_dummy()
	respawns += 1
	var container: Node = dummy.get_parent()
	if container != null:
		FeatherBurst.spawn(container, dummy.global_position + Vector2(0.0, -30.0), Color(0.85, 0.7, 0.35), 8)
	dummy_respawned.emit()
	_speak("respawn")


func _speak(event: String) -> void:
	if dummy_label == null:
		return
	var line: String = texts.line_for(event, _rng)
	if line.is_empty():
		return
	dummy_label.text = line
	_speech_left = config.speech_seconds


# ---------------------------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------------------------

## Re-reads the key names of the step on screen, so a remap made in the pause menu shows up.
func _refresh_hints() -> void:
	if is_completed or _feedback_left > 0.0 or current_index >= steps.size() or prompt_label == null:
		return
	var fresh: String = build_text(String(steps[current_index].get("text", "")))
	if fresh != prompt_label.text and prompt_label.visible:
		_set_prompt(fresh)
	if hud != null and hud.has_method(&"refresh_keys"):
		hud.call(&"refresh_keys")


## Replaces "{action}" tokens with the first key bound to that action (plain action name as fallback).
func build_text(template: String) -> String:
	var result: String = template
	for action in InputMap.get_actions():
		var token: String = "{%s}" % action
		if result.contains(token):
			result = result.replace(token, _key_hint(action))
	return result


## What the player reads for an action right now; follows remaps.
func _key_hint(action: StringName) -> String:
	return ControlsConfig.input_map_hint(action)


func _on_state_changed(_old_state: Player.State, new_state: Player.State) -> void:
	if new_state == Player.State.JUMP:
		_on_action(KIND_JUMP)


func _show_current_prompt() -> void:
	if is_completed:
		_set_prompt(final_text)
	elif current_index < steps.size():
		_set_prompt(build_text(String(steps[current_index].get("text", ""))))
		_maybe_show_heal_card()


## When the heal step comes up, a full-screen card announces the new ability with its current key(s).
func _maybe_show_heal_card() -> void:
	if _card_shown or not show_ability_card or get_current_step_id() != "heal":
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
	var ability_texts := AbilityTexts.get_default()
	var card: AbilityCard = AbilityCard.present(self, "heal_tutorial_%d" % get_instance_id(), ability_texts.heal_name, ability_texts.heal_description, PackedStringArray(["heal"]))
	return Signal(card, &"dismissed") if card != null else Signal()


func _set_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text


func _on_exit_entered(body: Node2D) -> void:
	if _exiting or body != player:
		return
	if not is_completed:
		exit_hint_text = texts.exit_hint_format % ", ".join(missing_steps())
		_set_prompt(exit_hint_text)
		_feedback_left = config.feedback_time * 2.0
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

class_name LevelBase
extends Node2D
## Reusable level template. The base scene (level_base.tscn) holds the common services wired like
## boss_test; each level inherits it and adds geometry/enemies/checkpoints under `Content`.
## Responsibilities: place the player (spawn or saved checkpoint), lock input during fades,
## open/close arena gates around the boss fight and advance to `next_scene_id` once the boss is
## defeated and its fragment decided. Gameplay logic stays in the existing components.
##
## Adaptive parameters are consumed ONCE, at `_ready` (after the player is placed): the boss
## aggression and the `variant_groups` (optional nodes that only exist in one encounter variant).
## Nothing is hot-swapped afterwards. When `next_scene_id` is not one of the registry's levels
## (the ending), completing the level writes the ending marker to GameState.

signal level_ready
signal level_completed(level_number: int)

## 0 = tutorial (never writes GameState), 1-3 = levels.
@export var level_number: int = 0
@export var level_id: StringName = &""
## Convention: "level_N_start". Written to GameState on a fresh arrival.
@export var start_checkpoint_id: String = ""
@export var next_scene_id: String = ""
@export var show_game_over: bool = true
## Zero size = no camera limits.
@export var camera_limits: Rect2i = Rect2i()
@export var advance_delay: float = 1.5
@export var refine_wait_timeout: float = 3.0
@export var boss: BossBase
@export var encounter: BossEncounter
@export var fragment_drop: SoulFragmentDrop
@export var arena_gates: Array[ArenaGate] = []
@export_group("Look and narrative")
## Placeholder palette. A fully transparent color (default) leaves the engine clear color untouched.
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Sky, parallax layers, ground skin and particles of the level (drawn under the play field).
@export var biome: Biome
## Narrative variant (String) -> short line shown for `intro_duration` seconds at level start.
@export var intro_lines: Dictionary = {}
@export var intro_duration: float = 4.0
@export_group("Adaptive variants")
## Encounter variant id (String) -> Array of NodePath (relative to this node) of optional nodes that
## only exist in that variant. Groups that do not match the adaptive result are removed at load.
@export var variant_groups: Dictionary = {}

var is_completed: bool = false

var _locked_by_level: bool = false
var _advance_pending: bool = false
var _advance_elapsed: float = 0.0
var _completion_started: bool = false
var _applied_result: AdaptiveResult = null
var _intro_left: float = 0.0
var _autosave_suspended: bool = false

@onready var player: Player = $Player
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var hud: PlayerHealthHud = $Hud
@onready var boss_bar: BossHealthBar = $BossHealthBar
@onready var decision_flow: DecisionFlow = $DecisionFlow
@onready var refiner: AdaptiveRefiner = $AdaptiveRefiner
@onready var game_over_controller: GameOverController = $GameOverController
@onready var background: ColorRect = $BackgroundLayer/Background
@onready var intro_label: Label = $IntroLayer/IntroLabel


func _ready() -> void:
	hud.bind(player)
	if boss != null:
		boss_bar.bind(boss)
		boss.defeated.connect(_on_boss_defeated)
		boss.encounter_reset.connect(_on_arena_reset)
	if decision_flow.drop != fragment_drop:
		push_warning("LevelBase: DecisionFlow.drop must be the level's fragment_drop (set it in the level scene)")
	if encounter != null:
		encounter.encounter_started.connect(_on_encounter_started)
	game_over_controller.show_game_over = show_game_over
	player.set_auto_respawn(not show_game_over)
	_apply_camera_limits()
	_place_player()
	_apply_adaptive()
	_apply_background()
	_show_intro()
	SceneManager.transition_started.connect(_on_transition_started)
	SceneManager.transition_finished.connect(_on_transition_finished)
	if SceneManager.is_transitioning():
		_set_level_lock(true)
	level_ready.emit()


func _exit_tree() -> void:
	if _autosave_suspended:
		GameState.autosave_enabled = true
		_autosave_suspended = false
	if SceneManager.transition_started.is_connected(_on_transition_started):
		SceneManager.transition_started.disconnect(_on_transition_started)
	if SceneManager.transition_finished.is_connected(_on_transition_finished):
		SceneManager.transition_finished.disconnect(_on_transition_finished)


func _process(delta: float) -> void:
	if _intro_left > 0.0:
		_intro_left -= delta
		if _intro_left <= 0.0:
			intro_label.visible = false
	# Safety net: a failed or missed transition must never leave the player locked.
	if _locked_by_level and not SceneManager.is_transitioning():
		_set_level_lock(false)
	if _advance_pending:
		_advance_elapsed += delta
		if _advance_elapsed >= advance_delay and (not refiner.in_flight or _advance_elapsed >= refine_wait_timeout):
			_advance_pending = false
			_advance()


## The adaptive result this level was loaded with (null before `_ready`).
func get_applied_adaptive_result() -> AdaptiveResult:
	return _applied_result


func is_intro_visible() -> bool:
	return intro_label.visible


## Runs once. Boss aggression + variant groups, from the adaptive result at load time.
func _apply_adaptive() -> void:
	_applied_result = GameState.get_adaptive_result()
	if boss != null:
		boss.set_aggression(_applied_result.boss_aggression)
	for group_id: Variant in variant_groups.keys():
		if String(group_id) == _applied_result.encounter_variant:
			continue
		var paths: Variant = variant_groups[group_id]
		if not paths is Array:
			push_warning("LevelBase: variant group '%s' must be an Array of NodePath" % String(group_id))
			continue
		for raw_path: Variant in paths as Array:
			_remove_variant_node(NodePath(raw_path), String(group_id))


## Removes the node from the tree at once (it can no longer emit or act) and frees it.
func _remove_variant_node(path: NodePath, group_id: String) -> void:
	var node: Node = get_node_or_null(path)
	if node == null:
		push_warning("LevelBase: variant group '%s' has an invalid NodePath '%s'" % [group_id, path])
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _apply_background() -> void:
	background.color = background_color
	background.visible = background_color.a > 0.0


func _show_intro() -> void:
	intro_label.visible = false
	var variant: String = _applied_result.narrative_variant
	if intro_duration <= 0.0 or not intro_lines.has(variant):
		return
	var line: String = String(intro_lines[variant])
	if line.is_empty():
		return
	intro_label.text = line
	intro_label.visible = true
	_intro_left = intro_duration


## Override in a level to react when the arena closes (encounter started).
func _on_arena_closed() -> void:
	pass


## Override in a level to react when the arena opens (boss reset or defeated).
func _on_arena_opened() -> void:
	pass


## Checkpoints that belong to this level.
func get_level_checkpoints() -> Array[Checkpoint]:
	var result: Array[Checkpoint] = []
	for node in get_tree().get_nodes_in_group(Checkpoint.GROUP):
		var checkpoint := node as Checkpoint
		if checkpoint != null and is_ancestor_of(checkpoint):
			result.append(checkpoint)
	return result


func _place_player() -> void:
	var restore: Checkpoint = null
	var game_completed: bool = GameState.is_game_completed()
	if game_completed and level_number >= 1:
		# Dev/debug entry after finishing the game: fresh arrival, but the "ending" marker must stay.
		GameState.autosave_enabled = false
		_autosave_suspended = true
	if level_number >= 1 and not game_completed and GameState.current_level == level_number:
		for checkpoint in get_level_checkpoints():
			if String(checkpoint.checkpoint_id) == GameState.checkpoint:
				restore = checkpoint
	if restore != null:
		player.global_position = restore.get_respawn_position()
		player.set_respawn_point(restore.get_respawn_position())
		for checkpoint in get_level_checkpoints():
			if checkpoint.order <= restore.order:
				checkpoint.mark_activated_silently()
		return
	player.global_position = spawn_point.global_position
	player.set_respawn_point(player.global_position)
	if level_number >= 1 and not game_completed:
		GameState.set_current_level(level_number)
		GameState.set_checkpoint(start_checkpoint_id)
		GameState.autosave()


func _apply_camera_limits() -> void:
	if camera_limits.size == Vector2i.ZERO:
		return
	player.camera.limit_left = camera_limits.position.x
	player.camera.limit_top = camera_limits.position.y
	player.camera.limit_right = camera_limits.end.x
	player.camera.limit_bottom = camera_limits.end.y


func _set_level_lock(value: bool) -> void:
	_locked_by_level = value
	player.set_input_locked(value)


func _on_transition_started(_scene_id: String) -> void:
	_set_level_lock(true)


func _on_transition_finished(_scene_id: String) -> void:
	_set_level_lock(false)


func _on_encounter_started() -> void:
	for gate in arena_gates:
		gate.close()
	_on_arena_closed()


func _on_arena_reset() -> void:
	for gate in arena_gates:
		gate.open()
	_on_arena_opened()


func _on_boss_defeated(_boss: BossBase) -> void:
	_on_arena_reset()
	if _completion_started:
		return
	_completion_started = true
	var fragment_id: String = ""
	if fragment_drop != null and fragment_drop.fragment_data != null:
		fragment_id = fragment_drop.fragment_data.fragment_id
	if fragment_id.is_empty() or GameState.has_decision(fragment_id):
		_schedule_advance()
	else:
		decision_flow.decision_made.connect(_on_decision_made, CONNECT_ONE_SHOT)


func _on_decision_made(_fragment_id: String, _choice: String) -> void:
	_schedule_advance()


func _schedule_advance() -> void:
	_advance_elapsed = 0.0
	_advance_pending = true


func _advance() -> void:
	if is_completed:
		return
	is_completed = true
	level_completed.emit(level_number)
	if next_scene_id.is_empty():
		return
	var registry: SceneRegistry = SceneManager.get_registry()
	if level_number >= 1 and registry != null and not registry.level_scene_ids.has(next_scene_id):
		_advance_to_ending()
		return
	if not SceneManager.go_to(next_scene_id):
		push_warning("LevelBase: could not go to '%s'; staying in the level" % next_scene_id)
		return
	var next_level: int = registry.level_scene_ids.find(next_scene_id) + 1 if registry != null else 0
	if next_level >= 1:
		GameState.set_current_level(next_level)
		GameState.set_checkpoint("%s_start" % next_scene_id)
		GameState.autosave()


## Last level: writes the ending marker (the current level stays), saves and opens the ending scene.
## If the scene is rejected the previous checkpoint is restored and the player keeps control.
func _advance_to_ending() -> void:
	var previous_checkpoint: String = GameState.checkpoint
	GameState.set_checkpoint(GameState.CHECKPOINT_ENDING)
	GameState.autosave()
	if SceneManager.go_to(next_scene_id):
		return
	push_warning("LevelBase: could not go to '%s'; staying in the level" % next_scene_id)
	GameState.set_checkpoint(previous_checkpoint)
	GameState.autosave()

class_name SwordWaveCaster
extends Node
## Child of the Player. Owns the sword wave data side: the tier (derived from GameState decisions),
## the cooldown and the projectile spawn. The cast timeline (startup/recovery) is driven by the
## Player state machine, which calls `can_cast()` and `fire()`.

signal tier_changed(tier: int)
signal wave_cooldown_changed(remaining: float, total: float)

const DEFAULT_CONFIG_PATH: String = "res://backend/player/default_sword_wave_config.tres"
const GAME_STATE_PATH: NodePath = ^"/root/GameState"

@export var config: SwordWaveConfig

var current_tier: int = 0

var _override: int = -1
var _cooldown_left: float = 0.0
var _cooldown_total: float = 0.0
var _game_state: Node = null


func _ready() -> void:
	if config == null:
		config = load(DEFAULT_CONFIG_PATH) as SwordWaveConfig
	_game_state = get_node_or_null(GAME_STATE_PATH)
	if _game_state != null:
		_game_state.decision_recorded.connect(_on_game_state_changed)
		_game_state.state_changed.connect(_on_game_state_changed)
	_refresh_tier()


func _exit_tree() -> void:
	if _game_state != null and is_instance_valid(_game_state):
		if _game_state.decision_recorded.is_connected(_on_game_state_changed):
			_game_state.decision_recorded.disconnect(_on_game_state_changed)
		if _game_state.state_changed.is_connected(_on_game_state_changed):
			_game_state.state_changed.disconnect(_on_game_state_changed)
	_game_state = null


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
		if _cooldown_left == 0.0:
			wave_cooldown_changed.emit(0.0, _cooldown_total)


## -1 clears the override. Tests/debug only.
func set_tier_override(tier: int) -> void:
	_override = tier
	_refresh_tier()


func get_effective_tier() -> int:
	if _override >= 0 and config != null:
		return clampi(_override, 0, maxi(config.tiers.size() - 1, 0))
	return current_tier


func get_cooldown_remaining() -> float:
	return _cooldown_left


func get_cooldown_total() -> float:
	return _cooldown_total


func get_tint() -> Color:
	var tier: SwordWaveTier = config.get_tier(get_effective_tier()) if config != null else null
	return tier.tint if tier != null else Color.WHITE


## Config present, at least one tier, and the cooldown is over.
func can_cast() -> bool:
	return config != null and config.projectile_scene != null and config.get_tier(0) != null and _cooldown_left <= 0.0


func reset() -> void:
	_cooldown_left = 0.0
	_cooldown_total = 0.0
	wave_cooldown_changed.emit(0.0, 0.0)


## Spawns exactly one wave in the current scene (never under the player) and starts the cooldown.
func fire(caster_body: Node2D, facing: int) -> Projectile:
	if not can_cast():
		return null
	var tier_index: int = get_effective_tier()
	var tier: SwordWaveTier = config.get_tier(tier_index)
	var projectile := config.projectile_scene.instantiate() as Projectile
	var scene: Node = caster_body.get_tree().current_scene
	var parent: Node = scene if scene != null else caster_body.get_parent()
	parent.add_child(projectile)
	var offset := Vector2(config.spawn_offset.x * facing, config.spawn_offset.y)
	projectile.global_position = caster_body.global_position + offset
	projectile.launch(Vector2(facing, 0.0), CombatLayers.Team.PLAYER, config.build_projectile_stats(tier_index), caster_body)
	if facing < 0 and projectile.visual != null:
		projectile.visual.scale.x = -projectile.visual.scale.x
	_cooldown_total = tier.cooldown
	_cooldown_left = tier.cooldown
	wave_cooldown_changed.emit(_cooldown_left, _cooldown_total)
	return projectile


func _on_game_state_changed(_unused: Variant = null) -> void:
	_refresh_tier()


func _refresh_tier() -> void:
	var previous: int = get_effective_tier()
	var decisions: Array = []
	if _game_state != null and config != null:
		decisions = _game_state.to_dict()["decisions"]
	current_tier = config.resolve_tier(decisions) if config != null else 0
	if get_effective_tier() != previous:
		tier_changed.emit(get_effective_tier())

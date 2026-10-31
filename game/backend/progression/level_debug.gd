class_name LevelDebug
extends Node
## Debug helpers for levels (debug builds only; frees itself otherwise). Keys are handled in code,
## not in the input map: K kills the boss, H hurts it 10%, F2 teleports to the arena checkpoint,
## F3 toggles the info label.

const HURT_FRACTION: int = 10

var _label: Label = null
var _level: LevelBase = null


func _ready() -> void:
	if should_remove(OS.is_debug_build()):
		queue_free()
		return
	_level = get_parent() as LevelBase
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16.0, 120.0)
	_label.visible = false
	layer.add_child(_label)


## True when the helper must not exist (any non-debug build).
static func should_remove(debug_build: bool) -> bool:
	return not debug_build


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or _level == null:
		return
	match key_event.keycode:
		KEY_K:
			_hurt_boss(_level.boss.health.max_health if _level.boss != null else 0)
		KEY_H:
			if _level.boss != null:
				@warning_ignore("integer_division")
				_hurt_boss(maxi(_level.boss.health.max_health / HURT_FRACTION, 1))
		KEY_F2:
			teleport_to_arena_checkpoint()
		KEY_F3:
			_label.visible = not _label.visible


func _process(_delta: float) -> void:
	if _label == null or not _label.visible:
		return
	var player: Player = _level.player
	var lines: PackedStringArray = ["player: %s hp %d/%d" % [Player.State.keys()[player.state], player.health.current_health, player.health.max_health]]
	if _level.boss != null and is_instance_valid(_level.boss):
		lines.append("boss: %s phase %d" % [BossBase.State.keys()[_level.boss.state], _level.boss.current_phase])
	lines.append("level %d  checkpoint %s  profile %s  souls %d/%d" % [GameState.current_level, GameState.checkpoint,
		GameState.adaptive_profile, GameState.souls_released, GameState.souls_kept])
	lines.append("pause holders: %d" % PauseLock.holder_count())
	_label.text = "\n".join(lines)


## The checkpoint with the highest `order` in the level.
func find_arena_checkpoint() -> Checkpoint:
	var best: Checkpoint = null
	for checkpoint in _level.get_level_checkpoints():
		if best == null or checkpoint.order > best.order:
			best = checkpoint
	return best


func teleport_to_arena_checkpoint() -> bool:
	var checkpoint: Checkpoint = find_arena_checkpoint()
	if checkpoint == null:
		return false
	_level.player.global_position = checkpoint.get_respawn_position()
	_level.player.velocity = Vector2.ZERO
	return true


func _hurt_boss(amount: int) -> void:
	var boss: BossBase = _level.boss
	if amount <= 0 or boss == null or not is_instance_valid(boss):
		return
	boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, _level.player, CombatLayers.Team.PLAYER))

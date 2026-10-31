extends Node2D
## Sandbox for the boss system. Debug keys are handled here only (not in the input map):
## R respawns the player and resets the encounter, L reloads the scene,
## H deals 10% of the boss's max health, K kills the boss, G resets GameState.
## GameState is an autoload, so its data survives R and L (scene reload); G is the only
## way to clear recorded decisions (otherwise a decided fragment will not drop again).
## Persistence: 1 saves now, 2 loads and moves the player to the saved checkpoint,
## 3 deletes the save file, 4 writes a corrupt save file (to test recovery).
## Esc/P opens the pause menu; the player's death opens the Game Over panel (retry / main menu).
## 7 asks the AI service to refine the profile now (the game works without the service).
## Adaptive profile: 5 records a fake "released" decision, 6 a fake "kept" one (same sequence as DecisionFlow).

const HURT_FRACTION: int = 10

@onready var player: Player = $Player
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var hud: PlayerHealthHud = $Hud
@onready var boss: BossBase = $Boss
@onready var boss_bar: BossHealthBar = $BossHealthBar
@onready var encounter: BossEncounter = $Encounter
@onready var refiner: AdaptiveRefiner = $AdaptiveRefiner
var _last_io_text: String = "-"
var _fake_count: int = 0

@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	player.global_position = spawn_point.global_position
	player.set_respawn_point($Checkpoint.global_position + $Checkpoint.respawn_offset)
	hud.bind(player)
	boss_bar.bind(boss)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			player.respawn()
			encounter.reset()
		KEY_L:
			PauseLock.reset(get_tree())
			get_tree().reload_current_scene()
		KEY_H:
			if is_instance_valid(boss):
				@warning_ignore("integer_division")
				var amount: int = maxi(boss.health.max_health / HURT_FRACTION, 1)
				boss.hurtbox.receive_hit(DamageInfo.create(amount, Vector2.ZERO, player, CombatLayers.Team.PLAYER))
		KEY_1:
			var saved: bool = GameState.save_to_disk()
			_last_io_text = "save: %s (%s)" % ["ok" if saved else "failed", GameState.last_io_message]
		KEY_2:
			_load_and_restore()
		KEY_3:
			_last_io_text = "delete: %s" % ("ok" if SaveSystem.delete_save() else "failed")
		KEY_4:
			_write_corrupt_save()
		KEY_5:
			_record_fake_decision(AdaptiveIds.CHOICE_RELEASED)
		KEY_6:
			_record_fake_decision(AdaptiveIds.CHOICE_KEPT)
		KEY_7:
			_last_io_text = "refine: %s" % ("sent" if refiner.request_refinement() else "not sent (%s)" % refiner.last_status)
		KEY_G:
			GameState.reset_run()
		KEY_K:
			if is_instance_valid(boss):
				boss.health.kill()


func _process(_delta: float) -> void:
	var lines: PackedStringArray = ["[J/X/click] attack  [R] reset  [L] reload  [H] hurt boss 10%  [K] kill boss  [G] reset GameState", "[1] save  [2] load  [3] delete save  [4] corrupt save"]
	if is_instance_valid(boss):
		lines.append("boss: %s  phase %d  pattern: %s" % [BossBase.State.keys()[boss.state], boss.current_phase, boss.current_pattern_id])
		lines.append("boss hp %d/%d" % [boss.health.current_health, boss.health.max_health])
	else:
		lines.append("boss: defeated")
	lines.append("souls released %d  kept %d  decisions %d  last: %s" % [
		GameState.souls_released, GameState.souls_kept, GameState.decisions.size(), _last_decision_text()])
	lines.append("save file: %s  last io: %s" % ["yes" if SaveSystem.has_save() else "no", _last_io_text])
	lines.append("pause holders: %d  transitioning: %s  save exists: %s  [Esc/P] pause" % [
		PauseLock.holder_count(), SceneManager.is_transitioning(), "yes" if SaveSystem.has_save() else "no"])
	var adaptive: AdaptiveResult = GameState.get_adaptive_result()
	var adaptive_input: AdaptiveInput = AdaptiveInput.from_state_dict(GameState.to_dict(), AdaptiveInput.POINT_AFTER_DECISION)
	lines.append("profile: %s (%s)  score: %.2f  [5] fake released  [6] fake kept" % [
		adaptive.profile, adaptive.source, LocalProfileClassifier.score(adaptive_input, GameState.get_adaptive_config())])
	lines.append("variants: %s / %s / %s  boss aggression x%.2f" % [
		adaptive.narrative_variant, adaptive.encounter_variant, adaptive.ending_variant, adaptive.boss_aggression])
	lines.append("ai [7] refine: %s  last: %s %s  url: %s" % [
		"in flight" if refiner.in_flight else "idle", refiner.last_status, refiner.last_message,
		refiner.config.resolve_base_url() if refiner.config != null else "-"])
	debug_label.text = "\n".join(lines)


func _last_decision_text() -> String:
	if GameState.decisions.is_empty():
		return "-"
	var entry: Dictionary = GameState.decisions[-1]
	return "%s -> %s" % [entry["fragment_id"], entry["choice"]]

## Same sequence as DecisionFlow: record -> refresh adaptive profile -> autosave.
func _record_fake_decision(choice: String) -> void:
	_fake_count += 1
	var level: int = (_fake_count - 1) % GameState.MAX_LEVEL + GameState.MIN_LEVEL
	var fragment_id: String = "debug_fake_%d" % _fake_count
	if GameState.record_decision(fragment_id, "debug", level, choice):
		GameState.refresh_adaptive_profile(AdaptiveInput.POINT_AFTER_DECISION)
		GameState.autosave()


func _load_and_restore() -> void:
	var result: Dictionary = GameState.load_from_disk()
	_last_io_text = "load: %s - %s" % [result["status"], result["message"]]
	if not result["ok"]:
		return
	var saved_checkpoint: Checkpoint = Checkpoint.find_checkpoint(get_tree(), GameState.checkpoint)
	if saved_checkpoint != null:
		player.revive()
		player.set_respawn_point(saved_checkpoint.get_respawn_position())
		player.global_position = saved_checkpoint.get_respawn_position()
		player.velocity = Vector2.ZERO
		saved_checkpoint.is_activated = true
	encounter.reset()


func _write_corrupt_save() -> void:
	var file := FileAccess.open(SaveSystem.get_save_path(), FileAccess.WRITE)
	if file == null:
		_last_io_text = "corrupt write failed"
		return
	file.store_string("this is not json {{{")
	file.close()
	_last_io_text = "wrote a corrupt save file"

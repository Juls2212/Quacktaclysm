class_name TelemetryObserver
extends Node
## Feeds the in-memory telemetry (GameState.director.telemetry) from the signals that already exist in a level, without
## changing any gameplay (Phase 16a). Created by LevelBase at load (code, no scene edit). It only listens: player deaths, damage
## taken (by source category), weapon use (by attack kind), dashes, double jumps, heals, kills, time in the level, time at low
## hearts and time in the boss fight (all game time: it runs in _physics_process, so a pause stops it). Numbered levels only.

var level_number: int = 0

var _telemetry: RunTelemetry = null
var _config: TelemetryConfig = null
var _player: Player = null
var _boss: BossBase = null
var _fighting: bool = false


func setup(level: LevelBase) -> void:
	level_number = level.level_number
	if level_number < 1:
		return
	_telemetry = GameState.director.telemetry
	_config = GameState.director.get_config()
	_telemetry.add(level_number, "time_in_level", 0.000001)
	_player = level.player
	_boss = level.boss
	if _player != null:
		_player.died.connect(on_player_died)
		_player.health.damaged.connect(on_player_damaged)
		_player.dash_started.connect(func() -> void: _telemetry.add(level_number, "dash_use"))
		_player.double_jumped.connect(func() -> void: _telemetry.add(level_number, "double_jump_use"))
		_player.attack_started.connect(func() -> void: _telemetry.add_weapon(level_number, &"light"))
		_player.heavy_attack_started.connect(func() -> void: _telemetry.add_weapon(level_number, &"heavy"))
		_player.dash_slash_started.connect(func() -> void: _telemetry.add_weapon(level_number, &"dash_slash"))
		_player.wave_cast.connect(func(_tier: int) -> void: _telemetry.add_weapon(level_number, &"wave"))
		_player.focus_completed.connect(func(_healed: int) -> void: _telemetry.add(level_number, "heals"))
	for enemy in level.find_children("*", "EnemyBase", true, false):
		(enemy as EnemyBase).died.connect(func(_e: EnemyBase) -> void: _telemetry.add(level_number, "kills"))
	if _boss != null:
		_boss.activated.connect(func() -> void: _fighting = true)
		_boss.encounter_reset.connect(func() -> void: _fighting = false)
		_boss.defeated.connect(func(_b: BossBase) -> void: _fighting = false)


func _physics_process(delta: float) -> void:
	if _telemetry == null:
		return
	_telemetry.add(level_number, "time_in_level", delta)
	if _fighting:
		_telemetry.add(level_number, "time_in_boss", delta)
	if _player != null and _player.health != null and not _player.health.is_dead and _player.health.current_health <= _config.low_health_hearts:
		_telemetry.add(level_number, "low_health_time", delta)


func on_player_died() -> void:
	if _telemetry != null:
		_telemetry.add(level_number, "deaths")


func on_player_damaged(info: DamageInfo) -> void:
	if _telemetry != null:
		_telemetry.record_damage(level_number, info.source, info.amount)

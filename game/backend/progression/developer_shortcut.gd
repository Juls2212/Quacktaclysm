class_name DeveloperShortcut
extends Node
## Developer shortcut. Raw physical key events, not the InputMap. Debug builds only unless the constant below is turned on.

## Developer shortcut: set to true to keep it in release exports too (default false).
const ENABLE_IN_RELEASE: bool = false
## The chord: hold MODIFIER, hold HOLD_KEY, then press TRIGGER_KEY (physical keycodes). All of it is here.
const MODIFIER: Key = KEY_ALT
const HOLD_KEY: Key = KEY_4
const TRIGGER_KEY: Key = KEY_7

## Tests set this to behave as a release build.
static var simulate_release_build: bool = false

## How many times it ran (the tests read it).
var runs: int = 0

var _held: Dictionary = {}
var _level: LevelBase = null


static func is_enabled() -> bool:
	return (OS.is_debug_build() and not simulate_release_build) or ENABLE_IN_RELEASE


func _ready() -> void:
	if not is_enabled():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = get_parent() as LevelBase


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_held.clear()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or not is_enabled():
		return
	var code: int = int(key.physical_keycode) if key.physical_keycode != KEY_NONE else int(key.keycode)
	if not key.pressed:
		_held.erase(code)
		return
	if code != int(TRIGGER_KEY):
		_held[code] = true
		return
	if (_held.has(int(MODIFIER)) or key.alt_pressed) and _held.has(int(HOLD_KEY)):
		run()


## With a boss encounter active it sends the boss to its NEXT corruption state (the normal transition and the new mechanics run); in the
## last phase it defeats the boss through the normal defeat flow; during a transition it does nothing. With no encounter, every regular
## enemy alive dies.
func run() -> void:
	if _level == null or not is_instance_valid(_level):
		return
	runs += 1
	var telemetry: RunTelemetry = GameState.director.telemetry
	telemetry.suppressed += 1
	if encounter_active():
		_defeat_boss()
	else:
		_kill_enemies()
	telemetry.suppressed -= 1


## True from the arena closing (the intro included) until the boss is defeated.
func encounter_active() -> bool:
	var boss: BossBase = _level.boss
	if boss == null or not is_instance_valid(boss) or boss.state == BossBase.State.DEAD:
		return false
	if boss.state != BossBase.State.INACTIVE:
		return true
	var intro: Node = _level.get_node_or_null(^"BossIntro")
	if intro != null and intro.get(&"active") == true:
		return true
	return _level.encounter != null and _level.encounter.get("_armed") == false


## The intro is finished first. A boss with phase lines left goes to its next phase; in its last phase the same lethal hit as the old
## debug kill defeats it (the normal defeat flow follows); in a transition nothing happens.
func _defeat_boss() -> void:
	var boss: BossBase = _level.boss
	var intro: Node = _level.get_node_or_null(^"BossIntro")
	if intro != null and intro.get(&"active") == true:
		intro.call(&"finish_now")
	if boss.state == BossBase.State.DEAD or boss.state == BossBase.State.PHASE_TRANSITION:
		return
	if boss.phase_lines_left() > 0:
		boss.force_next_phase()
		return
	boss.hurtbox.receive_hit(DamageInfo.create(boss.health.max_health, Vector2.ZERO, _level.player, CombatLayers.Team.PLAYER))
	if boss.state != BossBase.State.DEAD:
		boss.health.kill(_level.player)


func _kill_enemies() -> void:
	for node in _level.find_children("*", "EnemyBase", true, false):
		var enemy := node as EnemyBase
		if enemy != null and enemy.state != EnemyBase.State.DEAD and not enemy.health.is_dead:
			enemy.health.kill(_level.player)

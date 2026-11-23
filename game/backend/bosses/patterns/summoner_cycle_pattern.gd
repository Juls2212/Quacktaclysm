class_name SummonerCyclePattern
extends BossPattern
## Phase 2 of boss 3 (Phase 15j): one whole cycle of the summoner stage as a single pattern, so the boss is never idle (a cycle ends with the next
## one about to start). The platforms rise (the first cycle), the boss leaps to its perch and does not melee; it SUMMONS ducklings in batches
## (the shield is up while one lives); when the last of the wave dies the floor trembles, the boss leaps into the air, the floor crumbles,
## the platform barrage crosses for `barrage_time` s, the floor shimmers and returns, and the boss falls onto it EXHAUSTED: the vulnerable
## window (no shield, no shell, full damage). Then it leaps back to the perch and the next cycle begins. Every time comes from the StageConfig
## of the boss stage. Cancelling it (a phase change, the player's death, a retry, the boss's death) puts the arena back in order through
## BossStage.cancel_all, whatever step it was in.

signal step_changed(step: StringName)
signal cycle_completed(count: int)

enum Step { RISE, TO_PERCH, SUMMON, WAIT_KILLS, TREMBLE, LEAP_UP, COLLAPSE, BARRAGE, SHIMMER, LAND, WINDOW, BACK_TO_PERCH, DONE }

const STEP_NAMES: Dictionary = {
	Step.RISE: &"rise", Step.TO_PERCH: &"to_perch", Step.SUMMON: &"summon", Step.WAIT_KILLS: &"wait_kills", Step.TREMBLE: &"tremble", Step.LEAP_UP: &"leap_up",
	Step.COLLAPSE: &"collapse", Step.BARRAGE: &"barrage", Step.SHIMMER: &"shimmer", Step.LAND: &"land", Step.WINDOW: &"window", Step.BACK_TO_PERCH: &"back_to_perch",
	Step.DONE: &"done",
}

var step: Step = Step.DONE
var step_time: float = 0.0
## How many cycles finished in this fight (the tests read it).
var cycles_completed: int = 0
## How long the vulnerable window lasts (seconds): the config's, clamped to its allowed range.
var window_length: float = 6.0

var _stage: BossStage = null
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _batches: int = 0
var _side: int = 1


func step_name() -> StringName:
	return STEP_NAMES[step]


func stage_of(boss: BossBase) -> BossStage:
	# Phase 15q: get_meta(key, null) counts null as "no default" and prints an engine error when the key is missing.
	if not boss.has_meta(&"stage"):
		return null
	return boss.get_meta(&"stage") as BossStage


func can_start(boss: BossBase) -> bool:
	return super.can_start(boss) and boss.is_target_valid() and stage_of(boss) != null


func can_start_fallback(_boss: BossBase, _ignore_cooldown: bool) -> bool:
	return false


func start(boss: BossBase) -> void:
	_stage = stage_of(boss)
	window_length = clampf(_stage.config.window_seconds, _stage.config.window_min, _stage.config.window_max)
	_finished = false
	started.emit()
	if _stage.platforms_state == &"up" and boss.global_position.distance_to(_stage.perch_position()) < 30.0:
		_enter(boss, Step.SUMMON)
	elif _stage.platforms_state == &"up":
		_enter(boss, Step.TO_PERCH)
	else:
		_enter(boss, Step.RISE)


func physics_update(boss: BossBase, delta: float) -> void:
	if _finished:
		return
	step_time += delta
	var config: StageConfig = _stage.config
	if boss.is_target_valid() and step != Step.BARRAGE:
		boss.face_towards(boss.target.global_position.x)
	match step:
		Step.RISE:
			boss.velocity.x = 0.0
			if _stage.platforms_state == &"up":
				_enter(boss, Step.TO_PERCH)
		Step.TO_PERCH:
			if _arc(boss, config.perch_leap_time, config.perch_leap_arc):
				boss.global_position = _to
				boss.velocity = Vector2.ZERO
				_enter(boss, Step.SUMMON)
		Step.SUMMON:
			boss.velocity.x = 0.0
			while _batches < ceili(float(config.wave_size) / float(config.batch_size)) and step_time >= config.first_batch_delay + float(_batches) * config.batch_interval:
				_stage.summon(config.batch_size)
				_batches += 1
			if _stage.summoned >= config.wave_size:
				_enter(boss, Step.WAIT_KILLS)
		Step.WAIT_KILLS:
			boss.velocity.x = 0.0
			if _stage.wave_cleared():
				_enter(boss, Step.TREMBLE)
		Step.TREMBLE:
			boss.velocity.x = 0.0
			if step_time >= config.tremble_time:
				_enter(boss, Step.LEAP_UP)
		Step.LEAP_UP:
			if _arc(boss, config.leap_up_time, 40.0):
				boss.global_position = _to
				_enter(boss, Step.COLLAPSE)
		Step.COLLAPSE:
			_hold_aloft(boss)
			if step_time >= config.crumble_time:
				_enter(boss, Step.BARRAGE)
		Step.BARRAGE:
			_hold_aloft(boss)
			if not _stage.barrage.running:
				_enter(boss, Step.SHIMMER)
		Step.SHIMMER:
			_hold_aloft(boss)
			if step_time >= config.shimmer_time:
				_enter(boss, Step.LAND)
		Step.LAND:
			boss.velocity.x = 0.0
			if (step_time > 0.15 and boss.is_on_floor()) or step_time >= 1.5:
				_enter(boss, Step.WINDOW)
		Step.WINDOW:
			boss.velocity.x = 0.0
			if step_time >= window_length:
				_enter(boss, Step.BACK_TO_PERCH)
		Step.BACK_TO_PERCH:
			if _arc(boss, config.perch_leap_time, config.perch_leap_arc):
				boss.global_position = _to
				boss.velocity = Vector2.ZERO
				_enter(boss, Step.DONE)
		Step.DONE:
			pass


func is_finished() -> bool:
	return _finished


func cancel(boss: BossBase) -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.cancel_all(false)
	boss.gravity_scale = 1.0
	boss.exhausted = false
	boss.velocity.x = 0.0
	_finished = true
	step = Step.DONE
	phase_name = &""
	cooldown_left = cooldown * boss.cooldown_factor()


func _finish(boss: BossBase) -> void:
	_stage.end_wave()
	cycles_completed += 1
	_finished = true
	phase_name = &""
	cooldown_left = cooldown * boss.cooldown_factor()
	cycle_completed.emit(cycles_completed)
	finished.emit()


## Enters a step: what the arena and the boss do at its start.
func _enter(boss: BossBase, next: Step) -> void:
	step = next
	step_time = 0.0
	phase_name = &"active"
	match next:
		Step.RISE:
			boss.exhausted = false
			_stage.raise_platforms()
		Step.TO_PERCH:
			_begin_arc(boss, _stage.perch_position())
		Step.SUMMON:
			boss.exhausted = false
			_batches = 0
			_stage.begin_wave()
		Step.TREMBLE:
			_stage.begin_tremble()
		Step.LEAP_UP:
			boss.gravity_scale = 0.0
			# Over the bare floor on the side away from the player.
			_side = -1 if boss.is_target_valid() and boss.target.global_position.x >= _stage.arena_center else 1
			_begin_arc(boss, _stage.aloft_position(_side))
		Step.COLLAPSE:
			_stage.collapse_floor()
		Step.BARRAGE:
			_stage.barrage.start()
		Step.SHIMMER:
			_stage.begin_shimmer()
		Step.LAND:
			# The floor returns and the boss, worn out, falls onto it (no contact damage while it is exhausted).
			boss.exhausted = true
			_stage.restore_floor()
			boss.gravity_scale = 1.0
			boss.velocity = Vector2.ZERO
		Step.WINDOW:
			boss.exhausted = true
		Step.BACK_TO_PERCH:
			boss.exhausted = false
			_begin_arc(boss, _stage.perch_position())
		Step.DONE:
			_finish(boss)
	step_changed.emit(STEP_NAMES[next])


func _begin_arc(boss: BossBase, target: Vector2) -> void:
	_from = boss.global_position
	_to = target
	boss.velocity = Vector2.ZERO


## Moves the boss along an arc between the two points over `seconds`; true when it got there.
func _arc(boss: BossBase, seconds: float, height: float) -> bool:
	var k: float = clampf(step_time / maxf(seconds, 0.01), 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, k)
	boss.global_position = _from.lerp(_to, eased) + Vector2(0.0, -height * 4.0 * k * (1.0 - k))
	boss.velocity = Vector2.ZERO
	return k >= 1.0


func _hold_aloft(boss: BossBase) -> void:
	boss.global_position = _stage.aloft_position(_side)
	boss.velocity = Vector2.ZERO

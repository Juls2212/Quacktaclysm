class_name PlatformBarrage
extends Node
## The barrage that crosses the arena at the height of EVERY platform while the floor is gone (Phase 15j). Events start `lane_gap` s apart; each
## one first shows a lane marker for `lane_telegraph` s (arrows and a pulsing stripe: shape + pulse, not color alone), then a projectile (the
## usual enemy Projectile, so the possession sequence clears it too) crosses from the wall it was announced from, alternating sides, and
## hurts 1 heart. The dash is fully invulnerable, so a well-timed dash is also a way through. THE PLAN ALWAYS LEAVES A SAFE PLATFORM: two lanes
## that overlap in time are never neighbours, so a neighbour of every dangerous platform is safe, and StageMath.neighbour_time /
## arrival_time give the worst-case margin that phase15j_smoke_test checks against the real player numbers. A lane's marker and projectile
## belong to the stage; stop() clears every projectile at once.

signal lane_announced(lane: int, side: int)
signal lane_fired(lane: int, side: int)
signal finished

var config: StageConfig = null
var stage: BossStage = null
## The events of the running barrage (see StageMath.barrage_plan) and which ones were announced and fired.
var events: Array[Dictionary] = []
var running: bool = false
var clock: float = 0.0
var projectiles: Array[Projectile] = []
var announced: int = 0
var fired: int = 0
var fired_count_total: int = 0

var _rng := RandomNumberGenerator.new()


func setup(new_stage: BossStage, new_config: StageConfig, seed_value: int = 0) -> void:
	stage = new_stage
	config = new_config
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


## Starts a barrage with a plan (null makes a fresh one).
func start(plan: Array[Dictionary] = []) -> void:
	events = plan if not plan.is_empty() else StageMath.barrage_plan(config, _rng, config.platform_heights.size())
	running = true
	clock = 0.0
	announced = 0
	fired = 0


## True while a lane marker shows, a projectile flies or events are still to come.
func is_busy() -> bool:
	return running or not alive_projectiles().is_empty()


func alive_projectiles() -> Array[Projectile]:
	projectiles = projectiles.filter(func(p: Projectile) -> bool: return is_instance_valid(p) and not p.is_queued_for_deletion())
	return projectiles


func _physics_process(delta: float) -> void:
	if not running:
		return
	clock += delta
	for i in events.size():
		var event: Dictionary = events[i]
		if i >= announced and clock >= float(event["start"]):
			announced = i + 1
			lane_announced.emit(int(event["lane"]), int(event["side"]))
		if i >= fired and clock >= float(event["start"]) + config.lane_telegraph:
			fired = i + 1
			_fire(int(event["lane"]), int(event["side"]))
	if fired >= events.size() and clock >= config.barrage_time:
		running = false
		finished.emit()


func _fire(lane: int, side: int) -> void:
	fired_count_total += 1
	lane_fired.emit(lane, side)
	if stage == null or config.barrage_projectile_scene == null or config.barrage_projectile_stats == null:
		return
	var container: Node = stage.get_parent()
	if container == null or not container.is_inside_tree():
		return
	var bolt := config.barrage_projectile_scene.instantiate() as Projectile
	container.add_child(bolt)
	var wall_x: float = stage.arena_left + 8.0 if side < 0 else stage.arena_right - 8.0
	bolt.global_position = Vector2(wall_x, StageMath.lane_y(config, stage.floor_top, lane))
	bolt.launch(Vector2(1.0 if side < 0 else -1.0, 0.0), CombatLayers.Team.ENEMY, config.barrage_projectile_stats, stage.boss)
	projectiles.append(bolt)


## Ends everything at once: no more events, every projectile gone.
func stop() -> void:
	running = false
	events = []
	announced = 0
	fired = 0
	for bolt in projectiles:
		if is_instance_valid(bolt):
			bolt.queue_free()
	projectiles.clear()


## What the stage fx draws: every announced lane with how far its telegraph has gone.
func get_draw_state() -> Dictionary:
	var lanes: Array[Dictionary] = []
	if running:
		for i in mini(announced, events.size()):
			var event: Dictionary = events[i]
			var since: float = clock - float(event["start"])
			if since <= config.lane_telegraph + 0.15:
				lanes.append({"lane": int(event["lane"]), "side": int(event["side"]), "progress": clampf(since / config.lane_telegraph, 0.0, 1.0)})
	return {"kind": &"barrage", "lanes": lanes}

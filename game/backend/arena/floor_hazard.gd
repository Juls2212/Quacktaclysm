class_name FloorHazard
extends Node2D
## Spikes that come out of the arena floor (Phase 15c). A cycle of WARNING (the floor glows red and bubbles, spikes
## peek out, nothing hurts) -> ACTIVE (spikes out, they hurt) -> REST (nothing), repeated while it runs. The timings
## come from `config`. It is started by the boss it is bound to when that boss enters phase 2 and stops AT ONCE when
## the boss dies, the fight is cancelled (encounter reset) or the target dies; it never runs outside the fight.
## Damage goes through the normal Hitbox / DamageInfo path (ENEMY team: it can hurt only the player, never the boss
## or its drops), so the hurt invulnerability and the dash invulnerability of the player apply; it is NOT a KillZone.
## Platforms and the raised lily pads sit above the dangerous band, so they are always safe (the floor under a pad is not).
## The node position is the LEFT end of the arena floor at its top surface; `length` runs to the right.
## Gameplay only: the drawing is the child FloorHazardArt (it listens to `state_changed`).

signal state_changed(new_state: int)
signal started
signal stopped

enum State { IDLE, WARNING, ACTIVE, REST }

@export var config: FloorHazardConfig
## Length of the floor covered, from this node position to the right.
@export_range(10.0, 5000.0, 1.0, "suffix:px") var length: float = 930.0
## The boss whose phase 2 starts the hazard.
@export var boss: BossBase

var state: State = State.IDLE
var state_time: float = 0.0
var running: bool = false
## Dangerous segments in LOCAL coordinates, rebuilt at each start.
var segments: Array[Rect2] = []
var cycles_completed: int = 0

var _hitbox: Hitbox = null
var _target: Node = null


func _ready() -> void:
	if config == null:
		config = FloorHazardConfig.get_default()
	_hitbox = get_node_or_null(^"Hitbox") as Hitbox
	set_physics_process(false)
	if boss != null:
		bind(boss)


## Connects the hazard to a boss: phase 2 starts it, the end of the fight stops it.
func bind(new_boss: BossBase) -> void:
	boss = new_boss
	if not boss.phase_changed.is_connected(_on_boss_phase_changed):
		boss.phase_changed.connect(_on_boss_phase_changed)
		boss.defeated.connect(_on_boss_defeated)
		boss.encounter_reset.connect(stop)
		boss.activated.connect(_on_boss_activated)


func _on_boss_activated() -> void:
	# A new fight starts clean and watches for the death of the player.
	stop()
	_target = boss.target
	if _target != null and _target.has_signal(&"died") and not _target.is_connected(&"died", stop):
		_target.connect(&"died", stop)


func _on_boss_phase_changed(new_phase: int) -> void:
	if new_phase >= 2:
		start()


func _on_boss_defeated(_defeated: Node) -> void:
	stop()


## Starts the cycle with a warning. Does nothing if it is already running.
func start() -> void:
	if running:
		return
	running = true
	_rebuild_segments()
	set_physics_process(true)
	started.emit()
	_set_state(State.WARNING)


## Stops at once: the spikes go away and nothing can hurt any more.
func stop() -> void:
	var was_running: bool = running
	running = false
	set_physics_process(false)
	if _hitbox != null:
		_hitbox.deactivate()
	if state != State.IDLE:
		_set_state(State.IDLE)
	if was_running:
		stopped.emit()


func is_dangerous() -> bool:
	return running and state == State.ACTIVE


func state_duration(of_state: State) -> float:
	match of_state:
		State.WARNING:
			return config.warning_time
		State.ACTIVE:
			return config.active_time
		State.REST:
			return config.rest_time
	return 0.0


func _physics_process(delta: float) -> void:
	state_time += delta
	if state_time < state_duration(state):
		return
	match state:
		State.WARNING:
			_set_state(State.ACTIVE)
		State.ACTIVE:
			_set_state(State.REST)
		State.REST:
			cycles_completed += 1
			_set_state(State.WARNING)


func _set_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	if _hitbox != null:
		if new_state == State.ACTIVE:
			_hitbox.activate()
		else:
			_hitbox.deactivate()
	state_changed.emit(int(new_state))


## The floor minus the lily pads, as a few rectangles (they are also the hitbox shapes).
func _rebuild_segments() -> void:
	segments.clear()
	var cuts: Array[Vector2] = []
	var pads_to_cut: Array = get_tree().get_nodes_in_group(BouncePad.GROUP) if config.cut_out_pads else []
	for pad in pads_to_cut:
		var span: Vector2 = (pad as BouncePad).global_x_range()
		cuts.append(Vector2(span.x - config.pad_margin - global_position.x, span.y + config.pad_margin - global_position.x))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor: float = 0.0
	for cut in cuts:
		if cut.x > cursor:
			segments.append(Rect2(cursor, -config.band_height, minf(cut.x, length) - cursor, config.band_height))
		cursor = maxf(cursor, cut.y)
	if cursor < length:
		segments.append(Rect2(cursor, -config.band_height, length - cursor, config.band_height))
	if _hitbox == null:
		return
	for child in _hitbox.get_children():
		if child is CollisionShape2D:
			_hitbox.remove_child(child)
			child.queue_free()
	_hitbox.damage = config.damage
	_hitbox.knockback = config.knockback
	_hitbox.rehit_interval = config.rehit_interval
	for rect in segments:
		if rect.size.x <= 0.0:
			continue
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		shape_node.position = rect.position + rect.size * 0.5
		_hitbox.add_child(shape_node)

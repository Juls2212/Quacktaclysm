class_name FloorHazardArt
extends Node2D
## The drawing of a FloorHazard (Phase 15c), in code: while the warning runs the floor glows red and bubbles and
## small spike tips peek out; while the spikes are active a row of tall spikes covers the dangerous segments.
## If `spike_texture` is set it is drawn for every spike instead of the code drawing (null = drawn in code).
## `GLOW`, `SPIKE` and `SPIKE_EDGE` are the colors the contrast test measures. Presentation only: it listens to
## the hazard `state_changed` and reads its segments and timings.

const GLOW := Color(1.0, 0.56, 0.36)
const BUBBLE := Color(1.0, 0.62, 0.42)
const SPIKE := Color(1.0, 0.93, 0.8)
const SPIKE_EDGE := Color(0.62, 0.05, 0.05)
const OUTLINE := Color(0.106, 0.098, 0.122, 0.95)
const SPIKE_WIDTH: float = 16.0
const SPIKE_HEIGHT: float = 30.0

## Optional replacement for the drawn spikes.
@export var spike_texture: Texture2D

var _hazard: FloorHazard = null
var _time: float = 0.0


func _ready() -> void:
	_hazard = get_parent() as FloorHazard
	z_index = 2
	if _hazard != null:
		_hazard.state_changed.connect(func(_state: int) -> void: queue_redraw())


## True when `spike_texture` is set and is drawn instead of the code drawing.
func uses_texture() -> bool:
	return spike_texture != null


func _process(delta: float) -> void:
	_time += delta
	if _hazard != null and _hazard.state != FloorHazard.State.IDLE:
		queue_redraw()


func _draw() -> void:
	if _hazard == null or _hazard.state == FloorHazard.State.IDLE or _hazard.state == FloorHazard.State.REST:
		return
	var warning: bool = _hazard.state == FloorHazard.State.WARNING
	var progress: float = clampf(_hazard.state_time / maxf(_hazard.state_duration(_hazard.state), 0.001), 0.0, 1.0)
	for rect in _hazard.segments:
		if rect.size.x <= 0.0:
			continue
		if warning:
			_draw_warning(rect, progress)
		else:
			_draw_spikes(rect, 1.0)


func _draw_warning(rect: Rect2, progress: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * (8.0 + 12.0 * progress))
	# The floor glows: a red band that gets brighter as the spikes get closer.
	draw_rect(Rect2(rect.position.x, -8.0, rect.size.x, 8.0), Color(GLOW, 0.35 + 0.35 * pulse))
	draw_rect(Rect2(rect.position.x, -3.0, rect.size.x, 3.0), Color(GLOW, 0.8))
	# Bubbles rising from the floor.
	var count: int = int(rect.size.x / 22.0)
	for i in count:
		var x: float = rect.position.x + 11.0 + float(i) * 22.0
		var rise: float = fposmod(_time * 0.9 + float(i) * 0.37, 1.0)
		draw_circle(Vector2(x, -4.0 - 16.0 * rise), 2.0 + 2.5 * (1.0 - rise), Color(BUBBLE, 0.8 * (1.0 - rise)))
	# Spike tips peeking out, growing with the warning.
	_draw_spikes(rect, 0.18 + 0.32 * progress)


func _draw_spikes(rect: Rect2, height_factor: float) -> void:
	var count: int = maxi(int(rect.size.x / SPIKE_WIDTH), 1)
	var width: float = rect.size.x / float(count)
	var height: float = SPIKE_HEIGHT * height_factor
	for i in count:
		var x0: float = rect.position.x + float(i) * width
		if spike_texture != null:
			draw_texture_rect(spike_texture, Rect2(x0, -height, width, height), false)
			continue
		var tip := Vector2(x0 + width * 0.5, -height)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 - 1.5, 1.0), Vector2(x0 + width + 1.5, 1.0), tip + Vector2(0, -2.5)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + width, 0.0), tip]), SPIKE_EDGE)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + width * 0.18, 0.0), Vector2(x0 + width * 0.82, 0.0), tip + Vector2(0, 4.0)]), SPIKE)

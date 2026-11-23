class_name EndingBeatList
extends Resource
## The script of one ending (Phase 15i): its beats in order, the color it fades out to, and the range its timed beats must add up to.
## Built by hand in default_kept_beats.tres / default_released_beats.tres and read by EndingCinematic and by the tests.

@export var beats: Array[EndingBeat] = []
@export var fade_color: Color = Color.BLACK
## The timed beats add up to a value inside this range (seconds), without counting the time the player takes to read the lines.
@export_range(10.0, 200.0, 1.0, "suffix:s") var min_seconds: float = 45.0
@export_range(10.0, 200.0, 1.0, "suffix:s") var max_seconds: float = 75.0


@export_group("Fail-safes and cost")
## No beat can deadlock: a timed beat never lasts more than this, a LINE beat waits for the confirm action at most this long (a stuck
## input never traps the player) and the whole ending never lasts more than the total.
@export_range(5.0, 120.0, 1.0, "suffix:s") var max_beat_seconds: float = 30.0
@export_range(10.0, 600.0, 1.0, "suffix:s") var max_line_seconds: float = 120.0
@export_range(60.0, 1800.0, 1.0, "suffix:s") var max_total_seconds: float = 600.0
## Frames slower than this many milliseconds, for `slow_window_seconds` in a row, switch the scene to its light mode (static layers).
@export_range(10.0, 200.0, 1.0, "suffix:ms") var slow_frame_ms: float = 45.0
@export_range(0.2, 5.0, 0.1, "suffix:s") var slow_window_seconds: float = 1.0
## How often the big background layers are redrawn (they only twinkle; the camera moves them without redrawing).
@export_range(1.0, 60.0, 1.0, "suffix:Hz") var layer_redraw_hz: float = 12.0
## The tests' budgets: a whole play-through (lines answered at once) must end within this wall time, and a frame must cost less than this on average.
@export_range(30.0, 600.0, 1.0, "suffix:s") var wall_budget_seconds: float = 150.0
@export_range(5.0, 100.0, 1.0, "suffix:ms") var frame_cost_limit_ms: float = 30.0


func timed_seconds() -> float:
	var total: float = 0.0
	for beat in beats:
		if not beat.is_line():
			total += beat.seconds
	return total


func line_beats() -> Array[EndingBeat]:
	var out: Array[EndingBeat] = []
	for beat in beats:
		if beat.is_line():
			out.append(beat)
	return out


func index_of(beat_id: StringName) -> int:
	for i in beats.size():
		if beats[i].id == beat_id:
			return i
	return -1

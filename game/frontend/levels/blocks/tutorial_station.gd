class_name TutorialStation
extends Node2D
## A practice station of the tutorial (Phase 15m): a wooden signpost standing on the floor with the name of the step on its board, a small
## lantern that glows green with a check mark when the step is done, and a soft pool of light on the ground. Drawn by code (no art files);
## visual only: TutorialController sets `done` when the step is credited. The title comes from the tutorial texts by `step_id`.

const INK := Color(0.106, 0.098, 0.122)
const WOOD := Color(0.55, 0.38, 0.22)
const BOARD := Color(0.74, 0.62, 0.43)
const GREEN := Color(0.4, 0.95, 0.5)
const AMBER := Color(1.0, 0.8, 0.45)

@export var step_id: String = ""
@export_range(60.0, 200.0, 1.0, "suffix:px") var board_width: float = 92.0

var done: bool = false:
	set(value):
		done = value
		queue_redraw()
var title: String = ""

var _time: float = 0.0
var _font: Font
var _reduced: bool = false


func _ready() -> void:
	add_to_group(&"tutorial_station")
	z_index = -1
	_font = GameFonts.BODY
	_reduced = not GameSettings.is_corruption_effects_enabled()
	var step: Dictionary = TutorialTexts.get_default().step_by_id(step_id)
	title = String(step.get("station", step_id.to_upper()))
	queue_redraw()


func _process(delta: float) -> void:
	if _reduced:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var glow: Color = GREEN if done else AMBER
	var pulse: float = 1.0 if _reduced else 0.75 + 0.25 * sin(_time * 2.4)
	# A pool of light on the floor.
	for k in 3:
		draw_colored_polygon(_ellipse(Vector2(0, -2), board_width * (0.7 - 0.15 * float(k)), 9.0 - 2.0 * float(k)), Color(glow, 0.08 * pulse))
	# The post and the board.
	draw_rect(Rect2(-5, -88, 10, 88), INK)
	draw_rect(Rect2(-3, -86, 6, 86), WOOD)
	var board := Rect2(-board_width * 0.5, -122, board_width, 40)
	draw_rect(Rect2(board.position + Vector2(3, 3), board.size), Color(0, 0, 0, 0.3))
	draw_rect(board, INK)
	draw_rect(board.grow(-3.0), BOARD)
	var label: String = title
	var size: Vector2 = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(_font, Vector2(-size.x * 0.5, board.position.y + 25.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	# The lantern: amber until done, then green with a check mark.
	var lamp := Vector2(board.end.x - 4.0, board.position.y - 8.0)
	draw_circle(lamp, 13.0 * pulse + 4.0, Color(glow, 0.2))
	draw_circle(lamp, 8.0, INK)
	draw_circle(lamp, 6.0, glow)
	if done:
		draw_polyline(PackedVector2Array([lamp + Vector2(-3, 0), lamp + Vector2(-1, 3), lamp + Vector2(4, -3)]), INK, 2.0, true)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

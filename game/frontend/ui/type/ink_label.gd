@tool
class_name InkLabel
extends Control
## A line of text set in InkType ("Pato Tinta"), the game's display lettering.
## Sizes itself to the text; `wave` makes the letters bob in a travelling wave.

enum Align { LEFT, CENTER, RIGHT }

@export var text: String = "Quacktaclysm":
	set(value):
		text = value
		update_minimum_size()
		queue_redraw()
## Cap height in pixels.
@export var cap_height: float = 48.0:
	set(value):
		cap_height = value
		update_minimum_size()
		queue_redraw()
@export var align: Align = Align.CENTER:
	set(value):
		align = value
		queue_redraw()
@export var fill: Color = Color(0.98, 0.83, 0.42):
	set(value):
		fill = value
		queue_redraw()
@export var extrude: Color = Color(0.42, 0.24, 0.14):
	set(value):
		extrude = value
		queue_redraw()
@export_range(0.0, 3.0, 0.05) var depth: float = 0.9
@export_range(0.0, 2.0, 0.05) var wobble: float = 1.0
## Units of travelling bob (0 = still).
@export_range(0.0, 2.0, 0.05) var wave: float = 0.0

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if wave > 0.0:
		_time += delta
		queue_redraw()


func _get_minimum_size() -> Vector2:
	var u: float = cap_height / 10.0
	# Room for accents above, the extrusion and outline below.
	return Vector2(InkType.measure(text, cap_height) + u * (InkType.STROKE + 2.0), cap_height + u * 7.0)


func _draw() -> void:
	var style := InkType.Style.new()
	style.fill = fill
	style.extrude = extrude
	style.depth = depth
	style.wobble = wobble
	style.wave = wave
	style.time = _time
	var u: float = cap_height / 10.0
	var width: float = InkType.measure(text, cap_height)
	var x: float = u * InkType.STROKE * 0.5 + u
	match align:
		Align.CENTER:
			x = (size.x - width) * 0.5
		Align.RIGHT:
			x = size.x - width - u * (InkType.STROKE * 0.5 + 1.0)
	var y: float = (size.y - cap_height) * 0.5 - u * 0.6
	InkType.draw(self, text, Vector2(x, y), cap_height, style)

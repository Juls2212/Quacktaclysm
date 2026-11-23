class_name TutorialHud
extends Control
## The tutorial's checklist (top-left, every step with a check mark when done) and the skip hint with its hold bar (bottom centre), drawn by
## code (Phase 15m). Visual only: TutorialController feeds it through `setup`, `set_done`, `set_hold` and `refresh_keys`; it never decides
## anything. Key names come from the controls catalog, so remaps show up (`refresh_keys`).

const INK := Color(0.106, 0.098, 0.122)
const PAPER := Color(0.92, 0.87, 0.74)
const CARD := Color(0.74, 0.62, 0.43)
const GREEN := Color(0.25, 0.62, 0.3)
const ROW_HEIGHT: float = 28.0
const PANEL_WIDTH: float = 300.0

var rows: Array[Dictionary] = []
var title: String = ""
var note: String = ""
var skip_template: String = ""
var hold: float = 0.0
var reduced: bool = false

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = GameFonts.BODY
	reduced = not GameSettings.is_corruption_effects_enabled()


## Builds the rows from the tutorial's texts and steps.
func setup(texts: TutorialTexts, steps: Array[Dictionary]) -> void:
	title = texts.checklist_title
	note = texts.abilities_note
	skip_template = texts.skip_hint
	rows.clear()
	for step in steps:
		rows.append({"id": String(step["id"]), "template": String(step.get("short", step["id"])), "required": bool(step.get("required", true)), "done": false, "age": 99.0})
	refresh_keys()


func set_done(step_id: String, value: bool) -> void:
	for row in rows:
		if row["id"] == step_id:
			row["done"] = value
			row["age"] = 0.0
	queue_redraw()


func set_hold(progress: float) -> void:
	hold = clampf(progress, 0.0, 1.0)
	queue_redraw()


## Re-reads the key names (after a remap).
func refresh_keys() -> void:
	for row in rows:
		row["text"] = resolve(String(row["template"]))
	queue_redraw()


func resolve(template: String) -> String:
	var result: String = template
	for action in InputMap.get_actions():
		var token: String = "{%s}" % action
		if result.contains(token):
			result = result.replace(token, ControlsConfig.input_map_hint(action))
	return result


func done_count() -> int:
	var n: int = 0
	for row in rows:
		n += 1 if row["done"] else 0
	return n


func _process(delta: float) -> void:
	if reduced:
		return
	for row in rows:
		row["age"] = float(row["age"]) + delta
	queue_redraw()


func _draw() -> void:
	if rows.is_empty() or _font == null:
		return
	var height: float = 46.0 + ROW_HEIGHT * float(rows.size()) + 34.0
	var rect := Rect2(Vector2(18.0, 18.0), Vector2(PANEL_WIDTH, height))
	draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size), Color(0, 0, 0, 0.35))
	draw_rect(rect, Color(PAPER, 0.93))
	draw_rect(rect, INK, false, 3.0)
	draw_string(_font, rect.position + Vector2(16, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y: float = rect.position.y + 46.0 + ROW_HEIGHT * float(i)
		var box := Rect2(Vector2(rect.position.x + 16.0, y + 2.0), Vector2(18, 18))
		draw_rect(box, Color(1, 1, 1, 0.6))
		draw_rect(box, INK, false, 2.0)
		var pop: float = 1.0 if reduced else minf(float(row["age"]) / 0.25, 1.0)
		if row["done"]:
			var tick := PackedVector2Array([box.position + Vector2(3, 9), box.position + Vector2(8, 14), box.position + Vector2(16, 3)])
			draw_polyline(tick, Color(GREEN, pop), 3.0 * (0.5 + 0.5 * pop), true)
		var color: Color = INK if not row["done"] else Color(INK, 0.5)
		var suffix: String = "" if row["required"] else ""
		draw_string(_font, Vector2(box.end.x + 12.0, y + 17.0), String(row.get("text", "")) + suffix, HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - 70.0, 16, color)
	draw_string(_font, rect.position + Vector2(16, height - 12.0), note, HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - 26.0, 13, Color(INK, 0.75))
	# The skip hint, bottom centre, with its hold bar.
	var hint: String = resolve(skip_template)
	var size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var width: float = 360.0
	var at := Vector2((size.x - width) * 0.5, size.y - 64.0)
	draw_string(_font, at + Vector2(0, 16), hint, HORIZONTAL_ALIGNMENT_CENTER, width, 16, Color(1, 1, 1, 0.85))
	draw_rect(Rect2(at + Vector2(0, 26), Vector2(width, 8)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(at + Vector2(0, 26), Vector2(width * hold, 8)), Color(0.95, 0.8, 0.35))
	draw_rect(Rect2(at + Vector2(0, 26), Vector2(width, 8)), INK, false, 2.0)

class_name InkType
extends RefCounted
## The game's display lettering for big titles, set in "Rubik Wet Paint" (GameFonts.TITLE) and
## dressed like the duck art: a stacked extrusion toward the lower right, a thick ink outline, a
## light rim on the upper left and the fill, with a hand-set tilt and bounce per letter and an
## optional travelling wave. Lowercase input is set in capitals.
## `height` is the cap height in pixels; `origin` is the top-left of the capitals (cap line).

## Kept for callers that size boxes in cap units (u = height / 10).
const STROKE: float = 2.3
## Extra space between letters, in cap units.
const SPACING: float = 0.35


## Look of a run of text. Colors follow the duck art: ink outline, warm fill, deep extrusion.
class Style:
	var fill: Color = Color(0.98, 0.83, 0.42)
	var extrude: Color = Color(0.42, 0.24, 0.14)
	var ink: Color = Color(0.106, 0.098, 0.122)
	var highlight: Color = Color(1.0, 0.97, 0.86, 0.75)
	## Depth of the extrusion in units (down-right).
	var depth: float = 0.9
	## 0 = rigid, 1 = full hand-set tilt and bounce per letter.
	var wobble: float = 1.0
	## Units of vertical wave travelling along the word (animated with `time`).
	var wave: float = 0.0
	var time: float = 0.0
	## Transform the caller is already drawing with (restored afterwards).
	var base: Transform2D = Transform2D.IDENTITY


## Width in pixels of `text` at cap `height` (the real advances of the font).
static func measure(text: String, height: float) -> float:
	var size: int = GameFonts.title_size(height)
	var u: float = height / 10.0
	var w: float = 0.0
	var chars: String = text.to_upper()
	for i in chars.length():
		w += _advance(chars[i], size) + SPACING * u
	return maxf(w - SPACING * u, 0.0)


## Draws `text` on `canvas` with its cap line at `origin.y` and starting at `origin.x`.
static func draw(canvas: CanvasItem, text: String, origin: Vector2, height: float, style: Style) -> void:
	var font: Font = GameFonts.TITLE
	var size: int = GameFonts.title_size(height)
	var u: float = height / 10.0
	var outline: int = maxi(int(roundf(height * 0.2)), 3)
	var chars: String = text.to_upper()
	# Every pass runs over the whole word, so outlines of neighbours never cut into fills.
	for pass_index in 4:
		var x: float = 0.0
		for i in chars.length():
			var ch: String = chars[i]
			var adv: float = _advance(ch, size)
			if ch != " ":
				var tilt: float = sin(float(i) * 2.17 + 0.6) * 0.05 * style.wobble
				var lift: float = sin(float(i) * 1.31 + 1.4) * 0.35 * style.wobble
				lift += sin(style.time * 3.0 - float(i) * 0.55) * style.wave
				# Tilt each letter about its own middle.
				var center := Vector2(adv * 0.5, height * 0.5)
				var xf: Transform2D = style.base * Transform2D(tilt, origin + Vector2(x, lift * u) + center) * Transform2D(0.0, -center)
				canvas.draw_set_transform_matrix(xf)
				var baseline := Vector2(0.0, height)
				var code: int = ch.unicode_at(0)
				match pass_index:
					0:
						# Extrusion: the letter repeated toward the lower right, outlined, like a cut block.
						var steps: int = maxi(int(style.depth * 3.0), 1)
						for s in range(steps, 0, -1):
							var off := Vector2(0.45, 0.65) * style.depth * u * float(s) / float(steps)
							font.draw_char_outline(canvas.get_canvas_item(), baseline + off, code, size, outline, style.ink)
							font.draw_char(canvas.get_canvas_item(), baseline + off, code, size, style.extrude)
					1:
						font.draw_char_outline(canvas.get_canvas_item(), baseline, code, size, outline, style.ink)
					2:
						# A light rim on the upper left, just inside the ink.
						font.draw_char(canvas.get_canvas_item(), baseline + Vector2(-0.28, -0.32) * u, code, size, style.highlight)
					3:
						font.draw_char(canvas.get_canvas_item(), baseline, code, size, style.fill)
			x += adv + SPACING * u
	canvas.draw_set_transform_matrix(style.base)


static func _advance(ch: String, size: int) -> float:
	return GameFonts.TITLE.get_char_size(ch.unicode_at(0), size).x

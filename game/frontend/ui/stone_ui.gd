class_name StoneUi
extends RefCounted
## Drawing helpers for the stone HUD bars, in the game's thick-ink style: a chipped blue-grey
## stone frame with a highlight and small cracks, a dark well, a glossy gradient fill and a round
## stone (for the heart). Static; they draw on the CanvasItem they are given. Visual only.

const INK := Color(0.106, 0.098, 0.122)
const STONE_TOP := Color("8a9aa6")
const STONE_BOTTOM := Color("5a6a76")
const STONE_SHINE := Color(0.82, 0.88, 0.92, 0.75)
const WELL := Color(0.06, 0.05, 0.07)
const MOSS := Color(0.4, 0.66, 0.25)
const MOSS_DARK := Color(0.24, 0.44, 0.16)


static func hash01(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 4.1414) * 43758.5453
	return v - floorf(v)


## Irregular chipped outline around `rect` grown by `border` (clockwise), seeded by `salt`.
static func frame_points(rect: Rect2, border: float, salt: int) -> PackedVector2Array:
	var r: Rect2 = rect.grow(border)
	var pts := PackedVector2Array()
	var chip: float = border * 0.9
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for c in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var dir: Vector2 = (b - a).normalized()
		var normal: Vector2 = Vector2(dir.y, -dir.x)
		# Chipped corner: cut it diagonally.
		pts.append(a + dir * chip * (0.6 + hash01(salt + c * 5) * 0.8))
		var length: float = a.distance_to(b)
		var steps: int = maxi(int(length / 18.0), 1)
		for i in range(1, steps):
			var u: float = float(i) / float(steps)
			var jitter: float = (hash01(salt + c * 97 + i * 7) - 0.45) * border * 0.45
			# A notch knocked out of the edge now and then.
			if hash01(salt + c * 31 + i * 3) > 0.86:
				jitter -= border * 0.45
			pts.append(a.lerp(b, u) + normal * jitter)
		pts.append(b - dir * chip * (0.6 + hash01(salt + c * 5 + 2) * 0.8))
	return pts


## The stone frame: gradient body, thick ink outline, highlight along the top and small cracks.
static func frame(ci: CanvasItem, rect: Rect2, border: float, salt: int) -> void:
	var pts: PackedVector2Array = frame_points(rect, border, salt)
	var top: float = rect.position.y - border
	var height: float = rect.size.y + border * 2.0
	var colors := PackedColorArray()
	for p in pts:
		colors.append(STONE_TOP.lerp(STONE_BOTTOM, clampf((p.y - top) / height, 0.0, 1.0)))
	ci.draw_polygon(pts, colors)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	ci.draw_polyline(closed, INK, 3.6, true)
	# Highlight just inside the top edge.
	ci.draw_line(Vector2(rect.position.x - border * 0.4, top + 2.6), Vector2(rect.end.x + border * 0.3, top + 2.6), STONE_SHINE, 1.6, true)
	# Small cracks running in from the edges.
	var cracks: int = maxi(int(rect.size.x / 60.0), 2)
	for k in cracks:
		var x: float = lerpf(rect.position.x, rect.end.x, (float(k) + 0.3 + hash01(salt + k * 13) * 0.4) / float(cracks))
		var from_top: bool = k % 2 == 0
		var y0: float = top + 1.0 if from_top else rect.end.y + border - 1.0
		var sgn: float = 1.0 if from_top else -1.0
		var crack := PackedVector2Array([Vector2(x, y0), Vector2(x + 2.0, y0 + sgn * border * 0.35), Vector2(x - 1.5, y0 + sgn * border * 0.65)])
		ci.draw_polyline(crack, Color(INK, 0.6), 1.2, true)


## The dark well inside the frame, with an ink rim.
static func well(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, WELL)
	ci.draw_rect(rect.grow(0.5), Color(INK, 0.9), false, 1.6)


## A glossy fill: a vertical gradient through three colours and a shine along the top.
static func fill(ci: CanvasItem, rect: Rect2, light: Color, mid: Color, dark: Color, shine: Color) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	var y0: float = rect.position.y
	var ym: float = rect.position.y + rect.size.y * 0.45
	var y1: float = rect.end.y
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, ym), Vector2(x0, ym)]), PackedColorArray([light, light, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(x0, ym), Vector2(x1, ym), Vector2(x1, y1), Vector2(x0, y1)]), PackedColorArray([mid, mid, dark, dark]))
	ci.draw_line(Vector2(x0 + 1.0, y0 + 1.6), Vector2(x1 - 1.0, y0 + 1.6), shine, maxf(rect.size.y * 0.14, 1.2), true)


## A round chipped stone with a highlight (the heart sits in it).
static func round_stone(ci: CanvasItem, c: Vector2, r: float, salt: int) -> void:
	var pts := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 22:
		var a: float = TAU * float(i) / 22.0
		var k: float = 0.93 + hash01(salt + i * 3) * 0.1
		if hash01(salt + i * 11) > 0.88:
			k -= 0.07
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * r * k
		pts.append(p)
		colors.append(STONE_TOP.lerp(STONE_BOTTOM, clampf((p.y - (c.y - r)) / (r * 2.0), 0.0, 1.0)))
	ci.draw_polygon(pts, colors)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	ci.draw_polyline(closed, INK, 3.6, true)
	ci.draw_arc(c, r * 0.8, PI * 1.12, PI * 1.62, 10, STONE_SHINE, 2.0, true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.55, r * 0.55), c + Vector2(r * 0.4, r * 0.75), c + Vector2(r * 0.5, r * 0.92)]), Color(INK, 0.6), 1.2, true)


## Text centred on `at`, letters spaced out, with a thick ink outline.
static func spaced_text(ci: CanvasItem, at: Vector2, text: String, size: int, color: Color, outline: int) -> void:
	var spaced: String = ""
	for i in text.length():
		spaced += text[i]
		if i < text.length() - 1:
			spaced += " " if text[i] != " " else "   "
	var font: Font = GameFonts.BODY
	var w: float = font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(at.x - w * 0.5, at.y)
	ci.draw_string_outline(font, pos, spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
	ci.draw_string(font, pos, spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

class_name CorruptionMarks
extends RefCounted
## The corruption of the hero's duck, drawn INSIDE the rig's own parts (Phase 15o; it replaces the CorruptionVeins node laid over the duck in
## Phase 15l). It is not a node: the DuckRig owns one of these, asks it for the veins of a region (body, neck or head), clips every branch to that
## part's polygon so a vein never leaves the body, and draws them in the rig's own space and ink (so they move with every animation, keep the rig's
## outline weight and the same palette). The branches grow from the roots of a CorruptionVeinsStyle (colors, widths, tiers, seed: all data); the
## same seed always grows the same veins. Tier 1 = the first kept fragment (faint, arm and neck), tier 2 = the chest and the edge of the face,
## tier 3 = widespread. Presentation only.

enum Region { BODY, HEAD }

var style: CorruptionVeinsStyle = null
## The grown branches: {pts: PackedVector2Array, start: float, tier: int, region: int, width: float}.
var branches: Array[Dictionary] = []


func _init(p_style: CorruptionVeinsStyle = null) -> void:
	style = p_style if p_style != null else CorruptionVeinsStyle.get_default()
	rebuild()


## Grows every branch from the style's roots (deterministic).
func rebuild() -> void:
	branches.clear()
	if style == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = style.random_seed
	for i in style.root_points.size():
		var dir: Vector2 = style.root_directions[i].normalized()
		var tier: int = style.root_tiers[i]
		var step_len: float = style.root_lengths[i] / float(style.trunk_steps)
		var p: Vector2 = style.root_points[i]
		var trunk := PackedVector2Array([p])
		var heading: float = dir.angle()
		var base_heading: float = heading
		var region_of: int = Region.HEAD if p.y < style.head_line_y else Region.BODY
		var order: float = float(i) / float(maxi(style.root_points.size() - 1, 1))
		var start: float = style.max_delay * (0.0 if tier == 1 else (0.5 if tier == 2 else 1.0)) * 0.5 + style.max_delay * 0.5 * order
		var twig_roots: Array[Vector2] = []
		var twig_heads: Array[float] = []
		for s in style.trunk_steps:
			heading += rng.randf_range(-style.wiggle, style.wiggle) + angle_difference(heading, base_heading) * 0.25
			p = p + Vector2.from_angle(heading) * step_len
			trunk.append(p)
			if s >= 1 and s < style.trunk_steps - 1 and rng.randf() < style.twig_chance:
				twig_roots.append(p)
				twig_heads.append(heading + (style.twig_angle if rng.randf() < 0.5 else -style.twig_angle))
		branches.append({"pts": trunk, "start": start, "tier": tier, "region": region_of, "width": style.trunk_width})
		for t in twig_roots.size():
			var q: Vector2 = twig_roots[t]
			var twig := PackedVector2Array([q])
			var h: float = twig_heads[t]
			for s in style.twig_steps:
				h += rng.randf_range(-style.wiggle, style.wiggle)
				q = q + Vector2.from_angle(h) * step_len * style.twig_scale
				twig.append(q)
			branches.append({"pts": twig, "start": minf(start + 0.12, 0.95), "tier": tier, "region": region_of, "width": style.trunk_width * style.twig_width_scale})


## How much of a branch shows: tiers below `stage` are fully grown, the tier of the stage itself grows with `growth` (0..1), higher ones are hidden.
func progress_of(branch: Dictionary, stage: int, growth: float) -> float:
	var tier: int = int(branch["tier"])
	if tier > stage or stage <= 0:
		return 0.0
	if tier < stage:
		return 1.0
	var start: float = float(branch["start"])
	return clampf((growth - start) / maxf(1.0 - start, 0.15) * 1.35, 0.0, 1.0)


## The part of a branch revealed up to `progress` (0..1 of its length).
static func revealed(pts: PackedVector2Array, progress: float) -> PackedVector2Array:
	var total: float = 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var remaining: float = total * progress
	var line := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var seg: float = pts[i].distance_to(pts[i + 1])
		if remaining >= seg:
			line.append(pts[i + 1])
			remaining -= seg
		else:
			if seg > 0.0:
				line.append(pts[i].lerp(pts[i + 1], remaining / seg))
			break
	return line


## The visible pieces of the veins of `region`, already clipped to `polygons` (the part's outline, shrunk a little so the ink outline stays clean):
## an array of {pts, width, tier}. Nothing is returned for stage 0 or an empty growth.
func clipped_pieces(region: int, polygons: Array, stage: int, growth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if stage <= 0 or style == null:
		return out
	var inner: Array = []
	for polygon: Variant in polygons:
		for shrunk: Variant in Geometry2D.offset_polygon(polygon as PackedVector2Array, -style.clip_margin):
			inner.append(shrunk as PackedVector2Array)
	if inner.is_empty():
		return out
	for branch in branches:
		if int(branch["region"]) != region:
			continue
		var progress: float = progress_of(branch, stage, growth)
		if progress <= 0.0:
			continue
		var line: PackedVector2Array = revealed(branch["pts"] as PackedVector2Array, progress)
		if line.size() < 2:
			continue
		for polygon: Variant in inner:
			for piece: Variant in Geometry2D.intersect_polyline_with_polygon(line, polygon as PackedVector2Array):
				if (piece as PackedVector2Array).size() >= 2:
					out.append({"pts": piece, "width": float(branch["width"]), "tier": int(branch["tier"])})
	return out


## Draws clipped pieces on `canvas` (the rig) in its own ink language: a dark ink edge, a purple core that tapers and a thin highlight.
## `strength` scales the opacity, `reduced` draws static and thinner.
func draw_pieces(canvas: CanvasItem, pieces: Array[Dictionary], strength: float, reduced: bool) -> void:
	var thin: float = style.reduced_width_scale if reduced else 1.0
	for piece in pieces:
		var pts: PackedVector2Array = piece["pts"]
		var tier_k: float = style.tier_alpha[clampi(int(piece["tier"]) - 1, 0, style.tier_alpha.size() - 1)] * strength
		var w: float = float(piece["width"]) * thin
		canvas.draw_polyline(pts, Color(style.outline_color, style.outline_color.a * tier_k), w + style.outline_extra, true)
		for i in pts.size() - 1:
			var taper: float = 1.0 - 0.5 * float(i) / float(maxi(pts.size() - 2, 1))
			canvas.draw_line(pts[i], pts[i + 1], Color(style.core_color, style.core_color.a * tier_k), w * taper, true)
		if not reduced:
			canvas.draw_polyline(pts, Color(style.highlight_color, style.highlight_color.a * tier_k), maxf(w * 0.3, 0.5), true)


## A clouded iris INSIDE the eye's own sclera (the rig's eye keeps its lids on top): a violet rim, a milky middle with cracks, a small dark pupil.
## `cloud` is 0..1; nothing is drawn below 0.02.
static func draw_iris(canvas: CanvasItem, center: Vector2, radius: float, cloud: float, pulse: float) -> void:
	if cloud <= 0.02:
		return
	var ink := Color(0.106, 0.098, 0.122)
	canvas.draw_circle(center, radius * 0.78, Color(ink, 0.9 * cloud))
	for i in 4:
		var k: float = float(i) / 3.0
		var color: Color = Color(0.3, 0.1, 0.45).lerp(Color(0.74, 0.58, 0.9), k)
		canvas.draw_circle(center, radius * 0.72 * (1.0 - 0.7 * k), Color(color, 0.95 * cloud))
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + 0.3
		canvas.draw_line(center + Vector2.from_angle(a) * radius * 0.2, center + Vector2.from_angle(a + 0.12) * radius * 0.62, Color(0.12, 0.03, 0.2, 0.7 * cloud), 0.4, true)
	canvas.draw_circle(center + Vector2(0.1, 0.05), radius * 0.2, Color(0.08, 0.04, 0.12, 0.95 * cloud))
	canvas.draw_circle(center + Vector2(-radius * 0.22, -radius * 0.24), radius * 0.12, Color(1.0, 0.95, 1.0, (0.55 + 0.25 * pulse) * cloud))

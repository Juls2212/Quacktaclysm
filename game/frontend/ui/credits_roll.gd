class_name CreditsRoll
extends RefCounted
## Builds the credits column (Phase 15t) from the ONE credits resource, for the main menu and for the end of the game. The text never gets
## clipped: every label wraps at `width` and the column takes the height it needs (the caller measures it with `column_height`).

const GAP: float = 26.0


## Fills `roll` with one block per section. `style` keys (all optional): title_variation, header_variation, line_variation, note_variation,
## notice_variation (theme variations), sizes {title, header, line, note} and colors {title, header, line, note} (used when set).
static func fill(roll: VBoxContainer, content: CreditsContent, width: float, include_notice: bool, style: Dictionary = {}) -> void:
	for child in roll.get_children():
		child.queue_free()
		roll.remove_child(child)
	roll.add_theme_constant_override(&"separation", 8)
	var notice: String = StoryTexts.get_default().content_notice
	for section: Dictionary in content.sections(notice, include_notice):
		add_section(roll, section, width, style)


## One section (title, list or notice) as labels in `box`.
static func add_section(box: VBoxContainer, section: Dictionary, width: float, style: Dictionary = {}) -> void:
	var kind: String = String(section["kind"])
	var title: String = String(section["title"])
	if kind == "title":
		box.add_child(_label(title, "title", width, style))
		for line in section["lines"] as PackedStringArray:
			box.add_child(_label(line, "note", width, style))
		return
	box.add_child(_spacer(GAP))
	box.add_child(_label(title, "header", width, style))
	var role: String = "note" if kind == "notice" else "line"
	for line in section["lines"] as PackedStringArray:
		box.add_child(_label(line, role, width, style))
	if not String(section["note"]).is_empty():
		box.add_child(_label(String(section["note"]), "note", width, style))


## Height the column needs for `width` (the labels wrap, so it is read after a layout pass).
static func column_height(roll: VBoxContainer) -> float:
	return roll.get_combined_minimum_size().y


static func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


static func _label(text: String, role: String, width: float, style: Dictionary) -> Label:
	var label := Label.new()
	label.name = "Credit_" + role
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var variation: StringName = StringName(style.get(role + "_variation", ""))
	if variation != &"":
		label.theme_type_variation = variation
	var sizes: Dictionary = style.get("sizes", {})
	if sizes.has(role):
		label.add_theme_font_size_override(&"font_size", int(sizes[role]))
	var colors: Dictionary = style.get("colors", {})
	if colors.has(role):
		label.add_theme_color_override(&"font_color", colors[role] as Color)
	return label

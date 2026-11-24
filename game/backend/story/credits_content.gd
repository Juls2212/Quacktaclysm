class_name CreditsContent
extends Resource
## The credits of the game (Phase 15t): ONE resource (default_credits_content.tres) read by the «Créditos» section of the main menu AND by the
## credits that roll at the end of both endings. Every text lives here, nothing in code. Developers appear by NAME only (no roles).
## Every audio file, font or library added to the game needs its source and license written here (see HANDOFF).
## The line of support is NOT here: it stays on the final card of the endings.

const DEFAULT_PATH: String = "res://backend/story/default_credits_content.tres"

@export var game_title: String = "QUACKTACLYSM"
@export var tagline: String = ""
## Masthead of the menu panel (the front page of the last newspaper).
@export_multiline var masthead: String = ""
@export_group("Developers")
@export var developers_title: String = "Desarrollo"
## Names only.
@export var developers: PackedStringArray = PackedStringArray()
@export_group("Technology")
@export var technology_title: String = "Tecnología"
@export var technology_lines: PackedStringArray = PackedStringArray()
## The note shown under the AI Director line (the option in Options is called «Adaptación con IA»).
@export_multiline var ai_note: String = ""
@export_group("Music and sound effects")
@export var audio_title: String = "Música y efectos de sonido"
## One line per group of files: «what: author, license, source». Where the source is not documented the line says so in a neutral way.
@export var audio_lines: PackedStringArray = PackedStringArray()
@export var fonts_title: String = "Tipografías"
@export var fonts_lines: PackedStringArray = PackedStringArray()
@export_group("Thanks")
@export var thanks_title: String = "Agradecimientos"
## Editable: the person who helped with the ambient sounds, and the general thanks.
@export var thanks_lines: PackedStringArray = PackedStringArray()
@export_group("Content notice")
@export var notice_title: String = "Aviso de contenido"
@export_group("")
## Pixels per second the credits roll in the menu and at the end.
@export_range(10.0, 120.0, 1.0, "suffix:px/s") var menu_speed: float = 26.0
@export_range(10.0, 120.0, 1.0, "suffix:px/s") var ending_speed: float = 34.0


static func get_default() -> CreditsContent:
	return load(DEFAULT_PATH) as CreditsContent


## The sections in order, each a Dictionary {kind, title, lines (PackedStringArray), note (String)}. `kind` is "title", "list" or "notice".
## `include_notice` adds the content notice as the last section (the menu shows it apart, always visible, so it leaves it out of the roll).
func sections(notice_text: String, include_notice: bool = true) -> Array:
	var out: Array = []
	out.append({"kind": "title", "title": game_title, "lines": PackedStringArray([tagline] if not tagline.is_empty() else []), "note": ""})
	out.append({"kind": "list", "title": developers_title, "lines": developers, "note": ""})
	out.append({"kind": "list", "title": technology_title, "lines": technology_lines, "note": ai_note})
	out.append({"kind": "list", "title": audio_title, "lines": audio_lines, "note": ""})
	out.append({"kind": "list", "title": fonts_title, "lines": fonts_lines, "note": ""})
	out.append({"kind": "list", "title": thanks_title, "lines": thanks_lines, "note": ""})
	if include_notice and not notice_text.is_empty():
		out.append({"kind": "notice", "title": notice_title, "lines": PackedStringArray([notice_text]), "note": ""})
	return out


## Every text of the credits in one array (for the tests).
func all_texts(notice_text: String) -> PackedStringArray:
	var all := PackedStringArray()
	for section: Dictionary in sections(notice_text, true):
		all.append(String(section["title"]))
		all.append_array(section["lines"] as PackedStringArray)
		if not String(section["note"]).is_empty():
			all.append(String(section["note"]))
	return all

class_name GrandfatherLineValidator
extends RefCounted
## The rules of a grandfather line (Phase 16c). Pure and static; never throws on bad input. The same rules run in the service
## (ai-service/app/director.py, validate_line) and again here, so a line from the AI can never reach the screen unchecked.
## A line is accepted only if it is a single line of 8 to 18 words and at most 110 characters, made of letters and simple
## punctuation (no digits, links, markup, line breaks or emojis) and without a banned word (reproach, statistics, mechanics).

const ALLOWED_PUNCTUATION: String = " .,;:!?-—–«»\"'…()¿¡"
const ACCENTS: Dictionary = {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}


## Returns {"ok": bool, "reason": String, "line": String}. `line` is the trimmed text when ok.
static func validate(value: Variant, lines: GrandfatherLines = null) -> Dictionary:
	var rules: GrandfatherLines = lines if lines != null else GrandfatherLines.get_default()
	if not value is String:
		return _fail("not a string")
	var text: String = (value as String).strip_edges()
	if text.is_empty():
		return _fail("empty")
	if text.length() > rules.max_chars:
		return _fail("too long")
	for i in text.length():
		var character: String = text[i]
		if character >= "0" and character <= "9":
			return _fail("digit")
		if character == "\n" or character == "\r" or character == "\t":
			return _fail("line break")
		var is_letter: bool = character.to_lower() != character.to_upper()
		if not is_letter and not ALLOWED_PUNCTUATION.contains(character):
			return _fail("character not allowed")
	var word_count: int = text.split(" ", false).size()
	if word_count < rules.min_words:
		return _fail("too few words")
	if word_count > rules.max_words:
		return _fail("too many words")
	var plain_text: String = plain(text)
	for mark in rules.url_marks:
		if plain_text.contains(mark):
			return _fail("link")
	var padded: String = " " + _letters_only(plain_text) + " "
	for word in rules.banned_words:
		if padded.contains(" " + word + " "):
			return _fail("banned word")
	return {"ok": true, "reason": "", "line": text}


## Lower case without accents.
static func plain(text: String) -> String:
	var result: String = text.to_lower()
	for accent: Variant in ACCENTS.keys():
		result = result.replace(String(accent), String(ACCENTS[accent]))
	return result


static func _letters_only(plain_text: String) -> String:
	var result: String = ""
	for i in plain_text.length():
		var character: String = plain_text[i]
		result += character if (character >= "a" and character <= "z") else " "
	var parts: PackedStringArray = result.split(" ", false)
	return " ".join(parts)


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "line": ""}

class_name TutorialTexts
extends Resource
## Every text of the tutorial (Phase 15m): the steps (id, kind of action that completes it, the prompt, the short name for the checklist and the
## title of its station sign), the dummy's lines by event, the checklist title and the skip hint. Texts may hold "{action}" tokens that are
## replaced with the key bound to that action NOW (remaps included). Data only: TutorialController reads it.

const DEFAULT_PATH: String = "res://backend/progression/default_tutorial_texts.tres"

## One dictionary per step: id, kind, text, short, station, required (bool: the gate waits for it).
@export var steps: Array[Dictionary] = []
@export var greeting: String = "Abuelo: Ven, te enseñaré lo básico."
@export var feedback_text: String = "¡Bien!"
@export var final_text: String = "Muy bien. Sigue a la derecha para salir."
## "%s" is the list of the steps still missing.
@export var exit_hint_format: String = "Te falta: %s"
@export var checklist_title: String = "ENTRENAMIENTO"
@export var abilities_note: String = "Más habilidades llegan con los fragmentos de alma."
@export var skip_hint: String = "Mantén {ui_accept} para saltar el tutorial"
## Dummy lines by event: greet, hit, heavy_hit, killed, respawn, early, done, all_done, skipped, idle.
@export var dummy_lines: Dictionary = {}


static func get_default() -> TutorialTexts:
	return load(DEFAULT_PATH) as TutorialTexts


func step_by_id(step_id: String) -> Dictionary:
	for step in steps:
		if String(step.get("id", "")) == step_id:
			return step
	return {}


func line_for(event: String, rng: RandomNumberGenerator) -> String:
	var lines: Variant = dummy_lines.get(event, PackedStringArray())
	if lines is PackedStringArray and (lines as PackedStringArray).size() > 0:
		var list := lines as PackedStringArray
		return list[rng.randi_range(0, list.size() - 1)]
	return ""

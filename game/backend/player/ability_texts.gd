class_name AbilityTexts
extends Resource
## Every text of the "Nueva habilidad" card (Hollow Knight style): the title, the heal ability, the improved
## sword wave and the footer that points to the controls. Pure data (default_ability_texts.tres).

const DEFAULT_PATH: String = "res://backend/player/default_ability_texts.tres"

@export var card_title: String = "Nueva habilidad"
@export var heal_name: String = "Curarse"
@export_multiline var heal_description: String = "Reúne alma golpeando a tus enemigos. Mantén la tecla para enfocar y recuperar un corazón. Si te hieren, se interrumpe."
@export var wave_name_format: String = "Onda de espada: nivel %d"
## `%d` twice: the new wave level and the heal cost.
@export_multiline var wave_description_format: String = "Conservar el fragmento fortalece tu onda de espada (nivel %d), pero ahora curarte cuesta %d de alma."
## Phase 15c: the double jump, unlocked by boss 2's decision (released or kept).
@export var double_jump_name: String = "Doble salto"
@export_multiline var double_jump_description: String = "El pantano ya no te retiene: pulsa saltar otra vez en el aire y elévate un poco más. Es la misma tecla del salto."
@export var keys_format: String = "Tecla: %s"
@export var footer: String = "Puedes cambiarla en Opciones → Controles"
@export var dismiss_hint: String = "Pulsa Enter para continuar"


static func get_default() -> AbilityTexts:
	return load(DEFAULT_PATH) as AbilityTexts

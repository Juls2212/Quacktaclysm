class_name ControlsCatalog
extends Resource
## What the player can rebind and every text of the controls screen, as data (no logic): the list of
## rebindable actions with their Spanish names, the readable names of keys and mouse buttons, and
## the messages. Debug keys and the UI navigation actions (ui_*) are NOT in the list on purpose.
## Default instance: res://backend/controls/default_controls_catalog.tres.

## Rebindable InputMap actions, in display order. `action_names` holds their names, same order.
@export var action_ids: PackedStringArray = PackedStringArray([
	"move_left", "move_right", "jump", "dash", "attack", "wave", "heavy_attack", "heal", "pause",
])
@export var action_names: PackedStringArray = PackedStringArray([
	"Mover a la izquierda", "Mover a la derecha", "Saltar", "Esquivar (dash)", "Ataque de espada",
	"Onda de espada", "Golpe pesado", "Curarse (enfocar)", "Pausa",
])

## Godot's name of a key (OS.get_keycode_string) -> what the player reads. Others keep Godot's name.
@export var key_names: Dictionary = {
	"Space": "Barra espaciadora", "Left": "Flecha izquierda", "Right": "Flecha derecha",
	"Up": "Flecha arriba", "Down": "Flecha abajo", "Escape": "Esc", "Enter": "Intro",
	"Kp Enter": "Intro (teclado numérico)", "Backspace": "Retroceso", "Delete": "Supr",
	"Insert": "Insertar", "Home": "Inicio", "End": "Fin", "Page Up": "Re Pág", "Page Down": "Av Pág",
	"CapsLock": "Bloq Mayús", "Shift": "Shift", "Ctrl": "Ctrl", "Alt": "Alt", "Tab": "Tab",
}
## Mouse button index -> name.
@export var mouse_names: Dictionary = {
	1: "Clic izquierdo", 2: "Clic derecho", 3: "Clic central", 8: "Botón lateral 1", 9: "Botón lateral 2",
}
@export var mouse_other_format: String = "Botón del ratón %d"

@export_group("Screen texts")
@export var section_title: String = "Controles"
@export var open_button_text: String = "Controles…"
@export var primary_header: String = "Principal"
@export var alternative_header: String = "Alternativa"
@export var empty_slot_text: String = "—"
@export var capture_prompt: String = "Pulsa una tecla…"
@export var clear_text: String = "×"
@export var clear_tooltip: String = "Quitar la asignación alternativa"
@export var reset_text: String = "Restaurar valores por defecto"
@export var back_text: String = "Volver"
@export var swap_text: String = "Intercambiar"
@export var cancel_text: String = "Cancelar"
@export var hint_text: String = "Haz clic en una casilla y pulsa una tecla o un botón. Esc cancela."
@export var changed_format: String = "%s: %s"
@export var conflict_format: String = "«%s» ya se usa en «%s». ¿Intercambiar?"
@export var cancelled_text: String = "Cambio cancelado."
@export var capture_cancelled_text: String = "Captura cancelada."
@export var esc_reserved_text: String = "Esc está reservada para pausar y no se puede asignar."
@export var invalid_text: String = "Esa tecla o botón no se puede asignar."
@export var cannot_clear_text: String = "La asignación principal no se puede quitar."
@export var cannot_swap_text: String = "Ese intercambio dejaría una acción sin asignación principal."
@export var cleared_format: String = "%s: asignación alternativa quitada."
@export var reset_done_text: String = "Controles restaurados a los valores por defecto."
@export var save_failed_text: String = "No se pudieron guardar los controles."


func get_action_name(action: String) -> String:
	var index: int = action_ids.find(action)
	if index < 0 or index >= action_names.size():
		return action
	return action_names[index]

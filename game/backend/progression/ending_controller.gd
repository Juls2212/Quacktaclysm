class_name EndingController
extends Control
## Placeholder ending scene. Reads the adaptive result ONCE on _ready and shows the ending text of
## its `ending_variant`, the soul counts and a button back to the main menu. It never writes
## GameState (the "ending" checkpoint marker stays, so "Continuar" reopens this scene) and needs
## no network. All texts are exported placeholders.

@export var title_text: String = "Fin"
## ending_variant id -> Spanish placeholder text.
@export var ending_texts: Dictionary = {
	"ending_compassionate": "Liberaste cada alma y el pantano guardó silencio. El cielo, por fin, se despejó. (texto provisional)",
	"ending_neutral": "Elegiste caso por caso. El mundo sigue en pie, con sus luces y sus sombras. (texto provisional)",
	"ending_corrupt": "Guardaste las almas y su peso te siguió hasta el final. Nada volvió a ser igual. (texto provisional)",
}
@export var fallback_text: String = "El viaje termina aquí. (texto provisional)"
@export var fallback_variant_id: String = "ending_neutral"
@export var souls_released_format: String = "Almas liberadas: %d"
@export var souls_kept_format: String = "Almas guardadas: %d"
@export var narrative_format: String = "Variante narrativa: %s"
@export var show_narrative_variant: bool = true
@export var back_text: String = "Volver al menú principal"

var shown_variant: String = ""
var shown_text: String = ""

@onready var title_label: Label = $Center/Box/TitleLabel
@onready var ending_label: Label = $Center/Box/EndingLabel
@onready var released_label: Label = $Center/Box/ReleasedLabel
@onready var kept_label: Label = $Center/Box/KeptLabel
@onready var narrative_label: Label = $Center/Box/NarrativeLabel
@onready var back_button: Button = $Center/Box/BackButton


func _ready() -> void:
	var result: AdaptiveResult = GameState.get_adaptive_result()
	shown_variant = resolve_variant(result.ending_variant)
	shown_text = String(ending_texts.get(shown_variant, fallback_text))
	title_label.text = title_text
	ending_label.text = shown_text
	released_label.text = souls_released_format % GameState.souls_released
	kept_label.text = souls_kept_format % GameState.souls_kept
	narrative_label.visible = show_narrative_variant
	narrative_label.text = narrative_format % result.narrative_variant
	back_button.text = back_text
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()


## The variant whose text is shown: `variant` if it has an entry, else the neutral fallback entry
## (and its generic `fallback_text` if even that one is missing).
func resolve_variant(variant: String) -> String:
	if ending_texts.has(variant):
		return variant
	return fallback_variant_id


func _on_back_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	SceneManager.go_to_main_menu()

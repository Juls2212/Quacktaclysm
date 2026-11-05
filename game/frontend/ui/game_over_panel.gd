class_name GameOverPanel
extends CanvasLayer
## Game Over: the world stains dark red and loses its color, feathers drift down, "HAS CAÍDO" drops
## in and bounces over a splat of ink and blood, a dark joke appears, then the Reintentar and
## Menú principal signs fade in (within a second). Holds the PauseLock while open and emits exactly
## one of `retry_requested` / `menu_requested` per opening (buttons lock after the first press).
## The animation is visual only: the buttons are focused and usable from the moment it opens.

signal retry_requested
signal menu_requested

@export var title_text: String = "Has caído"
@export var retry_text: String = "Reintentar"
@export var main_menu_text: String = "Menú principal"
## One is picked at random each time the panel opens.
@export var quips: PackedStringArray = PackedStringArray([
	"El abuelo estaría decepcionado.",
	"Otra estrella más en el cielo.",
	"Al menos moriste con estilo.",
	"Los patos no tienen nueve vidas. Lo comprobaste.",
	"La katana sobrevivió. Tú no tanto.",
])
## Seconds before the buttons have fully appeared (they appear after the title lands).
@export_range(0.2, 1.0, 0.05) var buttons_delay: float = 0.75

var _holds_lock: bool = false
var _choice_locked: bool = true
var _rng := RandomNumberGenerator.new()
var _tween: Tween = null

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/Box/TitleLabel
@onready var retry_button: Button = $Root/Center/Panel/Margin/Box/RetryButton
@onready var main_menu_button: Button = $Root/Center/Panel/Margin/Box/MainMenuButton
@onready var title_ink: InkLabel = $Root/Center/Panel/Margin/Box/TitleHolder/TitleInk
@onready var splat: UiFx = $Root/Center/Panel/Margin/Box/TitleHolder/Splat
@onready var quip_label: Label = $Root/Center/Panel/Margin/Box/Quip
@onready var dim: ColorRect = $Root/Dim
@onready var ink_wipe: UiFx = $InkWipe


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_rng.randomize()
	title_label.text = title_text
	title_ink.text = title_text.to_upper()
	retry_button.text = retry_text
	main_menu_button.text = main_menu_text
	retry_button.pressed.connect(_on_choice_pressed.bind(retry_requested))
	main_menu_button.pressed.connect(_on_choice_pressed.bind(menu_requested))
	root.visible = false


func _exit_tree() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func is_open() -> bool:
	return root.visible


func open() -> void:
	if root.visible:
		return
	root.visible = true
	_choice_locked = false
	retry_button.disabled = false
	main_menu_button.disabled = false
	_holds_lock = true
	PauseLock.request(self, get_tree())
	retry_button.grab_focus()
	if not quips.is_empty():
		quip_label.text = quips[_rng.randi_range(0, quips.size() - 1)]
	_animate_open()


func close() -> void:
	root.visible = false
	_choice_locked = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_set_buttons_alpha(1.0)
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func _on_choice_pressed(choice_signal: Signal) -> void:
	if _choice_locked:
		return
	_choice_locked = true
	retry_button.disabled = true
	main_menu_button.disabled = true
	choice_signal.emit()


## Red stain and grey-out, the title falls and bounces on its splat, then the joke and the signs.
func _animate_open() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	ink_wipe.play(ink_wipe.size * 0.5, 520.0)
	splat.play()
	var grade := dim.material as ShaderMaterial
	_tween = create_tween().set_parallel(true)
	if grade != null:
		grade.set_shader_parameter("amount", 0.0)
		_tween.tween_method(func(v: float) -> void: grade.set_shader_parameter("amount", v), 0.0, 1.0, 0.4)
	title_ink.position = Vector2(0, -260)
	_tween.tween_property(title_ink, "position", Vector2.ZERO, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	quip_label.modulate.a = 0.0
	_tween.tween_property(quip_label, "modulate:a", 1.0, 0.25).set_delay(0.45)
	# The signs fade in after the title lands; they are focused and work meanwhile.
	_set_buttons_alpha(0.0)
	for button: Button in [retry_button, main_menu_button]:
		_tween.tween_property(button, "modulate:a", 1.0, 0.2).set_delay(maxf(buttons_delay - 0.2, 0.0))


func _set_buttons_alpha(alpha: float) -> void:
	retry_button.modulate.a = alpha
	main_menu_button.modulate.a = alpha

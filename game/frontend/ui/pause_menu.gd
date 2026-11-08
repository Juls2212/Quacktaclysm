class_name PauseMenu
extends CanvasLayer
## Pause menu: the game behind goes dark and grey under a vignette, and a cardboard sign taped up
## in the middle offers Continuar, Opciones and Menú principal, with a dark little joke below.
## Opens on the `pause` action through PauseLock and closes itself on `pause` or "Continuar".
## Does not open if another system already holds the lock (decision panel, game over), a scene
## transition is running, or the optional `player` is dead.
## "Menú principal" does not save: progress since the last autosave is lost.
## Animations are visual only: the lock, the focus and the buttons change at once.

@export var player: Player
@export var title_text: String = "Pausa"
@export var resume_text: String = "Continuar"
@export var options_text: String = "Opciones"
@export var main_menu_text: String = "Menú principal"
## One is picked at random each time the menu opens.
@export var quips: PackedStringArray = PackedStringArray([
	"El fin del mundo puede esperar.",
	"Los patos muertos también descansan.",
	"Las estrellas siguen cayendo. Tómate tu tiempo.",
	"Nadie te juzga. Bueno, el abuelo sí.",
	"Respira. Mientras puedas.",
])

var _holds_lock: bool = false
var _rng := RandomNumberGenerator.new()

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/Box/TitleLabel
@onready var resume_button: Button = $Root/Center/Panel/Margin/Box/ResumeButton
@onready var main_menu_button: Button = $Root/Center/Panel/Margin/Box/MainMenuButton
@onready var options_button: Button = $Root/Center/Panel/Margin/Box/OptionsButton
@onready var title_ink: InkLabel = $Root/Center/Panel/Margin/Box/TitleInk
@onready var panel: PanelContainer = $Root/Center/Panel
@onready var center: CenterContainer = $Root/Center
@onready var options: OptionsBoard = $Root/Options
@onready var dim: ColorRect = $Root/Dim
@onready var quip_label: Label = $Root/Quip
@onready var ink_wipe: UiFx = $InkWipe


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	title_label.text = title_text
	title_ink.text = title_text.to_upper()
	resume_button.text = resume_text
	options_button.text = options_text
	main_menu_button.text = main_menu_text
	resume_button.pressed.connect(close_menu)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	options.closed.connect(_on_options_closed)
	root.visible = false


func _exit_tree() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	if _holds_lock and options.is_open():
		options.close()
	elif _holds_lock:
		close_menu()
	else:
		open_menu()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _holds_lock


func can_open() -> bool:
	if _holds_lock or PauseLock.is_locked() or SceneManager.is_transitioning():
		return false
	return not (player != null and is_instance_valid(player) and player.is_dead)


## Returns false (and does nothing) when the rules above forbid opening.
func open_menu() -> bool:
	if not can_open():
		return false
	_holds_lock = true
	PauseLock.request(self, get_tree())
	root.visible = true
	center.visible = true
	options.visible = false
	if not quips.is_empty():
		quip_label.text = quips[_rng.randi_range(0, quips.size() - 1)]
	resume_button.grab_focus()
	_animate_open()
	return true


func close_menu() -> void:
	if not _holds_lock:
		return
	_holds_lock = false
	root.visible = false
	options.visible = false
	ink_wipe.play(ink_wipe.size * 0.5, 320.0)
	PauseLock.release(self, get_tree())


func _on_options_pressed() -> void:
	if not _holds_lock:
		return
	center.visible = false
	options.open()
	ink_wipe.play(ink_wipe.size * 0.5, 380.0)


func _on_options_closed() -> void:
	if not _holds_lock:
		return
	center.visible = true
	options_button.grab_focus()
	ink_wipe.play(ink_wipe.size * 0.5, 320.0)


func _on_main_menu_pressed() -> void:
	if not _holds_lock or SceneManager.is_transitioning():
		return
	close_menu()
	SceneManager.go_to_main_menu()


## The world greys out, the sign drops in and swings, the joke fades up. Short and skippable.
func _animate_open() -> void:
	ink_wipe.play(ink_wipe.size * 0.5, 360.0)
	var grade := dim.material as ShaderMaterial
	var tween := create_tween().set_parallel(true)
	if grade != null:
		grade.set_shader_parameter("amount", 0.0)
		tween.tween_method(func(v: float) -> void: grade.set_shader_parameter("amount", v), 0.0, 1.0, 0.25)
	panel.pivot_offset = panel.size * 0.5
	panel.rotation = deg_to_rad(-6.0)
	panel.scale = Vector2(0.92, 0.92)
	tween.tween_property(panel, "rotation", deg_to_rad(-1.5), 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	quip_label.modulate.a = 0.0
	tween.tween_property(quip_label, "modulate:a", 1.0, 0.3).set_delay(0.2)

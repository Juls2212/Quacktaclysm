extends Control
## Specimen of "Pato Tinta" (InkType): every glyph at display and button sizes. F6 to review.
## `-- --shot=<file.png>` saves one frame and quits.

const LINES: Array = [
	["QUACKTACLYSM", 84.0, 0.0],
	["ABCDEFGHIJKLMN", 52.0, 0.0],
	["ÑOPQRSTUVWXYZ", 52.0, 0.0],
	["ÁÉÍÓÚÜ 0123456789", 44.0, 0.0],
	["¡HOLA! ¿NUEVA PARTIDA? (1/3) - 'SÍ' + \"NO\": FIN.", 30.0, 0.0],
	["Continuar   Opciones   Créditos   Salir", 26.0, 0.0],
]

var _shot: String = ""
var _frames: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.substr(7)
	RenderingServer.set_default_clear_color(Color(0.95, 0.92, 0.86))
	var y: float = 10.0
	for line in LINES:
		var label := InkLabel.new()
		label.text = line[0]
		label.cap_height = line[1]
		label.wave = line[2]
		label.position = Vector2(0, y)
		label.size = Vector2(1280, line[1] * 1.7)
		add_child(label)
		y += line[1] * 1.75


func _process(_delta: float) -> void:
	_frames += 1
	if _shot != "" and _frames == 10:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()

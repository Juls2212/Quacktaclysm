extends Node2D
## Every biome on a strip of ground with a camera drifting right, to look at backdrops and
## terrain without playing a level. F6 to watch.
## Left / right arrows: previous / next biome with the 1.5 s cross-fade a BiomeZone uses.
## Keys 1-7: jump straight to a biome. `start` picks the first one shown.

const BIOMES: Array[Biome] = [
	preload("res://frontend/levels/biome/meadow_biome.tres"),
	preload("res://frontend/levels/biome/ruined_city_biome.tres"),
	preload("res://frontend/levels/biome/forest_biome.tres"),
	preload("res://frontend/levels/biome/flooded_suburb_biome.tres"),
	preload("res://frontend/levels/biome/swamp_biome.tres"),
	preload("res://frontend/levels/biome/industrial_biome.tres"),
	preload("res://frontend/levels/biome/storm_biome.tres"),
]
const NAMES: Array[String] = [
	"Tutorial - el pueblo antes del fin",
	"Nivel 1 A - ciudad en ruinas",
	"Nivel 1 B - bosque muerto",
	"Nivel 2 A - suburbios inundados",
	"Nivel 2 B - pantano toxico",
	"Nivel 3 A - zona industrial",
	"Nivel 3 B - crater de estrellas",
]
const FADE: float = 1.5
const PAN_SPEED: float = 110.0

@export_range(0, 6) var start: int = 0

var biome: Biome
var _index: int = 0
var _backdrop: Backdrop
var _camera: Camera2D
var _skins: Array[TerrainSkin] = []
var _label: Label


func _ready() -> void:
	_index = clampi(start, 0, BIOMES.size() - 1)
	biome = BIOMES[_index]
	_backdrop = Backdrop.new()
	_backdrop.biome = biome
	add_child(_backdrop)
	# Long floor with a gap, a few floating islands and a rock pillar, repeated far to the right.
	for k in 6:
		var x0: float = k * 1600.0
		_skin(TerrainSkin.Kind.GROUND, Vector2(x0 + 600.0, 620.0), Vector2(1300.0, 40.0))
		_skin(TerrainSkin.Kind.ISLAND, Vector2(x0 + 420.0, 470.0), Vector2(180.0, 28.0))
		_skin(TerrainSkin.Kind.ISLAND, Vector2(x0 + 900.0, 400.0), Vector2(240.0, 28.0))
		_skin(TerrainSkin.Kind.WALL, Vector2(x0 + 1180.0, 520.0), Vector2(60.0, 160.0))
		_skin(TerrainSkin.Kind.PLANK, Vector2(x0 + 1400.0, 560.0), Vector2(200.0, 16.0))
	_camera = Camera2D.new()
	_camera.position = Vector2(640.0, 360.0)
	add_child(_camera)
	_camera.make_current()
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_label = Label.new()
	_label.position = Vector2(24.0, 18.0)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(_label)
	_update_label()


func _process(delta: float) -> void:
	_camera.position.x += PAN_SPEED * delta
	# Loop back before the ground runs out (the backdrop tiles forever, the floor does not).
	if _camera.position.x > 8200.0:
		_camera.position.x = 640.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_show((_index + 1) % BIOMES.size())
	elif event.is_action_pressed("ui_left"):
		_show((_index + BIOMES.size() - 1) % BIOMES.size())
	else:
		var key_event := event as InputEventKey
		if key_event != null and key_event.pressed and not key_event.echo:
			var key: int = key_event.keycode
			if key >= KEY_1 and key <= KEY_7:
				_show(key - KEY_1)


func _show(index: int) -> void:
	if index == _index:
		return
	_index = index
	biome = BIOMES[index]
	_backdrop.show_biome(biome, FADE)
	for skin in _skins:
		skin.biome = biome
	_update_label()


func _skin(kind: TerrainSkin.Kind, at: Vector2, size: Vector2) -> void:
	var skin := TerrainSkin.new()
	skin.kind = kind
	skin.size = size
	skin.biome = biome
	skin.position = at
	add_child(skin)
	_skins.append(skin)


func _update_label() -> void:
	_label.text = "%d/%d  %s   (flechas o 1-7)" % [_index + 1, BIOMES.size(), NAMES[_index]]

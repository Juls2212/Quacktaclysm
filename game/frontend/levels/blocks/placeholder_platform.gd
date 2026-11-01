@tool
class_name PlaceholderPlatform
extends StaticBody2D
## Level block with collision (world layer). The box is centered on the node's origin and each
## instance builds its own shape. A TerrainSkin draws it as ground, a floating island, a rock wall
## or an overhang in the level's biome; the flat `Visual` rectangle stays as a hidden fallback.

@export var size: Vector2 = Vector2(200.0, 32.0):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_refresh()
@export var one_way: bool = false:
	set(value):
		one_way = value
		_refresh()
@export var color: Color = Color(0.35, 0.3, 0.25, 1.0):
	set(value):
		color = value
		_refresh()
## How the block is drawn. AUTO: tall blocks are walls, wide high ones overhangs, wide low ones
## ground, the rest floating islands. One-way blocks default to wooden planks.
@export var skin: TerrainSkin.Kind = TerrainSkin.Kind.AUTO:
	set(value):
		skin = value
		_refresh()
## Draw the flat placeholder rectangle instead of the terrain skin.
@export var show_placeholder: bool = false:
	set(value):
		show_placeholder = value
		_refresh()

var terrain: TerrainSkin

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	collision.shape = RectangleShape2D.new()
	terrain = TerrainSkin.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.biome = _find_biome()
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var rect := collision.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		collision.shape = rect
	rect.size = size
	collision.one_way_collision = one_way
	var half: Vector2 = size * 0.5
	visual.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	visual.color = color
	visual.visible = show_placeholder or terrain == null
	if terrain != null:
		terrain.visible = not show_placeholder
		terrain.size = size
		terrain.kind = TerrainSkin.Kind.PLANK if one_way and skin == TerrainSkin.Kind.AUTO else skin


## The biome of the level this block belongs to (the nearest ancestor exporting `biome`).
func _find_biome() -> Biome:
	var node: Node = get_parent()
	while node != null:
		var value: Variant = node.get(&"biome")
		if value is Biome:
			return value
		node = node.get_parent()
	return null

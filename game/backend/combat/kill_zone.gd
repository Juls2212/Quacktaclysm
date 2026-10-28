class_name KillZone
extends Area2D
## Kills any player-layer body that enters, even if it is invulnerable.

@export var size: Vector2 = Vector2(4000.0, 100.0)

@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatLayers.layer_bit(CombatLayers.LAYER_PLAYER)
	monitorable = false
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	for child in body.get_children():
		if child is HealthComponent:
			(child as HealthComponent).kill(self)
			return

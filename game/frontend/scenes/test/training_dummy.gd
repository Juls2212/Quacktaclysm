class_name TrainingDummy
extends Node2D
## Static damage target for testing hitboxes. No AI.

@export var flash_time: float = 0.12
@export var flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var dead_color: Color = Color(0.35, 0.35, 0.35, 1.0)

var _flash_left: float = 0.0

@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_on_health_changed(health.current_health, health.max_health)


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			visual.modulate = dead_color if health.is_dead else Color.WHITE


## Debug helper: restores health and re-enables the hurtbox.
func reset_dummy() -> void:
	health.reset()
	hurtbox.set_enabled(true)
	visual.modulate = Color.WHITE
	_flash_left = 0.0


func _on_damaged(_info: DamageInfo) -> void:
	_flash_left = flash_time
	visual.modulate = flash_color


func _on_health_changed(current: int, maximum: int) -> void:
	label.text = "%d/%d" % [current, maximum]


func _on_died() -> void:
	hurtbox.set_enabled(false)
	label.text = "DEAD"

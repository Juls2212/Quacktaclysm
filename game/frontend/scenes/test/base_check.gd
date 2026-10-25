extends Node2D

@onready var label: Label = $Label


func _ready() -> void:
	var info: Dictionary = Engine.get_version_info()
	label.text = "Project base OK — Godot %s" % info["string"]

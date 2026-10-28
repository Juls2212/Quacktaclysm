class_name SoulFragmentData
extends Resource
## Static description of a soul fragment. Placeholder texts and tint; art replaces them later.

@export var fragment_id: String = ""
@export var boss_id: String = ""
@export var level: int = 1
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var tint: Color = Color(0.6, 0.9, 1.0, 1.0)

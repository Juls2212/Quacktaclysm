class_name SoulStory
extends Resource
## The story of one soul fragment: who it was (tied to the grandfather's past), the memory shown on
## the decision panel, and what happens to it if the player releases or keeps it. Texts only.

@export var fragment_id: String = ""
@export var soul_name: String = ""
## The first name alone, used inside sentences ("Solo Daigo subió al cielo").
@export var short_name: String = ""
## Shown on the decision panel under the name.
@export_multiline var memory: String = ""
## Short lines shown under the LIBERAR / CONSERVAR signs.
@export var released_line: String = ""
@export var kept_line: String = ""

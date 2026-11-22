class_name BossAnchor
extends Marker2D
## A spot the swamp guardian can leap to (Phase 15c): the position is where the BOSS body stands (its center), on
## the floor or on a platform. No pathfinding: the leap pattern only picks among the anchors of its group.

enum Tier { FLOOR, PLATFORM }

const GROUP: StringName = &"boss_anchors"

@export var tier: Tier = Tier.FLOOR


func _ready() -> void:
	add_to_group(GROUP)

class_name CorruptionSpriteSet
extends Resource
## OPTIONAL hand-made sprites for the corrupted duck (Phase 15o). Every slot is empty by default and the code drawing (DuckRig, integrated veins,
## eye, wing and feathers) is used. To use art, drop a Texture2D in a slot: it is then drawn instead of the code drawing for that stage or pose.
## Textures are drawn with the feet at the node's origin, facing right, `texture_scale` times their size; the rig flips with the duck.
## - `stage_textures`: index 0..3 = corruption stages (kept fragments) of the hero in gameplay. Index 0 is never used (the clean duck stays code).
## - `pose_textures`: ending poses by name: stand, labored, stagger, kneel, kneel_edge, reach, resist, head_down, walk.
## A pose texture wins over a stage texture. Data only.

const DEFAULT_PATH: String = "res://frontend/fx/default_corruption_sprites.tres"
const POSES: PackedStringArray = ["stand", "labored", "stagger", "kneel", "kneel_edge", "reach", "resist", "head_down", "walk"]

@export var stage_textures: Array[Texture2D] = [null, null, null, null]
@export var pose_textures: Dictionary = {}
@export_range(0.1, 8.0, 0.05) var texture_scale: float = 1.0
## Where the feet are inside the texture (as a fraction of its size: x 0..1, y 0..1; the default is the middle of the bottom edge).
@export var feet_anchor: Vector2 = Vector2(0.5, 1.0)


## The texture to use for this pose and stage, or null when the code drawing is used.
func texture_for(pose: StringName, stage: int) -> Texture2D:
	var by_pose: Variant = pose_textures.get(pose, pose_textures.get(String(pose), null))
	if by_pose is Texture2D:
		return by_pose as Texture2D
	if stage >= 1 and stage < stage_textures.size():
		return stage_textures[stage]
	return null


func is_empty() -> bool:
	for texture in stage_textures:
		if texture != null:
			return false
	for value: Variant in pose_textures.values():
		if value is Texture2D:
			return false
	return true


static func get_default() -> CorruptionSpriteSet:
	var set_resource := load(DEFAULT_PATH) as CorruptionSpriteSet
	return set_resource if set_resource != null else CorruptionSpriteSet.new()

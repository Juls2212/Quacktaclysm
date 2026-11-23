class_name Duckling
extends MeleeEnemy
## «Patito corrupto» (Phase 15j): a small corrupted duck the possessed duck summons from its perch. One hit of the light sword or one hit
## of a sword wave kills it; it walks toward the player along the floor or its platform (it never walks off an edge) and swings with a
## 0.5 s telegraph for 1 heart. Everything but the look comes from `stats/duckling_stats.tres`, the soul it is worth from the stage config:
## its killing hit pays nothing by itself; it leaves a SMALL blue fragment worth `soul_gain` (the stage config), so a summoned crowd cannot fill
## the soul meter and the value is counted once.

## Soul its small fragment gives (set by the stage from its config).
var soul_gain: int = 5


## SoulComponent asks an enemy that has this what its hit is worth.
func soul_gain_override() -> int:
	return 0


## The small blue fragment pays `soul_gain` (the hit itself paid nothing).
func _release_soul() -> void:
	if is_inside_tree() and soul_gain > 0:
		SoulPickup.spawn(get_parent(), global_position + Vector2(0.0, -14.0), soul_gain, SoulPickup.Style.SMALL)


## The stage removes it (a retry, a phase change, the end of the fight): no death, no soul, no wisp.
func vanish() -> void:
	if is_queued_for_deletion():
		return
	set_physics_process(false)
	hide()
	queue_free()

class_name PossessionOverride
extends Resource
## Per-boss override of the possession sequence (Phase 15d): which boss (BossStats.boss_id) and what differs from the
## defaults of PossessionConfig. A duration of 0 and a color with alpha 0 mean "use the default".

@export var boss_id: StringName = &""
@export_range(0.0, 4.0, 0.1, "suffix:s") var duration: float = 0.0
@export var color: Color = Color(0.0, 0.0, 0.0, 0.0)

class_name SoulConfig
extends Resource
## Every number of the Soul meter and the focus heal (Phase 15a), in one editable resource
## (default_soul_config.tres). Soul is gathered by hitting enemies and bosses and by absorbing the soul
## wisp of what dies; holding the heal action spends it to recover a heart. Kept fragments make healing
## cost more. Runtime state only: nothing here is saved.

const DEFAULT_PATH: String = "res://backend/player/default_soul_config.tres"

@export_group("Meter")
@export_range(1, 999, 1) var max_soul: int = 99
@export_group("Soul gained per hit")
@export_range(0, 99, 1) var gain_light: int = 11
@export_range(0, 99, 1) var gain_heavy: int = 22
@export_range(0, 99, 1) var gain_dash_slash: int = 16
@export_range(0, 99, 1) var gain_wave: int = 8
@export_group("Soul wisps (absorbed when something dies)")
@export_range(0, 99, 1) var wisp_enemy: int = 11
@export_range(0, 99, 1) var wisp_boss: int = 33
## Longest a wisp takes to reach the player; it is absorbed by then at the latest.
@export_range(0.1, 1.2, 0.05, "suffix:s") var wisp_absorb_time: float = 0.8
@export_group("Focus heal")
## Seconds the heal action must be held.
@export_range(0.1, 5.0, 0.05, "suffix:s") var focus_time: float = 0.9
@export_range(1, 5, 1) var heal_hearts: int = 1
## Heal cost = heal_cost_base + heal_cost_per_kept * souls kept.
@export_range(1, 99, 1) var heal_cost_base: int = 33
@export_range(0, 50, 1) var heal_cost_per_kept: int = 5


static func get_default() -> SoulConfig:
	return load(DEFAULT_PATH) as SoulConfig


## Soul of one hit by a sword move. `kind` is a Player.SwordKind value (0 light, 1 heavy, 2 dash slash).
func gain_for_sword(kind: int) -> int:
	match kind:
		1:
			return gain_heavy
		2:
			return gain_dash_slash
	return gain_light


## The heal cost for a player who has kept `kept` fragments (clamped to what the meter can hold).
func heal_cost(kept: int) -> int:
	return mini(heal_cost_base + heal_cost_per_kept * maxi(kept, 0), max_soul)

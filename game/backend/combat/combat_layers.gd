class_name CombatLayers
extends RefCounted
## Team definitions and physics layer helpers for hitboxes and hurtboxes.
## Layer numbers match the names in Project Settings > Layer Names > 2D Physics.

enum Team { PLAYER, ENEMY }

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_PLAYER_HURTBOX: int = 3
const LAYER_ENEMY_HURTBOX: int = 4
const LAYER_PLAYER_HITBOX: int = 5
const LAYER_ENEMY_HITBOX: int = 6
const LAYER_ENEMY: int = 7


## Converts a 1-based layer number into its collision bit.
static func layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)


static func opposing_team(team: Team) -> Team:
	return Team.ENEMY if team == Team.PLAYER else Team.PLAYER


## Collision layer of the hurtboxes owned by `team`.
static func hurtbox_layer(team: Team) -> int:
	return layer_bit(LAYER_PLAYER_HURTBOX if team == Team.PLAYER else LAYER_ENEMY_HURTBOX)


## Collision layer of the hitboxes owned by `team`.
static func hitbox_layer(team: Team) -> int:
	return layer_bit(LAYER_PLAYER_HITBOX if team == Team.PLAYER else LAYER_ENEMY_HITBOX)


## Collision mask of a hitbox owned by `team`: only the opposing team's hurtboxes.
static func hitbox_mask(team: Team) -> int:
	return hurtbox_layer(opposing_team(team))

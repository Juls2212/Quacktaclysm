class_name DecisionTexts
extends Resource
## The player-facing texts that explain what the decisions so far did: the line shown when a level
## starts and the name / score shown by the corruption indicator of the HUD. Pure data and pure
## functions (no scene, no autoload), so the wording lives in default_decision_texts.tres and not in
## game logic. Default instance: res://backend/decisions/default_decision_texts.tres.

## Shown when no fragment has been decided yet (level 1 of a new game).
@export var no_decisions_line: String = "Cada alma que liberes o conserves cambiará tu destino."
## Reward for released fragments. `%d` is the number of maximum hearts gained.
@export var health_bonus_one: String = "+1 corazón máximo por alma liberada"
@export var health_bonus_many: String = "+%d corazones máximos por almas liberadas"
## Sword wave power. `%d` is the tier (1 or 2); tier 0 adds nothing.
@export var wave_line: String = "onda de espada nivel %d"
## How the profile (see AdaptiveIds) changes the level that is about to start.
@export var profile_lines: Dictionary = {
	"compassionate": "tu piedad suaviza este nivel: jefe más lento y sin enemigos extra",
	"neutral": "este nivel no se inclina hacia ningún lado",
	"corrupt": "tu corrupción endurece este nivel: jefe más rápido y enemigos extra",
}
@export var line_separator: String = " · "
## What healing costs (Phase 15a): the heal cost in soul grows with every fragment kept. `%d` is the cost.
@export var heal_cost_line: String = "curarse cuesta %d de alma"
## Corruption indicator of the HUD (profile name next to the signed score).
@export var profile_names: Dictionary = {
	"compassionate": "Compasivo",
	"neutral": "Neutral",
	"corrupt": "Corrupto",
}


## The one short line shown at the start of a level. `health_bonus` is the number of extra maximum
## hearts the released souls give (already capped), `wave_tier` the sword wave tier.
func build_level_line(released: int, kept: int, health_bonus: int, wave_tier: int, profile: String, heal_cost: int = -1) -> String:
	if released + kept <= 0:
		if heal_cost >= 0:
			return no_decisions_line + line_separator + heal_cost_line % heal_cost
		return no_decisions_line
	var parts: PackedStringArray = PackedStringArray()
	if health_bonus == 1:
		parts.append(health_bonus_one)
	elif health_bonus > 1:
		parts.append(health_bonus_many % health_bonus)
	if wave_tier > 0:
		parts.append(wave_line % wave_tier)
	var profile_line: String = String(profile_lines.get(profile, ""))
	if not profile_line.is_empty():
		parts.append(profile_line)
	if heal_cost >= 0:
		parts.append(heal_cost_line % heal_cost)
	var line: String = line_separator.join(parts)
	if line.is_empty():
		return ""
	return line.substr(0, 1).to_upper() + line.substr(1)


func get_profile_name(profile: String) -> String:
	return String(profile_names.get(profile, profile))


## "+2", "-1" (with a real minus sign) or "0". Scores are whole numbers with the default weights.
static func format_score(score: float) -> String:
	var rounded: int = roundi(score)
	if rounded > 0:
		return "+%d" % rounded
	if rounded < 0:
		return "−%d" % -rounded
	return "0"

class_name AdaptiveIds
extends RefCounted
## Single source of truth for the string ids shared by the adaptive system and GameState
## (profiles, decision choices, result sources). Pure constants: no autoload dependency.

const PROFILE_COMPASSIONATE: String = "compassionate"
const PROFILE_NEUTRAL: String = "neutral"
const PROFILE_CORRUPT: String = "corrupt"
## Ordered scale used for profile distance: index 0 = compassionate ... 2 = corrupt.
const PROFILE_ORDER: Array[String] = [PROFILE_COMPASSIONATE, PROFILE_NEUTRAL, PROFILE_CORRUPT]

const CHOICE_RELEASED: String = "released"
const CHOICE_KEPT: String = "kept"

const SOURCE_DEFAULT: String = "default"
const SOURCE_LOCAL: String = "local"
const SOURCE_REMOTE: String = "remote"


static func is_known_profile(profile: String) -> bool:
	return PROFILE_ORDER.has(profile)


static func is_valid_choice(choice: String) -> bool:
	return choice == CHOICE_RELEASED or choice == CHOICE_KEPT

class_name ProfilePresentation
extends Resource
## One ProfileLook per adaptive profile, plus the wording of the accessibility option. Edit
## default_profile_presentation.tres to retune colors, vignette, glows, music and the decision pulse;
## no code change is needed. The neutral entry must stay the identity (see ProfileLook).

@export var compassionate: ProfileLook
@export var neutral: ProfileLook
@export var corrupt: ProfileLook
## Seconds a change of profile takes to blend (world, duck, enemies and music).
@export_range(0.0, 5.0, 0.05, "suffix:s") var fade_time: float = 1.4
@export_group("Texts")
@export var toggle_text: String = "Efectos de corrupción"
## The option that switches the remote AI Director off (Phase 16b).
@export var blood_toggle_text: String = "Sangre"
@export var ai_toggle_text: String = "Adaptación con IA"


## The look of `profile`; an unknown id gives the neutral look.
func get_look(profile: String) -> ProfileLook:
	match profile:
		AdaptiveIds.PROFILE_COMPASSIONATE:
			return compassionate if compassionate != null else neutral
		AdaptiveIds.PROFILE_CORRUPT:
			return corrupt if corrupt != null else neutral
	return neutral if neutral != null else ProfileLook.new()


func has_all_looks() -> bool:
	return compassionate != null and neutral != null and corrupt != null

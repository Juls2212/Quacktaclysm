class_name LocalProfileClassifier
extends RefCounted
## Pure, deterministic local fallback: weighted released/kept score -> profile.
## No autoloads, scenes, files, randomness or time.


## Sum of weight(level) * (+1 released, -1 kept) over the valid decisions.
static func score(input: AdaptiveInput, config: AdaptiveConfig) -> float:
	if input == null:
		return 0.0
	var cfg: AdaptiveConfig = config if config != null else AdaptiveConfig.new()
	var total: float = 0.0
	for entry: Dictionary in input.decisions:
		var sign_value: float = 1.0 if entry["choice"] == AdaptiveIds.CHOICE_RELEASED else -1.0
		total += cfg.get_level_weight(entry["level"]) * sign_value
	return total


static func classify_profile(input: AdaptiveInput, config: AdaptiveConfig) -> String:
	var cfg: AdaptiveConfig = config if config != null else AdaptiveConfig.new()
	var value: float = score(input, cfg)
	if value >= cfg.decision_margin_threshold:
		return AdaptiveIds.PROFILE_COMPASSIONATE
	if value <= -cfg.decision_margin_threshold:
		return AdaptiveIds.PROFILE_CORRUPT
	return AdaptiveIds.PROFILE_NEUTRAL


static func classify(input: AdaptiveInput, config: AdaptiveConfig) -> AdaptiveResult:
	var cfg: AdaptiveConfig = config if config != null else AdaptiveConfig.new()
	var profile: String = classify_profile(input, cfg)
	var result: AdaptiveResult = AdaptiveResult.from_params(cfg.get_params(profile), AdaptiveIds.SOURCE_LOCAL)
	result.profile = profile
	return result

class_name DirectorThemes
extends RefCounted
## Local, deterministic theme selection (Phase 16a): the first ThemeRule of the config whose conditions all hold for the
## categorical summary wins; none matching gives the default theme. The same summary always gives the same theme.


static func select(summary: Dictionary, config: TelemetryConfig = null) -> String:
	var cfg: TelemetryConfig = config if config != null else TelemetryConfig.get_default()
	for rule in cfg.theme_rules:
		if rule != null and cfg.themes.has(rule.theme) and rule.matches(summary):
			return rule.theme
	return cfg.default_theme

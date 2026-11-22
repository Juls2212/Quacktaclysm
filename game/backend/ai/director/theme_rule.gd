class_name ThemeRule
extends Resource
## One rule of the local theme selection (Phase 16a): when EVERY condition holds, the rule theme is chosen. Rules are tried in
## order and the first match wins. `conditions` maps a summary metric (see RunTelemetry.METRICS) to the categories it may have
## (low / mid / high).

@export var theme: String = ""
@export var conditions: Dictionary = {}


func matches(summary: Dictionary) -> bool:
	if conditions.is_empty():
		return false
	for metric: Variant in conditions.keys():
		var allowed: Variant = conditions[metric]
		if not allowed is Array or not (allowed as Array).has(String(summary.get(String(metric), ""))):
			return false
	return true

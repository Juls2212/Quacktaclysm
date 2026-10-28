class_name AiServiceConfig
extends Resource
## Connection settings of the optional AI service. Holds no key, token or secret of any kind.

@export var enabled: bool = true
@export var base_url: String = "http://127.0.0.1:8000"
@export var profile_path: String = "/v1/adaptive/profile"
@export_range(1.0, 60.0, 0.5) var request_timeout_seconds: float = 10.0
@export var max_response_bytes: int = 4096
## Name of the environment variable that overrides `base_url` when it is not empty.
@export var env_url_override_name: String = "QUACKTACLYSM_AI_URL"

const _SCHEMES: PackedStringArray = ["http://", "https://"]


## Environment override (if set) or `base_url`, without trailing slashes. Returns "" unless
## the scheme is http:// or https:// and a host follows.
func resolve_base_url() -> String:
	var url: String = base_url
	if not env_url_override_name.is_empty():
		var override: String = OS.get_environment(env_url_override_name).strip_edges()
		if not override.is_empty():
			url = override
	url = url.strip_edges()
	while url.ends_with("/"):
		url = url.trim_suffix("/")
	var lower: String = url.to_lower()
	for scheme: String in _SCHEMES:
		if lower.begins_with(scheme) and lower.length() > scheme.length():
			return url
	return ""


## Full endpoint URL, or "" if the base URL is invalid.
func resolve_profile_url() -> String:
	var base: String = resolve_base_url()
	if base.is_empty():
		return ""
	return base + (profile_path if profile_path.begins_with("/") else "/" + profile_path)

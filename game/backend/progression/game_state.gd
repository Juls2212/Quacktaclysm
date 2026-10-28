extends Node
## In-memory run state (autoload "GameState"). No class_name on purpose: the autoload
## name is the global identifier. It knows nothing about players, bosses, UI or scenes.
## Persistence goes through SaveSystem; this node only validates and applies the data.

signal decision_recorded(entry: Dictionary)
signal state_changed

const SAVE_VERSION: int = 1
const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 3

## Same values as the adaptive system (AdaptiveIds is the single source of truth).
const PROFILE_COMPASSIONATE: String = AdaptiveIds.PROFILE_COMPASSIONATE
const PROFILE_NEUTRAL: String = AdaptiveIds.PROFILE_NEUTRAL
const PROFILE_CORRUPT: String = AdaptiveIds.PROFILE_CORRUPT

const CHOICE_RELEASED: String = AdaptiveIds.CHOICE_RELEASED
const CHOICE_KEPT: String = AdaptiveIds.CHOICE_KEPT

const DEFAULT_ADAPTIVE_CONFIG_PATH: String = "res://backend/ai/default_adaptive_config.tres"

const DEFAULT_LEVEL: int = MIN_LEVEL
const DEFAULT_CHECKPOINT: String = "start"
const DEFAULT_ADAPTIVE_PROFILE: String = PROFILE_NEUTRAL

var save_version: int = SAVE_VERSION
var current_level: int = DEFAULT_LEVEL
var checkpoint: String = DEFAULT_CHECKPOINT
var souls_released: int = 0
var souls_kept: int = 0
## Entries: {fragment_id: String, boss_id: String, level: int, choice: String}
var decisions: Array = []
var adaptive_profile: String = DEFAULT_ADAPTIVE_PROFILE
## In-memory only (never saved): narrative variant chosen by the remote AI for the current profile.
var adaptive_narrative_variant: String = ""

## Automatic triggers (autosave()) respect this; an explicit save_to_disk() does not.
var autosave_enabled: bool = true
## Non-empty while the file on disk came from a newer game version and must not be overwritten.
var save_blocked_reason: String = ""
## Source version of the last load_from_dict() that ran the migration hook (-1 if none).
var last_migrated_from: int = -1
## Short text of the last save/load outcome (debug display).
var last_io_message: String = ""

var _last_rejection_unsupported: bool = false
var _adaptive_config: AdaptiveConfig = null


static func is_valid_profile(profile: String) -> bool:
	return profile == PROFILE_COMPASSIONATE or profile == PROFILE_NEUTRAL or profile == PROFILE_CORRUPT


static func is_valid_choice(choice: String) -> bool:
	return choice == CHOICE_RELEASED or choice == CHOICE_KEPT


## Returns false and changes nothing if the choice is invalid, the id is empty or the
## fragment already has a decision.
func record_decision(fragment_id: String, boss_id: String, level: int, choice: String) -> bool:
	if not is_valid_choice(choice):
		push_warning("GameState: invalid choice '%s'" % choice)
		return false
	if fragment_id.is_empty():
		push_warning("GameState: empty fragment_id")
		return false
	if has_decision(fragment_id):
		push_warning("GameState: fragment '%s' already has a decision" % fragment_id)
		return false
	var entry: Dictionary = {
		"fragment_id": fragment_id,
		"boss_id": boss_id,
		"level": level,
		"choice": choice,
	}
	decisions.append(entry)
	if choice == CHOICE_RELEASED:
		souls_released += 1
	else:
		souls_kept += 1
	decision_recorded.emit(entry.duplicate(true))
	state_changed.emit()
	return true


func has_decision(fragment_id: String) -> bool:
	return not get_decision(fragment_id).is_empty()


## Copy of the decision for `fragment_id`, or an empty dictionary.
func get_decision(fragment_id: String) -> Dictionary:
	for entry: Dictionary in decisions:
		if entry["fragment_id"] == fragment_id:
			return entry.duplicate(true)
	return {}


func set_current_level(level: int) -> void:
	current_level = level
	state_changed.emit()


func set_checkpoint(checkpoint_id: String) -> void:
	checkpoint = checkpoint_id
	state_changed.emit()


## Lazily loads the default config; set_adaptive_config() overrides it (tests).
func get_adaptive_config() -> AdaptiveConfig:
	if _adaptive_config == null:
		_adaptive_config = load(DEFAULT_ADAPTIVE_CONFIG_PATH) as AdaptiveConfig
		if _adaptive_config == null:
			push_warning("GameState: could not load " + DEFAULT_ADAPTIVE_CONFIG_PATH)
			_adaptive_config = AdaptiveConfig.new()
	return _adaptive_config


## Passing null restores lazy loading of the default config.
func set_adaptive_config(config: AdaptiveConfig) -> void:
	_adaptive_config = config


## Returns false and changes nothing for an unknown profile. Emits state_changed only on change.
func set_adaptive_profile(profile: String) -> bool:
	if not is_valid_profile(profile):
		push_warning("GameState: invalid adaptive profile '%s'" % profile)
		return false
	if profile != adaptive_profile:
		adaptive_profile = profile
		adaptive_narrative_variant = ""
		state_changed.emit()
	return true


## Classifies the recorded decisions locally and stores the resulting profile.
func refresh_adaptive_profile(point: String = AdaptiveInput.POINT_AFTER_DECISION) -> AdaptiveResult:
	var input: AdaptiveInput = AdaptiveInput.from_state_dict(to_dict(), point)
	var result: AdaptiveResult = LocalProfileClassifier.classify(input, get_adaptive_config())
	set_adaptive_profile(result.profile)
	return result


## Stored as is; get_adaptive_result() only honors it if the current profile allows it.
func set_adaptive_narrative_variant(variant: String) -> void:
	adaptive_narrative_variant = variant


## Derived from the STORED profile (a loaded save keeps it); decisions only decide the source.
func get_adaptive_result() -> AdaptiveResult:
	var source: String = AdaptiveIds.SOURCE_LOCAL if not decisions.is_empty() else AdaptiveIds.SOURCE_DEFAULT
	var result: AdaptiveResult = AdaptiveResult.from_params(get_adaptive_config().get_params(adaptive_profile), source)
	result.profile = adaptive_profile
	if not adaptive_narrative_variant.is_empty() 			and get_adaptive_config().get_params(adaptive_profile).allowed_narrative_variants.has(adaptive_narrative_variant):
		result.narrative_variant = adaptive_narrative_variant
		result.source = AdaptiveIds.SOURCE_REMOTE
	return result


func reset_run() -> void:
	save_version = SAVE_VERSION
	current_level = DEFAULT_LEVEL
	checkpoint = DEFAULT_CHECKPOINT
	souls_released = 0
	souls_kept = 0
	decisions = []
	adaptive_profile = DEFAULT_ADAPTIVE_PROFILE
	adaptive_narrative_variant = ""
	state_changed.emit()


## Explicit "new game": resets the run and lifts a newer-version save block. The file on
## disk is only replaced by the next save.
func start_new_game() -> void:
	save_blocked_reason = ""
	reset_run()


## JSON-safe snapshot using the planned save schema. Decisions are deep-copied.
func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"current_level": current_level,
		"checkpoint": checkpoint,
		"souls_released": souls_released,
		"souls_kept": souls_kept,
		"decisions": decisions.duplicate(true),
		"adaptive_profile": adaptive_profile,
	}


# --- Loading ---

## Validates and sanitizes `data` into a new state and applies it only if acceptable.
## Returns {"ok": bool, "warnings": Array[String], "error": String}. On rejection nothing changes.
func load_from_dict(data: Variant) -> Dictionary:
	var warnings: Array[String] = []
	_last_rejection_unsupported = false
	if not data is Dictionary:
		return _reject("save data is not a dictionary", warnings)
	var source: Dictionary = (data as Dictionary).duplicate(true)

	var version: Variant = _as_int(source.get("save_version"))
	if version == null:
		return _reject("save_version missing or not an integer", warnings)
	if version > SAVE_VERSION:
		_last_rejection_unsupported = true
		return _reject("save_version %d is newer than supported version %d" % [version, SAVE_VERSION], warnings)
	var migrated_from: int = -1
	if version < SAVE_VERSION:
		migrated_from = version
		source = _migrate(source, version)
		warnings.append("migrated save from version %d" % version)

	var level: int = DEFAULT_LEVEL
	var level_value: Variant = _as_int(source.get("current_level"))
	if level_value == null:
		warnings.append("current_level missing or invalid, using %d" % DEFAULT_LEVEL)
	else:
		level = clampi(level_value, MIN_LEVEL, MAX_LEVEL)
		if level != level_value:
			warnings.append("current_level %d clamped to %d" % [level_value, level])

	var checkpoint_value: String = DEFAULT_CHECKPOINT
	var raw_checkpoint: Variant = source.get("checkpoint")
	if raw_checkpoint is String and not (raw_checkpoint as String).is_empty():
		checkpoint_value = raw_checkpoint
	else:
		warnings.append("checkpoint missing or invalid, using '%s'" % DEFAULT_CHECKPOINT)

	var profile_value: String = DEFAULT_ADAPTIVE_PROFILE
	var raw_profile: Variant = source.get("adaptive_profile")
	if raw_profile is String and is_valid_profile(raw_profile):
		profile_value = raw_profile
	else:
		warnings.append("adaptive_profile missing or unknown, using '%s'" % DEFAULT_ADAPTIVE_PROFILE)

	var clean_decisions: Array = []
	var raw_decisions: Variant = source.get("decisions")
	if raw_decisions == null:
		warnings.append("decisions missing, using an empty list")
	elif not raw_decisions is Array:
		return _reject("decisions is not an array", warnings)
	else:
		var seen: Dictionary = {}
		for raw_entry: Variant in raw_decisions:
			var entry: Dictionary = _sanitize_entry(raw_entry, seen, warnings)
			if not entry.is_empty():
				seen[entry["fragment_id"]] = true
				clean_decisions.append(entry)

	var released: int = 0
	var kept: int = 0
	for entry: Dictionary in clean_decisions:
		if entry["choice"] == CHOICE_RELEASED:
			released += 1
		else:
			kept += 1
	if _as_int(source.get("souls_released")) != released or _as_int(source.get("souls_kept")) != kept:
		warnings.append("stored soul counters missing or not matching decisions, recomputed")

	save_version = SAVE_VERSION
	current_level = level
	checkpoint = checkpoint_value
	souls_released = released
	souls_kept = kept
	decisions = clean_decisions
	adaptive_profile = profile_value
	adaptive_narrative_variant = ""
	last_migrated_from = migrated_from
	state_changed.emit()
	return {"ok": true, "warnings": warnings, "error": ""}


## Hook for upgrading older saves to SAVE_VERSION. Only version 1 exists, so there are no
## migrations yet: add one `if from_version < N:` step per future version here.
func _migrate(data: Dictionary, _from_version: int) -> Dictionary:
	return data


## Returns the clean entry, or an empty dictionary (with a warning) if it must be dropped.
func _sanitize_entry(raw_entry: Variant, seen: Dictionary, warnings: Array[String]) -> Dictionary:
	if not raw_entry is Dictionary:
		warnings.append("dropped decision: not a dictionary")
		return {}
	var raw: Dictionary = raw_entry
	var id: Variant = raw.get("fragment_id")
	var boss: Variant = raw.get("boss_id")
	var level_value: Variant = _as_int(raw.get("level"))
	var choice: Variant = raw.get("choice")
	if not id is String or (id as String).is_empty():
		warnings.append("dropped decision: invalid fragment_id")
		return {}
	if not boss is String or level_value == null or not choice is String or not is_valid_choice(choice):
		warnings.append("dropped decision '%s': invalid fields" % id)
		return {}
	if seen.has(id):
		warnings.append("dropped duplicate decision '%s'" % id)
		return {}
	return {"fragment_id": id, "boss_id": boss, "level": level_value, "choice": choice}


## int for ints and integer-valued floats (JSON numbers), otherwise null.
func _as_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return null


func _reject(message: String, warnings: Array[String]) -> Dictionary:
	push_warning("GameState: load rejected: " + message)
	return {"ok": false, "warnings": warnings, "error": message}


# --- Persistence wrappers ---

## Used by automatic triggers (decision accepted, checkpoint reached). Honors autosave_enabled.
func autosave() -> bool:
	if not autosave_enabled:
		return false
	return save_to_disk()


## Saves now regardless of autosave_enabled. Refuses to overwrite a save written by a newer game
## version unless `allow_overwrite_newer` is true.
func save_to_disk(allow_overwrite_newer: bool = false) -> bool:
	if not save_blocked_reason.is_empty() and not allow_overwrite_newer:
		last_io_message = "save blocked: " + save_blocked_reason
		push_warning("GameState: " + last_io_message)
		return false
	var result: Dictionary = SaveSystem.save(to_dict())
	if result["ok"]:
		save_blocked_reason = ""
		last_io_message = "saved"
	else:
		last_io_message = "save failed: " + String(result["error"])
	return result["ok"]


## Loads the file into the state. Returns {"ok", "status", "message", "warnings"}; on any
## failure the in-memory state stays unchanged. Statuses: SaveSystem's plus "invalid_data".
func load_from_disk() -> Dictionary:
	save_blocked_reason = ""
	var loaded: Dictionary = SaveSystem.load_game(SAVE_VERSION)
	var status: String = loaded["status"]
	var message: String = loaded["message"]
	var warnings: Array = []
	var ok: bool = false
	if status == SaveSystem.STATUS_OK or status == SaveSystem.STATUS_RECOVERED:
		var applied: Dictionary = load_from_dict(loaded["data"])
		ok = applied["ok"]
		warnings = applied["warnings"]
		if not ok:
			status = SaveSystem.STATUS_UNSUPPORTED if _last_rejection_unsupported else "invalid_data"
			message = applied["error"]
	if status == SaveSystem.STATUS_UNSUPPORTED:
		save_blocked_reason = message
	last_io_message = "%s: %s" % [status, message]
	return {"ok": ok, "status": status, "message": message, "warnings": warnings}

class_name SaveSystem
extends RefCounted
## Safe local JSON I/O for the save file (static, not an autoload). It only reads, parses and
## writes files; semantic validation belongs to GameState.load_from_dict().
##
## Files (all under user://), derived from the active path:
##   <path>          main save          <path>.bak      previous good version
##   <path>.tmp      write in progress  <path>.corrupt   quarantined unreadable main save
##
## Save order: write .tmp -> read it back and compare -> copy the current main to .bak
## (only if that main is itself valid) -> move .tmp over the main file. If the move onto
## an existing file is refused the main file is removed first; because the .bak already holds
## the previous version, load_game() can still recover if the process dies in that instant.

const DEFAULT_PATH: String = "user://save_game.json"
const URL_PREFIX: String = "user://"

const STATUS_OK: String = "ok"
const STATUS_NO_SAVE: String = "no_save"
const STATUS_RECOVERED: String = "recovered_from_backup"
const STATUS_CORRUPT: String = "corrupt"
const STATUS_UNSUPPORTED: String = "unsupported_version"

static var _save_path: String = DEFAULT_PATH


## Redirects every file operation (tests use this). Only user:// paths are accepted.
static func set_save_path(path: String) -> void:
	if not path.begins_with(URL_PREFIX) or path.length() <= URL_PREFIX.length():
		push_warning("SaveSystem: save path must be a user:// path, ignoring '%s'" % path)
		return
	_save_path = path


static func get_save_path() -> String:
	return _save_path


static func backup_path() -> String:
	return _save_path + ".bak"


static func temp_path() -> String:
	return _save_path + ".tmp"


static func corrupt_path() -> String:
	return _save_path + ".corrupt"


## True if a main file or a backup exists.
static func has_save() -> bool:
	return FileAccess.file_exists(_save_path) or FileAccess.file_exists(backup_path())


static func save(data: Dictionary) -> Dictionary:
	var main: String = _save_path
	var tmp: String = temp_path()
	var bak: String = backup_path()

	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return _fail("cannot open temp file (error %d)" % FileAccess.get_open_error())
	file.store_string(JSON.stringify(data, "\t") + "\n")
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_remove(tmp)
		return _fail("temp file write failed (error %d)" % write_error)

	# Guards against a truncated or otherwise damaged write.
	var written: Dictionary = _read_json(tmp)
	if written["status"] != STATUS_OK or not json_equal(written["data"], data):
		_remove(tmp)
		return _fail("temp file did not read back identical")

	if FileAccess.file_exists(main) and _read_json(main)["status"] == STATUS_OK:
		var copy_error: Error = DirAccess.copy_absolute(main, bak)
		if copy_error != OK:
			_remove(tmp)
			return _fail("cannot update backup (error %d)" % copy_error)

	var move_error: Error = DirAccess.rename_absolute(tmp, main)
	if move_error != OK and FileAccess.file_exists(main):
		# The platform refused to replace an existing file: the backup already has the old data.
		_remove(main)
		move_error = DirAccess.rename_absolute(tmp, main)
		if move_error != OK and FileAccess.file_exists(bak):
			DirAccess.copy_absolute(bak, main)
	if move_error != OK:
		_remove(tmp)
		return _fail("cannot move temp file into place (error %d)" % move_error)
	return {"ok": true, "error": ""}


## `max_version` >= 0 makes a parsed save with a newer `save_version` come back as
## "unsupported_version" without touching any file (and without trying the backup).
static func load_game(max_version: int = -1) -> Dictionary:
	var main: String = _save_path
	var bak: String = backup_path()
	if not FileAccess.file_exists(main) and not FileAccess.file_exists(bak):
		return _load_result(STATUS_NO_SAVE, {}, "No save file")

	if FileAccess.file_exists(main):
		var main_read: Dictionary = _read_json(main)
		if main_read["status"] == STATUS_OK:
			if _is_newer(main_read["data"], max_version):
				return _load_result(STATUS_UNSUPPORTED, main_read["data"], "Save was written by a newer game version")
			return _load_result(STATUS_OK, main_read["data"], "Save loaded")
		_quarantine(main)

	if FileAccess.file_exists(bak):
		var bak_read: Dictionary = _read_json(bak)
		if bak_read["status"] == STATUS_OK:
			if _is_newer(bak_read["data"], max_version):
				return _load_result(STATUS_UNSUPPORTED, bak_read["data"], "Backup was written by a newer game version")
			DirAccess.copy_absolute(bak, main)
			return _load_result(STATUS_RECOVERED, bak_read["data"], "Main save was unreadable; restored from backup")
	return _load_result(STATUS_CORRUPT, {}, "Save file is corrupt and no valid backup exists")


## Removes the main file, the backup and the temp file. The quarantine file is kept.
static func delete_save() -> bool:
	for path in [_save_path, backup_path(), temp_path()]:
		_remove(path)
	return not FileAccess.file_exists(_save_path) and not FileAccess.file_exists(backup_path()) \
		and not FileAccess.file_exists(temp_path())


## Removes every file of the active path including the quarantine. For tests.
static func purge() -> void:
	delete_save()
	_remove(corrupt_path())


## Numbers come back from JSON as floats, so integers compare by value.
static func json_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not json_equal(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not json_equal(a[i], b[i]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return a == b


## {"status": "ok" | "corrupt", "data": Dictionary}. The root must be a Dictionary.
static func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": STATUS_CORRUPT, "data": {}}
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {"status": STATUS_CORRUPT, "data": {}}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"status": STATUS_CORRUPT, "data": {}}
	return {"status": STATUS_OK, "data": json.data}


static func _is_newer(data: Dictionary, max_version: int) -> bool:
	if max_version < 0:
		return false
	var version: Variant = data.get("save_version")
	return (version is int or version is float) and float(version) > float(max_version)


## Moves an unreadable file to the .corrupt path, replacing an older quarantine.
static func _quarantine(path: String) -> void:
	_remove(corrupt_path())
	if DirAccess.rename_absolute(path, corrupt_path()) != OK:
		push_warning("SaveSystem: could not quarantine '%s'" % path)


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _fail(message: String) -> Dictionary:
	push_warning("SaveSystem: " + message)
	return {"ok": false, "error": message}


static func _load_result(status: String, data: Dictionary, message: String) -> Dictionary:
	return {"status": status, "data": data, "message": message}

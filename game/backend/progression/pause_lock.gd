class_name PauseLock
extends RefCounted
## Central pause control. Every system that pauses the tree (decision panel, pause menu,
## game over) registers as a holder; the tree only resumes when the last holder releases.
## Holders are tracked by instance id and freed ones are purged on every call, so a freed
## panel can never keep the game paused. Knows nothing about GameState, UI or scenes.

static var _holders: Dictionary = {}


static func request(holder: Object, tree: SceneTree) -> void:
	_purge()
	if holder == null:
		return
	_holders[holder.get_instance_id()] = true
	if tree != null:
		tree.paused = true


## Releasing a holder that is not registered is a no-op (the tree is left as it is).
static func release(holder: Object, tree: SceneTree) -> void:
	var had_freed_holders: bool = _purge()
	if holder == null or not _holders.erase(holder.get_instance_id()):
		if had_freed_holders and _holders.is_empty() and tree != null:
			tree.paused = false
		return
	if _holders.is_empty() and tree != null:
		tree.paused = false


static func is_locked() -> bool:
	_purge()
	return not _holders.is_empty()


static func holder_count() -> int:
	_purge()
	return _holders.size()


## Clears every holder and unpauses (scene changes and tests).
static func reset(tree: SceneTree) -> void:
	_holders.clear()
	if tree != null:
		tree.paused = false


## Drops freed holders. Returns true if any was removed.
static func _purge() -> bool:
	var removed: bool = false
	for id: int in _holders.keys():
		if not is_instance_id_valid(id):
			_holders.erase(id)
			removed = true
	return removed

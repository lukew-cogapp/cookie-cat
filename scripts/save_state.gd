extends Node
## What survives between runs: cookies earned, cats unlocked, and the best run
## so far. Autoloaded as `Save`.
##
## A rogue-like has to remember, or every run starts from the same place and
## the cookies mean nothing. Written whenever it changes rather than only on
## quit: a child closes the window, they do not use a menu, and a run's cookies
## must not depend on how the game ended.
##
## Two backends. On desktop it is one JSON file in `user://`. On the web it is
## `localStorage`, NOT `user://`: there, `user://` is an in-memory filesystem
## synced to IndexedDB asynchronously, so `close()` only queues the write and a
## tab closed straight after a run loses its cookies (godot#39643).
## `localStorage` is synchronous, so the save is committed the moment it is
## written and there is no race to lose.

const PATH := "user://save.json"
## The browser localStorage key used instead of a file on the web. Namespaced,
## because every game published under the same github.io account shares one
## origin and therefore one storage bucket: an unprefixed "save" would be
## clobbered by the next game published beside this one.
const WEB_KEY := "cookie_cat_save_v1"
## Bumped when a field's meaning changes. An older file is discarded rather
## than migrated: there is nothing here worth a migration path.
const VERSION := 1

signal changed

var cookies := 0
var unlocked: Array[String] = []
## Maps bought, kept apart from the cats so neither list can price the other.
var maps: Array[String] = []
var best_time := 0.0
var best_kills := 0
var runs := 0


func _ready() -> void:
	load_now()


func _is_web() -> bool:
	return OS.get_name() == "Web"


## The stored JSON, or an empty string when there is nothing saved.
func _read_raw() -> String:
	if _is_web():
		var got: Variant = JavaScriptBridge.eval(
			"window.localStorage.getItem(%s) || ''" % JSON.stringify(WEB_KEY), true
		)
		return "" if got == null else String(got)
	if not FileAccess.file_exists(PATH):
		return ""
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _write_raw(text: String) -> void:
	if _is_web():
		# Both arguments are JSON-encoded rather than interpolated raw: the
		# payload contains quotes and braces, and pasting it into a JS string
		# would end the string early and run whatever followed.
		JavaScriptBridge.eval(
			"window.localStorage.setItem(%s, %s)"
			% [JSON.stringify(WEB_KEY), JSON.stringify(text)],
			true,
		)
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()


func load_now() -> void:
	unlocked = [Tuning.STARTER_CAT]
	maps = []
	cookies = 0
	best_time = 0.0
	best_kills = 0
	runs = 0
	var raw := _read_raw()
	if raw == "":
		return
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != VERSION:
		return
	cookies = int(d.get("cookies", 0))
	best_time = float(d.get("best_time", 0.0))
	best_kills = int(d.get("best_kills", 0))
	runs = int(d.get("runs", 0))
	# Rebuilt rather than assigned: a JSON array is untyped, and an unknown id
	# in an edited save would otherwise reach the cat picker.
	for id: Variant in d.get("unlocked", []):
		var name := String(id)
		if Tuning.CATS.has(name) and name not in unlocked:
			unlocked.append(name)
	# Same guard for maps. A save from before maps existed has no key, which
	# reads as none bought rather than a discarded file.
	for id: Variant in d.get("maps", []):
		var name := String(id)
		if Tuning.MAPS.has(name) and name not in maps:
			maps.append(name)
	changed.emit()


func save_now() -> void:
	_write_raw(
		JSON.stringify(
			{
				"version": VERSION,
				"cookies": cookies,
				"unlocked": unlocked,
				"maps": maps,
				"best_time": best_time,
				"best_kills": best_kills,
				"runs": runs,
			}
		)
	)


func add_cookies(amount: int) -> void:
	cookies += amount
	save_now()
	changed.emit()


func can_afford(id: String) -> bool:
	return Tuning.CATS.has(id) and cookies >= int(Tuning.CATS[id]["cost"])


## A cat costing nothing is always available, whatever an older save recorded.
func is_unlocked(id: String) -> bool:
	if Tuning.CATS.has(id) and int(Tuning.CATS[id]["cost"]) == 0:
		return true
	return id in unlocked


## Buys a cat. Returns false when it is already owned or unaffordable, so the
## caller can say why rather than the button doing nothing.
func unlock(id: String) -> bool:
	if is_unlocked(id) or not can_afford(id):
		return false
	cookies -= int(Tuning.CATS[id]["cost"])
	unlocked.append(id)
	save_now()
	changed.emit()
	return true


# --- Maps: the same shop, over Tuning.MAPS ---
func can_afford_map(id: String) -> bool:
	return Tuning.MAPS.has(id) and cookies >= int(Tuning.MAPS[id]["cost"])


## A free map is always open, whatever an older save recorded.
func is_map_unlocked(id: String) -> bool:
	if Tuning.MAPS.has(id) and int(Tuning.MAPS[id]["cost"]) == 0:
		return true
	return id in maps


func unlock_map(id: String) -> bool:
	if is_map_unlocked(id) or not can_afford_map(id):
		return false
	cookies -= int(Tuning.MAPS[id]["cost"])
	maps.append(id)
	save_now()
	changed.emit()
	return true


## Called once a run is over, with what it achieved.
func finish_run(seconds: float, kills: int, cookies_earned: int) -> void:
	runs += 1
	best_time = maxf(best_time, seconds)
	best_kills = maxi(best_kills, kills)
	cookies += cookies_earned
	save_now()
	changed.emit()

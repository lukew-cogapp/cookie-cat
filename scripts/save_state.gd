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
## Written first, then renamed over `PATH`, so a save is never half a file.
const TMP_PATH := "user://save.json.tmp"
## The browser localStorage key used instead of a file on the web. Namespaced,
## because every game published under the same github.io account shares one
## origin and therefore one storage bucket: an unprefixed "save" would be
## clobbered by the next game published beside this one.
const WEB_KEY := "cat_vs_bugs_save_v1"
## Bumped when a field's meaning changes. An older file is discarded rather
## than migrated: there is nothing here worth a migration path.
const VERSION := 1

signal changed

var cookies := 0
var unlocked: Array[String] = []
## Maps bought, kept apart from the cats so neither list can price the other.
var maps: Array[String] = []
## Hats bought, and the one being worn. Cosmetics are all cookies buy.
var hats: Array[String] = []
var hat: String = Tuning.STARTER_HAT
var best_time := 0.0
var best_kills := 0
var runs := 0
## The audio switches. Kept here so quiet survives closing the window: a child
## who turned the sound off did not mean only for one run.
##
## Music starts off. Ten minutes of one looping phrase wears thin on whoever is
## in the room, and the sound effects are what actually tell a child what just
## happened. It is one button on the title screen for anyone who wants it.
var sound_off := false
var music_off := true


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
	# Written beside the real file and renamed over it. `FileAccess.WRITE`
	# truncates the moment it opens, so writing in place means a kill between
	# the open and the close leaves an empty save. Android kills a backgrounded
	# app without warning, and this runs on exactly the actions a child takes
	# before leaving: buying a hat, finishing a run, turning the sound off.
	# A rename is atomic, so an interrupted write keeps the old save instead.
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	if f.get_error() != OK:
		DirAccess.remove_absolute(TMP_PATH)
		return
	DirAccess.rename_absolute(TMP_PATH, PATH)


func load_now() -> void:
	unlocked = [Tuning.STARTER_CAT]
	maps = []
	hats = []
	hat = Tuning.STARTER_HAT
	cookies = 0
	best_time = 0.0
	best_kills = 0
	runs = 0
	sound_off = false
	music_off = true
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
	sound_off = bool(d.get("sound_off", false))
	music_off = bool(d.get("music_off", true))
	Audio.set_muted(sound_off, music_off)
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
	# And for hats. The worn hat must also still be owned: an edited save
	# naming an unbought crown falls back to bare-headed.
	for id: Variant in d.get("hats", []):
		var name := String(id)
		if Tuning.HATS.has(name) and name not in hats:
			hats.append(name)
	var worn := String(d.get("hat", Tuning.STARTER_HAT))
	hat = worn if is_hat_unlocked(worn) else Tuning.STARTER_HAT
	changed.emit()


func save_now() -> void:
	_write_raw(
		JSON.stringify(
			{
				"version": VERSION,
				"cookies": cookies,
				"unlocked": unlocked,
				"maps": maps,
				"hats": hats,
				"hat": hat,
				"best_time": best_time,
				"best_kills": best_kills,
				"runs": runs,
				"sound_off": sound_off,
				"music_off": music_off,
			}
		)
	)


## Flips one of the audio switches and remembers it.
func set_audio(sound_is_off: bool, music_is_off: bool) -> void:
	sound_off = sound_is_off
	music_off = music_is_off
	Audio.set_muted(sound_off, music_off)
	save_now()
	changed.emit()


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


# --- Hats: the same shop, over Tuning.HATS ---
func can_afford_hat(id: String) -> bool:
	return Tuning.HATS.has(id) and cookies >= int(Tuning.HATS[id]["cost"])


## "none" costs nothing, so bare-headed is always available.
func is_hat_unlocked(id: String) -> bool:
	if Tuning.HATS.has(id) and int(Tuning.HATS[id]["cost"]) == 0:
		return true
	return id in hats


## Buying a hat also puts it on: a child who paid wants to see it at once.
func unlock_hat(id: String) -> bool:
	if is_hat_unlocked(id) or not can_afford_hat(id):
		return false
	cookies -= int(Tuning.HATS[id]["cost"])
	hats.append(id)
	hat = id
	save_now()
	changed.emit()
	return true


## Wears an owned hat. Refused for anything unowned, so the shop cannot equip
## what was not paid for.
func equip_hat(id: String) -> bool:
	if not is_hat_unlocked(id):
		return false
	hat = id
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

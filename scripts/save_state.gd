extends Node
## What survives between runs: cookies earned, cats unlocked, and the best run
## so far. Autoloaded as `Save`.
##
## A rogue-like has to remember, or every run starts from the same place and
## the cookies mean nothing. One JSON file in `user://`, written whenever it
## changes rather than only on quit: a child closes the window, they do not
## use a menu, and a run's cookies must not depend on how the game ended.

const PATH := "user://save.json"
## Bumped when a field's meaning changes. An older file is discarded rather
## than migrated: there is nothing here worth a migration path.
const VERSION := 1

signal changed

var cookies := 0
var unlocked: Array[String] = []
var best_time := 0.0
var best_kills := 0
var runs := 0


func _ready() -> void:
	load_now()


func load_now() -> void:
	unlocked = [Tuning.STARTER_CAT]
	cookies = 0
	best_time = 0.0
	best_kills = 0
	runs = 0
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
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
	changed.emit()


func save_now() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(
		JSON.stringify(
			{
				"version": VERSION,
				"cookies": cookies,
				"unlocked": unlocked,
				"best_time": best_time,
				"best_kills": best_kills,
				"runs": runs,
			}
		)
	)
	f.close()


func add_cookies(amount: int) -> void:
	cookies += amount
	save_now()
	changed.emit()


func can_afford(id: String) -> bool:
	return Tuning.CATS.has(id) and cookies >= int(Tuning.CATS[id]["cost"])


func is_unlocked(id: String) -> bool:
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


## Called once a run is over, with what it achieved.
func finish_run(seconds: float, kills: int, cookies_earned: int) -> void:
	runs += 1
	best_time = maxf(best_time, seconds)
	best_kills = maxi(best_kills, kills)
	cookies += cookies_earned
	save_now()
	changed.emit()

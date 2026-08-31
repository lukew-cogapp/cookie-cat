extends GutTest
## Cookies and unlocks, and that they survive a reload.
##
## `Save` writes to `user://save.json`, so these keep the real file's contents
## and put them back afterwards: a test run must not spend a child's cookies.

var _kept: Dictionary = {}


func before_all() -> void:
	_kept = {
		"cookies": Save.cookies,
		"unlocked": Save.unlocked.duplicate(),
		"maps": Save.maps.duplicate(),
		"hats": Save.hats.duplicate(),
		"hat": Save.hat,
		"best_time": Save.best_time,
		"best_kills": Save.best_kills,
		"runs": Save.runs,
	}


func after_all() -> void:
	Save.cookies = int(_kept["cookies"])
	Save.unlocked = _kept["unlocked"]
	Save.maps = _kept["maps"]
	Save.hats = _kept["hats"]
	Save.hat = String(_kept["hat"])
	Save.best_time = float(_kept["best_time"])
	Save.best_kills = int(_kept["best_kills"])
	Save.runs = int(_kept["runs"])
	Save.save_now()


func before_each() -> void:
	Save.cookies = 0
	Save.unlocked = [Tuning.STARTER_CAT]


func test_the_first_cat_is_free() -> void:
	assert_true(Save.is_unlocked(Tuning.STARTER_CAT), "there is always one cat")
	assert_eq(int(Tuning.CATS[Tuning.STARTER_CAT]["cost"]), 0, "and it costs nothing")


## Every cat is free: the choice of cat is the first decision of a run, not a
## reward to grind for. Cookies buy cosmetics instead, which change nothing
## about how a run plays.
func test_every_cat_is_free() -> void:
	for id: String in Tuning.CATS:
		assert_eq(int(Tuning.CATS[id]["cost"]), 0, "%s is free" % id)
		assert_true(Save.is_unlocked(id), "%s is available" % id)


## Including on a save written when they were not, so an older file does not
## hide a cat the game now gives away.
func test_an_old_save_still_gets_every_cat() -> void:
	Save.unlocked = [Tuning.STARTER_CAT]
	Save.save_now()
	Save.load_now()
	for id: String in Tuning.CATS:
		assert_true(Save.is_unlocked(id), "%s survived the old save" % id)


## Buying is refused for anything already owned, which now includes every cat.
func test_cannot_buy_what_is_already_owned() -> void:
	Save.cookies = 500
	var before := Save.cookies
	assert_false(Save.unlock("mint"), "refused: already owned")
	assert_eq(Save.cookies, before, "and charged nothing")


## The shop machinery still has to work, for the cosmetics cookies buy. Against
## a priced hat rather than a cat, since cats are free.
##
## This used to set `cookies` to 500 and assert it was 500, so it could not fail
## and the spend it is named for was never exercised.
func test_unlocking_spends_and_records() -> void:
	var id := "party"
	var cost := int(Tuning.HATS[id]["cost"])
	assert_gt(cost, 0, "the fixture hat is actually priced")
	Save.hats = []
	Save.cookies = cost + 40
	assert_false(Save.is_hat_unlocked(id), "not owned to begin with")
	assert_true(Save.unlock_hat(id), "bought")
	assert_eq(Save.cookies, 40, "and paid exactly its price")
	assert_true(Save.is_hat_unlocked(id), "and recorded")


## Buying the same cat twice would charge twice for nothing.
func test_cookies_accumulate_for_later() -> void:
	Save.cookies = 0
	Save.finish_run(120.0, 50, 40)
	Save.finish_run(120.0, 50, 35)
	assert_eq(Save.cookies, 75, "banked across runs")


func test_unknown_ids_are_refused() -> void:
	Save.cookies = 9999
	assert_false(Save.unlock("not_a_cat"), "no such cat")


## A rogue-like has to remember, or the cookies mean nothing.
func test_cookies_and_unlocks_survive_a_reload() -> void:
	Save.cookies = 250
	Save.unlock("mint")
	var cookies := Save.cookies
	Save.save_now()
	Save.load_now()
	assert_eq(Save.cookies, cookies, "cookies came back")
	assert_true(Save.is_unlocked("mint"), "and so did the cat")


func test_finish_run_records_the_best() -> void:
	Save.best_time = 0.0
	Save.best_kills = 0
	Save.finish_run(120.0, 80, 5)
	assert_eq(Save.best_time, 120.0, "the time")
	assert_eq(Save.best_kills, 80, "the kills")


## A worse run must not overwrite a better one.
func test_a_worse_run_does_not_lower_the_best() -> void:
	Save.best_time = 300.0
	Save.best_kills = 400
	Save.finish_run(10.0, 5, 1)
	assert_eq(Save.best_time, 300.0, "the best time stands")
	assert_eq(Save.best_kills, 400, "so does the best count")


func test_finish_run_banks_cookies() -> void:
	Save.cookies = 10
	Save.finish_run(60.0, 10, 7)
	assert_eq(Save.cookies, 17, "the run's cookies were added")


## An edited or corrupt save must not put an unknown cat in the picker.
func test_a_bad_id_in_the_file_is_dropped() -> void:
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string(
		JSON.stringify({"version": Save.VERSION, "cookies": 5, "unlocked": ["ghost_cat"]})
	)
	f.close()
	Save.load_now()
	assert_false("ghost_cat" in Save.unlocked, "the unknown id was dropped")
	assert_true(Save.is_unlocked(Tuning.STARTER_CAT), "and the starter is still there")


func test_a_stale_version_is_discarded() -> void:
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": Save.VERSION + 99, "cookies": 4321}))
	f.close()
	Save.load_now()
	assert_eq(Save.cookies, 0, "a file from another version is not read")


## The web build must not use `user://`. There it is an in-memory filesystem
## synced to IndexedDB asynchronously, so a tab closed straight after a run
## loses its cookies (godot#39643); localStorage is synchronous.
func test_the_web_key_is_namespaced() -> void:
	# Every game published under one github.io account shares an origin and
	# therefore one storage bucket, so an unprefixed key would be clobbered by
	# the next game published beside this one.
	assert_true(Save.WEB_KEY.begins_with("cookie_cat"), "the key names this game")


## Whatever the backend, a round trip has to survive. On desktop this exercises
## the file; on web it exercises localStorage, which is what CI cannot reach.
func test_a_round_trip_survives_the_backend() -> void:
	Save.cookies = 137
	Save.unlocked = [Tuning.STARTER_CAT, "mint"]
	Save.best_kills = 412
	Save.save_now()
	Save.cookies = 0
	Save.unlocked = []
	Save.best_kills = 0
	Save.load_now()
	assert_eq(Save.cookies, 137, "cookies came back")
	assert_eq(Save.best_kills, 412, "so did the best run")
	assert_true(Save.is_unlocked("mint"), "and the cat")


## An empty store must read as a fresh save rather than throwing: a first-time
## player has nothing stored at all.
func test_nothing_stored_reads_as_a_fresh_save() -> void:
	if not Save._is_web():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PATH))
	Save.load_now()
	assert_eq(Save.cookies, 0, "no cookies yet")
	assert_true(Save.is_unlocked(Tuning.STARTER_CAT), "but there is always one cat")

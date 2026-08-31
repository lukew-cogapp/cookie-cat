extends GutTest
## The hat shop: the only thing cookies buy. Everything that changes how a run
## plays is free, so a hat must change no number, and the shop machinery must
## not lose or invent one.
##
## Like save_test, these keep the real file's contents and put them back: a
## test run must not spend a child's cookies or knock their hat off.

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
	Save.hats = []
	Save.hat = Tuning.STARTER_HAT


func test_bare_headed_is_always_available() -> void:
	assert_true(Save.is_hat_unlocked(Tuning.STARTER_HAT), "no hat is always an option")
	assert_eq(int(Tuning.HATS[Tuning.STARTER_HAT]["cost"]), 0, "and it costs nothing")
	assert_true(Save.equip_hat(Tuning.STARTER_HAT), "and can always be worn")


## Every priced hat must have art on disk and a name; a shop card with a blank
## picture sells nothing to a child who reads by pictures.
func test_every_hat_has_art_and_a_name() -> void:
	for id: String in Tuning.HATS:
		assert_ne(String(Tuning.HATS[id]["name"]), "", "%s has a name" % id)
		if id == Tuning.STARTER_HAT:
			continue
		assert_true(
			ResourceLoader.exists(String(Tuning.HATS[id]["art"])), "%s art exists" % id
		)


## A run pays roughly 76 to 135 cookies. The cheapest hat must be one run away
## and the dearest a few, or the shop is a wall rather than something to want.
func test_prices_are_reachable() -> void:
	var costs: Array[int] = []
	for id: String in Tuning.HATS:
		if id != Tuning.STARTER_HAT:
			costs.append(int(Tuning.HATS[id]["cost"]))
	costs.sort()
	assert_lte(costs[0], 76, "the first hat is one run away")
	assert_lte(costs[-1], 4 * 135, "the last is a few runs, not a season")


func test_buying_spends_exactly_once() -> void:
	Save.cookies = int(Tuning.HATS["party"]["cost"]) + 5
	assert_true(Save.unlock_hat("party"), "the first buy works")
	assert_eq(Save.cookies, 5, "and charged the price")
	assert_false(Save.unlock_hat("party"), "buying it again is refused")
	assert_eq(Save.cookies, 5, "and charged nothing")


func test_buying_puts_the_hat_on() -> void:
	Save.cookies = int(Tuning.HATS["bow"]["cost"])
	Save.unlock_hat("bow")
	assert_eq(Save.hat, "bow", "a child who paid wants to see it at once")


func test_a_hat_that_cannot_be_afforded_stays_in_the_shop() -> void:
	Save.cookies = int(Tuning.HATS["crown"]["cost"]) - 1
	assert_false(Save.unlock_hat("crown"), "refused")
	assert_eq(Save.cookies, int(Tuning.HATS["crown"]["cost"]) - 1, "and charged nothing")
	assert_false(Save.is_hat_unlocked("crown"), "and not owned")


func test_an_unowned_hat_cannot_be_worn() -> void:
	assert_false(Save.equip_hat("crown"), "not paid for")
	assert_eq(Save.hat, Tuning.STARTER_HAT, "so the head stays bare")


func test_unknown_ids_are_refused() -> void:
	Save.cookies = 9999
	assert_false(Save.unlock_hat("propeller"), "no such hat to buy")
	assert_false(Save.equip_hat("propeller"), "or to wear")


func test_owned_and_worn_survive_a_reload() -> void:
	Save.cookies = int(Tuning.HATS["cap"]["cost"])
	Save.unlock_hat("cap")
	Save.load_now()
	assert_true(Save.is_hat_unlocked("cap"), "the hat came back")
	assert_eq(Save.hat, "cap", "still being worn")


func test_taking_the_hat_off_survives_a_reload() -> void:
	Save.cookies = int(Tuning.HATS["party"]["cost"])
	Save.unlock_hat("party")
	Save.equip_hat(Tuning.STARTER_HAT)
	Save.load_now()
	assert_eq(Save.hat, Tuning.STARTER_HAT, "bare-headed stuck")
	assert_true(Save.is_hat_unlocked("party"), "and the hat is still owned")


## An edited or corrupt save must not put an unknown hat on the cat.
func test_an_unknown_hat_in_the_file_is_dropped() -> void:
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string(
		JSON.stringify(
			{"version": Save.VERSION, "hats": ["propeller"], "hat": "propeller"}
		)
	)
	f.close()
	Save.load_now()
	assert_false("propeller" in Save.hats, "the unknown hat was dropped")
	assert_eq(Save.hat, Tuning.STARTER_HAT, "and the head is bare, not broken")


## A save naming an unbought crown as worn falls back to bare-headed.
func test_wearing_an_unowned_hat_in_the_file_is_refused() -> void:
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": Save.VERSION, "hats": [], "hat": "crown"}))
	f.close()
	Save.load_now()
	assert_eq(Save.hat, Tuning.STARTER_HAT, "not owned, so not worn")

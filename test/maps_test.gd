extends GutTest
## Maps: the garden, the beach and the arctic. A map swaps the floor, the
## decals and the props and nothing else, so these pin the tables' shape, the
## prices, and that the swap actually happens.
##
## Like `save_test.gd`, anything touching `Save` keeps the real file's
## contents and puts them back: a test run must not spend a child's cookies.

var _kept_cookies := 0
var _kept_maps: Array[String] = []
var _kept_map := ""


func before_all() -> void:
	_kept_cookies = Save.cookies
	_kept_maps = Save.maps.duplicate()
	_kept_map = Run.map


func after_all() -> void:
	Save.cookies = _kept_cookies
	Save.maps = _kept_maps
	Save.save_now()
	Run.map = _kept_map


func before_each() -> void:
	Save.cookies = 0
	Save.maps = []
	Run.map = Tuning.STARTER_MAP


## The child's first map must never be behind a price.
func test_the_garden_is_free_and_always_open() -> void:
	assert_eq(int(Tuning.MAPS[Tuning.STARTER_MAP]["cost"]), 0, "the garden costs nothing")
	assert_true(Save.is_map_unlocked(Tuning.STARTER_MAP), "and is always open")


## Every map needs the full set: a missing texture draws an invisible field.
func test_every_map_is_a_complete_place() -> void:
	for id: String in Tuning.MAPS:
		var m: Dictionary = Tuning.MAPS[id]
		assert_true(String(m["name"]).length() > 0, "%s has a name" % id)
		assert_true(ResourceLoader.exists(String(m["art"])), "%s has picker art" % id)
		assert_true(ResourceLoader.exists(String(m["lawn"])), "%s has a floor" % id)
		for path: String in m["ground_art"]:
			assert_true(ResourceLoader.exists(path), "%s decal loads" % path)
		for prop: Dictionary in m["props"]:
			assert_true(
				ResourceLoader.exists(String(prop["art"])), "%s prop art loads" % id
			)


## The decal tables are read side by side, so a short one indexes off the end.
func test_ground_tables_line_up() -> void:
	for id: String in Tuning.MAPS:
		var m: Dictionary = Tuning.MAPS[id]
		var kinds: int = m["ground_art"].size()
		assert_eq(m["ground_weights"].size(), kinds, "%s weights per kind" % id)
		assert_eq(m["ground_scale"].size(), kinds, "%s scales per kind" % id)
		assert_eq(m["ground_alpha"].size(), kinds, "%s alphas per kind" % id)


func test_ground_weights_cover_the_roll() -> void:
	for id: String in Tuning.MAPS:
		var sum := 0.0
		for w: float in Tuning.MAPS[id]["ground_weights"]:
			sum += w
		assert_almost_eq(sum, 1.0, 0.01, "%s weights sum to one" % id)


## The rule the garden's decals were tuned to: nothing on the ground competes
## with the bugs standing on it, so every big patch stays translucent.
func test_big_patches_stay_translucent() -> void:
	for id: String in Tuning.MAPS:
		var m: Dictionary = Tuning.MAPS[id]
		for k in m["ground_scale"].size():
			if float(m["ground_scale"][k]) >= 1.0:
				assert_lt(
					float(m["ground_alpha"][k]),
					0.85,
					"%s kind %d is see-through" % [id, k],
				)


## Every map's props keep the garden's rules: a few hits to break, and drops
## stingy enough that hearts stay meaningful.
func test_props_everywhere_keep_the_garden_rules() -> void:
	var paw := Tuning.weapon_stat("paw", "damage", 1)
	for id: String in Tuning.MAPS:
		for prop: Dictionary in Tuning.MAPS[id]["props"]:
			assert_gt(float(prop["hp"]), paw, "%s survives one swipe" % prop["name"])
			var special := float(prop["heart_chance"]) + float(prop["cookie_chance"])
			assert_lt(special, 0.6, "%s usually drops plain xp" % prop["name"])
			assert_gt(int(prop["xp"]), 0, "%s pays something" % prop["name"])


## Every place is free to pick, and has been since the beach and the arctic
## arrived. Three tests here used to describe a shop that charged for them, and
## went on failing for as long as the whole suite was timing out.
##
## A place a child cannot reach is worse than no place at all: choosing where to
## play is the one decision on the start screen that is not a cat, and paying
## for it would gate the only variety in the game behind a grind.
func test_every_map_is_free() -> void:
	for id: String in Tuning.MAPS:
		assert_eq(int(Tuning.MAPS[id]["cost"]), 0, "%s costs nothing" % id)


## And is therefore already owned, whatever the save file says. `unlock_map`
## still exists and still has to behave: a free map is granted, and granting it
## twice must not be an error a child could hit by tapping twice.
func test_a_free_map_is_owned_and_can_be_asked_for_twice() -> void:
	Save.cookies = 0
	assert_true(Save.is_map_unlocked("beach"), "the beach is there from the start")
	var held := Save.cookies
	Save.unlock_map("beach")
	assert_eq(Save.cookies, held, "and asking for it charges nothing")
	Save.unlock_map("beach")
	assert_true(Save.is_map_unlocked("beach"), "still owned after asking twice")
	assert_eq(Save.cookies, held, "and still free")
	assert_false(Save.unlock_map("moon"), "no such place")


## An edited save must not put an unknown map in the picker.
func test_a_bad_map_id_in_the_file_is_dropped() -> void:
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string(
		JSON.stringify({"version": Save.VERSION, "cookies": 5, "maps": ["moon"]})
	)
	f.close()
	Save.load_now()
	assert_false("moon" in Save.maps, "the unknown map was dropped")
	assert_true(Save.is_map_unlocked(Tuning.STARTER_MAP), "and the garden is still there")


## `Run.map` is what the world reads, so an id the tables lack must fall back
## rather than crash mid-load.
func test_an_unknown_map_falls_back_to_the_garden() -> void:
	assert_eq(Tuning.map_info("moon"), Tuning.MAPS[Tuning.STARTER_MAP], "the garden")


func test_the_ground_swaps_with_the_map() -> void:
	Run.map = "beach"
	var ground := Ground.new()
	add_child_autofree(ground)
	await wait_process_frames(1)
	assert_eq(ground._art, Tuning.MAPS["beach"]["ground_art"], "beach decals")
	ground.scatter(Vector2.ZERO)
	assert_eq(ground.alive, Tuning.GROUND_COUNT, "and the field still fills")


func test_the_props_swap_with_the_map() -> void:
	Run.map = "arctic"
	var props := Props.new()
	add_child_autofree(props)
	await wait_process_frames(1)
	props.set_physics_process(false)
	assert_eq(props._table, Tuning.MAPS["arctic"]["props"], "arctic props")
	props.scatter(Vector2.ZERO)
	assert_eq(props.count(), Tuning.PROP_COUNT, "and the field still fills")

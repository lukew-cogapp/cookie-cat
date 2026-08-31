extends GutTest
## The pick screen.
##
## Building a card crashed on every passive and every snack: the `data`
## initialiser read `Tuning.WEAPONS[id]` before the branch below could redirect
## it, so the picker filled with nothing and the run stalled with the tree
## paused. It shipped past a green suite because nothing built a card.

var _hud: CanvasLayer


func before_all() -> void:
	_hud = load("res://scenes/hud.tscn").instantiate()
	add_child(_hud)
	await wait_process_frames(1)


func after_all() -> void:
	_hud.free()


## The regression: every id the picker can offer must build a card.
func test_a_card_builds_for_everything_offerable() -> void:
	var ids: Array[String] = []
	for id: String in Tuning.WEAPONS:
		ids.append(id)
	for id: String in Tuning.PASSIVES:
		ids.append(id)
	for id: String in Tuning.CONSUMABLES:
		ids.append(id)
	for id in ids:
		var card: Button = _hud._card(id)
		assert_not_null(card, "%s builds a card" % id)
		if card != null:
			card.free()


## A card with no words on it is a card a child cannot be told about.
func test_every_card_names_itself() -> void:
	for id: String in Tuning.WEAPONS:
		var card: Button = _hud._card(id)
		var found := _labels(card)
		assert_true(
			String(Tuning.WEAPONS[id]["name"]) in found,
			"%s shows its name" % id,
		)
		card.free()


## The one thing that must never be wrong on a snack card: it is not an upgrade
## of something owned, so pips would lie about it.
func test_a_snack_card_is_not_marked_as_an_upgrade() -> void:
	for id: String in Tuning.CONSUMABLES:
		var card: Button = _hud._card(id)
		assert_null(_find_pips(card), "%s counts no levels" % id)
		card.free()


## Web exports cannot rely on a star glyph either, so an upgrade card counts its
## level in drawn pips. An unowned toy says NEW! instead and has none.
func test_an_upgrade_card_counts_its_level_without_font_glyphs() -> void:
	Run.cat = Tuning.STARTER_CAT
	Run.start()
	# start() grants the cat's own weapon at level one, so an unowned toy has to
	# come from elsewhere in the table.
	var id := String(Tuning.CATS[Run.cat]["weapon"])
	var unowned := ""
	for other: String in Tuning.WEAPONS:
		if Run.level_of(other) == 0:
			unowned = other
			break
	assert_ne(unowned, "", "the table holds a weapon the starter cat lacks")
	if unowned != "":
		var fresh: Button = _hud._card(unowned)
		assert_null(_find_pips(fresh), "an unowned toy says NEW! rather than counting")
		fresh.free()
	Run.take(id)
	var card: Button = _hud._card(id)
	var pips := _find_pips(card)
	assert_not_null(pips, "an owned toy's card counts in pips")
	if pips != null:
		assert_eq(_visible_child_count(pips), 3, "the card counts the level it grants")
		assert_eq(_labels(card).contains("*"), false, "no star glyph")
	card.free()
	Run.alive = false


func _labels(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		out += _labels(child)
	return out


## Escape pauses. It must be refused while the picker or the end screen is up:
## both already pause the tree, and unpausing under them would let the run
## carry on behind a modal.
func test_pause_is_refused_under_a_modal() -> void:
	Run.start()
	_hud._picker.visible = true
	_hud._unhandled_input(_pause_event())
	assert_false(_hud._paused.visible, "no pause menu over the picker")
	_hud._picker.visible = false
	_hud._over.visible = true
	_hud._unhandled_input(_pause_event())
	assert_false(_hud._paused.visible, "nor over the end screen")
	_hud._over.visible = false
	Run.alive = false


func test_pause_toggles() -> void:
	Run.start()
	_hud._unhandled_input(_pause_event())
	assert_true(_hud._paused.visible, "paused")
	_hud._unhandled_input(_pause_event())
	assert_false(_hud._paused.visible, "and unpaused again")
	get_tree().paused = false
	Run.alive = false


## The panel must not leave the tree paused behind it, which would freeze the
## run with nothing on screen to explain why.
func test_unpausing_resumes_the_tree() -> void:
	Run.start()
	_hud._pause()
	_hud._unpause()
	assert_false(get_tree().paused, "the run is running again")
	Run.alive = false


## The loadout is what tells a child what they have. One row per toy, and a pip
## per level, however many they end up with.
func test_the_loadout_lists_what_is_owned() -> void:
	Run.start()
	Run.take("yarn")
	Run.take("yarn")
	Run.take("claw")
	_hud._refresh_loadout()
	var shown := 0
	for row in _hud._loadout.get_children():
		if row.visible:
			shown += 1
	assert_eq(shown, Run.weapons.size() + Run.passives.size(), "a row each")
	Run.alive = false


## Web exports cannot rely on the filled-circle glyph being present in the
## browser fallback font, so the level counters are drawn controls, not text.
func test_the_loadout_level_counters_do_not_need_font_glyphs() -> void:
	Run.cat = Tuning.STARTER_CAT
	Run.start()
	Run.take(String(Tuning.CATS[Run.cat]["weapon"]))
	_hud._refresh_loadout()
	var row: Control = _hud._loadout.get_child(0)
	var pips: HBoxContainer = row.get_node("Pips")
	assert_eq(_visible_child_count(pips), 2, "level two is two drawn pips")
	assert_eq(_labels(pips), "", "no bullet glyph label")
	Run.alive = false


## Rows are reused, so picking fewer things must hide the spare rows rather
## than leave a stale toy on screen.
func test_spare_loadout_rows_are_hidden() -> void:
	Run.start()
	for id: String in Tuning.WEAPONS:
		Run.weapons[id] = 1
	_hud._refresh_loadout()
	var many: int = _hud._loadout.get_child_count()
	Run.start()
	_hud._refresh_loadout()
	var shown := 0
	for row in _hud._loadout.get_children():
		if row.visible:
			shown += 1
	assert_eq(_hud._loadout.get_child_count(), many, "rows were kept")
	assert_eq(shown, 1, "but only the starter is shown")
	Run.alive = false


func _find_pips(node: Node) -> HBoxContainer:
	for child: Node in node.get_children():
		if child.name == "Pips" and child is HBoxContainer:
			return child as HBoxContainer
		var found := _find_pips(child)
		if found != null:
			return found
	return null


func _visible_child_count(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			count += 1
	return count


func _pause_event() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "pause"
	e.pressed = true
	return e


## Three cards, actually on screen. `_choices` always returned three, but a
## card that threw while building was silently dropped, so a level-up showed one
## or two: the crash was in `_card` and no test built one.
func test_a_level_up_shows_three_cards() -> void:
	Run.start()
	Run.hurt = true
	for _attempt in 25:
		var choices: Array = Run._choices()
		assert_eq(choices.size(), Tuning.LEVEL_CHOICES, "three offered")
		var built := 0
		for id: String in choices:
			var card: Button = _hud._card(id)
			if card != null:
				built += 1
				card.free()
		assert_eq(built, choices.size(), "and all three built: %s" % str(choices))
	Run.hurt = false
	Run.alive = false

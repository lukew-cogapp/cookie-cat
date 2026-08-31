extends Control
## The front door: pick a cat and a place, see the cookie jar, press Play.
##
## Cards are built in code from `Tuning.CATS` and `Tuning.MAPS`, the way the
## HUD builds level-up cards: every part is driven by the id. The words here
## are for the adult; the child plays this screen by pictures alone, so Play
## holds focus from the first frame and one confirm press starts a run.

@onready var _title: Label = $Title
@onready var _cards: HBoxContainer = $Cards
@onready var _maps: HBoxContainer = $Maps
@onready var _hats: HBoxContainer = $Hats
@onready var _play: Button = $Play
@onready var _quit: Button = $Quit
@onready var _music_button: Button = $Audio/Music
@onready var _sound_button: Button = $Audio/Sound
@onready var _cookies: Label = $Cookies/Pad/Row/Count
@onready var _stats: Label = $Stats
@onready var _bugs: Control = $Bugs

var _card_style := load("res://ui/card.tres")
var _card_hover := load("res://ui/card_hover.tres")
var _card_selected := load("res://ui/card_selected.tres")

## Cat id -> its card, and -> its portrait, for selection and the hop.
var _buttons: Dictionary = {}
var _arts: Dictionary = {}
## The same pair for the map row.
var _map_buttons: Dictionary = {}
var _map_arts: Dictionary = {}
## And for the hat shop, plus each card's price row, hidden once it is owned.
var _hat_buttons: Dictionary = {}
var _hat_arts: Dictionary = {}
var _hat_prices: Dictionary = {}
## Hat overlay per cat card, so the picker shows the cat as it will play.
var _cat_hats: Dictionary = {}
var _hop: Tween


func _ready() -> void:
	_music_button.pressed.connect(_toggle_music)
	_sound_button.pressed.connect(_toggle_sound)
	_refresh_audio()
	_title.text = ProjectSettings.get_setting("application/config/name")
	# An edited save or a version bump can orphan the remembered cat or map.
	if not Save.is_unlocked(Run.cat):
		Run.cat = Tuning.STARTER_CAT
	if not Save.is_map_unlocked(Run.map):
		Run.map = Tuning.STARTER_MAP
	_play.pressed.connect(_start)
	# Nothing to quit to in a browser tab, and a dead button a child presses
	# twice is worse than no button.
	_quit.visible = OS.get_name() != "Web"
	_quit.pressed.connect(_quit_game)
	Save.changed.connect(_refresh)
	_build_cards()
	_build_map_cards()
	_build_hat_cards()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	_wire_focus()
	_select(Run.cat)
	_select_map(Run.map)
	_refresh()
	_bob_title()
	_pulse_play()
	for _i in Tuning.START_BUG_COUNT:
		_launch_bug(_make_bug(), true)
	# `play_music` is idempotent, so the loop carries into the run unbroken.
	Audio.play_music("music")
	_play.grab_focus()


## Places the map-and-hat strip against the width the screen actually has.
##
## Everything else here is centred and has room to spare at any width. The strip
## does not: it is about 1170 units of small cards, hand-placed for the 1280
## design, and the last hat card was drawn off the edge of a 4:3 window. See
## `Tuning.START_BAND_MARGIN` for why a wider screen means more units.
##
## Connected to `size_changed` as well as called from `_ready`, because a
## browser tab is resized constantly: a phone rotating, and Safari collapsing
## its toolbar on the first scroll.
## `at_width` is for the tests, which need to check a phone's 1600 units and a
## 4:3 window's 960 without owning a window of either size.
func _relayout(at_width := 0.0) -> void:
	var width := at_width if at_width > 0.0 else get_viewport_rect().size.x
	# The scene's own alignment would fight these offsets: Maps right-aligns and
	# Hats left-aligns, which was how the two halves met in the middle of the
	# old fixed strip. Each group is now placed exactly, so both fill.
	_maps.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hats.alignment = BoxContainer.ALIGNMENT_BEGIN
	# GROW_DIRECTION_BOTH lets a container widen past its own offsets to fit its
	# children's minimum sizes, which silently undid every offset set below. The
	# offsets are the authority here, so the growth has to be off.
	_maps.grow_horizontal = Control.GROW_DIRECTION_END
	_hats.grow_horizontal = Control.GROW_DIRECTION_END
	_maps.add_theme_constant_override("separation", int(Tuning.START_MAP_SEPARATION))
	_hats.add_theme_constant_override("separation", int(Tuning.START_HAT_SEPARATION))
	# The cards shrink to whatever fits, rather than to one of two fixed sizes:
	# the widths in play run from a 900-unit desktop window to a 1680-unit
	# phone, and no single smaller size covers both ends. Never above 1.0, so a
	# wide screen gets margin rather than oversized cards.
	var room := width - Tuning.START_BAND_MARGIN * 2.0
	var fixed := (
		(Tuning.MAPS.size() - 1) * Tuning.START_MAP_SEPARATION
		+ (Tuning.HATS.size() - 1) * Tuning.START_HAT_SEPARATION
		+ Tuning.START_BAND_GAP
	)
	var per_scale := (
		Tuning.MAPS.size() * Tuning.START_MAP_CARD_SIZE.x
		+ Tuning.HATS.size() * Tuning.START_HAT_CARD_SIZE.x
	)
	var scale := clampf((room - fixed) / per_scale, Tuning.START_BAND_MIN_SCALE, 1.0)
	for id: String in _map_buttons:
		(_map_buttons[id] as Control).custom_minimum_size = (
			Tuning.START_MAP_CARD_SIZE * scale
		)
	for id: String in _hat_buttons:
		(_hat_buttons[id] as Control).custom_minimum_size = (
			Tuning.START_HAT_CARD_SIZE * scale
		)
	# The two groups' own widths, from the tables rather than measured: a
	# container's `size` is an output of the layout pass and is stale on the
	# frame its contents changed.
	var maps_w := (
		Tuning.MAPS.size() * Tuning.START_MAP_CARD_SIZE.x * scale
		+ (Tuning.MAPS.size() - 1) * Tuning.START_MAP_SEPARATION
	)
	var hats_w := (
		Tuning.HATS.size() * Tuning.START_HAT_CARD_SIZE.x * scale
		+ (Tuning.HATS.size() - 1) * Tuning.START_HAT_SEPARATION
	)
	# Centred as one strip, so the gap between the groups stays in the middle
	# however much room there is either side. Both containers are anchored to the
	# centre of the screen, so these offsets are measured from there and the left
	# edge of the strip is negative.
	var total := maps_w + Tuning.START_BAND_GAP + hats_w
	var left := -total * 0.5
	# Only the left edge is set. A container sizes itself to its children's
	# minimums and the layout pass rewrites `offset_right`, so assigning it does
	# nothing: the group's width follows its cards, and placing the left edge is
	# what centres the strip.
	_maps.offset_left = left
	_hats.offset_left = left + maps_w + Tuning.START_BAND_GAP


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")


## Written before quitting rather than trusted to the autosave. `Save` writes on
## every change, so there is normally nothing outstanding, but `quit()` tears
## the tree down and this is the one exit that can be sure it did not race one.
func _quit_game() -> void:
	Save.save_now()
	get_tree().quit()


func _refresh() -> void:
	_cookies.text = str(Save.cookies)
	_refresh_hats()
	if Save.runs == 0:
		# A first-time player has no history worth printing.
		_stats.text = ""
		return
	var m := int(Save.best_time) / 60
	var s := int(Save.best_time) % 60
	_stats.text = (
		"Best %d:%02d   -   %d bugs bopped   -   %d runs"
		% [m, s, Save.best_kills, Save.runs]
	)


func _build_cards() -> void:
	for id: String in Tuning.CATS:
		var b := _card(id)
		_buttons[id] = b
		_cards.add_child(b)


func _build_map_cards() -> void:
	for id: String in Tuning.MAPS:
		var b := _map_card(id)
		_map_buttons[id] = b
		_maps.add_child(b)


func _build_hat_cards() -> void:
	for id: String in Tuning.HATS:
		var b := _hat_card(id)
		_hat_buttons[id] = b
		_hats.add_child(b)


## A card: the cat, its name, and the toy it starts with. Nothing is locked, so
## there is no price row and no greyed state to draw.
func _card(id: String) -> Button:
	var cat: Dictionary = Tuning.CATS[id]

	var b := Button.new()
	b.custom_minimum_size = Tuning.START_CARD_SIZE
	b.add_theme_stylebox_override("normal", _card_style)
	b.add_theme_stylebox_override("hover", _card_hover)
	b.add_theme_stylebox_override("focus", _card_hover)
	b.add_theme_stylebox_override("pressed", _card_hover)
	b.pressed.connect(_press.bind(id))

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	# So the click lands on the button, not on the pictures sitting over it.
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var art := TextureRect.new()
	art.texture = load(String(cat["art"]))
	art.custom_minimum_size = Tuning.START_CAT_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arts[id] = art
	col.add_child(art)

	# The equipped hat, over the portrait: hat and cat are both 16x16 sharing
	# an origin, so a full-rect overlay lines the pixels up. It is then lifted
	# by HAT_LIFT, scaled from the art's 16px to the portrait's drawn size.
	var hat := TextureRect.new()
	hat.set_anchors_preset(Control.PRESET_FULL_RECT)
	hat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hat.offset_top = Tuning.HAT_LIFT * Tuning.START_CAT_SIZE.y / 16.0
	hat.offset_bottom = hat.offset_top
	_cat_hats[id] = hat
	art.add_child(hat)

	var cat_name := Label.new()
	cat_name.text = String(cat["name"])
	cat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_name.add_theme_font_size_override("font_size", Tuning.TEXT_BODY)
	col.add_child(cat_name)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)

	var weapon := String(cat["weapon"])
	if Tuning.ICONS.has(weapon):
		row.add_child(_pixel_icon(String(Tuning.ICONS[weapon])))
	var wname := Label.new()
	wname.text = String(Tuning.WEAPONS[weapon]["name"])
	wname.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wname.add_theme_font_size_override("font_size", Tuning.TEXT_TINY)
	wname.add_theme_color_override("font_color", Tuning.CARD_BLURB_COLOUR)
	row.add_child(wname)

	return b


## A map card: a postcard of the place and its name. Nothing is locked, so the
## picture is the whole promise.
func _map_card(id: String) -> Button:
	var info: Dictionary = Tuning.MAPS[id]

	var b := Button.new()
	b.custom_minimum_size = Tuning.START_MAP_CARD_SIZE
	b.add_theme_stylebox_override("normal", _card_style)
	b.add_theme_stylebox_override("hover", _card_hover)
	b.add_theme_stylebox_override("focus", _card_hover)
	b.add_theme_stylebox_override("pressed", _card_hover)
	b.pressed.connect(_press_map.bind(id))

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var art := TextureRect.new()
	art.texture = load(String(info["art"]))
	art.custom_minimum_size = Tuning.START_MAP_ART_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_arts[id] = art
	col.add_child(art)

	var map_name := Label.new()
	map_name.text = String(info["name"])
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_name.add_theme_font_size_override("font_size", Tuning.TEXT_SMALL)
	col.add_child(map_name)


	return b


## A hat card: the hat, its name, and its cookie price until it is owned. The
## "none" card wears the chosen cat's bare face, so taking the hat off is a
## picture rather than a word.
func _hat_card(id: String) -> Button:
	var info: Dictionary = Tuning.HATS[id]

	var b := Button.new()
	b.custom_minimum_size = Tuning.START_HAT_CARD_SIZE
	b.add_theme_stylebox_override("normal", _card_style)
	b.add_theme_stylebox_override("hover", _card_hover)
	b.add_theme_stylebox_override("focus", _card_hover)
	b.add_theme_stylebox_override("pressed", _card_hover)
	b.pressed.connect(_press_hat.bind(id))

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var art := TextureRect.new()
	if String(info["art"]) != "":
		art.texture = load(String(info["art"]))
	art.custom_minimum_size = Tuning.START_HAT_ART_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hat_arts[id] = art
	col.add_child(art)

	var hat_name := Label.new()
	hat_name.text = String(info["name"])
	hat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hat_name.add_theme_font_size_override("font_size", Tuning.TEXT_TINY)
	col.add_child(hat_name)

	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 4)
	var icon := _pixel_icon(Tuning.pickup_art("cookie"))
	icon.custom_minimum_size = Tuning.START_HAT_COOKIE_SIZE
	price.add_child(icon)
	var cost := Label.new()
	cost.text = str(int(info["cost"]))
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", Tuning.TEXT_TINY)
	cost.add_theme_color_override("font_color", Tuning.START_COST_COLOUR)
	price.add_child(cost)
	_hat_prices[id] = price
	col.add_child(price)

	return b


func _pixel_icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.custom_minimum_size = Tuning.START_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


## Left and right wrap around each row; up and down cycle cats, the shop band
## and Play, so a gamepad can never park focus in a dead end. Maps and hats
## share one band, so left and right walk from the last map into the first hat
## and wrap round. Rebuilt rows leave their old cards dying until the frame
## ends, so those are filtered out.
func _wire_focus() -> void:
	var alive := func(c: Node) -> bool: return not c.is_queued_for_deletion()
	var cats: Array = _cards.get_children().filter(alive)
	var band: Array = _maps.get_children().filter(alive) + _hats.get_children().filter(alive)
	for i in cats.size():
		var b: Button = cats[i]
		b.focus_neighbor_left = b.get_path_to(cats[(i - 1 + cats.size()) % cats.size()])
		b.focus_neighbor_right = b.get_path_to(cats[(i + 1) % cats.size()])
		b.focus_neighbor_top = b.get_path_to(_play)
		b.focus_neighbor_bottom = b.get_path_to(band[mini(i, band.size() - 1)])
	for i in band.size():
		var b: Button = band[i]
		b.focus_neighbor_left = b.get_path_to(band[(i - 1 + band.size()) % band.size()])
		b.focus_neighbor_right = b.get_path_to(band[(i + 1) % band.size()])
		b.focus_neighbor_top = b.get_path_to(cats[mini(i, cats.size() - 1)])
		b.focus_neighbor_bottom = b.get_path_to(_play)
	_play.focus_neighbor_top = _play.get_path_to(band[0])
	# Quit sits between Play and the cats, and drops out of the cycle entirely on
	# the web, where it is hidden: a focus neighbour pointing at a hidden button
	# is a dead end, which is the thing this whole function exists to avoid.
	if _quit.visible:
		_play.focus_neighbor_bottom = _play.get_path_to(_quit)
		_quit.focus_neighbor_top = _quit.get_path_to(_play)
		_quit.focus_neighbor_bottom = _quit.get_path_to(cats[0])
		_quit.focus_neighbor_left = _quit.get_path_to(_quit)
		_quit.focus_neighbor_right = _quit.get_path_to(_quit)
		for i in cats.size():
			var b: Button = cats[i]
			b.focus_neighbor_top = b.get_path_to(_quit)
	else:
		_play.focus_neighbor_bottom = _play.get_path_to(cats[0])


## The audio switches. Off is shown by dimming rather than by words, since the
## label has to stay readable to someone who cannot read it.
func _refresh_audio() -> void:
	_music_button.modulate.a = Tuning.START_AUDIO_OFF_ALPHA if Save.music_off else 1.0
	_sound_button.modulate.a = Tuning.START_AUDIO_OFF_ALPHA if Save.sound_off else 1.0


func _toggle_music() -> void:
	Save.set_audio(Save.sound_off, not Save.music_off)
	if not Save.music_off:
		Audio.play_music("music")
	_refresh_audio()
	Audio.play("choose")


func _toggle_sound() -> void:
	Save.set_audio(not Save.sound_off, Save.music_off)
	_refresh_audio()
	# After the switch, so turning sound back ON is audible and turning it off
	# is silent, which is the feedback a child expects.
	Audio.play("choose")


func _press(id: String) -> void:
	Audio.play("choose")
	_select(id)


func _select(id: String) -> void:
	Run.cat = id
	for cid: String in _buttons:
		var style: StyleBox = _card_selected if cid == id else _card_style
		_buttons[cid].add_theme_stylebox_override("normal", style)
	# The "no hat" card wears whichever cat is chosen.
	_hat_arts[Tuning.STARTER_HAT].texture = load(String(Tuning.CATS[id]["art"]))
	_hop_art(_arts[id])


func _press_map(id: String) -> void:
	Audio.play("choose")
	_select_map(id)


func _select_map(id: String) -> void:
	Run.map = id
	for mid: String in _map_buttons:
		var style: StyleBox = _card_selected if mid == id else _card_style
		_map_buttons[mid].add_theme_stylebox_override("normal", style)
	_hop_art(_map_arts[id])


## Owned on press wears it; unowned on press buys it, which also wears it; and
## a price the jar cannot cover shakes its head, the one refusal on the screen.
func _press_hat(id: String) -> void:
	if Save.is_hat_unlocked(id):
		Save.equip_hat(id)
		Audio.play("choose")
		_hop_art(_hat_arts[id])
	elif Save.unlock_hat(id):
		Audio.play("chest")
		_hop_art(_hat_arts[id])
	else:
		_wobble(_hat_buttons[id])


## Owned hats drop their price and stand full colour; the worn one is framed,
## on its card and on every cat portrait above.
func _refresh_hats() -> void:
	for id: String in _hat_buttons:
		var owned := Save.is_hat_unlocked(id)
		var style: StyleBox = _card_selected if id == Save.hat else _card_style
		_hat_buttons[id].add_theme_stylebox_override("normal", style)
		_hat_arts[id].modulate = Color.WHITE if owned else Tuning.START_LOCKED_TINT
		# Invisible rather than gone, so every card keeps the same layout.
		_hat_prices[id].modulate.a = 0.0 if owned else 1.0
	var path := Tuning.hat_art(Save.hat)
	var tex: Texture2D = load(path) if path != "" else null
	for cid: String in _cat_hats:
		_cat_hats[cid].texture = tex


## A card the player cannot afford shakes its head.
func _wobble(card: Control) -> void:
	var t := create_tween()
	for _n in 2:
		t.tween_property(
			card, "position:x", -Tuning.START_WOBBLE, Tuning.START_WOBBLE_TIME
		).as_relative()
		t.tween_property(
			card, "position:x", Tuning.START_WOBBLE, Tuning.START_WOBBLE_TIME
		).as_relative()


func _hop_art(art: TextureRect) -> void:
	# Mid-hop the portrait is off its resting spot; a second hop from there
	# would walk it up the card.
	if _hop and _hop.is_running():
		return
	var half := Tuning.START_HOP_TIME * 0.5
	_hop = create_tween().set_trans(Tween.TRANS_SINE)
	_hop.tween_property(art, "position:y", -Tuning.START_HOP, half).as_relative().set_ease(Tween.EASE_OUT)
	_hop.tween_property(art, "position:y", Tuning.START_HOP, half).as_relative().set_ease(Tween.EASE_IN)


func _bob_title() -> void:
	var half := Tuning.START_TITLE_BOB_TIME
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_title, "position:y", -Tuning.START_TITLE_BOB, half).as_relative()
	t.tween_property(_title, "position:y", Tuning.START_TITLE_BOB, half).as_relative()


func _pulse_play() -> void:
	# The pivot needs the button's laid-out size, which _ready is too early for.
	await get_tree().process_frame
	_play.pivot_offset = _play.size * 0.5
	var pulse := Vector2.ONE * Tuning.START_PLAY_PULSE
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_play, "scale", pulse, Tuning.START_PLAY_PULSE_TIME)
	t.tween_property(_play, "scale", Vector2.ONE, Tuning.START_PLAY_PULSE_TIME)


func _make_bug() -> TextureRect:
	var bug := TextureRect.new()
	# Never the Big Bug: the menu lawn is a calm place. Named rather than counted
	# off the end of the list, which excluded whichever kind happened to be last
	# and let the boss onto the lawn as soon as one was added after it.
	var kind := randi() % Tuning.ENEMY_TEXTURES.size()
	if kind == Swarm.Kind.BIG:
		kind = Swarm.Kind.GRUB
	bug.texture = load(Tuning.ENEMY_TEXTURES[kind])
	bug.custom_minimum_size = Tuning.START_BUG_SIZE
	bug.size = Tuning.START_BUG_SIZE
	bug.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bug.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bug.modulate.a = Tuning.START_BUG_ALPHA
	_bugs.add_child(bug)
	return bug


## Sends a bug ambling across the lawn, then round it goes again. The first
## batch starts mid-crossing, so the lawn is alive on frame one.
func _launch_bug(bug: TextureRect, mid_crossing: bool) -> void:
	var view := get_viewport_rect().size
	var ltr := randf() < 0.5
	var from_x := -Tuning.START_BUG_SIZE.x if ltr else view.x
	var to_x := view.x if ltr else -Tuning.START_BUG_SIZE.x
	bug.flip_h = not ltr
	var secs := randf_range(Tuning.START_BUG_TIME_MIN, Tuning.START_BUG_TIME_MAX)
	bug.position = Vector2(from_x, randf_range(0.05, 0.92) * view.y)
	if mid_crossing:
		var part := randf()
		bug.position.x = lerpf(from_x, to_x, part)
		secs *= 1.0 - part
	var t := create_tween()
	t.tween_property(bug, "position:x", to_x, secs)
	t.tween_callback(_launch_bug.bind(bug, false))

extends Control
## The front door: pick a cat, see the cookie jar, press Play.
##
## Cards are built in code from `Tuning.CATS`, the way the HUD builds level-up
## cards: every part is driven by the id. The words here are for the adult;
## the child plays this screen by pictures alone, so Play holds focus from the
## first frame and one confirm press starts a run.

@onready var _title: Label = $Title
@onready var _cards: HBoxContainer = $Cards
@onready var _play: Button = $Play
@onready var _cookies: Label = $Cookies/Pad/Row/Count
@onready var _stats: Label = $Stats
@onready var _bugs: Control = $Bugs

var _card_style := load("res://ui/card.tres")
var _card_hover := load("res://ui/card_hover.tres")
var _card_selected := load("res://ui/card_selected.tres")

## Cat id -> its card, and -> its portrait, for selection and the hop.
var _buttons: Dictionary = {}
var _arts: Dictionary = {}
var _hop: Tween


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name")
	# An edited save or a version bump can orphan the remembered cat.
	if not Save.is_unlocked(Run.cat):
		Run.cat = Tuning.STARTER_CAT
	_play.pressed.connect(_start)
	Save.changed.connect(_refresh)
	_build_cards()
	_select(Run.cat)
	_refresh()
	_bob_title()
	_pulse_play()
	for _i in Tuning.START_BUG_COUNT:
		_launch_bug(_make_bug(), true)
	# `play_music` is idempotent, so the loop carries into the run unbroken.
	Audio.play_music("music")
	_play.grab_focus()


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _refresh() -> void:
	_cookies.text = str(Save.cookies)
	if Save.runs == 0:
		# A first-time player has no history worth printing.
		_stats.text = ""
		return
	var m := int(Save.best_time) / 60
	var s := int(Save.best_time) % 60
	_stats.text = (
		"Best %d:%02d   ·   %d bugs bopped   ·   %d runs"
		% [m, s, Save.best_kills, Save.runs]
	)


func _build_cards() -> void:
	for id: String in Tuning.CATS:
		var b := _card(id)
		_buttons[id] = b
		_cards.add_child(b)
	_wire_focus()


## A card: the cat, its name, then its starting weapon or its price.
func _card(id: String) -> Button:
	var cat: Dictionary = Tuning.CATS[id]
	var owned := Save.is_unlocked(id)

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

	var cat_name := Label.new()
	cat_name.text = String(cat["name"])
	cat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_name.add_theme_font_size_override("font_size", 20)
	col.add_child(cat_name)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)

	if owned:
		var weapon := String(cat["weapon"])
		if Tuning.ICONS.has(weapon):
			row.add_child(_pixel_icon(String(Tuning.ICONS[weapon])))
		var wname := Label.new()
		wname.text = String(Tuning.WEAPONS[weapon]["name"])
		wname.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wname.add_theme_font_size_override("font_size", 14)
		wname.add_theme_color_override("font_color", Tuning.CARD_BLURB_COLOUR)
		row.add_child(wname)
	else:
		art.modulate = Tuning.START_LOCKED_TINT
		cat_name.modulate = Tuning.START_LOCKED_TINT
		row.add_child(_pixel_icon(Tuning.pickup_art("cookie")))
		var cost := Label.new()
		cost.text = str(int(cat["cost"]))
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.add_theme_font_size_override("font_size", 22)
		cost.add_theme_color_override("font_color", Tuning.START_COST_COLOUR)
		row.add_child(cost)

	return b


func _pixel_icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.custom_minimum_size = Tuning.START_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


## Left and right wrap around the row, and up and down always land somewhere,
## so a gamepad can never park focus in a dead end.
func _wire_focus() -> void:
	var list := _cards.get_children()
	for i in list.size():
		var b: Button = list[i]
		b.focus_neighbor_left = b.get_path_to(list[(i - 1 + list.size()) % list.size()])
		b.focus_neighbor_right = b.get_path_to(list[(i + 1) % list.size()])
		b.focus_neighbor_top = b.get_path_to(_play)
		b.focus_neighbor_bottom = b.get_path_to(_play)
	_play.focus_neighbor_top = _play.get_path_to(list[0])
	_play.focus_neighbor_bottom = _play.get_path_to(list[0])


func _press(id: String) -> void:
	if Save.is_unlocked(id):
		Audio.play("choose")
		_select(id)
	elif Save.unlock(id):
		# The fanfare, and the card redrawn as owned: buying is also choosing.
		Audio.play("chest")
		_rebuild(id)
	else:
		Audio.play("hit")
		_wobble(_buttons[id])


func _select(id: String) -> void:
	Run.cat = id
	for cid: String in _buttons:
		var style: StyleBox = _card_selected if cid == id else _card_style
		_buttons[cid].add_theme_stylebox_override("normal", style)
	_hop_art(id)


## Unlocking changes a card's whole footer, so the row is rebuilt rather than
## patched, and focus is handed back to the cat just bought.
func _rebuild(id: String) -> void:
	for c in _cards.get_children():
		c.queue_free()
	_buttons.clear()
	_arts.clear()
	_build_cards()
	_select(id)
	await get_tree().process_frame
	if _buttons.has(id):
		_buttons[id].grab_focus()


func _hop_art(id: String) -> void:
	# Mid-hop the portrait is off its resting spot; a second hop from there
	# would walk it up the card.
	if _hop and _hop.is_running():
		return
	var art: TextureRect = _arts[id]
	var half := Tuning.START_HOP_TIME * 0.5
	_hop = create_tween().set_trans(Tween.TRANS_SINE)
	_hop.tween_property(art, "position:y", -Tuning.START_HOP, half).as_relative().set_ease(Tween.EASE_OUT)
	_hop.tween_property(art, "position:y", Tuning.START_HOP, half).as_relative().set_ease(Tween.EASE_IN)


func _wobble(b: Button) -> void:
	var t := create_tween()
	t.tween_property(b, "position:x", Tuning.START_WOBBLE, Tuning.START_WOBBLE_TIME).as_relative()
	var back := -2.0 * Tuning.START_WOBBLE
	t.tween_property(b, "position:x", back, Tuning.START_WOBBLE_TIME).as_relative()
	t.tween_property(b, "position:x", Tuning.START_WOBBLE, Tuning.START_WOBBLE_TIME).as_relative()


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
	# Never the Big Bug: the menu lawn is a calm place.
	bug.texture = load(Tuning.ENEMY_TEXTURES[randi() % (Tuning.ENEMY_TEXTURES.size() - 1)])
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

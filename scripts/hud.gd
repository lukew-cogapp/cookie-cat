extends CanvasLayer
## The health bar, the XP bar, the clock, and the level-up picker.
##
## The text is content and lives here beside the condition it describes, not
## in `tuning.gd`. Everything a five-year-old must read to play is an icon or
## a number: the words are for the adult sitting next to them.

@onready var _health_fill: ColorRect = $Top/Row/Health/Pad/Bar/Fill
@onready var _clock: Label = $Top/Row/Clock
@onready var _xp_fill: ColorRect = $Xp/Fill
@onready var _level: Label = $Xp/Level
@onready var _picker: Control = $Picker
@onready var _cards: HBoxContainer = $Picker/Panel/Pad/Col/Cards
@onready var _banner: Label = $Banner
@onready var _over: Control = $Over
@onready var _over_text: Label = $Over/Panel/Pad/Col/Text
@onready var _again: Button = $Over/Panel/Pad/Col/Again
@onready var _loadout: VBoxContainer = $Loadout/Pad/Rows
@onready var _paused: Control = $Paused
@onready var _stats: VBoxContainer = $Paused/Panel/Pad/Col/Stats
@onready var _resume: Button = $Paused/Panel/Pad/Col/Resume
@onready var _quit: Button = $Paused/Panel/Pad/Col/Quit

var _pending: Array = []
## True while the slow-mo ramp runs, so a second level in that window queues
## rather than restarting the ramp.
var _card_style := load("res://ui/card.tres")
var _card_hover := load("res://ui/card_hover.tres")


func _ready() -> void:
	_picker.visible = false
	_over.visible = false
	_banner.text = ""
	Run.changed.connect(_refresh)
	Run.levelled.connect(_offer)
	Run.ended.connect(_finish)
	_again.pressed.connect(_restart)
	_paused.visible = false
	_resume.pressed.connect(_unpause)
	_quit.pressed.connect(_restart)
	_refresh()


## Escape and Start pause. Read as an unhandled input so a button holding focus
## on the pick screen cannot swallow it, and refused while the picker or the end
## screen is up: both already pause the tree, and unpausing under them would let
## the run continue behind a modal.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if not Run.alive or _picker.visible or _over.visible:
		return
	get_viewport().set_input_as_handled()
	if _paused.visible:
		_unpause()
	else:
		_pause()


func _pause() -> void:
	_paused.visible = true
	_fill_stats()
	get_tree().paused = true
	_resume.grab_focus()


## How the run is going: kills, cookies, and the time left. A picture per line
## where one exists, because the audience reads pictures and not labels.
##
## Rebuilt on every pause rather than kept in step with `Run.changed`: all three
## numbers move while playing, and a frame of work costs nothing on a screen
## that has stopped the game.
func _fill_stats() -> void:
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	# One grid, not a row per line: an HBox centred per row re-centres it on its
	# own width, which left the iconless clock out of line with the rows above.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var left := int(maxf(Tuning.RUN_SECONDS - Run.clock, 0.0))
	_add_stat(grid, Tuning.PAUSE_KILL_ICON, str(Run.kills))
	_add_stat(grid, Tuning.PAUSE_COOKIE_ICON, str(Run.cookies))
	_add_stat(grid, "", "%d:%02d" % [left / 60, left % 60])
	_stats.add_child(grid)


## One line of the tally: a picture, then the number.
func _add_stat(grid: GridContainer, art: String, value: String) -> void:
	# The clock has no sprite of its own, and borrowing another would lie about
	# what the number means, so its cell is left empty. The grid still holds the
	# column, which is what keeps the time under the numbers above it.
	if art == "":
		var gap := Control.new()
		gap.custom_minimum_size = Tuning.PAUSE_ICON_SIZE
		grid.add_child(gap)
	else:
		var pic := TextureRect.new()
		pic.custom_minimum_size = Tuning.PAUSE_ICON_SIZE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.texture = load(art)
		grid.add_child(pic)
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tuning.PAUSE_STAT_SIZE)
	grid.add_child(label)


func _unpause() -> void:
	_paused.visible = false
	get_tree().paused = false


func _process(_delta: float) -> void:
	if not Run.alive:
		return
	# The clock counts DOWN. "Two minutes left" is a fact a child can act on;
	# "eight minutes elapsed" is arithmetic.
	var left: float = maxf(Tuning.RUN_SECONDS - Run.clock, 0.0)
	_clock.text = "%d:%02d" % [int(left) / 60, int(left) % 60]


## The health bar. A bar rather than a row of hearts, so a boss's hit visibly takes more
## than a grub's; the colour is what a child reads, not the number.
func set_health(hp: float, max_hp: float) -> void:
	var frac: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_health_fill.anchor_right = frac
	var colour := Tuning.HEALTH_GOOD
	if frac < Tuning.HEALTH_LOW_BELOW:
		colour = Tuning.HEALTH_LOW
	elif frac < Tuning.HEALTH_FAIR_BELOW:
		colour = Tuning.HEALTH_FAIR
	_health_fill.color = colour


func flash(text: String) -> void:
	_banner.text = text
	var t := create_tween()
	t.tween_interval(Tuning.BANNER_TIME)
	t.tween_property(_banner, "modulate:a", 0.0, 0.4)
	t.tween_callback(func() -> void:
		_banner.text = ""
		_banner.modulate.a = 1.0
	)


func _refresh() -> void:
	_level.text = "Lv %d" % Run.level
	_refresh_loadout()
	var frac := float(Run.xp) / float(maxi(Run.xp_needed, 1))
	_xp_fill.anchor_right = clampf(frac, 0.0, 1.0)


## What the cat is carrying, top right, as an icon and a row of pips per toy.
## Rows are reused rather than rebuilt: `Run.changed` fires on every gem, and
## rebuilding a dozen rows that often was the one avoidable cost in the HUD.
func _refresh_loadout() -> void:
	var owned: Array[String] = []
	for id: String in Run.weapons:
		owned.append(id)
	for id: String in Run.passives:
		owned.append(id)
	while _loadout.get_child_count() < owned.size():
		_loadout.add_child(_loadout_row())
	for n in _loadout.get_child_count():
		var row: Control = _loadout.get_child(n)
		row.visible = n < owned.size()
		if not row.visible:
			continue
		var id := owned[n]
		var art: TextureRect = row.get_node("Art")
		var pips: HBoxContainer = row.get_node("Pips")
		if Tuning.ICONS.has(id):
			art.texture = load(Tuning.ICONS[id])
		_set_pips(pips, Run.level_of(id))


func _loadout_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var art := TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Tuning.LOADOUT_ICON_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(art)
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.custom_minimum_size = Vector2(0, Tuning.LOADOUT_ICON_SIZE.y)
	pips.add_theme_constant_override("separation", Tuning.LOADOUT_PIP_GAP)
	row.add_child(pips)
	return row


func _set_pips(pips: HBoxContainer, level: int) -> void:
	while pips.get_child_count() < level:
		pips.add_child(_pip(Tuning.LOADOUT_PIP_SIZE, Tuning.LOADOUT_PIP_COLOUR))
	for n in pips.get_child_count():
		pips.get_child(n).visible = n < level


## A drawn circle, not a text glyph. The project ships no font, so every label
## renders in the default one, and a web export falls back to whatever the
## browser has: the bullet and star both come out as tofu when it has neither.
func _pip(size: Vector2, colour: Color) -> Panel:
	var pip := Panel.new()
	pip.custom_minimum_size = size
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	var radius := int(size.x * 0.5)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	pip.add_theme_stylebox_override("panel", style)
	return pip


## A level-up pauses the game until a card is chosen. Two levels at once queue,
## so a big gem that crosses two owes the player two picks.
func _offer(choices: Array) -> void:
	if choices.is_empty():
		return
	_pending.append(choices)
	# Instantly, with no ramp. A beat of slow motion was tried and is worse than
	# nothing: it slows the cat as well as the bugs, so a level earned while
	# surrounded handed the crowd the ground the player was using to escape.
	if not _picker.visible:
		_show_next()


func _show_next() -> void:
	if _pending.is_empty():
		_picker.visible = false
		get_tree().paused = false
		return
	var choices: Array = _pending.pop_front()
	for c in _cards.get_children():
		# Removed as well as freed: `queue_free` leaves the node in the tree
		# until the end of the frame, so `_pop_cards` would find the old cards
		# alongside the new ones and pop both.
		_cards.remove_child(c)
		c.queue_free()
	for id: String in choices:
		_cards.add_child(_card(id))
	_picker.visible = true
	get_tree().paused = true
	_pop_in()
	# So mashing the confirm button always works, and a child who cannot yet
	# read a card still progresses.
	await get_tree().process_frame
	if _cards.get_child_count() > 0:
		_link_cards()
		_cards.get_child(0).grab_focus()


## Left and right wrap around the three cards, spelled out rather than left to
## Godot's geometric guess: the cards are rebuilt every level, and a stick
## nudged slightly off the horizontal would otherwise find nothing and the
## picker would look frozen. The start screen wires its own cards the same way.
func _link_cards() -> void:
	var cards: Array[Node] = _cards.get_children()
	for i in cards.size():
		var b: Control = cards[i]
		b.focus_mode = Control.FOCUS_ALL
		var left: Control = cards[(i - 1 + cards.size()) % cards.size()]
		var right: Control = cards[(i + 1) % cards.size()]
		b.focus_neighbor_left = b.get_path_to(left)
		b.focus_neighbor_right = b.get_path_to(right)
		# Up and down stay put: there is nothing else on this screen, and a
		# nudge that lost focus read as the game hanging.
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_next = b.get_path_to(right)
		b.focus_previous = b.get_path_to(left)


## The panel pops from small to full size, then each card pops in turn. A
## modal that simply appears is easy to miss mid-fight; this reads as the
## game stopping for you. Tweens run TWEEN_PAUSE_PROCESS because the tree is
## paused by the time they play.
func _pop_in() -> void:
	var panel: Control = _picker.get_node("Panel")
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(Tuning.MODAL_POP_FROM, Tuning.MODAL_POP_FROM)
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", Vector2.ONE, Tuning.MODAL_POP_TIME)
	_pop_cards()


## Cards pop one after another, left to right. Sizes are only known after a
## layout pass, hence the deferred pivot.
func _pop_cards() -> void:
	var n := 0
	for c: Control in _cards.get_children():
		c.scale = Vector2(Tuning.CARD_POP_FROM, Tuning.CARD_POP_FROM)
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		# Bound to the card, so answering one level while the next is queued
		# kills the tween with the card it belongs to. Without this the
		# deferred callback below fired on a card `_show_next` had already
		# freed, and every frame logged a freed lambda capture.
		t.bind_node(c)
		t.tween_callback(func() -> void:
			if is_instance_valid(c):
				c.pivot_offset = c.size * 0.5
		)
		t.tween_interval(Tuning.CARD_STAGGER * float(n))
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(c, "scale", Vector2.ONE, Tuning.CARD_POP_TIME)
		n += 1


## A card: the picture first, then the name, then what it does. Built in code
## rather than as a scene because every part is driven by the id, and a scene
## would need each one wired by path anyway.
func _card(id: String) -> Button:
	var is_consumable := Tuning.CONSUMABLES.has(id)
	var is_passive := Tuning.PASSIVES.has(id)
	# Looked up in the table the id actually belongs to. Seeding this from
	# WEAPONS and correcting it below crashed on every passive and snack: the
	# initialiser is evaluated before the branch can redirect it.
	var data: Dictionary = {}
	if is_consumable:
		data = Tuning.CONSUMABLES[id]
	elif is_passive:
		data = Tuning.PASSIVES[id]
	else:
		data = Tuning.WEAPONS[id]
	var level := Run.level_of(id)

	var b := Button.new()
	b.custom_minimum_size = Tuning.CARD_SIZE
	b.add_theme_stylebox_override("normal", _card_style)
	b.add_theme_stylebox_override("hover", _card_hover)
	b.add_theme_stylebox_override("focus", _card_hover)
	b.add_theme_stylebox_override("pressed", _card_hover)
	# The button's own label is empty: the contents are the box below, which a
	# Button cannot lay out itself.
	b.pressed.connect(func() -> void:
		Audio.play("choose")
		Run.take(id)
		_show_next()
	)

	# Inset from the card's own border, or wrapped text touches it. The column
	# filled the card edge to edge, so a two-line blurb ran into the outline.
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, Tuning.CARD_PAD)
	b.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	# So the click lands on the button, not on the labels sitting over it.
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	# A snack is not an upgrade of anything owned, and a first pick has no level
	# to count, so both say a word. Only an upgrade gets pips, one per level the
	# card would take the toy to.
	if is_consumable or level == 0:
		var head := Label.new()
		head.text = "YUM!" if is_consumable else "NEW!"
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_font_size_override("font_size", 22)
		head.add_theme_color_override("font_color", Tuning.CARD_NEW_COLOUR)
		col.add_child(head)
	else:
		var head := HBoxContainer.new()
		head.name = "Pips"
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(0, Tuning.CARD_PIP_SIZE.y)
		head.add_theme_constant_override("separation", Tuning.CARD_PIP_GAP)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for _n in level + 1:
			head.add_child(_pip(Tuning.CARD_PIP_SIZE, Tuning.CARD_UP_COLOUR))
		col.add_child(head)

	var art := TextureRect.new()
	if Tuning.ICONS.has(id):
		art.texture = load(Tuning.ICONS[id])
	art.custom_minimum_size = Tuning.CARD_ICON_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(art)

	var name := Label.new()
	name.text = String(data["name"])
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", Tuning.TEXT_BODY)
	col.add_child(name)

	var blurb := Label.new()
	# A new toy says what it is; an upgrade says what the level actually gives,
	# since "Fish Friends" twice tells a child nothing about which card to take.
	blurb.text = String(Tuning.BLURBS.get(id, ""))
	if level > 0:
		var gives := Tuning.upgrade_blurb(id, level)
		if gives != "":
			blurb.text = gives
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", Tuning.TEXT_SMALL)
	blurb.add_theme_color_override("font_color", Tuning.CARD_BLURB_COLOUR)
	col.add_child(blurb)

	# A spacer under the blurb, so the last line is not against the border.
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, Tuning.CARD_TAIL)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tail)

	return b


## Back to the start screen rather than straight into another run: the cookies
## just earned buy cats there, and a child who wants the same cat again presses
## Play, which is one button either way.
func _restart() -> void:
	# The tree is paused by the end screen, and a paused tree keeps the next
	# scene paused too.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _finish(won: bool) -> void:
	_over.visible = true
	_picker.visible = false
	_pending.clear()
	get_tree().paused = true
	_again.grab_focus()
	# Never "you died". The run always ends in a tally, because a child who
	# feels they lost stops asking to play.
	var head := "You did it!" if won else "Nice try!"
	_over_text.text = "%s\n\nBugs bopped: %d\nLevel reached: %d" % [head, Run.kills, Run.level]

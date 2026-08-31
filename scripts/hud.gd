extends CanvasLayer
## Hearts, the XP bar, the clock, and the level-up picker.
##
## The text is content and lives here beside the condition it describes, not
## in `tuning.gd`. Everything a five-year-old must read to play is an icon or
## a number: the words are for the adult sitting next to them.

## Big enough to count across the room.
const HEART_FULL := "♥"
const HEART_EMPTY := "♡"

@onready var _hearts: Label = $Top/Row/Hearts
@onready var _clock: Label = $Top/Row/Clock
@onready var _xp_fill: ColorRect = $Xp/Fill
@onready var _level: Label = $Xp/Level
@onready var _picker: Control = $Picker
@onready var _cards: HBoxContainer = $Picker/Panel/Pad/Col/Cards
@onready var _banner: Label = $Banner
@onready var _over: Control = $Over
@onready var _over_text: Label = $Over/Panel/Pad/Col/Text
@onready var _again: Button = $Over/Panel/Pad/Col/Again

var _pending: Array = []
## True while the slow-mo ramp runs, so a second level in that window queues
## rather than restarting the ramp.
var _slowing := false
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
	_refresh()


func _process(_delta: float) -> void:
	if not Run.alive:
		return
	# The clock counts DOWN. "Two minutes left" is a fact a child can act on;
	# "eight minutes elapsed" is arithmetic.
	var left: float = maxf(Tuning.RUN_SECONDS - Run.clock, 0.0)
	_clock.text = "%d:%02d" % [int(left) / 60, int(left) % 60]


func set_health(hp: float, max_hp: float) -> void:
	var full := int(round(hp))
	var total := int(round(max_hp))
	_hearts.text = HEART_FULL.repeat(full) + HEART_EMPTY.repeat(maxi(total - full, 0))


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
	var frac := float(Run.xp) / float(maxi(Run.xp_needed, 1))
	_xp_fill.anchor_right = clampf(frac, 0.0, 1.0)


## A level-up pauses the game until a card is chosen. Two levels at once queue,
## so a big gem that crosses two owes the player two picks.
func _offer(choices: Array) -> void:
	if choices.is_empty():
		return
	_pending.append(choices)
	if not _picker.visible and not _slowing:
		_slow_into_pick()


## A beat of slow motion before the pause, so the level-up is a moment the
## whole screen leans into rather than a stop.
func _slow_into_pick() -> void:
	_slowing = true
	Engine.time_scale = Tuning.LEVELUP_SLOWMO
	# Real seconds, unpaused: the timer must outlive the slow-mo it measures.
	await get_tree().create_timer(Tuning.LEVELUP_SLOWMO_TIME, true, false, true).timeout
	_slowing = false
	Engine.time_scale = 1.0
	# Died mid-ramp: _finish cleared the queue, and _show_next's empty branch
	# would unpause the game-over screen.
	if not Run.alive:
		return
	_show_next()


func _show_next() -> void:
	if _pending.is_empty():
		_picker.visible = false
		get_tree().paused = false
		return
	var choices: Array = _pending.pop_front()
	for c in _cards.get_children():
		c.queue_free()
	for id: String in choices:
		_cards.add_child(_card(id))
	_picker.visible = true
	get_tree().paused = true
	# In case the ramp was skipped or interrupted; the pause replaces it.
	Engine.time_scale = 1.0
	_pop_in()
	# So mashing the confirm button always works, and a child who cannot yet
	# read a card still progresses.
	await get_tree().process_frame
	if _cards.get_child_count() > 0:
		_cards.get_child(0).grab_focus()


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
		t.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5)
		t.tween_interval(Tuning.CARD_STAGGER * float(n))
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(c, "scale", Vector2.ONE, Tuning.CARD_POP_TIME)
		n += 1


## A card: the picture first, then the name, then what it does. Built in code
## rather than as a scene because every part is driven by the id, and a scene
## would need each one wired by path anyway.
func _card(id: String) -> Button:
	var is_passive := Tuning.PASSIVES.has(id)
	var data: Dictionary = Tuning.PASSIVES[id] if is_passive else Tuning.WEAPONS[id]
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

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	# So the click lands on the button, not on the labels sitting over it.
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var head := Label.new()
	head.text = "NEW!" if level == 0 else "★".repeat(level + 1)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override(
		"font_color", Tuning.CARD_NEW_COLOUR if level == 0 else Tuning.CARD_UP_COLOUR
	)
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
	name.add_theme_font_size_override("font_size", 20)
	col.add_child(name)

	var blurb := Label.new()
	blurb.text = String(Tuning.BLURBS.get(id, ""))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 14)
	blurb.add_theme_color_override("font_color", Tuning.CARD_BLURB_COLOUR)
	col.add_child(blurb)

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
	# A death mid-ramp must not leave the whole game slow.
	Engine.time_scale = 1.0
	_over.visible = true
	_picker.visible = false
	_pending.clear()
	get_tree().paused = true
	_again.grab_focus()
	# Never "you died". The run always ends in a tally, because a child who
	# feels they lost stops asking to play.
	var head := "You did it!" if won else "Nice try!"
	_over_text.text = "%s\n\nBugs bopped: %d\nLevel reached: %d" % [head, Run.kills, Run.level]

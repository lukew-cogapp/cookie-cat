extends Node
## The state of one run: the clock, XP, level, and what the player has picked.
## Autoloaded as `Run`, and reset by `start()` rather than by reloading the
## scene, so a second run cannot inherit the first one's upgrades.

signal changed
signal levelled(choices: Array)
signal ended(won: bool)
## A consumable was picked. `world.gd` applies it, since `Run` holds no nodes.
signal consumed(id: String)

## Seconds survived. The wave table and every spawn rate read this, so it is
## the one clock in the game.
var clock := 0.0
var level := 1
var xp := 0
var xp_needed := 0
var alive := false
var won := false

## Weapon id -> its level. Passives live in `passives` for the same reason
## they are separate in the pick list: they never fire, so nothing iterates
## both together.
var weapons: Dictionary = {}
var passives: Dictionary = {}

var kills := 0
## Cookies picked up this run. Banked by `Save` when the run ends, not as they
## are collected: a run that is quit halfway should not pay.
var cookies := 0
## Which cat is playing. Set by the start screen before the world loads.
var cat := Tuning.STARTER_CAT
## And where: the map decides the floor and the props, never the bugs.
var map := Tuning.STARTER_MAP
## Set by `world.gd` each time the player's health changes. `_choices` reads it
## rather than the player, which `Run` cannot reach, and a snack is only worth
## offering when the bar is not full.
var hurt := false


func _ready() -> void:
	xp_needed = Tuning.xp_for_level(1)


## Wipes the previous run. Called by the world before the player exists, so it
## must not touch nodes.
func start() -> void:
	clock = 0.0
	level = 1
	xp = 0
	xp_needed = Tuning.xp_for_level(1)
	kills = 0
	alive = true
	won = false
	cookies = 0
	# The cat decides the opening weapon, which is the only difference between
	# them and the reason to unlock another.
	var starter := String(Tuning.CATS[cat]["weapon"])
	weapons = {starter: 1}
	passives = {}
	changed.emit()


func tick(delta: float) -> void:
	if not alive:
		return
	clock += delta
	if clock >= Tuning.RUN_SECONDS:
		finish(true)


func add_xp(amount: int) -> void:
	if not alive:
		return
	xp += amount
	# A single big gem can cross two levels, and each one owes the player a
	# pick, so the choices queue rather than overwrite.
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = Tuning.xp_for_level(level)
		Audio.play("level_up")
		levelled.emit(_choices())
	changed.emit()


## Levels up a weapon or passive by id, or adds it at level 1. A consumable is
## used at once instead, so it never enters either pool.
func take(id: String) -> void:
	if Tuning.CONSUMABLES.has(id):
		Audio.play("choose")
		consumed.emit(id)
		return
	var pool := passives if Tuning.PASSIVES.has(id) else weapons
	pool[id] = int(pool.get(id, 0)) + 1
	Audio.play("choose")
	changed.emit()


## A consumable is never owned, so it always reports 0.
func level_of(id: String) -> int:
	if Tuning.CONSUMABLES.has(id):
		return 0
	if Tuning.PASSIVES.has(id):
		return int(passives.get(id, 0))
	return int(weapons.get(id, 0))


## A passive's multiplier, 1.0 when it has never been picked.
func passive(id: String) -> float:
	var lv := int(passives.get(id, 0))
	if lv == 0:
		return 1.0
	return 1.0 + float(Tuning.PASSIVES[id]["per_level"]) * lv


func finish(win: bool) -> void:
	if not alive:
		return
	alive = false
	won = win
	if win:
		cookies += Tuning.COOKIE_FINISH_BONUS
	Save.finish_run(clock, kills, cookies)
	Audio.stop_music()
	Audio.play("win" if win else "run_over")
	ended.emit(win)


## Three picks: anything not yet at its cap. Weapons stop being offered once
## `WEAPON_SLOTS` are full, or a run ends up with eight weapons at level 1 and
## none of them strong enough to matter.
func _choices() -> Array:
	var pool: Array[String] = []
	for id: String in Tuning.WEAPONS:
		var lv := int(weapons.get(id, 0))
		if lv == 0 and weapons.size() >= Tuning.WEAPON_SLOTS:
			continue
		if lv < Tuning.WEAPON_LEVEL_MAX:
			pool.append(id)
	for id: String in Tuning.PASSIVES:
		var lv := int(passives.get(id, 0))
		if lv == 0 and passives.size() >= Tuning.PASSIVE_SLOTS:
			continue
		if lv < Tuning.PASSIVE_LEVEL_MAX:
			pool.append(id)
	# A snack at full health is a wasted card, and the one pick a child would
	# resent, so it is only in the pool while the bar is not full.
	if hurt:
		for id: String in Tuning.CONSUMABLES:
			pool.append(id)
	pool.shuffle()
	# Everything maxed: the level still has to resolve, and the caller draws
	# nothing rather than hanging on an empty pick screen.
	return pool.slice(0, Tuning.LEVEL_CHOICES)

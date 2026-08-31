extends SceneTree
## Renders the game to PNGs so changes can be reviewed without playing.
##
## Runs WINDOWED, never --headless: the dummy renderer writes blank images.
##
##   godot --path . -s test/shots.gd
##
## A -s script cannot name an autoload, so Run and Save come from the root.

const OUT := "res://test/shots/"


func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	# Play's promotion bar is 16:9 at 1920x1080 or better, and the root window
	# is the capture surface, so it is sized here rather than in project.godot.
	# On top because macOS stops presenting a fully covered window, and every
	# capture after that moment is the same stale frame.
	get_root().mode = Window.MODE_WINDOWED
	get_root().size = Vector2i(1920, 1080)
	get_root().always_on_top = true
	await process_frame

	# The shop first: cats, maps and hats are half the game, and the store
	# listing needs a picture of them.
	var shop: Node = load("res://scenes/start_screen.tscn").instantiate()
	get_root().add_child(shop)
	await _wait(30)
	await _shoot("00_shop")
	shop.queue_free()
	await process_frame
	await process_frame

	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_root().add_child(world)
	var run: Node = get_root().get_node("Run")
	var player: Node = world.get_node("Player")
	var swarm: Node = world.get_node("Swarm")
	var weapons: Node = world.get_node("Weapons")
	await physics_frame

	# The opening seconds, so the first thing a child sees is checked.
	await _wait(60)
	await _shoot("01_start")

	# A crowd, with the starting weapon swiping into it.
	for i in 40:
		var a := TAU * float(i) / 40.0
		swarm.spawn(player.global_position + Vector2.from_angle(a) * 150.0, i % 5)
	await _wait(20)
	await _shoot("02_crowd")

	# Every weapon at once, which is what a good run looks like by minute six
	# and the only way to see whether the effects read against each other.
	run.weapons = _loadout({
		"paw": 3, "yarn": 3, "purr": 3, "fish": 3,
		"mouse": 2, "milk": 2, "zap": 2, "nap": 2,
	})
	for i in 70:
		var a := TAU * float(i) / 70.0
		swarm.spawn(player.global_position + Vector2.from_angle(a) * 210.0, i % 5)
	await _wait(30)
	await _shoot("03_all_weapons")
	await _wait(12)
	await _shoot("04_all_weapons_later")

	# The boss.
	swarm.spawn(player.global_position + Vector2(180, -60), 5)
	await _wait(25)
	await _shoot("05_boss")

	# The juice layer, each effect caught mid-burst.
	# Kill a close ring through the world's kill path, so the star pop and
	# the reward numbers are on screen together.
	for i in 14:
		var a := TAU * float(i) / 14.0
		swarm.spawn(player.global_position + Vector2.from_angle(a) * 90.0, i % 5)
	await _wait(30)
	var popped := 0
	var row := 0
	while row < swarm.alive and popped < 12:
		var d: float = swarm.pos[row].distance_to(player.global_position)
		if d < 130.0:
			var at: Vector2 = swarm.pos[row]
			var k: int = swarm.kind[row]
			swarm.damage(row, 9999.0, player.global_position)
			world._on_killed(at, k)
			popped += 1
		row += 1
	await _wait(3)
	await _shoot("07_kill_pop")

	# The dropped gems dart away and fly in; sparkles land at the cat.
	await _wait(14)
	await _shoot("08_pickup_sparkle")

	# The XP just collected can level up mid-harness, and the picker would sit
	# over the remaining shots. Dismiss it; _wait already unpauses.
	var hud: Node = world.get_node("Hud")
	hud._pending.clear()
	hud._picker.visible = false
	await _wait(2)

	# The boss telegraph ring, placed on screen so it can be judged.
	world._on_boss(player.global_position + Vector2(130, -50))
	await _wait(5)
	await _shoot("09_boss_telegraph")

	# The combo cheer: prime the counter, then one kill trips it.
	world._combo = Tuning.COMBO_EVERY - 1
	world._on_killed(player.global_position + Vector2(60, 0), 0)
	await _wait(4)
	await _shoot("10_combo_cheer")

	# Fresh spawns mid grow-in, half size.
	for i in 8:
		var a := TAU * float(i) / 8.0
		swarm.spawn(player.global_position + Vector2.from_angle(a) * 130.0, i % 5)
	await _wait(6)
	await _shoot("11_spawn_grow")

	# The boomerang, alone, so both legs and the catch can be judged. Clearing
	# the loadout also stops the other toys popping the target bugs first.
	hud._pending.clear()
	hud._picker.visible = false
	run.weapons = _loadout({"boomer": 3})
	weapons._ready_in.clear()
	weapons.shots = 0
	weapons.zones = 0
	for i in 8:
		swarm.spawn(player.global_position + Vector2(190, -70 + 20.0 * float(i)), i % 5)
	await _wait(10)
	hud._pending.clear()
	hud._picker.visible = false
	await _shoot("12_boomer_out")
	await _wait(28)
	hud._pending.clear()
	hud._picker.visible = false
	await _shoot("13_boomer_return")
	await _wait(20)
	hud._pending.clear()
	hud._picker.visible = false
	await _shoot("14_boomer_catch")

	# The crumb trail: walk the cat so a line of crumbs drops, then let bugs
	# reach it and eat.
	hud._pending.clear()
	hud._picker.visible = false
	run.weapons = _loadout({"trail": 3})
	weapons._ready_in.clear()
	weapons.shots = 0
	for _step in 6:
		player.position += Vector2(28, 0)
		await _wait(14)
	hud._pending.clear()
	hud._picker.visible = false
	await _shoot("15_crumbs")
	for i in 6:
		swarm.spawn(player.global_position + Vector2(-80.0 - 20.0 * float(i), 40), 0)
	await _wait(40)
	hud._pending.clear()
	hud._picker.visible = false
	await _shoot("16_crumb_eaten")

	# Minute-eight density: the full quota of bugs and a full loadout, which is
	# where the cat historically vanished. The one shot legibility is judged on.
	hud._pending.clear()
	hud._picker.visible = false
	run.weapons = _loadout({
		"paw": 4, "yarn": 3, "purr": 3, "fish": 3, "mouse": 2,
		"milk": 2, "zap": 2, "nap": 2, "boomer": 2, "trail": 2,
	})
	weapons._ready_in.clear()
	for i in 120:
		var a := TAU * float(i) * 7.0 / 120.0
		var d := 70.0 + float((i * 37) % 210)
		swarm.spawn(player.global_position + Vector2.from_angle(a) * d, i % 5)
	await _wait(25)
	await _shoot("17_minute8_crowd")
	await _wait(15)
	await _shoot("18_minute8_crowd_later")

	# The eclipse: full night with the lamp, the moon, stars and fireflies
	# over the minute-eight crowd, which is what "pretty, not scary" is judged
	# on: every bug must stay readable in the dim.
	hud._pending.clear()
	hud._picker.visible = false
	# Standing in the minute-eight crowd for the whole night kills the cat,
	# and the end screen would sit over both shots.
	player.heal(Tuning.PLAYER_MAX_HP)
	world._on_eclipse_started()
	await _wait(int(Tuning.ECLIPSE_FADE * 60.0) + 12)
	hud._pending.clear()
	hud._picker.visible = false
	# Topped up on the frame of the shot, not before the fade: the cat dies
	# standing in this crowd long before the night has finished falling, and
	# the end screen then covers the picture the shot exists to take.
	player.heal(Tuning.PLAYER_MAX_HP)
	await _wait(2)
	await _shoot("20_eclipse")
	world._on_eclipse_ended()
	# Long enough for the night to be visibly gone, or the dawn shot is the
	# same picture as the one above it.
	await _wait(int(Tuning.ECLIPSE_FADE * 60.0) + 30)
	# The crowd's xp can level up during the fade, and the picker would sit
	# over the dawn this shot exists to show.
	hud._pending.clear()
	hud._picker.visible = false
	player.heal(Tuning.PLAYER_MAX_HP)
	await _wait(2)
	await _shoot("21_eclipse_dawn")
	await _wait(int(Tuning.ECLIPSE_FADE * 40.0) + 10)

	# The pick screen, which is the one piece of UI a child has to use.
	hud._pending.clear()
	hud._picker.visible = false
	run.add_xp(run.xp_needed)
	await _wait(30)
	await _shoot("06_level_up")

	# The pause screen, which is where a child checks how the run is going.
	# Given some numbers to show, or the tally reads as three zeroes.
	hud._pending.clear()
	hud._picker.visible = false
	run.kills = 137
	run.cookies = 8
	hud._pause()
	await process_frame
	await process_frame
	await _shoot("19_paused")

	quit(0)


func _wait(frames: int) -> void:
	for i in frames:
		# The picker pauses the tree, and a paused tree stops delivering
		# physics frames, so shots after a level-up would hang here.
		get_root().get_tree().paused = false
		await physics_frame


func _shoot(name: String) -> void:
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s%s.png" % [OUT, name])
	print("shot ", name)


## `Run.weapons` is a `Dictionary[String, int]`, and an untyped literal cannot
## be assigned to one: the run stopped after the second shot with every later
## picture missing.
func _loadout(picks: Dictionary) -> Dictionary:
	var out: Dictionary[String, int] = {}
	for k: String in picks:
		out[k] = int(picks[k])
	return out

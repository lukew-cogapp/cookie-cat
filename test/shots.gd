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
	run.weapons = {
		"paw": 3, "yarn": 3, "purr": 3, "fish": 3,
		"mouse": 2, "milk": 2, "zap": 2, "nap": 2,
	}
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

	# The juice layer, each effect caught mid-burst. A -s script cannot name
	# autoloads, so Tuning comes from the root.
	var tuning: Node = get_root().get_node("Tuning")

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
	world._combo = int(tuning.COMBO_EVERY) - 1
	world._on_killed(player.global_position + Vector2(60, 0), 0)
	await _wait(4)
	await _shoot("10_combo_cheer")

	# Fresh spawns mid grow-in, half size.
	for i in 8:
		var a := TAU * float(i) / 8.0
		swarm.spawn(player.global_position + Vector2.from_angle(a) * 130.0, i % 5)
	await _wait(6)
	await _shoot("11_spawn_grow")

	# The pick screen, which is the one piece of UI a child has to use.
	run.add_xp(run.xp_needed)
	await _wait(30)
	await _shoot("06_level_up")

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

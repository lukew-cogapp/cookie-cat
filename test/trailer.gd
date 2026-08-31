extends SceneTree
## Records a run for the Play listing's promo video.
##
## Runs WINDOWED and through Godot's own movie writer, which forces a fixed
## frame rate and writes every frame however long it took to draw:
##
##   godot --path . --write-movie store/trailer.avi --fixed-fps 60 \
##       --resolution 1920x1080 -s test/trailer.gd
##
## Play takes a YouTube link rather than a file, so the AVI is footage to
## upload rather than the finished thing.
##
## It shows the loop the game actually is: bugs arrive, the toys kill them
## without being aimed, the bar fills, and a card is picked. A cat walking
## through empty grass shows none of that, which is what the first cut did.
##
## A -s script cannot name an autoload, so Run comes from the root.

## Eight seconds. Godot's movie writer emits uncompressed frames, so a minute
## at 1080p is most of a gigabyte, and the loop repeats anyway: a viewer who
## has seen one level up has seen the game. Cut and re-encode from here.
const SECONDS := 8.0
## Matches the physics tick. Everything here moves on `_physics_process`, so
## one recorded frame is one tick: recording at 30 writes every other tick and
## the footage plays back at half speed.
const FPS := 60.0
## The picker is held long enough to read the three cards before one is taken.
const PICK_HOLD := 1.4


func _init() -> void:
	await process_frame
	# Silent. Sixty bugs bursting in one frame is a wall of noise even through
	# the throttle, and a trailer gets music laid over it anyway.
	get_root().get_node("Audio").set_muted(true, true)
	var run: Node = get_root().get_node("Run")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_root().add_child(world)
	var player: Node2D = world.get_node("Player")
	var hud: Node = world.get_node("Hud")
	var swarm: Node = world.get_node("Swarm")
	await physics_frame

	# Eight seconds is no time to build a crowd from nothing, so the run opens
	# mid-fight: a ring of bugs, a few toys already earned, and the bar nearly
	# full so the level up lands inside the clip.
	for i in 60:
		var a := TAU * float(i) / 60.0
		var d := 220.0 + float(i % 5) * 40.0
		swarm.spawn(player.global_position + Vector2.from_angle(a) * d, i % 5)
	run.weapons["yarn"] = 2
	run.weapons["purr"] = 2
	run.weapons["fish"] = 1
	run.add_xp(run.xp_needed - 40)

	var frames := int(SECONDS * FPS)
	var held := 0
	for f in frames:
		if hud._picker.visible:
			# Left up so the cards can be read, then one is taken. The pause
			# stops physics, so the countdown runs on rendered frames instead.
			held += 1
			# Only the first one is shown. Four pick screens in eight seconds is
			# a video about menus, and the game is the crowd behind them.
			if held > int(PICK_HOLD * FPS):
				held = 0
				var choices: Array = hud._pending[0] if not hud._pending.is_empty() else []
				hud._pending.clear()
				hud._picker.visible = false
				paused = false
				if not choices.is_empty():
					run.take(String(choices[0]))
				# One pick screen is the feature; four in eight seconds is a
				# video about menus.
				run.xp_needed = 100000
				run.xp_needed = 100000
			await process_frame
			continue

		# A slow drift rather than a circle: enough for the lawn to scroll and
		# for the crowd to have somewhere to chase the cat from.
		var a := TAU * float(f) / (FPS * 12.0)
		player.position += Vector2.from_angle(a) * Tuning.PLAYER_SPEED * 0.7 / FPS
		# Bugs are fed in faster than the wave table would this early: the
		# footage has to show a crowd, and minute zero is three grubs.
		if f % 3 == 0:
			var at: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * 320.0
			swarm.spawn(at, randi() % 4)
		# Kept alive. A death screen halfway through is not what this is for.
		player.heal(Tuning.PLAYER_MAX_HP)
		await physics_frame

	print("TRAILER DONE, %d frames" % frames)
	quit()

extends GutTest
## The sound switches, and that they survive being closed.

var _kept := [false, false]


func before_all() -> void:
	_kept = [Save.sound_off, Save.music_off]


func after_all() -> void:
	Save.set_audio(_kept[0], _kept[1])


func before_each() -> void:
	Save.set_audio(false, false)
	Audio.played.clear()


func test_muting_stops_cues() -> void:
	Audio.set_muted(true, false)
	Audio.play("pop")
	assert_eq(Audio.played.size(), 0, "nothing played")


func test_unmuting_lets_them_through() -> void:
	Audio.set_muted(false, false)
	Audio.play("pop")
	assert_gt(Audio.played.size(), 0, "the pop played")


## Separate switches: a child who wants quiet in the room usually still wants
## the pops, and turning the music off must not take the game's feedback too.
func test_the_switches_are_independent() -> void:
	Audio.set_muted(false, true)
	# `heal` rather than `pop`: the common cues are throttled, so a pop from
	# the previous test can still be inside its window and this would measure
	# the throttle rather than the switch.
	Audio.play("heal")
	assert_gt(Audio.played.size(), 0, "sound still plays with music off")


## Quiet has to survive closing the window: a child who turned the sound off
## did not mean only for one run.
func test_the_switches_survive_a_reload() -> void:
	Save.set_audio(true, true)
	Save.load_now()
	assert_true(Save.sound_off, "sound stayed off")
	assert_true(Save.music_off, "music stayed off")
	assert_true(Audio.muted, "and Audio was told")


## The bar emptying needs its own cue, before the tally.
func test_death_has_a_sound() -> void:
	Audio.set_muted(false, false)
	Audio.play("death")
	assert_true("death" in Audio.played, "the death cue exists and played")


## The loop was eight beats at 3.2 seconds, which a child hears as one bar
## repeating for ten minutes.
func test_the_music_loop_is_long_enough() -> void:
	var music: AudioStreamWAV = Audio._bank["music"]
	var seconds := float(music.data.size() / 2) / float(Audio.RATE)
	assert_gt(seconds, 4.5, "the loop runs %.1fs before repeating" % seconds)

extends Node
## Small procedural sound bank.
##
## Tones are synthesised at startup rather than shipped as files: the whole
## bank is a few lines here, and there are no assets to license or lose.
##
## Players are plain AudioStreamPlayer, not 2D: everything that makes a sound
## in this game happens within a screen of the player, so panning by position
## would only make the same cue quieter at the edge of a fight.
##
## A global autoloaded sound bank is the worked example of what NOT to do on
## Godot's "autoloads versus regular nodes" page, and it is kept anyway. The two
## things this exists for both need one owner that can see every cue at once: a
## hundred bugs popping in a frame have to collapse to one sound (`THROTTLED`),
## and the music has to duck under it (`_duck_until`). Per-scene players cannot
## know what another player is already doing, so they would produce exactly the
## wall of noise the throttle is here to prevent.

const RATE := 22050.0
## A swarm fires and dies in bursts, so the pool is wider than the 3D game's.
const VOICES := 16
const MUSIC_VOLUME_DB := -12.0
## Cap on the `played` log. Long enough to cover a burst of cues in one
## frame, short enough that a long session never grows it.
const PLAYED_LOG := 48
## Cues this common are throttled: a hundred bugs popping in one frame is one
## sound to a listener, and sixteen voices of it is a wall of noise.
const THROTTLED := {
	"hit": 0.05, "pop": 0.06, "pickup": 0.04, "shoot": 0.07, "crumb": 0.2, "catch": 0.1
}

var _bank: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_player: AudioStreamPlayer
## Cue name -> the time it last played, for THROTTLED.
var _last: Dictionary = {}
## Pops the throttle swallowed since the last big pop, and when that was.
## Enough swallowed pops earn one deep pop that cuts through: mowing a crowd
## should sound bigger, not busier.
var _pops_banked := 0
var _big_pop_at := -100.0
## Until when the common cues are held down, so a fanfare owns its moment.
var _duck_until := 0.0
var _rng := RandomNumberGenerator.new()

## Off switches, kept by `Save` between sessions. Sound and music are separate
## because a child who wants quiet in the room usually still wants the pops.
var muted := false
var music_muted := false

## Names played, newest last, kept only so headless tests can assert that a
## cue fired. Sound is the one kind of feedback a screenshot cannot show.
var played: Array[String] = []


func _ready() -> void:
	# name: [start hz, end hz, seconds, waveform, volume]
	# A shot leaving the player. Short and high so it never masks a hit.
	_bank["shoot"] = _tone(700.0, 940.0, 0.07, "sine", 0.22)
	# A shot connecting. Lower than the shot itself, which is what makes the
	# pair read as cause and effect rather than as two clicks.
	_bank["hit"] = _tone(300.0, 140.0, 0.06, "square", 0.16)
	# A bug bursting. Rounder and lower than a hit, so a kill is audible over
	# the hits that led to it.
	_bank["pop"] = _tone(420.0, 90.0, 0.13, "sine", 0.34)
	_bank["pickup"] = _tone(880.0, 1180.0, 0.06, "sine", 0.20)
	_bank["level_up"] = _chime([659.0, 784.0, 988.0, 1319.0], 0.55)
	_bank["choose"] = _chime([523.0, 784.0], 0.22)
	# Taking a hit. The one cue that must cut through a full swarm, so it is
	# the loudest thing in the bank.
	_bank["hurt"] = _tone(320.0, 120.0, 0.20, "square", 0.5)
	_bank["heal"] = _chime([523.0, 659.0, 784.0], 0.34)
	# A chest opening: the reward fanfare, longer than a level.
	_bank["chest"] = _chime([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.7)
	# End of a run. Falling, but a major third, not a dirge: the run ending is
	# not a punishment.
	_bank["run_over"] = _chime([784.0, 659.0, 523.0], 0.8)
	# The bar emptying. A soft wobble down rather than a sting: the run
	# still ends on a tally, so this cannot read as a punishment.
	_bank["death"] = _chime([659.0, 587.0, 523.0, 440.0, 392.0], 0.9)
	_bank["win"] = _chime([523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0], 1.1)
	# A big one is coming: low but major, an announcement rather than a scare.
	_bank["boss"] = _chime([130.8, 164.8, 196.0, 261.6], 0.8)
	# Many pops at once, as one sound: deeper and longer than a pop, so a
	# mown crowd reads as one big burst rather than a buzz.
	_bank["pop_big"] = _tone(300.0, 70.0, 0.24, "sine", 0.42)
	# The boomerang landing back in the paw: a falling thwip, quieter than a
	# pickup so ten catches a minute stay background.
	_bank["catch"] = _tone(900.0, 300.0, 0.08, "sine", 0.2)
	# A bug nibbling a crumb: the smallest sound in the bank.
	_bank["crumb"] = _tone(240.0, 180.0, 0.05, "sine", 0.14)
	# C-major bass under a sparse melody. The loop point never clicks: see _music.
	# Thirty-two beats, and a melody that goes somewhere before it comes back.
	# Sixteen at 0.36 still came round every 5.8 seconds, which a child hears
	# as one phrase repeating; this runs twice as long and moves through I-vi-
	# IV-V so the return lands rather than just restarting.
	_bank["music"] = _music(
		[130.81, 130.81, 164.81, 196.0, 110.0, 110.0, 130.81, 164.81,
		 174.61, 174.61, 220.0, 174.61, 196.0, 196.0, 246.94, 196.0,
		 130.81, 164.81, 196.0, 164.81, 110.0, 130.81, 164.81, 130.81,
		 174.61, 220.0, 196.0, 246.94, 196.0, 164.81, 146.83, 130.81],
		[523.25, 0.0, 659.25, 0.0, 440.0, 523.25, 0.0, 659.25,
		 698.46, 0.0, 880.0, 0.0, 783.99, 0.0, 987.77, 0.0,
		 523.25, 659.25, 0.0, 783.99, 659.25, 0.0, 523.25, 0.0,
		 698.46, 0.0, 783.99, 987.77, 0.0, 659.25, 0.0, 523.25],
		0.34,
	)
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	# Music gets its own player: it must not be recycled out from under a
	# loop by the voice pool.
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)


func play(sound: String, pitch := 1.0) -> void:
	if muted or not _bank.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var throttled: bool = THROTTLED.has(sound)
	if throttled:
		if now - float(_last.get(sound, -1.0)) < float(THROTTLED[sound]):
			if sound == "pop":
				_bank_pop(now)
			return
		_last[sound] = now
		# The spammy cues wander in pitch, or ten a second machine-gun. The
		# jingles stay fixed on purpose, like an alarm.
		pitch *= 1.0 + _rng.randf_range(-Tuning.AUDIO_VARY, Tuning.AUDIO_VARY)
	elif Tuning.AUDIO_BIG_CUES.has(sound):
		_duck_until = now + Tuning.AUDIO_DUCK_TIME
	played.append(sound)
	if played.size() > PLAYED_LOG:
		played.pop_front()
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _bank[sound]
	# Always set: voices are recycled, and a stale pitch or duck would carry
	# over.
	p.pitch_scale = pitch
	p.volume_db = Tuning.AUDIO_DUCK_DB if throttled and now < _duck_until else 0.0
	p.play()


## A pop the throttle swallowed still counts: enough of them inside the gap
## earn one deep pop that cuts through the wall of small ones.
func _bank_pop(now: float) -> void:
	_pops_banked += 1
	if _pops_banked < Tuning.POP_BIG_EVERY or now - _big_pop_at < Tuning.POP_BIG_GAP:
		return
	_pops_banked = 0
	_big_pop_at = now
	play("pop_big")


func play_music(sound: String) -> void:
	if music_muted or not _bank.has(sound):
		return
	if _music_player.playing and _music_player.stream == _bank[sound]:
		return
	_music_player.stream = _bank[sound]
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


## Applies the saved switches. Called by `Save` once it has loaded, and by the
## title screen's toggles.
func set_muted(sound_off: bool, music_off: bool) -> void:
	muted = sound_off
	music_muted = music_off
	# `Save` loads before this node is ready, so the player may not exist yet.
	# The flags are enough: `play_music` checks them when it is next called.
	if _music_player == null:
		return
	if music_muted:
		_music_player.stop()
	elif _music_player.stream != null and not _music_player.playing:
		_music_player.play()


## One beat per entry; a 0.0 melody entry is a rest. The saw bass keeps
## running phase across beat boundaries, so the loop point never clicks.
func _music(bass: Array, melody: Array, beat_secs: float) -> AudioStreamWAV:
	var frames := int(RATE * beat_secs * bass.size())
	var data := PackedByteArray()
	data.resize(frames * 2)
	var bass_phase := 0.0
	var mel_phase := 0.0
	for i in frames:
		var beat_pos := float(i) / (RATE * beat_secs)
		var b := int(beat_pos) % bass.size()
		var local := beat_pos - floorf(beat_pos)
		bass_phase += TAU * float(bass[b]) / RATE
		var s := _wave("saw", bass_phase) * 0.4 * pow(1.0 - local, 0.5)
		var hz := float(melody[b])
		if hz > 0.0:
			mel_phase += TAU * hz / RATE
			s += sin(mel_phase) * 0.3 * minf(local * 8.0, 1.0) * pow(1.0 - local, 1.2)
		_put(data, i, s * 0.8)
	var w := _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = frames
	return w


func _tone(from_hz: float, to_hz: float, secs: float, wave: String, vol: float) -> AudioStreamWAV:
	var frames := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / frames
		var hz: float = lerpf(from_hz, to_hz, t)
		phase += TAU * hz / RATE
		var s := _wave(wave, phase)
		# Short attack, long decay, so nothing clicks at the edges.
		var env: float = minf(t * 12.0, 1.0) * pow(1.0 - t, 1.6)
		_put(data, i, s * env * vol)
	return _wav(data)


func _chime(notes: Array, secs: float) -> AudioStreamWAV:
	var frames := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var per := frames / notes.size()
	for i in frames:
		# Deliberate integer division: `per` samples map to one note.
		@warning_ignore("integer_division")
		var idx: int = mini(i / per, notes.size() - 1)
		var local := float(i - idx * per) / per
		var phase := TAU * float(notes[idx]) * float(i) / RATE
		var env: float = minf(local * 14.0, 1.0) * pow(1.0 - local, 1.4)
		_put(data, i, sin(phase) * env * 0.42)
	return _wav(data)


func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"saw":
			return fmod(phase, TAU) / PI - 1.0
		_:
			return sin(phase)


func _put(data: PackedByteArray, i: int, value: float) -> void:
	var v := int(clampf(value, -1.0, 1.0) * 32767.0)
	data.encode_s16(i * 2, v)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w

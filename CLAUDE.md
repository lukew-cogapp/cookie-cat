# cookie-cat

Godot 4.7 survivors-like, built with Aubrey. 2D, top-down, kid-themed: you are
a cat, the bugs come to you, the toys fire themselves. Ten minute runs, cookies
between them, more cats to unlock. Sibling project to `../godot-world`, whose
conventions this follows.

Audience is a five-year-old. That is a design constraint, not a note: it
decides the control scheme (movement only), the fail state (a tally, never a
defeat), the reading load (pictures), and every difficulty number.

## Commands

```
godot --path .                                        play it
godot --headless --path . --import                    after a clone, or a new PNG
godot --headless --path . -s test/compile_check.gd    compile every script and scene
./test/run.sh                                         every suite
./test/run.sh swarm_test.gd                            one suite, by file name
godot --path . -s test/shots.gd                        screenshots, windowed
python3 scripts/tools/make_art.py                      redraw every sprite
```

`-gselect` matches file names, not test names: `./test/run.sh one_gem` runs
nothing and says so. Wrap long invocations in `perl -e 'alarm N; exec @ARGV'`,
because `timeout` is not installed here, and pass `env HOME=/private/tmp` to
keep a headless run out of the real editor config.

## Layout

```
project.godot              input map, autoloads, main scene
scripts/tuning.gd          every tunable number, autoloaded as `Tuning`
scripts/save_state.gd      cookies and unlocked cats, autoloaded as `Save`
scripts/run_state.gd       one run's state, autoloaded as `Run`
scripts/swarm.gd           enemies as array rows, one MultiMesh per kind
scripts/weapons.gd         all eight toys in one node
scripts/gems.gd            pickups, same pattern as the swarm
scripts/traps.gd           holes in the ground, one hazard per map
scripts/director.gd        the wave table, and bosses
scripts/world.gd           wires the run together
scripts/hud.gd             health bar, clock, xp bar, the pick screen
scripts/tools/make_art.py  draws every sprite from pixel grids
assets/*.png               16x16, all generated
ui/*.tres                  shared styles
addons/gut/                vendored, do not restyle
test/*_test.gd             GUT suites; run with test/run.sh
test/shots.gd              windowed screenshot renderer
test/compile_check.gd      loads everything, run by the pre-commit hook
```

**Numbers live in `tuning.gd`.** Nothing else holds a literal. This game is
almost entirely tuning, so the file is long on purpose and every constant that
is not self-evident carries a `##` line saying why it is what it is.

**Art is generated**, not licensed. `scripts/tools/make_art.py` holds a pixel
grid per sprite and writes `assets/*.png` with nothing but zlib. Rerun it after
editing a grid, then `--import`. A new bug is a grid and a palette letter.

Assets were nearly a CC0 pack instead. Clint Bellanger's Tiny Creatures (CC0,
matches Kenney's Tiny sets) is the best 16px pack going and was rejected after
looking at it: it is a fantasy bestiary of orcs, dragons and wolves, so a
garden of bugs plus a cat plus a cookie would have been a collage of two
styles. Generating the lot is what keeps one look across cat, bugs, pickups,
toy effects and UI icons.

## Enemies are not nodes

An enemy is a row in parallel arrays in `swarm.gd`, moved in one loop, drawn by
one `MultiMesh` per kind. No node, no script instance, no physics body, no
`_physics_process` per bug. Bugs collide with nothing but the cat, and that is
one distance check.

This is the decision the genre lives or dies on in Godot: the documented
failure mode is collision-pair explosion, where a few hundred overlapping
bodies take a steady frame rate to single digits, and it bites long before
rendering does. Gems, shots, puddles and effects all follow the same shape.

**Rows are swap-removed.** A kill moves the last row into the dead one's index,
so:

- Deaths are collected in `_dead` and applied by `_compact` **after** the loop.
  A mid-loop swap moves a row the loop has not visited yet and skips it.
- `_compact` sorts descending and skips repeats. One row can be queued twice in
  a frame (two shots landing, or killed and culled), and dropping it twice
  deletes a live enemy.
- An index is only valid for the frame it was read in. `damage()` bounds-checks
  for exactly this reason: a shot holds an index and the bug can die in between.

`test/swarm_test.gd` pins all of it.

## What playing it taught, that green tests did not

Every one of these shipped past a passing suite and was caught by looking at a
screenshot or reading a probe's numbers.

**The cat was the smallest thing on screen.** Art is 16x16 and was rendered at
16x16 while bugs drew at 30 to 46, so the thing the child controls was a speck
in a crowd. The camera now zooms `Tuning.ZOOM` and the cat is drawn at
`PLAYER_DRAW_SIZE`, larger than any bug. It is also a later sibling of the
swarm in `world.tscn`, because it was being drawn underneath the wave.

**Weapons that dealt damage invisibly.** The paw swipe, the yawn and the zap
all killed bugs with nothing on screen, which reads as the game killing them
rather than the cat. `weapons.gd` now records an effect per instant hit
(`_add_fx`) and draws the wedge, the ring and the bolt. If a weapon is added,
it gets a picture or it does not ship.

**The first weapon could not hit anything.** The paw's arc was 1.5 radians,
which at eight compass points hits one. A probe reported three kills in twenty
seconds and a dead cat. It is 2.5 now, a bit over 140 degrees: a child cannot
aim, so anything in front counts.

**Mercy time alone is not survivable.** The whole bar went in 3.7 seconds
standing in a crowd, because the next touch landed the frame the flashing
stopped. A hit now also shoves every bug clear (`Swarm.push_from`), which is
what buys the room to walk out. `test_mercy_outlasts_a_touch` pins the
relationship.

**The snail took three attempts.** Drawn as a shell shape and a body shape it
reads as an orange disc floating over a white bar, at every combination of
tones. They have to share one outline. Grub and slime were also the same blob
in two greens until the grub was segmented; kinds must differ by silhouette,
not by hue, because hue is what the hit flash overwrites.

**A two-tone 2px check reads as graph paper**, and fought with the bugs
standing on it. The lawn is four tones in a fixed irregular scatter.

**An input map can break silently.** Adding the D-pad put five events after the
events array's closing bracket, which made the whole `[input]` section
unparseable: every action vanished, and nothing errored. `test/input_test.gd`
asserts the bindings exist.

**A lambda capturing a local `int` gets a copy.** A test counted signal
emissions into a captured `var seen := 0` and read 0 while the behaviour was
correct. Capture an Array if a closure must accumulate.

**A gentle stick push was a trap.** `Input.get_vector` keeps the stick's
magnitude, so a light push walked at 65 against a wasp's 104: the child was
moving and still being caught. `STICK_WALK_FLOOR` floors it above the fastest
bug, and `test_the_slowest_walk_still_escapes` pins that against the enemy
table. The default `deadzone` of 0.5 also ignores half the stick's travel and
is 0.2 here.

**Milk is the only crowd control.** It slows as well as damages
(`WEAPONS.milk.slow`, applied through `Swarm.slow`); without the slow it was a
second purr ring, since damage over an area already exists. The strongest slow
wins while two puddles overlap, and it lingers `SLOW_LINGER` past the edge so
crossing out does not flicker.

**Props are damaged through `world.gd`, not by each weapon.** `Props` exposes
`damage_near`, and `weapons.gd` routes every area of effect through
`_break_props`, so a new weapon breaks pots without knowing props exist.

**A hazard the camera never shows teaches nothing.** The traps were first
scattered one per 520-unit cell, which is a reasonable-looking number and put a
hole on screen about half the time: the camera shows 512x288 world units at
`ZOOM`, not the whole field. Any field of anything the player must react to has
to be sized against the visible area, not against the world.

**A hole is read by its darkness, not its colour.** The ice hole was first
drawn in the palette's ice blues and vanished on snow, which is the same
value-range trap the white hit flash fell into. All three traps now share one
rule: near-black or deep-water centre, pale lip, one dark outline. Mud was
tried for the pond's depth and read as a mud patch rather than water, so the
palette gained one deep blue (`Q`) instead.

## Godot facts worth not relearning

**A `QuadMesh` draws a texture upside down in 2D.** Its UVs map `uv.y=0`, the
top of the image, to `y=+0.5`, which on screen is DOWN, so every MultiMesh
sprite is vertically mirrored. It hid for a long time because most of the art
is near-symmetric and the start screen uses `TextureRect`, which is correct:
the same sprite looked right in the menu and wrong in the game. `Tuning`
`sprite_quad()` builds the quad with explicit UVs; use it, never `QuadMesh`.

**Mercy time caps damage, so damage per hit is the only lever.** A hit can only
land every `PLAYER_MERCY_TIME` however many bugs are touching, so raising the
crowd size does not make a run deadlier. At 4 damage against 100 health a swarm
of grubs took forty seconds to finish the cat and the bar looked stuck.
`test_standing_in_a_crowd_kills_you` pins the relationship.

**A flash that may restart the moment it ends reads as permanent.** An aura or
a puddle damages every frame, so a hit flash needs an enforced quiet gap
(`HIT_FLASH_GAP`) rather than merely refusing to refresh: without it a pot was
white about half the time, which looks solid white. The same rule silences the
hit cue, which otherwise fires once per bug per frame.

**A field that follows the cat teleports the world.** Props and ground decals
were re-scattered whenever the cat walked far enough, which replaced every pot
on screen at once and reads as being transported. They sit on a fixed grid of
cells seeded by cell coordinates, so walking into new ground fills it in and
walking back finds the same garden.

**Overlapping circles read as clouds from above.** The milk puddle was drawn
three ways as clusters of blobs (evenly spaced, jittered, then flattened) and
every one read as a cloud or a flower. A spill is ONE outline: it is a single
polygon with a wobbly edge, squashed vertically so it lies on the grass.

**A passive has to reach what its card claims.** Big Bowl says every toy gets
bigger; it silently did nothing for the two weapons with no radius of their
own, and for the fish it widened the orbit while the sprite stayed the same
size. Both the reach and the drawn size follow it now.

**Web saves use `localStorage`, not `user://`.** On a web export `user://` is
an in-memory filesystem synced to IndexedDB asynchronously, so `close()` only
queues the write: a tab closed straight after a run loses its cookies
(godot#39643). `save_state.gd` branches on `OS.get_name() == "Web"` and goes
through `JavaScriptBridge` to `localStorage`, which is synchronous, so there is
no race to lose. Both arguments to `eval` are `JSON.stringify`d rather than
interpolated, since the payload is full of quotes and braces.

The key is namespaced (`WEB_KEY`) because every game published under one
`github.io` account shares an origin and therefore one storage bucket. Safari
also evicts script-writable storage after seven days without a visit, which no
code here can prevent; it is worth knowing before wondering where a save went.

**There is no wall, on purpose.** The cat used to be clamped to `WORLD_HALF`,
and the edge was about eight seconds of walking away. Being cornered against an
invisible edge with bugs closing in is the one situation a child cannot escape,
and the whole difficulty rests on running away always working, so the clamp is
gone. The lawn sprite rides the camera and scrolls its own `region_rect` instead, and
`Props` re-scatters its field around the cat past `PROP_REFILL_DISTANCE`,
seeded off the field's own position so walking back finds the same garden.

Snapping the lawn's POSITION to a tile is what a player twice reported as
being "transported": the region is drawn at the sprite's scale, so one texture
tile is not one tile on screen and the ground jumped by the remainder at every
boundary. Scroll the region, never the sprite.

**`is_touchscreen_available()` reports true on desktops with no touchscreen**
(godot#84235), so `touch_stick.gd` does not gate on it. Nothing is drawn until
an `InputEventScreenTouch` proves a real finger, which needs no platform check
and is correct on a touch laptop whose owner is using the trackpad.

Godot 4.7 ships no analogue virtual joystick: `TouchScreenButton` is boolean,
and the `emulate_*` settings only translate between mouse and touch. The stick
feeds `Input.action_press(action, strength)`, which `Input.get_vector` reads
back through `get_action_raw_strength`, so the cat's movement code stays one
`get_vector` call and the touch input keeps the stick's magnitude.

Most of these are inherited from `../godot-world` and still true here.

**Screenshots must run windowed.** `godot --path . -s test/shots.gd`. Under
`--headless` the dummy renderer writes blank images. Downscale with `sips -Z
780` before reading them. This is the only way to check anything visual, and
the list above is what it caught.

**A `-s` script cannot name an autoload at all.** Naming `Run`, `Save` or
`Tuning` fails at compile time before any code runs, so awaiting a frame does
not help. Use `get_root().get_node("Run")`. GUT suites load at runtime and are
unaffected, so they name autoloads directly. `test/shots.gd` and
`compile_check.gd` are the constrained ones.

**One Godot at a time per checkout.** Concurrent `-s` runs fight over `.godot/`
and hang with no output, not even a `print` on the first line. Give a parallel
agent its own worktree.

**GUT needs an import before it will run.** A fresh clone fails naming
`GutTest`, because the addon's `class_name` registrations live in gitignored
`.godot/`. `godot --headless --path . --import` once.

**`timeout` is not installed here.** `test/run.sh` uses
`perl -e 'alarm N; exec @ARGV'` instead, and so should any long invocation.

**Run tests only through `test/run.sh`** and read its header before changing
it. No `-d` (it drops an error into an interactive prompt that waits forever),
`-gprefix= -gsuffix=_test.gd` (GUT looks for `test_*.gd` by default and would
find nothing while exiting 0), and the summary-line check, because GUT exits 0
when its filters match nothing at all.

`add_child_autofree` frees at the end of the calling test, not the script, so a
`before_all` fixture needs `after_all` calling `free()`, not `queue_free`, which
has not run when GUT counts unfreed children.

**`.tscn` sub-resources must be declared before the node using them**, and
`load_steps` must cover every ext plus sub resource or the scene fails to load.

**Hot reload:** `.gd` yes, `.tscn` no.

**`--quit` exits before importing.** Use `--import` to build the cache, and
`--quit-after N` frames to check a scene runs. Both exit 0 on failure, so grep
stderr for `error`.

**A new PNG needs an import before anything can load it.** The error is `No
loader found for resource`, which reads like a missing file.

## Working notes

The clock is the only difficulty input. No scaling by player level, no rubber
banding: `Tuning.WAVES` is one entry per minute holding which kinds spawn, how
often, and how many must be alive. The quota is what fills the screen; the
interval only decides how lumpy the filling looks. Kinds arrive on a schedule,
so minute 0 is grubs and minute 9 is all five plus bosses at 4, 7 and 9.

Rushes ride on the same clock. Past `RUSH_AFTER` the director rolls a gap
between `RUSH_GAP_MIN` and `RUSH_GAP_MAX` and sends a pack of the weakest bug in
from one arc of the spawn ring, at `RUSH_HURRY` times its listed speed and
announced `RUSH_TELEGRAPH_TIME` ahead like a boss. The hurry is a per-row
`Swarm.hurry` multiplier, not a second entry in the enemy table, so the
no-bug-outruns-the-cat rule is one check on the product.

Enemy HP scales with the clock at spawn and is fixed thereafter, which is why
`enemy_hp` takes the clock. It does **not** scale with player level: a child who
levels fast should feel stronger, not meet tougher bugs.

`test/tuning_test.gd` asserts the properties the numbers must keep rather than
the numbers themselves: no bug outruns the cat, waves escalate, the peak crowd
fits the arrays, the spawn ring clears the screen corner, every weapon has art
and a blurb and gets better with levels, the cheapest cat is reachable in a few
runs. Retuning freely is the point; breaking one of those is a bug.

Cookies are banked by `Save` when a run **ends**, not as they are picked up, so
quitting halfway pays nothing. Surviving the full ten minutes pays
`COOKIE_FINISH_BONUS` on top.

`Run.cat` is set by the start screen before `world.tscn` loads, and decides the
opening weapon. `Save` keeps the file in `user://save.json` and writes on every
change, because a child closes the window rather than using a menu.

The HUD owns its own text, beside the condition it describes, rather than in
`tuning.gd`. The clock counts **down**: "two minutes left" is a fact a child can
act on.

## Deploying

`git tag v1 && git push --tags` publishes to Pages via
`.github/workflows/web.yml`. Tags rather than pushes, so a half-finished build
never replaces the live one. The web export needs no renderer change: Godot
4.7 forces `gl_compatibility` on the web through `rendering_method.web`.

**Nothing can lock a phone to landscape here, and three things that look like
they would do not.** `window/handheld/orientation` is Android and iOS only:
`DisplayServer.screen_get_orientation` returns `SCREEN_LANDSCAPE` on every
other platform, so it is a no-op on web. The PWA manifest's `orientation` key
only binds a page launched from the home screen in standalone display mode, and
this game is opened from a shared link in a normal tab, so it is inert.
`screen.orientation.lock()` needs fullscreen, which needs a tap, and Safari
does not implement it at all (mdn/browser-compat-data#19355 tested it: `"lock"
in screen.orientation` is false on iOS).

That leaves asking. A `@media (orientation: portrait)` overlay through the
export's `html/head_include` works the same on both platforms and, unlike
rotating the canvas with a CSS transform, cannot break touch input: the browser
reports touches in the untransformed layout box, so a rotated canvas puts every
`InputEventScreenTouch` in the wrong place and takes the thumbstick with it.

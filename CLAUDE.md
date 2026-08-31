# cookie-cat

Godot 4.7 survivors-like, built with Aubrey. 2D, top-down, kid-themed: you are
a cat, the bugs come to you, the toys fire themselves. Ten minute runs, cookies
between them, more cats to unlock. Sibling project to `../godot-world`, whose
conventions this follows.

Audience is a five-year-old. That is a design constraint, not a note: it
decides the control scheme (movement only), the fail state (a tally, never a
defeat), the reading load (pictures), and every difficulty number.

## Layout

```
project.godot              input map, autoloads, main scene
scripts/tuning.gd          every tunable number, autoloaded as `Tuning`
scripts/save_state.gd      cookies and unlocked cats, autoloaded as `Save`
scripts/run_state.gd       one run's state, autoloaded as `Run`
scripts/swarm.gd           enemies as array rows, one MultiMesh per kind
scripts/weapons.gd         all eight toys in one node
scripts/gems.gd            pickups, same pattern as the swarm
scripts/director.gd        the wave table, and bosses
scripts/world.gd           wires the run together
scripts/hud.gd             hearts, clock, xp bar, the pick screen
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

**Mercy time alone is not survivable.** Three hearts went in 3.7 seconds
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

## Godot facts worth not relearning

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

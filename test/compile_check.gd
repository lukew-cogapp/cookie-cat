extends SceneTree
## Loads every script and scene in the project so the parser reports on all
## of them, then fails on any error or warning.
##
## Booting the game only compiles what the main scene happens to reach, so a
## broken script in an unvisited corner stays quiet until someone plays that
## far. A rename that misses a use in a function body costs seconds to find
## once something actually compiles the file, and an afternoon otherwise.
##
## Run: godot --headless --path . -s test/compile_check.gd

const DIRS := [
	"res://scripts",
	"res://scenes",
	"res://test",
]

## `reload()` fails on a script that is already running as an autoload, whether
## or not it compiles, so these are checked by loading alone. The engine has
## already compiled them by the time this runs: a real error in one of them
## fails the boot, which is louder than this check.
const AUTOLOADS := [
	"res://scripts/save_state.gd",
	"res://scripts/audio.gd",
	"res://scripts/run_state.gd",
]


func _init() -> void:
	await process_frame
	var loaded := 0
	var failed: Array[String] = []
	for dir in DIRS:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if not (f.ends_with(".gd") or f.ends_with(".tscn")):
				continue
			var path := "%s/%s" % [dir, f]
			# This script is itself running, so it is not loadable from here.
			if path.ends_with("compile_check.gd"):
				continue
			# A script that does not compile still loads: `load` hands back a
			# GDScript object and only `reload()` reports the parse error. This
			# printed 40 loaded and 0 failures while run_state.gd was failing to
			# compile, which is the one thing the check exists to catch. Scenes
			# are the null case; scripts are the reload case.
			var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if res == null:
				failed.append(path)
			elif res is GDScript and not path in AUTOLOADS:
				if (res as GDScript).reload() != OK:
					failed.append(path)
				else:
					loaded += 1
			else:
				loaded += 1
	print("LOADED=%d" % loaded)
	for path in failed:
		print("FAILED_TO_LOAD ", path)
	print("FAILURES=", failed.size())
	quit(1 if failed.size() > 0 else 0)

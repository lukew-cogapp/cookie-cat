extends Control
## Title and a Play button. The title reads the project name at runtime, so
## renaming the game is one edit in `project.godot`.

@onready var _title: Label = $Col/Title
@onready var _play: Button = $Col/Play


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name")
	_play.pressed.connect(_start)
	_play.grab_focus()


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

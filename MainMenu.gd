extends Control

# Point to world scene
const GAME_SCENE := "res://world.tscn"

@onready var start_btn: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_btn.text = "Start Game"
	quit_btn.text = "Quit Game"
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(_on_quit)

func _on_start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_quit() -> void:
	get_tree().quit()

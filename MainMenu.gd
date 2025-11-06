extends Control

# Point to world scene
const GAME_SCENE := "res://world.tscn"
const GAME_SCENE2 := "res://world_2.tscn"

@onready var start_btn: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var start_btn_2: Button =$CenterContainer/VBoxContainer/StartButton2

func _ready() -> void:
	start_btn.text = "First Mode Button"
	start_btn_2.text = "Second Mode Button"
	quit_btn.text = "Quit Game"
	start_btn.pressed.connect(_on_start)
	start_btn_2.pressed.connect(_on_start2)
	quit_btn.pressed.connect(_on_quit)

func _on_start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
	
func _on_start2() -> void:
	get_tree().change_scene_to_file(GAME_SCENE2)

func _on_quit() -> void:
	get_tree().quit()

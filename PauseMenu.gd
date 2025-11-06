extends CanvasLayer

const MAIN_MENU_SCENE := "res://MainMenu.tscn"

@onready var resume_btn: Button     = $Control/CenterContainer/MarginContainer/MenuBox/ResumeButton
@onready var main_btn: Button       = $Control/CenterContainer/MarginContainer/MenuBox/MainMenuButton
@onready var quit_btn: Button       = $Control/CenterContainer/MarginContainer/MenuBox/QuitButton
@onready var title_lbl: Label       = $Control/CenterContainer/MarginContainer/MenuBox/Title

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED   # UI works while paused
	hide()

	title_lbl.text = "Paused"
	resume_btn.text = "Resume"
	main_btn.text = "Main Menu"
	quit_btn.text = "Quit"

	resume_btn.pressed.connect(close)
	main_btn.pressed.connect(_go_main_menu)
	quit_btn.pressed.connect(_quit)

func open() -> void:
	show()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	get_tree().paused = false
	hide()
	# recapture for FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _go_main_menu() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _quit() -> void:
	get_tree().quit()

extends Node

@onready var pause_menu = $PauseMenuCanvasLayer  

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # if FPS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # Esc by default
		if get_tree().paused:
			pause_menu.close()
		else:
			pause_menu.open()

extends CanvasLayer

@export var player_path: NodePath   
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/HBoxContainer/HPLabel

var player: Node = null

func _ready() -> void:
	# find player
	if player_path != NodePath():
		player = get_node_or_null(player_path)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)

		# initialize from current values if present
		if "max_health" in player and "health" in player:
			hp_bar.max_value = player.max_health
			hp_bar.value = player.health

func _on_player_health(current: int, maxv: int) -> void:
	hp_bar.max_value = maxv
	hp_bar.value = current

func _on_player_died() -> void:
	# flash red, show a label, etc.
	pass

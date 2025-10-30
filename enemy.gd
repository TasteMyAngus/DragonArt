extends CharacterBody3D

@export var movement_speed: float = 3.0
@export var retarget_interval: float = 0.15
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var turn_speed: float = 6.0  

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@export var player_path: NodePath
@onready var player: Node3D = get_node(player_path)

var _retarget_timer := 0.0

func _ready() -> void:
	navigation_agent.path_desired_distance = 0.3
	navigation_agent.target_desired_distance = 0.3
	navigation_agent.avoidance_enabled = false
	call_deferred("_post_ready")

func _post_ready() -> void:
	await get_tree().physics_frame
	_refresh_target()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_refresh_target()
		_retarget_timer = retarget_interval

	if not navigation_agent.is_navigation_finished():
		var next_point: Vector3 = navigation_agent.get_next_path_position()
		var to_next: Vector3 = next_point - global_position
		to_next.y = 0.0

		var desired_velocity := to_next.normalized() * movement_speed
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z

	# face the player 
	if player:
		var look_dir := player.global_transform.origin - global_transform.origin
		look_dir.y = 0.0
		if look_dir.length() > 0.001:
			var target_basis := Basis().looking_at(look_dir.normalized(), Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(
				target_basis,
				clamp(turn_speed * delta, 0.0, 1.0)
			)
	# 

	move_and_slide()

func _refresh_target() -> void:
	if player:
		navigation_agent.set_target_position(player.global_transform.origin)

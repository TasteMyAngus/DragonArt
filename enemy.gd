extends CharacterBody3D

@export var movement_speed: float = 3.0
@export var retarget_interval: float = 0.15
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var turn_speed: float = 6.0

@export var player_path: NodePath           # optional (spawner sets this)
@export var player_ref: Node3D              # optional direct reference (spawner sets this)

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
var player: Node3D = null

var _retarget_timer := 0.0
var _nav_map: RID
var _last_target: Vector3 = Vector3.INF
var _resolve_attempts := 0

func _ready() -> void:
	navigation_agent.path_desired_distance = 0.3
	navigation_agent.target_desired_distance = 0.3
	navigation_agent.avoidance_enabled = false
	navigation_agent.debug_enabled = true

	_nav_map = get_world_3d().navigation_map
	if navigation_agent.get_navigation_map() == RID():
		navigation_agent.set_navigation_map(_nav_map)

	# First attempt
	_resolve_player()
	call_deferred("_post_ready")

func _post_ready() -> void:
	await get_tree().physics_frame
	# Try again after one frame in case spawner finished wiring
	if player == null:
		_resolve_player()
	_retarget_now()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Keep trying to resolve player for a short while if still null
	if player == null and _resolve_attempts < 120:
		_resolve_player()

	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_now()

	var path := navigation_agent.get_current_navigation_path()
	if path.size() > 1 and not navigation_agent.is_navigation_finished():
		var next_point: Vector3 = navigation_agent.get_next_path_position()
		var to_next: Vector3 = next_point - global_position
		to_next.y = 0.0
		var v := to_next.normalized() * movement_speed
		velocity.x = v.x
		velocity.z = v.z
	else:
		velocity.x = move_toward(velocity.x, 0.0, movement_speed)
		velocity.z = move_toward(velocity.z, 0.0, movement_speed)

	# Face the player if known
	if player:
		var look := player.global_transform.origin - global_transform.origin
		look.y = 0.0
		if look.length() > 0.001:
			var target_basis := Basis().looking_at(look.normalized(), Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(
				target_basis,
				clamp(turn_speed * delta, 0.0, 1.0)
			)

	move_and_slide()

func _retarget_now() -> void:
	_retarget_timer = retarget_interval
	if player == null:
		return

	if navigation_agent.get_navigation_map() == RID():
		navigation_agent.set_navigation_map(_nav_map)

	var player_pos: Vector3 = player.global_transform.origin
	var nav_map: RID = get_world_3d().navigation_map
	var target_on_nav: Vector3 = player_pos
	if nav_map != RID():
		target_on_nav = NavigationServer3D.map_get_closest_point(nav_map, player_pos)

	if _last_target == Vector3.INF or _last_target.distance_to(target_on_nav) > 0.2:
		navigation_agent.set_target_position(target_on_nav)
		_last_target = target_on_nav

		var path := navigation_agent.get_current_navigation_path()
		if path.size() > 0:
			print("Enemy path pts=", path.size(),
				  " first=", path[0],
				  " last=", path[path.size() - 1],
				  " target_on_nav=", target_on_nav)
		else:
			print("Enemy path pts=0  target_on_nav=", target_on_nav)

func _resolve_player() -> void:
	_resolve_attempts += 1
	# 1) direct reference wins
	if player_ref and is_instance_valid(player_ref):
		player = player_ref
		return
	# 2) path lookup
	if player == null and player_path != NodePath():
		var by_path := get_node_or_null(player_path) as Node3D
		if by_path:
			player = by_path
			return
	# 3) group fallback
	if player == null:
		var by_group := get_tree().get_first_node_in_group("player") as Node3D
		if by_group:
			player = by_group
			return
	# Debug once in a while so you know it's still resolving
	if _resolve_attempts % 30 == 0:
		print("Enemy still resolving player... attempt #", _resolve_attempts)

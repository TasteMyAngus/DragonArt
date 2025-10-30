extends Node3D

@export var enemy_scene: PackedScene
@export var count: int = 5
@export var separation: float = 1.2
@export var random_yaw: bool = true
@export var spawn_on_ready: bool = true

@export var use_navmesh_snap: bool = true
@export var spawn_height_offset: float = 0.6
@export var no_collide_seconds: float = 0.5
@export var player_path: NodePath

@export var use_floor_raycast: bool = true
@export var floor_max_drop: float = 20.0
@export var collider_half_height: float = 1.0
@export var floor_offset_epsilon: float = 0.05

@export var parent_under_spawner: bool = true
@export var draw_debug_spheres: bool = true
@export var log_verbose: bool = true

# Random spawn settings
@export var enable_random_spawning: bool = true
@export var spawn_interval_min: float = 2.0
@export var spawn_interval_max: float = 5.0
@export var spawn_count_per_tick: int = 1

# Distance-based spawn rate
@export var distance_spawn_min: float = 5.0
@export var distance_spawn_max: float = 50.0
@export var interval_near: float = 1.0
@export var interval_far: float = 6.0

var _nav_map: RID
var _nav_ready := false

func _ready() -> void:
	randomize()
	_nav_map = get_world_3d().navigation_map
	call_deferred("_post_ready")

func _post_ready() -> void:
	await get_tree().create_timer(0.2).timeout
	await _await_nav_ready()

	if spawn_on_ready:
		var spawned := spawn_batch()
		if spawned.is_empty():
			push_warning("EnemySpawner: spawn_batch() produced 0 nodes.")
		else:
			print("EnemySpawner: finished spawning ", spawned.size(), " enemies.")

	if enable_random_spawning:
		_start_random_spawn_loop()

	var player_node: Node3D = null
	if player_path != NodePath():
		player_node = get_node_or_null(player_path) as Node3D
	if player_node == null:
		push_warning("EnemySpawner: Could not find player node at path: " + str(player_path))
	else:
		print("EnemySpawner: Found player node at path: " + str(player_path))
		if not player_node.is_in_group("player"):
			player_node.add_to_group("player")
			print("EnemySpawner: Added player node to 'player' group.")

func _await_nav_ready() -> void:
	if _nav_map == RID():
		await get_tree().physics_frame
		_nav_ready = false
		return
	var start_id := NavigationServer3D.map_get_iteration_id(_nav_map)
	var tries := 0
	while NavigationServer3D.map_get_iteration_id(_nav_map) == start_id and tries < 120:
		tries += 1
		await get_tree().physics_frame
	_nav_ready = NavigationServer3D.map_get_iteration_id(_nav_map) != start_id

func _start_random_spawn_loop() -> void:
	spawn_random_tick()

func spawn_random_tick() -> void:
	var player_node: Node3D = null
	if player_path != NodePath():
		player_node = get_node_or_null(player_path) as Node3D

	var delay := spawn_interval_max
	var dist := 0.0
	if player_node:
		dist = global_transform.origin.distance_to(player_node.global_transform.origin)
		var t: float = clamp((dist - distance_spawn_min) / (distance_spawn_max - distance_spawn_min), 0.0, 1.0)
		delay = lerp(interval_near, interval_far, t)

	await get_tree().create_timer(delay).timeout

	var original_count := count
	count = spawn_count_per_tick
	var spawned := spawn_batch()
	count = original_count

	if log_verbose:
		print("EnemySpawner: Distance = ", dist, " → delay = ", delay, "s → spawned ", spawned.size())

	spawn_random_tick()

func spawn_batch() -> Array:
	if enemy_scene == null:
		push_error("EnemySpawner: 'enemy_scene' is NOT set.")
		return []
	if count <= 0:
		push_warning("EnemySpawner: count <= 0; nothing to spawn.")
		return []

	var base := global_transform.origin
	var points := _vogel_points_around(base, count, separation)

	var player_node: Node3D = null
	if player_path != NodePath():
		player_node = get_node_or_null(player_path) as Node3D

	var spawned: Array[PhysicsBody3D] = []
	for idx: int in range(points.size()):
		var desired := points[idx]
		var pos := desired

		if use_navmesh_snap and _nav_ready and _nav_map != RID():
			pos = NavigationServer3D.map_get_closest_point(_nav_map, desired)

		if use_floor_raycast:
			var from := pos + Vector3.UP * 2.0
			var to := from + Vector3.DOWN * floor_max_drop
			var space := get_world_3d().direct_space_state
			var qp := PhysicsRayQueryParameters3D.create(from, to)
			qp.collide_with_areas = false
			var hit := space.intersect_ray(qp)
			if hit.has("position"):
				pos.y = hit.position.y + collider_half_height + floor_offset_epsilon
			else:
				pos.y += spawn_height_offset
		else:
			pos.y += spawn_height_offset

		var inst := enemy_scene.instantiate()
		if inst == null:
			push_error("EnemySpawner: instantiate() returned null.")
			continue

		if player_path != NodePath():
			if inst.get_property_list().any(func(p): return p.name == "player_path"):
				inst.set("player_path", player_path)
		if player_node and inst.get_property_list().any(func(p): return p.name == "player_ref"):
			inst.set("player_ref", player_node)

		if parent_under_spawner:
			add_child(inst)
			if log_verbose: print("[", idx, "] parented under spawner: ", name)
		else:
			var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
			parent.add_child(inst)
			if log_verbose: print("[", idx, "] parented under: ", parent.name)

		var agent: NavigationAgent3D = inst.get_node_or_null("NavigationAgent3D")
		if agent == null:
			agent = inst.find_child("NavigationAgent3D", true, false)
		if agent:
			agent.debug_enabled = true
			if agent.get_navigation_map() == RID():
				agent.set_navigation_map(_nav_map)
			if player_node:
				agent.set_target_position(player_node.global_transform.origin)

		_force_visible_layer1(inst)

		if inst is Node3D:
			(inst as Node3D).global_position = pos
			if random_yaw:
				(inst as Node3D).rotate_y(randf() * TAU)
		else:
			push_warning("Enemy root is not Node3D; got: " + str(inst.get_class()))

		if draw_debug_spheres:
			var s := MeshInstance3D.new()
			s.mesh = SphereMesh.new()
			s.scale = Vector3(0.2, 0.2, 0.2)
			s.name = "SpawnDebugSphere_" + str(idx)
			add_child(s)
			s.global_position = pos

		if log_verbose:
			var ep := "" if enemy_scene == null else enemy_scene.resource_path
			print("[", idx, "] enemy_scene: ", ep)
			print("[", idx, "] desired: ", desired, "  final: ", pos, "  delta: ", pos - desired)
			print("[", idx, "] type: ", inst.get_class(), "  visible? ", inst.has_method("show"))

		if inst is PhysicsBody3D:
			spawned.append(inst as PhysicsBody3D)

	if no_collide_seconds > 0.0 and spawned.size() > 1:
		for i in range(spawned.size()):
			for j in range(i + 1, spawned.size()):
				if is_instance_valid(spawned[i]) and is_instance_valid(spawned[j]):
					spawned[i].add_collision_exception_with(spawned[j])
					spawned[j].add_collision_exception_with(spawned[i])
		get_tree().create_timer(no_collide_seconds).timeout.connect(func():
			for i in range(spawned.size()):
				for j in range(i + 1, spawned.size()):
					if is_instance_valid(spawned[i]) and is_instance_valid(spawned[j]):
						spawned[i].remove_collision_exception_with(spawned[j])
						spawned[j].remove_collision_exception_with(spawned[i])
		)

	return spawned

func _vogel_points_around(center: Vector3, n: int, min_sep: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var phi: float = PI * (3.0 - sqrt(5.0))  # golden angle
	var c: float = max(min_sep, 0.01) * 0.6
	for k: int in range(n):
		var r: float = c * sqrt(float(k) + 1.0)
		var ang: float = float(k) * phi
		var x: float = center.x + r * cos(ang)
		var z: float = center.z + r * sin(ang)
		pts.append(Vector3(x, center.y, z))
	return pts

func _force_visible_layer1(node: Node) -> void:
	if node is VisualInstance3D:
		var v := node as VisualInstance3D
		v.layers = 1
		v.visible = true
	if "show" in node:
		node.call("show")
	for child in node.get_children():
		_force_visible_layer1(child)

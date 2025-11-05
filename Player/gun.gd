extends Node3D

@onready var muzzle: Marker3D = $Marker3D
@onready var beam: MeshInstance3D = $BeamMesh
@onready var cam: Camera3D = get_viewport().get_camera_3d()

@export var damage: int = 25
@export var alt_fire_damage: int = 100
@export var max_distance: float = 100.0

@export var alt_fire_cooldown: float = 1.5
var alt_fire_ready: bool = true

enum Weapon { AUTO = 1, BURST = 2, SHOTGUN = 3 }

@export var fire_cooldown: float = 0.1         
@export var burst_count: int = 3               
@export var burst_interval: float = 0.08       
@export var shotgun_pellets: int = 8           
@export var shotgun_spread_degrees: float = 6  
var current_weapon: int = Weapon.AUTO
var can_fire: bool = true 

@export var auto_color: Color    = Color(0.804, 0.141, 0.455)
@export var burst_color: Color   = Color(1.00, 0.55, 0.15) 
@export var shotgun_color: Color = Color(0.35, 1.00, 0.35) 

@onready var gun_mesh: MeshInstance3D = $MeshInstance3D


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			current_weapon = Weapon.AUTO
			_set_gun_color(auto_color)
		elif event.keycode == KEY_2:
			current_weapon = Weapon.BURST
			_set_gun_color(burst_color)
		elif event.keycode == KEY_3:
			current_weapon = Weapon.SHOTGUN
			_set_gun_color(shotgun_color)

	if (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed) \
		or event.is_action_pressed("attack"):
		fire_current_weapon()
		

func shoot():
	var cam_origin = cam.global_transform.origin
	var cam_dir = -cam.global_transform.basis.z

	var start_pos = muzzle.global_transform.origin
	var end_pos = cam_origin + cam_dir * max_distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(cam_origin, end_pos)
	var result = space_state.intersect_ray(query)

	if result:
		end_pos = result.position
		var target = result.collider
		if target.has_method("take_damage"):
			target.take_damage(damage)

	show_beam(start_pos, end_pos)

func shoot_strong():
	if not alt_fire_ready:
		return

	alt_fire_ready = false
	await get_tree().create_timer(alt_fire_cooldown).timeout
	alt_fire_ready = true

	var cam_origin = cam.global_transform.origin
	var cam_dir = -cam.global_transform.basis.z

	var start_pos = muzzle.global_transform.origin
	var end_pos = cam_origin + cam_dir * max_distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(cam_origin, end_pos)
	var result = space_state.intersect_ray(query)

	if result:
		end_pos = result.position
		var target = result.collider
		if target.has_method("take_damage"):
			target.take_damage(alt_fire_damage)

	show_beam(start_pos, end_pos)

func show_beam(start_pos: Vector3, end_pos: Vector3):
	var length = start_pos.distance_to(end_pos)
	if length < 0.1:
		return

	var dir = (end_pos - start_pos).normalized()
	var basis = Basis.looking_at(dir, Vector3.UP)
	var xform = Transform3D(basis, start_pos + dir * (length * 0.5))

	beam.global_transform = xform
	beam.scale = Vector3(0.05, 0.05, length)

	beam.show()
	await get_tree().create_timer(0.05).timeout
	beam.hide()

func fire_current_weapon() -> void:
	if not can_fire:
		return

	match current_weapon:
		Weapon.AUTO:
			shoot()
			_throttle_fire(fire_cooldown)

		Weapon.BURST:
			_burst_fire()

		Weapon.SHOTGUN:
			_shotgun_fire()
			_throttle_fire(fire_cooldown * 2.0)

func _throttle_fire(seconds: float) -> void:
	can_fire = false
	await get_tree().create_timer(seconds).timeout
	can_fire = true

func _burst_fire() -> void:
	if not can_fire:
		return
	can_fire = false
	for i in burst_count:
		shoot()
		if i < burst_count - 1:
			await get_tree().create_timer(burst_interval).timeout
	await get_tree().create_timer(max(fire_cooldown, 0.01)).timeout
	can_fire = true

func _shotgun_fire() -> void:
	var cam_origin: Vector3 = cam.global_transform.origin
	var cam_dir: Vector3 = -cam.global_transform.basis.z
	var start_pos: Vector3 = muzzle.global_transform.origin

	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.new()
	params.from = start_pos
	params.collision_mask = 0xFFFFFFFF  

	var forward := cam_dir.normalized()
	var up := Vector3.UP
	
	if abs(forward.dot(up)) > 0.95:
		up = Vector3(0, 0, 1)
	var right := forward.cross(up).normalized()
	up = right.cross(forward).normalized()

	for i in shotgun_pellets:
		var yaw = deg_to_rad(randf_range(-shotgun_spread_degrees, shotgun_spread_degrees))
		var pitch = deg_to_rad(randf_range(-shotgun_spread_degrees, shotgun_spread_degrees))

		var dir := (forward
			+ right * tan(yaw)
			+ up * tan(pitch)).normalized()

		params.to = start_pos + dir * max_distance
		var hit := space.intersect_ray(params)

		var end_pos := params.to
		if hit and hit.has("position"):
			end_pos = hit.position
			if hit.has("collider") and hit.collider and hit.collider.has_method("apply_damage"):
				hit.collider.apply_damage(damage)
		
		show_beam(start_pos, end_pos)

func _set_gun_color(color: Color) -> void:
	if gun_mesh == null:
		return

	var base_mat: Material = gun_mesh.material_override
	if base_mat == null and gun_mesh.mesh and gun_mesh.mesh.get_surface_count() > 0:
		base_mat = gun_mesh.mesh.surface_get_material(0)

	if base_mat:
		var mat = base_mat.duplicate() as StandardMaterial3D
		mat.albedo_color = color
		gun_mesh.material_override = mat
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		gun_mesh.material_override = mat

func _ready() -> void:
	match current_weapon:
		Weapon.AUTO:    _set_gun_color(auto_color)
		Weapon.BURST:   _set_gun_color(burst_color)
		Weapon.SHOTGUN: _set_gun_color(shotgun_color)
		

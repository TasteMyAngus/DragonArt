extends Node3D

@onready var muzzle: Marker3D = $Marker3D
@onready var beam: MeshInstance3D = $BeamMesh
@onready var cam: Camera3D = get_viewport().get_camera_3d()

var damage := 20
var max_distance := 100.0

func shoot():
	# Camera origin and forward direction (-Z is forward in Godot)
	var cam_origin = cam.global_transform.origin
	var cam_dir = -cam.global_transform.basis.z

	# Start beam at muzzle
	var start_pos = muzzle.global_transform.origin
	var end_pos = cam_origin + cam_dir * max_distance

	# Raycast from camera center
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(cam_origin, end_pos)
	var result = space_state.intersect_ray(query)

	if result:
		end_pos = result.position
		var target = result.collider
		if target.has_method("take_damage"):
			target.take_damage(damage)

	show_beam(start_pos, end_pos)


func show_beam(start_pos: Vector3, end_pos: Vector3):
	var length = start_pos.distance_to(end_pos)
	if length < 0.1:
		return

	var dir = (end_pos - start_pos).normalized()
	var basis = Basis.looking_at(dir, Vector3.UP)

	# Offset beam so it only extends forward, not backward
	var xform = Transform3D(basis, start_pos + dir * (length * 0.5))

	beam.global_transform = xform
	beam.scale = Vector3(0.05, 0.05, length)

	beam.show()
	await get_tree().create_timer(0.05).timeout
	beam.hide()

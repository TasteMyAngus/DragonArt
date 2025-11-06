# HealthBar3D.gd
extends Node3D
@export var y_only := true  # true = rotate only around Y so it stays level

func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	look_at(cam.global_transform.origin, Vector3.UP)
	if y_only:
		rotation.x = 0.0
		rotation.z = 0.0

extends CharacterBody3D

@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var acceleration: float = 12.0
@export var air_control: float = 2.5
@export var mouse_sensitivity: float = 0.0025
@export var jump_velocity: float = 4.8
@export var gravity: float = 7.0
@export var fireball_scene: PackedScene
@export var fireball_speed: float = 20.0
@export var fireball_spawn_offset: Vector3 = Vector3(0, 1.5, -1)


@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D
@onready var gun = $Head/Camera3D/Gun

var _mouse_captured := true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse()
	if event is InputEventMouseMotion and _mouse_captured:
		_apply_mouse_look(event)

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# Jumping
	if on_floor:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	# Movement
	var input2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir: Vector3 = (transform.basis * Vector3(input2d.x, 0.0, input2d.y)).normalized()

	var target_speed := sprint_speed if (Input.is_action_pressed("sprint") and on_floor) else walk_speed
	var desired_vel := move_dir * target_speed
	var accel := acceleration if on_floor else air_control

	velocity.x = move_toward(velocity.x, desired_vel.x, accel * delta * target_speed)
	velocity.z = move_toward(velocity.z, desired_vel.z, accel * delta * target_speed)

	move_and_slide()

	# Shooting
	if Input.is_action_just_pressed("shoot") and gun:
		gun.shoot()
	if Input.is_action_just_pressed("alt_fire") and gun:
		gun.shoot_strong()
	#
	if Input.is_action_just_pressed("throw_grenade"):
		shoot_fireball()

func shoot_fireball():
	if fireball_scene == null:
		push_warning("No fireball scene assigned.")
		return

	var fireball = fireball_scene.instantiate()
	var spawn_pos = cam.global_transform.origin + cam.global_transform.basis * fireball_spawn_offset
	fireball.global_transform.origin = spawn_pos
	fireball.look_at(spawn_pos + cam.global_transform.basis.z * -1, Vector3.UP)

	get_tree().current_scene.add_child(fireball)

	if fireball.has_method("launch"):
		fireball.launch(cam.global_transform.basis.z * -fireball_speed)
		
func _apply_mouse_look(event: InputEventMouseMotion) -> void:
	rotate_y(-event.relative.x * mouse_sensitivity)
	head.rotate_x(-event.relative.y * mouse_sensitivity)
	head.rotation_degrees.x = clamp(head.rotation_degrees.x, -89.0, 89.0)

func _toggle_mouse() -> void:
	_mouse_captured = not _mouse_captured
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE)

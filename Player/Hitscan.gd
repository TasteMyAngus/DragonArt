extends Node3D

@onready var ray = $RayCast3D
var damage = 20
var cooldown = 0.2
var can_shoot = true

func _input(event):
	if event.is_action_pressed("shoot") and can_shoot:
		shoot()

func shoot():
	can_shoot = false
	if ray.is_colliding():
		var target = ray.get_collider()
		if target.has_method("take_damage"):
			target.take_damage(damage)
		# Debug: show where it hit
		print("Hit: ", target)
	# Reset cooldown
	await get_tree().create_timer(cooldown).timeout
	can_shoot = true

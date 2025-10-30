extends RigidBody3D

@export var lifetime: float = 3.0
@export var explosion_radius: float = 5.0
@export var damage: float = 200.0

@onready var explosion_area: Area3D = $ExplosionArea

func launch(velocity: Vector3):
	linear_velocity = velocity
	$Timer.start(lifetime)

func _ready():
	var shape = $ExplosionArea/CollisionShape3D.shape
	if shape is SphereShape3D:
		shape.radius = explosion_radius


	explosion_area.monitoring = false
	explosion_area.monitorable = true
	explosion_area.collision_layer = 0
	explosion_area.collision_mask = 1  # Make sure it matches your enemy layer

func _on_Timer_timeout():
	explode()

func _on_body_entered(body):
	explode()

func explode():
	explosion_area.global_position = global_position
	explosion_area.monitoring = true

	var bodies := explosion_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemy"):
			if body.has_method("take_damage"):
				body.apply_damage(damage)

	# Optional: spawn particles, sound, etc.
	queue_free()

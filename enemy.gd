extends CharacterBody3D

@export var max_health := 100

@export var movement_speed: float = 7.0
@export var retarget_interval: float = 0.15
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var turn_speed: float = 6.0

@export var player_path: NodePath          
@export var player_ref: Node3D              

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var healthbar_mesh: MeshInstance3D = $HealthBar3D/Bar

@export var attack_range: float = 2.0           # how close to hit the player
@export var attack_cooldown: float = 1.0        # seconds between hits
@export var attack_damage: int = 10
@export var require_los: bool = true            # need clear line of sight

@export var heal_on_death: int = 5       # how much the player heals when THIS enemy dies
@export var heal_is_percent: bool = false # if true, treat heal_on_death as % of player's max HP

@export var approach_distance: float = 2.0     # desired stand-off within attack range
@export var min_distance: float = 1.2          # never come closer than this
@export var standoff_hysteresis: float = 0.25  # deadzone to prevent jitter
@export var allow_circle_strafe: bool = true   # circle around player when in range
@export var strafe_ratio: float = 0.4          # 0..1 of movement_speed used for strafing


var player: Node3D = null

var _retarget_timer := 0.0
var _nav_map: RID
var _last_target: Vector3 = Vector3.INF
var _resolve_attempts := 0
var health := 0
var hb_mat: ShaderMaterial
var _attack_cd_left: float = 0.0
var _is_dead := false
var player_health: int

func _ready() -> void:
	navigation_agent.path_desired_distance = 0.3
	navigation_agent.target_desired_distance = 0.3
	navigation_agent.avoidance_enabled = false
	navigation_agent.debug_enabled = true

	_safe_init_healthbar()
	call_deferred("_late_init_hb")
	_nav_map = get_world_3d().navigation_map
	if navigation_agent.get_navigation_map() == RID():
		navigation_agent.set_navigation_map(_nav_map)
		
	health = max_health
	# Ensure we're damageable by bullets that look for this:
	add_to_group("damageable")
	# Connect hurtbox if not connected in the editor
	if $Hurtbox and not $Hurtbox.is_connected("body_entered", Callable(self, "_on_hurtbox_body_entered")):
		$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)
		
	_resolve_player()
	call_deferred("_post_ready")
	hb_mat = healthbar_mesh.material_override as ShaderMaterial
	if hb_mat == null:
		# fallback to surface material (slot 0) if override not set
		hb_mat = healthbar_mesh.get_active_material(0) as ShaderMaterial
	if hb_mat == null:
		push_warning("Healthbar material not found (need a ShaderMaterial on Bar).")
	else:
		_update_healthbar_immediate()

func _post_ready() -> void:
	await get_tree().physics_frame
	if player == null:
		_resolve_player()
	_retarget_now()
	
func _apply_standoff_velocity(base_v: Vector3, dir_to_player: Vector3, dist: float) -> Vector3:
	var v := base_v
	# Only constrain movement when we’re within the attack envelope
	if dist <= attack_range:
		# Too close: gently back up
		if dist <= min_distance:
			v = -dir_to_player * movement_speed
		# Inside approach ring: stop pushing forward (optional strafe)
		elif dist <= approach_distance + standoff_hysteresis:
			v = Vector3.ZERO

		# Add lateral strafe so they don’t just “park”
		if allow_circle_strafe:
			var tangent := Vector3(-dir_to_player.z, 0.0, dir_to_player.x) # right-hand perp on XZ
			v += tangent.normalized() * (movement_speed * strafe_ratio)
	return v

	
func _late_init_hb() -> void:
	_safe_init_healthbar()
	
func _safe_init_healthbar() -> void:
	if healthbar_mesh == null:
		return

	var mat := healthbar_mesh.material_override
	if mat == null:
		var surf := healthbar_mesh.get_active_material(0)
		if surf:
			mat = surf.duplicate()  # clone so it's not shared
		else:
			mat = ShaderMaterial.new()
	else:
		if not mat.resource_local_to_scene:
			mat = mat.duplicate()

	# mark unique to this scene instance and assign back
	mat.resource_local_to_scene = true
	healthbar_mesh.material_override = mat

	hb_mat = mat as ShaderMaterial
	if hb_mat:
		_update_healthbar_immediate()
	else:
		push_warning("Healthbar material is not a ShaderMaterial.")

	
func _update_healthbar_immediate() -> void:
	if hb_mat:
		var f := float(health) / float(max_health)
		hb_mat.set_shader_parameter("fill", f)
		print("HB fill (immediate) = ", f)

func _update_healthbar_smooth() -> void:
	if hb_mat:
		var target := float(health) / float(max_health)
		print("HB fill (target) = ", target)
		var tw := get_tree().create_tween()
		tw.tween_property(hb_mat, "shader_parameter/fill", target, 0.15)


	
func take_damage(amount: int, hit_pos: Vector3 = global_position) -> void:
	if amount <= 0: return
	health = max(health - amount, 0)
	# optional hurt flash
	if hb_mat:
		hb_mat.set_shader_parameter("hurt_flash", 1.0)
		get_tree().create_tween().tween_property(hb_mat, "shader_parameter/hurt_flash", 0.0, 0.25)
	_update_healthbar_smooth()
	if health == 0:
		die()


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	
	if player and player.has_method("_get_health"):
		player_health = player._get_health()
	# Heal the player on kill
	if player and player.has_method("heal"):
		if player_health <= 90:
			player.heal(heal_on_death)
		else:
			player.heal(100 - player_health)
	
	queue_free()

func _on_hurtbox_body_entered(body: Node) -> void:
	# Bullets will call take_damage themselves, but this allows
	# alternate damage sources that just enter the hurtbox.
	
	if body.has_method("get_bullet_damage"):
		take_damage(body.get_bullet_damage(), body.global_transform.origin)
		if body.has_method("on_bullet_resolved"):
			body.on_bullet_resolved()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
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
		var forward := to_next.normalized() * movement_speed

		# compute player dir/dist once
		var dirp: Vector3 = Vector3.ZERO
		var dist := INF
		if player:
			var d := player.global_transform.origin - global_position
			d.y = 0.0
			dist = d.length()
			dirp = (d / dist) if dist > 0.001 else Vector3.ZERO

		var v := _apply_standoff_velocity(forward, dirp, dist)
		velocity.x = v.x
		velocity.z = v.z
	else:
		if player:
			var d := player.global_transform.origin - global_position
			d.y = 0.0
			var dist := d.length()
			var dir := (d / dist) if dist > 0.001 else Vector3.ZERO
			var forward := dir * movement_speed
			var v := _apply_standoff_velocity(forward, dir, dist)
			velocity.x = v.x
			velocity.z = v.z
		else:
			velocity.x = move_toward(velocity.x, 0.0, movement_speed)
			velocity.z = move_toward(velocity.z, 0.0, movement_speed)


	
	_attack_cd_left = maxf(_attack_cd_left - delta, 0.0)
	
	if player:
		var look := player.global_transform.origin - global_transform.origin
		look.y = 0.0
		if look.length() > 0.001:
			var target_basis := Basis().looking_at(look.normalized(), Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(
				target_basis,
				clamp(turn_speed * delta, 0.0, 1.0)
			).orthonormalized()

	# attacking
	_try_attack_player()

	move_and_slide()
	
func _try_attack_player() -> void:
	if player == null or _attack_cd_left > 0.0:
		return

	# distance check
	var to_player := player.global_transform.origin - global_transform.origin
	var horizontal := Vector3(to_player.x, 0.0, to_player.z)
	var dist := horizontal.length()
	if dist > attack_range:
		return

	# optional line of sight (raycast)
	if require_los:
		var space := get_world_3d().direct_space_state
		var from := global_transform.origin + Vector3(0, 1.2, 0)  # chest/eye height
		var to := player.global_transform.origin + Vector3(0, 1.2, 0)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = false
		query.exclude = [self.get_rid()]  # ignore self

		var hit: Dictionary = space.intersect_ray(query)
		if hit.size() > 0:
			var collider: Object = hit["collider"]        
			# If ray hits something that is not the player, no LoS
			if collider != player:
				return

	# apply damage (player script must have take_damage)
	if player.has_method("take_damage"):
		player.take_damage(attack_damage, self)

	_attack_cd_left = attack_cooldown

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
		#if path.size() > 0:
			#print("Enemy path pts=", path.size(),
			#	  " first=", path[0],
			#	  " last=", path[path.size() - 1],
			#	  " target_on_nav=", target_on_nav)
		#else:
			# print("Enemy path pts=0  target_on_nav=", target_on_nav)

func _resolve_player() -> void:
	_resolve_attempts += 1
	if player_ref and is_instance_valid(player_ref):
		player = player_ref
		return
	if player == null and player_path != NodePath():
		var by_path := get_node_or_null(player_path) as Node3D
		if by_path:
			player = by_path
			return
	if player == null:
		var by_group := get_tree().get_first_node_in_group("player") as Node3D
		if by_group:
			player = by_group
			return
	# Debug 
	if _resolve_attempts % 30 == 0:
		print("Enemy still resolving player... attempt #", _resolve_attempts)

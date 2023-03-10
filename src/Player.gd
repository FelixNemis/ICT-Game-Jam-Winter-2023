extends RigidBody

onready var camera_pivot = find_node("CameraFocus")

onready var seed_root = find_node("Seed")

var mouse_sensitivity = 0.5

var controller_look_sensitivity = 12

var movement_force = 1.0
var torque_amount = 0.15

var vel_limit = 35.0

var has_fruit: = false

var zoom: = false
var zoom_time = 11.0
var zoom_timer = 0.0

var material : SpatialMaterial

func _ready():
#	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	material = $Ball/DurianModel/Icosphere002.mesh.surface_get_material(0)

func get_seed() -> void:
	has_fruit = true
	seed_root.visible = true

func drop_seed() -> void:
	has_fruit = false
	seed_root.visible = false

func _process(delta):
	if Input.is_action_just_pressed("fire1"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.is_action_just_pressed("Esc"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.is_action_just_pressed("restart"):
		get_tree().change_scene("res://Scenes/MainMenu.tscn")
	
	var controller_h_look = Input.get_axis("controller_look_left", "controller_look_right")
	var controller_v_look = Input.get_axis("controller_look_up", "controller_look_down")
	if controller_h_look or controller_v_look:
		camera_look(Vector2(controller_h_look, controller_v_look), controller_look_sensitivity)
	
	var detected_zones = len($DetectZone.get_overlapping_areas())
	if detected_zones < 1:
		if zoom:
			zoom_timer += delta
			if zoom_timer >= zoom_time:
				zoom = false
				material.emission_energy = 1.0
				
	
	if detected_zones > 0:
		zoom = true
		material.emission_energy = 1.8
		zoom_timer = 0
	

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_look(event.relative, mouse_sensitivity)
#		var arm = camera_pivot.get_child(0)
#		arm.rotate_x(-event.relative.y * 0.01 * mouse_sensitivity)
#		camera_pivot.rotate_y(-event.relative.x * 0.01 * mouse_sensitivity)
#		arm.rotation.x = clamp(arm.rotation.x, -1.2, 1.2)

func camera_look(delta: Vector2, sensitivity) -> void:
	var arm = camera_pivot.get_child(0)
	arm.rotate_x(-delta.y * 0.01 * sensitivity)
	camera_pivot.rotate_y(-delta.x * 0.01 * sensitivity)
	arm.rotation.x = clamp(arm.rotation.x, -1.2, 1.2)

func comp(vec1: Vector3, vec2: Vector3) -> bool:
	#print("%s~%s %s~%s %s~%s" % [sign(vec1.x), sign(vec2.x),sign(vec1.y), sign(vec2.y),sign(vec1.z), sign(vec2.z)])
	
	return not (sign(vec1.x) == sign(vec2.x) and sign(vec1.z) == sign(vec2.z))

func _integrate_forces(state: PhysicsDirectBodyState):
#func _physics_process(delta):
	var forward_vec = -camera_pivot.transform.basis.z
	var left_vec = -camera_pivot.transform.basis.x
	
	var move_vec = Vector3.ZERO
	
	var actual_vel_limit = vel_limit
	if zoom:
		actual_vel_limit *= 3
	
	var fb = Input.get_axis("backward", "forward")
	if fb != 0:
		var projected = state.linear_velocity.project(forward_vec * fb)
		var current_vel = projected.length() * sign(projected.dot(forward_vec * fb))
		
		var effective_force = movement_force
		if current_vel > actual_vel_limit:
			effective_force = 0
		if current_vel < 0:
			effective_force *= 2
		state.linear_velocity += forward_vec * fb * effective_force
		move_vec += forward_vec * fb
		
	
	var lr = Input.get_axis("right", "left")
	if lr != 0:
		var projected = state.linear_velocity.project(left_vec * lr)
		var current_vel = projected.length() * sign(projected.dot(left_vec * lr))
		
		var effective_force = movement_force
		if current_vel > actual_vel_limit:
			effective_force = 0
		if current_vel < 0:
			effective_force *= 2
		state.linear_velocity += left_vec * lr * effective_force
		move_vec += left_vec * lr
	
	if move_vec:
		var perpendicular = move_vec.normalized().rotated(Vector3.UP, PI/2)
		
		var angle = state.angular_velocity.length() / 1000.0
		var axis = state.angular_velocity.normalized()
		
		var current_ang_vel = 0
		var invert = false
		if angle != 0:
			var quat = Quat(axis, angle)
			
			var xyz = Vector3(quat.x, quat.y, quat.z)
			var proj = xyz.project(perpendicular)
			var twist = Quat(proj.x, proj.y, proj.z, quat.w).normalized()
			
			current_ang_vel = Quat.IDENTITY.angle_to(twist)
			invert = comp(perpendicular, Vector3(twist.x, twist.y, twist.z))
		
		#print(current_ang_vel)
		if invert or current_ang_vel < 0.003:
			state.apply_torque_impulse(perpendicular * torque_amount)
	
	if angular_velocity:
		var av = angular_velocity
		seed_root.transform.basis = seed_root.transform.basis.rotated(av.normalized() * -1, av.length() * state.step)

extends CharacterBody3D

# for death...
var is_frozen: bool = false

# to get the Health bar HUD working...
@onready var bar_health: TextureProgressBar = $CanvasLayer/HUD/bar_health

# to pick up stuff...
@onready var raycast: RayCast3D = $Head/Camera3D/InteractionRay
@onready var hold_position: Marker3D = $Head/Camera3D/HoldPosition
var held_object: RigidBody3D = null

# The tutorial does not show how to add stats such as health.
# I attempt to add this myself with documentation.
var health = 200 # We will actually give the player 200 HP.
const MAX_HEALTH = 200.0
const GREYSCALE_THRESHOLD = 100.0

# For this script i was earlier referring to myself in 3rd person and now switched to 1st person.

var speed
const WALK_SPEED = 4.0 ###
const SPRINT_SPEED = 8.5 ###
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.01 ### Tutorial said 0.03, but I changed this to 0.01 because that is too high.

# Coyote time for better jumps
const COYOTETIME: float = 0.15 # duration in seconds
var COYOTETIMER: float = 0.0 # track the grace time

# Headbob variables
const BOB_FREQ = 1.0 # Originally 2.0, but excessive headbob is annoying in my experience, so I usually always set it to minimal values.
const BOB_AMP = 0.04
var t_bob = 0.0

# FOV (my personal favourite) variables
var BASE_FOV = 90
const FOV_CHANGE = 1.5

# Devran also added variables here so the script can access the head and camera3d
@onready var head = $Head
@onready var camera = $Head/Camera3D

# Devran's addition here: func _ready
func _ready():	
	# process_mode = PROCESS_MODE_ALWAYS # Player node will always be processed even if game paused. [disabled because the player does not need to move when dead, and the pause menu serves as a restarter for levels.
	
	# Wait for level scene to finish loading
	await get_tree().process_frame
	
	# Get level environment
	var level_env = camera.get_viewport().get_camera_3d().get_environment()
	if level_env:
		# Duplicate it to protect level environment
		camera.environment = level_env.duplicate()
	else:
		# Fallback for levels without an environment setup.
		camera.environment = Environment.new()
		
	camera.environment.adjustment_enabled = true
	camera.environment.adjustment_saturation = 1.0
	
	# Init healthbar
	bar_health.max_value = 200.0
	bar_health.value = health

func _unhandled_input(event):
	# Lock the mouse to the camera so that we can look around (new method)
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: # addition to move camera only when mouselock.
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(85))
	
	# Unlock mouse (and later show a menu)
	if event.is_action_pressed("escape"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event.is_action_pressed("interact"): # script for init the cube pickup
		if held_object:
			drop_cube()
		else:
			try_pickup_cube()

func try_pickup_cube() -> void:
	# check if the raycast is hitting something
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# check the object is a RigidBody3D and belongs to the 'phys_prop' group
		if collider is RigidBody3D and collider.is_in_group("phys_prop"):
			held_object = collider
			
			# disable physics so it doesn't fall or collide with the player [added this option but commented it out because i want the cube to still interact with physics]
			# held_object.freeze = true
			held_object.gravity_scale = 0.0 # set the gravity to 0 so it doesn't fall.
			
			# parent it to the hold marker
			held_object.get_parent().remove_child(held_object)
			hold_position.add_child(held_object)
			
			# snap position and rotation to the holding point
			held_object.position = Vector3.ZERO
			held_object.rotation = Vector3.ZERO
			
func drop_cube() -> void:
	if not held_object:
		return
		
	# store the current global position
	var current_global_transform = held_object.global_transform
	
	# move the cube back to the root of scene
	hold_position.remove_child(held_object)
	get_tree().current_scene.add_child(held_object)
	
	# restore its position in the world
	held_object.global_transform = current_global_transform
	
	# turn physics back on [commented out for redundancy - physics was not disabled]
	# held_object.freeze = false
	held_object.gravity_scale = 1.0 # gravity is reset so that the item does fall when not held.
	
	# clear reference
	held_object = null

func _physics_process(delta: float) -> void:
	if is_frozen:
		# Apply gravity to player to make them fall
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			# apply heavy friction once they hit the ground
			velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
			velocity.y = 0
			
		move_and_slide()
		return # Skips running the player inputs.
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		# tick coyote timer in air
		COYOTETIMER -= delta
	else:
		COYOTETIMER = COYOTETIME

	# Handle jump.
	if Input.is_action_just_pressed("move_jump"): #and is_on_floor():
		# Check if the coyote timer is still active instead of is_on_floor()
		if COYOTETIMER > 0.0:
			velocity.y = JUMP_VELOCITY
			COYOTETIMER = 0.0 # clear timer so that player can't double-jump
	
	# Handle sprint // devran
	if Input.is_action_pressed("move_sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	
	if held_object: # Handle holding items
		# find the vector pointing from the cube to holdmarker
		var target_vector = hold_position.global_position - held_object.global_position
		
		# apply a physical velocity to pull it there
		held_object.linear_velocity = target_vector * 15.0
		
		# keep the cube's rotation matching camera look angle
		held_object.angular_velocity = Vector3.ZERO 
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector3 = (head.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0) # Fixed previous code so that now the player will slow to a stop.
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0) # This is inertia.
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.5)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.5)
		# velocity.y = lerp(velocity.y, direction.y * speed, delta * 2.0)
		
	# Apply headbob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 7.0)
	
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

# Now we need to add damage (and damage type), using a function.
func _takedamage(amount, type):
	health -= amount
	print("Player took damage. HP = ", health, "damage type: ", type) # Prints to the console the player HP state.
	
	var current_hp = clamp(health, 0.0, MAX_HEALTH)
	
	bar_health.value = health
	
	if camera.environment and camera.environment.adjustment_enabled:
		if current_hp <= GREYSCALE_THRESHOLD:
			var saturation_ratio = current_hp / GREYSCALE_THRESHOLD
			camera.environment.adjustment_saturation = saturation_ratio
		else:
			camera.environment.adjustment_saturation = 1.0
	
	# Does the damage kill the player?
	if health <= 0:
		_die()

func _heal(amount): # added healing on 16/10/2026
	if health < 200:
		health += amount
		print("Player healed. HP = ", amount)
		var current_hp = clamp(health, 0.0, MAX_HEALTH)
	
		bar_health.value = health
	
		if camera.environment and camera.environment.adjustment_enabled:
			if current_hp <= GREYSCALE_THRESHOLD:
				var saturation_ratio = current_hp / GREYSCALE_THRESHOLD
				camera.environment.adjustment_saturation = saturation_ratio
			else:
				camera.environment.adjustment_saturation = 1.0

func _die():
	print("Player is dead.") # Again, print to console.
	
	# freeze player controls
	is_frozen = true
	
	# force 100% greyscale if HP dropped into negatives.
	if camera.environment:
		camera.environment.adjustment_saturation = 0.0
		
	# Release the mouse so the player can interact with UI menus
	# Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) (make sure this doesn't interfere with the global 'Esc' to unlock mouse
	
	# set_physics_process(false) # Disable movement. (if uncommented, the player will instantly tilt to their side like Half-Life 1.)
	# turn the player into a simulated physical object that rolls and falls (as they are a pill shape), basically a first person ragdoll
	motion_mode = MOTION_MODE_GROUNDED # standard ground mode fallback
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_INHERIT
	process_mode = PROCESS_MODE_INHERIT # change the body type to rigid so gravity has an effect
	
	# push the player slightly so they aren't left standing.
	rotation.z = deg_to_rad(75) # tip them over onto their side
	velocity.y = -1.0           # tiny downward push to settle into the floor

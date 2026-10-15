extends CharacterBody3D

# to get the Health bar HUD working...
@onready var bar_health: TextureProgressBar = $CanvasLayer/HUD/bar_health

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
# Lock the mouse to the camera so that we can look around
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	process_mode = PROCESS_MODE_ALWAYS # Player node will always be processed even if game paused.
	
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
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle sprint // devran
	if Input.is_action_pressed("move_sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	
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

func _die():
	print("Player is dead.") # Again, print to console.
	
	# force 100% greyscale if HP dropped into negatives.
	if camera.environment:
		camera.environment.adjustment_saturation = 0.0
		
	# Release the mouse so the player can interact with UI menus
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Pause the level scene loop
	get_tree().paused = true

extends CanvasLayer
@onready var player_node: CharacterBody3D = get_parent() # so that we can call functions on the player with buttons.

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_tree().paused = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			visible = false
			get_tree().paused = false
		else:
			visible = true
			get_tree().paused = true
	if event.is_action_pressed("escape"): # Enables mouse unlock in both game and pause
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_button_pressed() -> void: # Resume button
	visible = false
	get_tree().paused = false
	pass # Replace with function body.


func _on_button_2_pressed() -> void: # Reload button
	get_tree().reload_current_scene()
	pass # Replace with function body.


func _on_button_3_pressed() -> void:
	visible = false
	get_tree().paused = false # Unpause the game so that the button action applies.
	if player_node and player_node.has_method("_takedamage"):
		player_node._takedamage(999999, "general") # Kill the player.
	pass # Replace with function body.

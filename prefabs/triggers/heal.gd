extends Area3D

# @export should allow me to change the properties of a specific heal block.
@export_group("Heal settings")
@export var heal_amount: float = 25.0
@export var heal_interval_seconds: float = 1.0 # Choose exactly how many seconds between hits

@export_group("Visual settings")
@export var is_visible: bool = true # toggle visibility

var player_node: Node3D = null
var time_since_last_heal: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if mesh_instance:
		mesh_instance.visible = is_visible

func _physics_process(delta: float) -> void:
	# if player is standing inside this block, tick the timer forward
	if player_node:
		time_since_last_heal += delta
		if time_since_last_heal >= heal_interval_seconds:
			time_since_last_heal = 0.0
			_apply_heal_to_player()

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_node = body
		# apply heal when they touch it
		_apply_heal_to_player()
		time_since_last_heal = 0.0

func _on_body_exited(body: Node3D) -> void:
	if body == player_node:
		player_node = null

func _apply_heal_to_player() -> void:
	if player_node and player_node.has_method("_takeheal"):
		player_node._heal(heal_amount)

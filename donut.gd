extends RigidBody3D

var target : Node3D
var speed : int
var damage : int

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if target:
		var targeting_position = target.get_targeting_position()
		var attack_position = transform.looking_at(targeting_position, Vector3.UP, true)
		# Move toward the enemy if too far, move away if too close
		if attack_position.origin.distance_to(targeting_position) > 0:
			transform.origin = attack_position.origin.move_toward(targeting_position, delta * speed)

func fire(fire_damage: int, fire_speed: int, spawn_location: Vector3, fire_target):
	global_transform.origin = spawn_location
	damage = fire_damage
	speed = fire_speed
	target = fire_target

func _on_body_entered(body):
	if target and body in get_tree().get_nodes_in_group("Enemies"):
		body.on_hit(damage)
	
	target = null
	gravity_scale = 1

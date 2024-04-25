extends CharacterBody3D

signal no_target_found

enum states {
	MOVING = Globals.movement_states.MOVING,
	ATTACKING = Globals.movement_states.ATTACKING,
	HIT = Globals.movement_states.HIT,
	DYING = Globals.movement_states.DYING
}

var target : Node3D

const SPEED = 1.2
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 6

var state = states.MOVING

var max_health = 1

var health = max_health
var melee_damage = 1

var close_targets: Array
var melee_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var animation_tree
var animation_state

func _ready():
	animation_tree = $AnimationTree
	animation_state = animation_tree.get("parameters/playback")
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.max_value = max_health
	$HealthBarView/HealthBar.value = health

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		states.MOVING:
			move_state(delta)
		states.ATTACKING:
			attack_state(delta)
		states.HIT:
			hit_state(delta)
		states.DYING:
			death_state(delta)

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

# This function will be called from the Main scene.
func initialize(start_position, start_target):
	# We position the enemy by placing it at start_position
	position = start_position
	add_to_group("Enemies")
	set_target(start_target)
	
func move_state(delta):
	look_at(Vector3(target.global_position.x, 0, target.global_position.z), Vector3.UP, true)
	if target not in close_targets:
		animation_state.travel("Walk")
		var direction = (target.transform.origin - transform.origin).normalized() * Vector3(1,0,1)
		velocity = direction * SPEED
		move_and_slide()
	else:
		animation_state.travel("idle")
	
	if target in melee_targets:
		state = states.ATTACKING

func attack_state(delta):
	transform = transform.interpolate_with(transform.looking_at(Vector3(target.global_position.x, 0, target.global_position.z), Vector3.UP, true), delta * TURN_SPEED)
	animation_state.travel("Attack")

func hit_state(delta):
	animation_state.travel("Hit")

func death_state(delta):
	animation_state.travel("Die")

func attack(target):
	velocity = Vector3.ZERO
	target.on_hit(melee_damage)

func _on_melee_range_body_entered(body):
	var player_targets = get_tree().get_nodes_in_group("PlayerTargets")
	if body not in melee_targets && body in player_targets:
		melee_targets.append(body)
		set_target(body)
		if body == target && body.has_method("targeted"):
			body.targeted()

func _on_melee_range_body_exited(body):
	if body in melee_targets:
		melee_targets.erase(body)
		if body == target && body.has_method("untargeted"):
			body.untargeted()
		
		# When current target leaves melee range, target the latest added melee target
		# If no available melee targets, signal that you have none
		# TODO: Add aggro range
		if melee_targets.is_empty():
			no_target_found.emit(self)
		else:
			if body == target:
				set_target(melee_targets.back())

func _on_close_range_body_entered(body):
	if body not in close_targets && body in get_tree().get_nodes_in_group("PlayerTargets"):
		close_targets.append(body)

func _on_close_range_body_exited(body):
	if body in close_targets:
		close_targets.erase(body)

func on_hit(damage):
	health = clamp(health - damage, 0, max_health)
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.value = health
	if health > 0:
		state = states.HIT
	else:
		# Remove collision and info so it's just untargetable animation left
		$CollisionShape3D.queue_free()
		$HealthBarSprite.queue_free()
		state = states.DYING

func set_target(new_target):
	target = new_target

func attack_connects():
	attack(target)

func _on_action_animation_finished():
	state = states.MOVING

func _on_death_animation_finished():
	queue_free()

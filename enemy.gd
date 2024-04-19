extends CharacterBody3D

signal no_target_found

var target : Node3D

const SPEED = 1.2
const JUMP_VELOCITY = 4.5

var max_health = 1

var health = max_health
var melee_damage = 1

var close_targets: Array
var melee_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.max_value = max_health
	$HealthBarView/HealthBar.value = health

func _physics_process(delta):
	if health <= 0:
		die()

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	look_at(Vector3(target.global_position.x, 0, target.global_position.z), Vector3.UP, true)
	if target not in close_targets:
		var direction = (target.transform.origin - transform.origin).normalized() * Vector3(1,0,1)
		velocity = direction * SPEED
		move_and_slide()
	
	$AnimationTree.set("parameters/conditions/idle", close_targets.find(target) != -1 && is_on_floor())
	$AnimationTree.set("parameters/conditions/walk", close_targets.find(target) == -1 && is_on_floor())
	
	if target in melee_targets:
		if $Abilities/Attack/AttackCooldownTimer.is_stopped():
			$Abilities/Attack/AttackCooldownTimer.start()
	else:
		$Abilities/Attack/AttackCooldownTimer.stop()

# This function will be called from the Main scene.
func initialize(start_position, start_target):
	# We position the enemy by placing it at start_position
	global_position = start_position
	add_to_group("Enemies")
	set_target(start_target)

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
		# TODO: Add a function to find possible target in view outside of melee range
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

func die():
	queue_free()
	
func set_target(new_target):
	target = new_target

func _on_attack_cooldown_timer_timeout():
	attack(target)

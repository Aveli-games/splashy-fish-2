extends CharacterBody3D

@export var target : Player

const SPEED = 1.2
const JUMP_VELOCITY = 4.5
const CLOSE_RANGE = .75
const MELEE_RANGE = 1.5

var close_targets: Array
var melee_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	look_at(Vector3(target.global_position.x, 0, target.global_position.z), Vector3.UP, true)
	if target in melee_targets:
		if $Abilities/Attack/AttackCooldownTimer.is_stopped():
			$Abilities/Attack/AttackCooldownTimer.start()
	else:
		$Abilities/Attack/AttackCooldownTimer.stop()
		var direction = (target.transform.origin - transform.origin).normalized() * Vector3(1,0,1)
		
		velocity = direction * SPEED

	$AnimationTree.set("parameters/conditions/idle", close_targets.find(target) != -1 && is_on_floor())
	$AnimationTree.set("parameters/conditions/walk", close_targets.find(target) == -1 && is_on_floor())

	move_and_slide()

func attack(target):
	velocity = Vector3.ZERO
	target.on_hit()

func _on_melee_range_body_entered(body: Player):
	if body not in melee_targets && body != self:
		melee_targets.append(body)

func _on_melee_range_body_exited(body):
	if body in melee_targets:
		melee_targets.erase(body)

func _on_close_range_body_entered(body: Player):
	if body not in close_targets:
		close_targets.append(body)

func _on_close_range_body_exited(body):
	if body in close_targets:
		close_targets.erase(body)
		
func on_hit():
	queue_free()

func _on_attack_cooldown_timer_timeout():
	attack(target)

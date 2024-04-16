extends CharacterBody3D

signal hit_player

@export var target : Player

const SPEED = 3.0
const JUMP_VELOCITY = 4.5

var close_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	look_at(target.global_position, Vector3.UP, true)
	
	if close_targets.find(target) != -1:
		attack(target)
	else:
		var direction = (target.transform.origin - transform.origin).normalized()
		
		velocity = direction * SPEED

		$AnimationTree.set("parameters/conditions/idle", target.global_position == self.global_position && is_on_floor())
		$AnimationTree.set("parameters/conditions/walk", target.global_position != self.global_position && is_on_floor())

		move_and_slide()

func attack(target):
	#target.on_hit() TODO: write an on_hit function for units that processes hits from other units
	hit_player.emit()

func _on_close_range_body_entered(body: Player):
	if body not in close_targets:
		close_targets.append(body)

func _on_close_range_body_exited(body: Player):
	if body in close_targets:
		close_targets.erase(body)

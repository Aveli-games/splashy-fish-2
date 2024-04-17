extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$AttackCooldownView/AttackCooldown.value = 100 - ($AttackCooldownTimer.time_left/$AttackCooldownTimer.wait_time) * 100

func use():
	$AttackCooldownTimer.start()

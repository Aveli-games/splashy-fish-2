extends StaticBody3D

signal died

@export var max_health = 3

var health
var health_bar_modulate
var targeted_times = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	health = max_health
	$HealthBarView/HealthBar.max_value = max_health
	$HealthBarView/HealthBar.value = max_health
	health_bar_modulate = $HealthBarView/HealthBar.modulate
	$HealthBarView/HealthLabel.text = str(health)

func on_hit(damage):
	if health > 0:
		health = clamp(health - damage, 0, max_health)
		$HealthBarView/HealthLabel.text = str(health)
		$HealthBarView/HealthBar.value = health
		if health <= 0:
			die()

func die():
	died.emit()

func targeted():
	targeted_times += 1
	$HealthBarView/HealthBar.set_modulate(Color.CRIMSON)

func untargeted():
	targeted_times -= 1
	if targeted_times <= 0:
		$HealthBarView/HealthBar.set_modulate(health_bar_modulate)

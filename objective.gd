extends StaticBody3D

signal died

var health = 3
var health_bar_modulate
var targeted_times = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	health_bar_modulate = $HealthBarView/HealthBar.modulate

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if health <= 0:
		died.emit()
		queue_free()

func on_hit():
	health -= 1
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.value = health

func targeted():
	targeted_times += 1
	$HealthBarView/HealthBar.set_modulate(Color.CRIMSON)

func untargeted():
	targeted_times -= 1
	if targeted_times <= 0:
		$HealthBarView/HealthBar.set_modulate(health_bar_modulate)

extends Node

var mouse_sensitivity = 2
var rng = RandomNumberGenerator.new()
const TURN_SPEED = 10

enum movement_states {
	MOVING,
	ATTACKING,
	HIT,
	DYING,
	BLOCKING,
	KNOCKBACK,
	KICKING,
	DODGING
}

enum interface_types {
	DIRECTION
}

enum roll_result_types {
	FAIL,
	SUCCESS,
	CRITICAL
}

# Called when the node enters the scene tree for the first time.
func _ready():
	rng.seed = hash("Splashy")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

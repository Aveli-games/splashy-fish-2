extends Control

signal actions_chosen
signal direction_chosen

var actions_left = 1
var action_queue = []
var prev_mouse_mode
var chosen_direction: Vector3

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_options(options: Array, num_actions: int):
	actions_left = num_actions
	$ActionOptions.set_options(options)
	$ActionOptions.show()

func _on_action_options_option_chosen(number: int, option: Dictionary):
	if option["data"] and option["data"]["type"] == Globals.interface_types.DIRECTION:
		show_direction_interface()
		await direction_chosen
		option["data"]["direction"] = chosen_direction
		$ActionOptions.show()
	action_queue.append(option)
	actions_left -= 1
	if actions_left <= 0:
		$ActionOptions.hide()
		actions_chosen.emit(action_queue)

func show_direction_interface():
	prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	Input.warp_mouse(Vector2(get_viewport().size.x / 2, 0))
	$DirectionInterface.show()
	$ActionOptions.hide()
	
func _on_direction_interface_direction_chosen(direction: Vector2):
	Input.mouse_mode = prev_mouse_mode
	# Adjust the resultant direction to account for the difference between 2D and 3D axes
	chosen_direction = Vector3(direction.x, 0, direction.y)
	$DirectionInterface.hide()
	direction_chosen.emit()

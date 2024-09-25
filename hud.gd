extends CanvasLayer

signal roll_finished
signal action_chosen
signal direction_chosen

var requester
var hud
var dice_roll_canvas
var prev_mouse_mode
var chosen_direction: Vector3

func _ready():
	dice_roll_canvas = $DiceRollCanvas
	dice_roll_canvas.hide()
	prev_mouse_mode = Input.mouse_mode

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_roll_finished(value):
	roll_finished.emit(value)
	
func show_dice_roll():
	dice_roll_canvas.show()

func hide_dice_roll():
	dice_roll_canvas.hide_roller()
	
func roll():
	dice_roll_canvas.roll()

func _on_action_options_option_chosen(number: int, option: Dictionary):
	$ActionOptions.hide()
	if option["data"] and option["data"]["type"] == Globals.interface_types.DIRECTION:
		show_direction_interface()
		await direction_chosen
		option["data"]["direction"] = chosen_direction
	action_chosen.emit(option)
	
func show_action_options(option_requester, options: Array):
	requester = option_requester
	$ActionOptions.set_options(options)
	$ActionOptions.show()

func show_direction_interface():
	prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	Input.warp_mouse(Vector2(get_viewport().size.x / 2, 0))
	$DirectionInterface.show()

func _on_direction_interface_direction_chosen(direction: Vector2):
	Input.mouse_mode = prev_mouse_mode
	# Adjust the resultant direction to account for the difference between 2D and 3D axes
	chosen_direction = Vector3(direction.x, 0, direction.y)
	$DirectionInterface.hide()
	direction_chosen.emit()
	

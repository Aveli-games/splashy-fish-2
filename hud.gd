extends CanvasLayer

signal roll_finished
signal actions_chosen

var requester
var hud
var dice_roll_canvas

func _ready():
	dice_roll_canvas = $DiceRollCanvas
	dice_roll_canvas.hide()
	$ControlsScreen.show()

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
	
func show_action_options(option_requester, options: Array, num_actions: int):
	requester = option_requester
	$ActionSelect.set_options(options, num_actions)
	
func _on_action_select_actions_chosen(action_queue: Array):
	actions_chosen.emit(action_queue)

func _on_controls_screen_exited():
	$ControlsScreen.hide()

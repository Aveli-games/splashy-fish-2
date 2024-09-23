extends CanvasLayer

signal roll_finished
signal action_chosen

var roll_requester
var hud
var dice_roll_canvas

func _ready():
	dice_roll_canvas = $DiceRollCanvas
	dice_roll_canvas.hide()

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

func _on_action_options_option_chosen(number: int, label: String):
	action_chosen.emit(number, label)
	$ActionOptions.hide()
	
func show_action_options(options: Dictionary):
	$ActionOptions.set_options(options)
	$ActionOptions.show()

extends CanvasLayer

signal roll_finished

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_dice_roll_viewport_roll_finished(value):
	roll_finished.emit(value)

func roll():
	$DiceRollViewport.roll()

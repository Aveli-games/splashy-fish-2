extends Node2D

signal roll_finished

var dice_roller

# Called when the node enters the scene tree for the first time.
func _ready():
	dice_roller = $DiceRollViewport

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_dice_roll_viewport_roll_finished(value):
	roll_finished.emit(value)

func roll():
	dice_roller.roll()
	
func hide_roller():
	hide()
	dice_roller.reset()
	

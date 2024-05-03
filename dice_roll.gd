extends Node3D

signal roll_finished(value: int)

var rolling = false
var num_dice = 0
var num_dice_finished = 0
var roll_result = 0

func roll():
	if not rolling:
		rolling = true
		for die in $Dice.get_children():
			num_dice += 1
			die.roll()
			
func reset():
	rolling = false
	num_dice = 0
	num_dice_finished = 0
	roll_result = 0

func _on_die_roll_finished(value):
	num_dice_finished += 1
	roll_result += value
	if num_dice_finished >= num_dice:
		roll_finished.emit(roll_result)
		reset()

extends SubViewport

signal roll_finished(value: int)

func _on_dice_roll_finished(value):
	$RollTextOverlay/RollResult.text = str(value)
	roll_finished.emit(value)
	
func roll():
	$RollTextOverlay/RollResult.text = ""
	$DiceRoll.roll()

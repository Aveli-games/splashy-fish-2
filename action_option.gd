extends HBoxContainer

signal chosen

var number: int
var label: String

func initialize(init_number: int, init_label: String):
	number = init_number
	label = init_label
	
	$Button.text = str(number)
	$OptionLabel.text = label

func _on_button_pressed():
	chosen.emit(number, label)

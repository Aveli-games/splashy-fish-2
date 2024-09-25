extends HBoxContainer

signal chosen

var number: int
var option: Dictionary

func initialize(init_number: int, init_option):
	number = init_number
	option = init_option
	
	$Button.text = str(number)
	$OptionLabel.text = option["name"]

func _on_button_pressed():
	chosen.emit(number, option)

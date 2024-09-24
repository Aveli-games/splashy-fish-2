extends HBoxContainer

signal chosen

var number: int
var label: String
var id: int
var data

func initialize(init_number: int, init_label: String, init_id: int, init_data):
	number = init_number
	label = init_label
	id = init_id
	data = init_data
	
	$Button.text = str(number)
	$OptionLabel.text = label

func _on_button_pressed():
	chosen.emit(number, id)

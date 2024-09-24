extends Control

signal option_chosen

var options_list

# Called when the node enters the scene tree for the first time.
func _ready():
	options_list = $ActionOptionsList
	options_list.clear()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_options(options: Array):
	options_list.clear()
	for option in options:
		options_list.add_option(option)

func _on_option_chosen(number: int, id: int, data):
	option_chosen.emit(number, id, data)

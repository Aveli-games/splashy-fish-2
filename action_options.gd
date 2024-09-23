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

func set_options(options: Dictionary):
	options_list.clear()
	for i in options.values().size():
		options_list.add_option(options.values()[i])

func _on_option_chosen(number: int, label: String):
	option_chosen.emit(number, label)

extends VBoxContainer

signal option_chosen

var option_item_scene: PackedScene

func _ready():
	option_item_scene = preload("res://GUI/action_option.tscn")
	clear()

func clear():
	for child in get_children():
		child.free()

func add_option(option: Dictionary):
	var item = option_item_scene.instantiate()
	item.initialize(get_children().size() + 1, option)
	add_child(item)
	item.chosen.connect(_on_option_chosen.bind())
	
func _on_option_chosen(number: int, option: Dictionary):
	option_chosen.emit(number, option)

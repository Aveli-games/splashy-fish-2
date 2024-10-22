extends Control

signal level_selected

@export var levels: Array[PackedScene]
@export var level_button_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	for level in levels:
		_add_level_button(level)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _add_level_button(level: PackedScene):
	var level_state = level.get_state()
	var level_name = ""
	for i in level_state.get_node_property_count(0):
		if level_state.get_node_property_name(0, i) == "level_name":
			level_name = level_state.get_node_property_value(0, i)
			break
	
	if level_name != "":
		var level_button = level_button_scene.instantiate()

		level_button.initialize(level_name, level)

		$MenuContent/MenuButtons.add_child(level_button)

		level_button.selected.connect(_on_level_button_selected.bind())
	else:
		print("Unable to create level: ", level)

func _on_level_button_selected(level_scene: PackedScene):
	level_selected.emit(level_scene)

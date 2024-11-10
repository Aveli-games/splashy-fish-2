extends PanelContainer

@export var value = 0
var label
var progress_bar
var has_text = false

# Called when the node enters the scene tree for the first time.
func _ready():
	label = $Label
	progress_bar = $ProgressBar
	
	initialize(value)

func initialize(new_value: int):
	progress_bar.max_value = new_value
	set_value(new_value)
	
func initialize_with_text(new_value: int, text: String):
	initialize(new_value)
	label.text = text
	has_text = true

func set_value(new_value: int):
	if not has_text:
		label.text = str(new_value)
	progress_bar.value = new_value
	
func set_bar_modulate(color: Color):
	progress_bar.modulate = color

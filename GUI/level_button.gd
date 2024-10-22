extends Button

signal selected

var level_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func initialize(level_name: String, level: PackedScene):
	text = level_name
	level_scene = level

func _on_pressed():
	selected.emit(level_scene)

extends CanvasLayer

signal roll_finished

@export var dice_roller_scene: PackedScene

var roll_requester
var hud
var dice_roll_canvas

func _ready():
	dice_roll_canvas = _spawn_dice_roll_canvas()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _spawn_dice_roll_canvas():
		var dice_roller = dice_roller_scene.instantiate()

		# Spawn the enemy by adding it to the Main scene.
		add_child(dice_roller)
		
		# We connect the enemy to the no target found signal so the level can assign the default
		dice_roller.roll_finished.connect(_on_roll_finished.bind())
		
		dice_roller.hide()
		
		return dice_roller

func _on_roll_finished(value):
	roll_finished.emit(value)
	
func show_dice_roll():
	dice_roll_canvas.show()

func hide_dice_roll():
	dice_roll_canvas.hide()
	
func roll():
	dice_roll_canvas.roll()

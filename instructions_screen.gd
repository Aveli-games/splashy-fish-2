extends Control

signal continue_pressed
signal shown

var prev_mouse_mode = Input.MOUSE_MODE_VISIBLE

var instructions = {
	"introduction": {"title": "Introduction", "text": "Welcome to Splashy Fish 2: Moonshine Madness! 

This tutorial will go through the game controls so you can play future levels knowing how everything works!

Splashy O'Feesh here can move, punch, and throw donuts. Let's get swingin'!"},

	"movement": {"title": "Movement", "text": "Moving the mouse around will rotate the camera.
	
Use WASD to make Splashy walk. The direction he walks will be relative to the direction the camera is facing.

Holding SHIFT will run, at the cost of stamina"},
	
	"melee": {"title": "Melee Attacking", "text": "Next is melee attacking.
	
All you need to do is get close enough to the enemy for them to highlight yellow, then LEFT-CLICK the mouse!

A dice roll will be made with 2-3 being failure, 4-9 success, 10-12 critical. I'll give you free hits for a bit!"},
	
	"hit_options": {"title": "Melee Hit Options", "text": "Before a punch resolves, you get to choose follow-up actions! 1 action for success, 2 actions for a critical. 

- Block negates all enemy attacks for 2 seconds
- Recover Stamina refills stamina by 40%
- Combo automatically punches an extra in-range enemy
- Dodge lets you choose a direction to roll with invulnerability"},
	
	"melee_failure": {"title": "Melee Failure", "text": "On a melee failure, enemies will kick you!
	
This usually staggers you and lowers STAMINA, but if you don't have enough stamina, it will deal unavoidable DAMAGE!"},
	
	"ranged": {"title": "Ranged Attacking", "text": "Lastly, you can chuck donuts at far away enemies!
	
If you have donuts (I'll give you one), you can hold RIGHT-CLICK to aim your throw. Back up and give it a try.

When the + reticle turns RED, that means you can throw a homing donut at that enemy by LEFT-CLICKING."},
	
	"end": {"title": "Wrap Up", "text": "That's about it, thanks for playing the tutorial!
	
In future levels, all you have to do is defeat all the cats that try to smash your still. 

Have fun!"}
}

# Called when the node enters the scene tree for the first time.
func _ready():
	_set_instruction_text(instructions["introduction"])

func _set_instruction_text(instruction: Dictionary):
	$VBoxContainer/HBoxContainer/Title.text = instruction["title"]
	$VBoxContainer/SpeechBox.text = instruction["text"]
	
func show_intro():
	_set_instruction_text(instructions["introduction"])
	show_self()
	
func show_movement():
	_set_instruction_text(instructions["movement"])
	show_self()
	
func show_melee():
	_set_instruction_text(instructions["melee"])
	show_self()
	
func show_hit_options():
	_set_instruction_text(instructions["hit_options"])
	show_self()
	
func show_melee_failure():
	_set_instruction_text(instructions["melee_failure"])
	show_self()
	
func show_ranged():
	_set_instruction_text(instructions["ranged"])
	show_self()
	
func show_end():
	_set_instruction_text(instructions["end"])
	show_self()

func show_self():
	show()
	shown.emit()

func _on_continue_button_pressed():
	hide()
	continue_pressed.emit($VBoxContainer/HBoxContainer/Title.text)

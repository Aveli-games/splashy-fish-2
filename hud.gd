extends CanvasLayer

signal roll_finished
signal actions_chosen
signal play_pressed
signal restart_pressed
signal quit_pressed

var requester
var hud
var dice_roll_canvas

func _ready():
	dice_roll_canvas = $DiceRollCanvas
	dice_roll_canvas.hide()
	show_main_menu()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_roll_finished(value):
	roll_finished.emit(value)
	
func hide_menus():
	hide_dice_roll()
	hide_action_select()
	hide_menu_screens()
	
func show_dice_roll():
	dice_roll_canvas.show()

func hide_dice_roll():
	dice_roll_canvas.hide_roller()

func show_action_select():
	$ActionSelect.show()

func hide_action_select():
	$ActionSelect.hide()
	
func roll():
	dice_roll_canvas.roll()
	
func show_action_options(option_requester, options: Array, num_actions: int):
	requester = option_requester
	show_action_select()
	$ActionSelect.set_options(options, num_actions)
	
func _on_action_select_actions_chosen(action_queue: Array):
	actions_chosen.emit(action_queue)

func _clear_menu():
	for child in $MenuScreens.get_children():
		if child != $MenuScreens/MenuBackGround:
			child.hide()

func show_menu_screens():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$MenuScreens.show()

func hide_menu_screens():
	$MenuScreens.hide()

func _on_controls_screen_exited():
	show_main_menu()
	
func _show_controls():
	_clear_menu()
	show_menu_screens()
	$MenuScreens/ControlsScreen.show()
	
func _hide_controls():
	$MenuScreens/ControlsScreen.hide()
	hide_menu_screens()
	
func show_main_menu():
	_clear_menu()
	show_menu_screens()
	$MenuScreens/MainMenu.show()

func hide_main_menu():
	$MenuScreens/MainMenu.hide()
	hide_menu_screens()

func _on_game_menu_button_pressed(type: String):
	match type:
		"Play":
			play_pressed.emit()
		"Restart":
			restart_pressed.emit()
		"Controls":
			_show_controls()
		"Quit":
			quit_pressed.emit()

extends Control

signal direction_chosen

@export var bg_color: Color
@export var outer_radius: float

var direction_selector: Marker2D
var center: Marker2D
var direction_vector: Vector2
var viewport_size: Vector2

func _ready():
	outer_radius = size.x/2
	direction_selector = $DirectionSelector
	center = $Center
	center.position.x += size.x/2
	center.position.y += size.y/2

func _draw():
	draw_circle(center.position, outer_radius, bg_color)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if visible:
		direction_vector = (get_viewport().get_mouse_position() - center.global_position).normalized()
		direction_selector.global_position = center.global_position + (direction_vector.normalized() * outer_radius)
		direction_selector.look_at(center.global_position)

func _input(event):
	if visible and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				direction_chosen.emit(direction_vector)

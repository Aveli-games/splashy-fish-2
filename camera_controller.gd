extends Marker3D

@export var sensitivity := 5

func _input(event):
	if event is InputEventMouseMotion:
		rotate_x(event.relative.y / 1000 * sensitivity)

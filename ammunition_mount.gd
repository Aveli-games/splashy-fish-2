extends Node3D

signal ammo_depleted

@export var ammo_scene: PackedScene

@export var cur_ammo = 6
var cur_slot: Node3D
var ammo_slots: Array[Node]

# Called when the node enters the scene tree for the first time.
func _ready():
	ammo_slots = get_children()
	set_ammo(cur_ammo)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func use_ammo():
	if cur_ammo > 0:
		if cur_ammo <= ammo_slots.size():
			for child in cur_slot.get_children():
				child.free()
			var new_slot_index = ammo_slots.find(cur_slot) - 1
			if new_slot_index >= 0:
				cur_slot = ammo_slots[new_slot_index]
		
		cur_ammo -= 1
	
	if cur_ammo <= 0:
		ammo_depleted.emit()

func set_ammo(number: int):
	cur_ammo = number
	for slot in ammo_slots:
		if number <= 0:
			for child in slot.get_children():
				child.free()
		else:
			if slot.get_children().size() <= 0:
				var new_ammo = ammo_scene.instantiate()
				new_ammo.global_position = slot.global_position
				slot.add_child(new_ammo)
				
			number -= 1
			if number == 0:
				cur_slot = slot

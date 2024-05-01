extends Node3D

func roll():
	for die in $Dice.get_children():
		die.roll()

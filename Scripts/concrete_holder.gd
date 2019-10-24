extends Node2D


var concrete_pieces = []
var width = 8
var height = 10
var concrete = preload("res://Scenes/concrete.tscn")

signal remove_concrete

func _ready():
	pass


func make_2d_array():
	var array = []
	
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	
	return array


func _on_Grid_make_concrete(board_position):
	var current
	
	if concrete_pieces.size() == 0:
		concrete_pieces = make_2d_array()
	
	current = concrete.instance()
	add_child(current)
	current.position = Vector2(board_position.x * 64 + 64, -board_position.y * 64 + 800)
	concrete_pieces[board_position.x][board_position.y] = current


func _on_Grid_damage_concrete(board_position):
	if concrete_pieces[board_position.x][board_position.y]:
		concrete_pieces[board_position.x][board_position.y].take_damage(1)
		if concrete_pieces[board_position.x][board_position.y].health <= 0:
			concrete_pieces[board_position.x][board_position.y].queue_free()
			concrete_pieces[board_position.x][board_position.y] = null
			emit_signal("remove_concrete", board_position)

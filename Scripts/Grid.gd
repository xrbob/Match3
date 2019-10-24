extends Node2D

export (int) var width
export (int) var height
export (int) var x_start
export (int) var y_start
export (int) var offset

# Obstacle variables
export (PoolVector2Array) var empty_spaces
export (PoolVector2Array) var ice_spaces
export (PoolVector2Array) var lock_spaces
export (PoolVector2Array) var concrete_spaces
export (PoolVector2Array) var slime_spaces

var damaged_slime = false

signal make_ice
signal damage_ice
signal make_locks
signal damage_locks
signal make_concrete
signal damage_concrete
signal make_slime
signal damage_slime


enum {
	wait,
	move
}

var state

var possible_pieces = [
	preload("res://Scenes/Yellow_Piece.tscn"),
	preload("res://Scenes/Blue_Piece.tscn"),
	preload("res://Scenes/Green_Piece.tscn"),
	preload("res://Scenes/Orange_Piece.tscn"),
	preload("res://Scenes/Pink_Piece.tscn"),
	preload("res://Scenes/Light_Green_Piece.tscn")
]

var all_pieces  = []
var current_matches = []

var piece_one = null
var piece_two = null
var last_place = Vector2(0, 0)
var last_direction = Vector2(0, 0)
var move_checked = false

# Touch variables
var first_touch = Vector2(0, 0)
var final_touch = Vector2(0, 0)
var controlling = false

func _ready():
	randomize()
	all_pieces = make_2d_array()
	
	state = move
	get_parent().get_node("start_timer").start()


func make_2d_array():
	var array = []
	
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	
	return array


func spawn_pieces():
	for i in width:
		for j in height:
			if !(Vector2(i, j) in empty_spaces):
				var rand = floor(rand_range(0, possible_pieces.size()))
				var piece = possible_pieces[rand].instance()
				var loops = 0
				
				while(match_at(i, j, piece.colour) && loops < 100):
					rand = floor(rand_range(0, possible_pieces.size()))
					loops += 1
					piece = possible_pieces[rand].instance()
				
				add_child(piece)
				piece.position = grid_to_pixel(i, height + 2) ## draw the piece at this position on screen
				piece.move(grid_to_pixel(i, j))
				all_pieces[i][j] = piece             ## put the piece in the array logically, so we can reference it for matches later
	
	spawn_ice()
	spawn_locks()
	spawn_concrete()
	spawn_slime()


func spawn_concrete():
	for space in concrete_spaces.size():
		emit_signal("make_concrete", concrete_spaces[space])


func spawn_ice():
	for space in ice_spaces.size():
		emit_signal("make_ice", ice_spaces[space])


func spawn_locks():
	for space in lock_spaces.size():
		emit_signal("make_locks", lock_spaces[space])


func spawn_slime():
	for space in slime_spaces.size():
		emit_signal("make_slime", slime_spaces[space])


func match_at(column, row, colour):
	if column > 1:
		if all_pieces[column - 1][row] != null && all_pieces[column - 2][row] != null:
			if all_pieces[column - 1][row].colour == colour && all_pieces[column - 2][row].colour == colour:
				return true
	if row > 1:
		if all_pieces[column][row - 1] != null && all_pieces[column][row - 2] != null:
			if all_pieces[column][row - 1].colour == colour && all_pieces[column][row - 2].colour == colour:
				return true


func find_matches():
	var current_colour
	
	for column in width:
		for row in height:
			if all_pieces[column][row] != null:
				current_colour = all_pieces[column][row].colour
				if column > 0 && column < width - 1:
					if all_pieces[column - 1][row] != null && all_pieces[column + 1][row] != null:
						if all_pieces[column - 1][row].colour == current_colour && all_pieces[column + 1][row].colour == current_colour:
							all_pieces[column - 1][row].matched()
							all_pieces[column][row].matched()
							all_pieces[column + 1][row].matched()
							add_to_array(Vector2(column - 1, row), current_matches)
							add_to_array(Vector2(column, row), current_matches)
							add_to_array(Vector2(column + 1, row), current_matches)
				if row > 0 && row < height - 1:
					if all_pieces[column][row - 1] != null && all_pieces[column][row + 1] != null:
						if all_pieces[column][row - 1].colour == current_colour && all_pieces[column][row + 1].colour == current_colour:
							all_pieces[column][row - 1].matched()
							all_pieces[column][row].matched()
							all_pieces[column][row + 1].matched()
							add_to_array(Vector2(column, row - 1), current_matches)
							add_to_array(Vector2(column, row), current_matches)
							add_to_array(Vector2(column, row + 1), current_matches)

	get_parent().get_node("destroy_timer").start()


func add_to_array(value, array = current_matches):
	if !array.has(value):
		array.append(value)


func find_bombs():
	for i in current_matches.size():
		var current_column = current_matches[i].x
		var current_row    = current_matches[i].y
		var current_colour = all_pieces[current_column][current_row].colour
		var col_matched = 0
		var row_matched = 0
		
		for j in current_matches.size():
			var this_column = current_matches[j].x
			var this_row    = current_matches[j].y
			var this_colour = all_pieces[this_column][this_row].colour
			if this_column == current_column and this_colour == current_colour:
				col_matched += 1
			if this_row == current_row and this_colour == current_colour:
				row_matched += 1
		
		if col_matched == 5 or row_matched == 5:
			print("Colour Bomb")
			return
		if col_matched == 3 and row_matched == 3:
			make_bomb(0, current_colour)
			return
		if col_matched == 4:
			make_bomb(1, current_colour)
			return
		if row_matched == 4:
			make_bomb(2, current_colour)
			return


func destroy_matched_pieces():
	var was_matched = false
	
	find_bombs()
	
	for column in width:
		for row in height:
			if all_pieces[column][row] != null:
				if all_pieces[column][row].matched:
					damage_special(column, row)
					all_pieces[column][row].queue_free()
					all_pieces[column][row] = null
					was_matched = true
	
	move_checked = true
	if was_matched:
		get_parent().get_node("collapse_timer").start()
	else:
		swap_back()
	
	current_matches.clear()


func check_concrete(column, row):
	if column < width - 1:
		emit_signal("damage_concrete", Vector2(column + 1, row))
	if column > 0:
		emit_signal("damage_concrete", Vector2(column - 1, row))
	if row < height - 1:
		emit_signal("damage_concrete", Vector2(column, row + 1))
	if row > 0:
		emit_signal("damage_concrete", Vector2(column, row - 1))


func check_slime(column, row):
	if column < width - 1:
		emit_signal("damage_slime", Vector2(column + 1, row))
	if column > 0:
		emit_signal("damage_slime", Vector2(column - 1, row))
	if row < height - 1:
		emit_signal("damage_slime", Vector2(column, row + 1))
	if row > 0:
		emit_signal("damage_slime", Vector2(column, row - 1))
		

func damage_special(col, row):
	emit_signal("damage_ice", Vector2(col, row))
	emit_signal("damage_locks", Vector2(col, row))
	emit_signal("damage_concrete", Vector2(col, row))
	check_slime(col, row)
	check_concrete(col, row)


func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x, new_y)


func pixel_to_grid(pixel_x, pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	
	return Vector2(new_x, new_y)


func touch_input():
	if Input.is_action_just_pressed("ui_touch"):
		if is_in_grid(pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)):
			controlling = true
			first_touch = get_global_mouse_position()
			
	if Input.is_action_just_released("ui_touch"):
		if is_in_grid(pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)):
			final_touch = get_global_mouse_position()
			touch_difference(pixel_to_grid(first_touch.x, first_touch.y), pixel_to_grid(final_touch.x, final_touch.y))
			
		controlling = false


func swap_pieces(column, row, direction):
	var first_piece = all_pieces[column][row]
	var other_piece = all_pieces[column + direction.x][row + direction.y]
	
	if first_piece != null && other_piece != null && !restricted_move(Vector2(column, row)) && !restricted_move(Vector2(column, row) + direction):
		piece_one = first_piece
		piece_two = other_piece
		last_place = Vector2(column, row)
		last_direction = direction
		state = wait
		all_pieces[column][row] = other_piece
		all_pieces[column + direction.x][row + direction.y] = first_piece
		
		first_piece.move(grid_to_pixel(column + direction.x, row + direction.y))
		other_piece.move(grid_to_pixel(column, row))
	
		if !move_checked:
			find_matches()


func restricted_fill(place):
	if is_in_array(empty_spaces, place):
		return true
	if is_in_array(concrete_spaces, place):
		return true
	if is_in_array(slime_spaces, place):
		return true
	return false

func restricted_move(place):
	if is_in_array(lock_spaces, place):
		return true
	if is_in_array(concrete_spaces, place):
		return true
	if is_in_array(slime_spaces, place):
		return true
	return false
	

func is_in_array(array, item):
	for i in array.size():
		if array[i] == item:
			return true
	return false


func remove_from_array(array, item):
	for i in range(array.size() - 1, -1, -1):
		if array[i] == item:
			array.remove(i)
	return array


func swap_back():
	if piece_one != null && piece_two != null:
		swap_pieces(last_place.x, last_place.y, last_direction)
	state = move
	move_checked = false


func touch_difference(grid_touch, grid_release):
	var difference = grid_release - grid_touch
	var direction = Vector2(0, 0)
	
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			direction = Vector2(1, 0)
		elif difference.x < 0:
			direction = Vector2(-1, 0)
	elif abs(difference.x) < abs(difference.y):
		if difference.y > 0:
			direction = Vector2(0, 1)
		elif difference.y < 0:
			direction = Vector2(0, -1)
	
	swap_pieces(grid_touch.x, grid_touch.y, direction)


func is_in_grid(grid_position):
	if grid_position.x >= 0 && grid_position.x < width:
		if grid_position.y >= 0 && grid_position.y < height:
			return true
	return false


func collapse_columns():
	
	#Collapse
	for column in width:
		for row in height:
			if all_pieces[column][row] == null && !restricted_fill(Vector2(column, row)):
				for piece_above in range(row + 1, height):
					if all_pieces[column][piece_above] != null:
						all_pieces[column][piece_above].move(grid_to_pixel(column, row))
						all_pieces[column][row] = all_pieces[column][piece_above]
						all_pieces[column][piece_above] = null
						break
	
	# Now refill
	for column in width:
		for row in height:
			if all_pieces[column][row] == null && !restricted_fill(Vector2(column, row)):
				var rand = floor(rand_range(0, possible_pieces.size()))
				var piece = possible_pieces[rand].instance()
				add_child(piece)
				piece.position = grid_to_pixel(column, height)
				piece.move(grid_to_pixel(column, row))
				all_pieces[column][row] = piece 
	
	after_refill()
	

# warning-ignore:unused_argument
func _process(delta):
	if state == move:
		touch_input()


func _on_destroy_timer_timeout():
	destroy_matched_pieces()


func after_refill():
	for col in width:
		for row in height:
			if all_pieces[col][row] != null:
				if match_at(col, row, all_pieces[col][row].colour):
					find_matches()
					get_parent().get_node("destroy_timer").start()
					return
					
	if !damaged_slime:
		generate_slime()
	state = move
	move_checked = false
	damaged_slime = false


func generate_slime():
	randomize()
	if slime_spaces.size() > 0:
		var slime_made = false
		var tracker = 0
		while !slime_made and tracker < 100:
			var random_num = floor(rand_range(0, slime_spaces.size()))
			var neighbour = find_normal_neighbour(slime_spaces[random_num].x, slime_spaces[random_num].y)
			
			if neighbour != null && !(neighbour in slime_spaces):
				all_pieces[neighbour.x][neighbour.y].queue_free()
				all_pieces[neighbour.x][neighbour.y] = null
				slime_spaces.append(Vector2(neighbour.x, neighbour.y))
				emit_signal("make_slime", Vector2(neighbour.x, neighbour.y))
				slime_made = true
				
			tracker += 1


func find_normal_neighbour(col, row):
	var neighbours = []
	randomize()
	
	# Check Right
	if is_in_grid(Vector2(col + 1, row)):
		if all_pieces[col + 1][row] != null:
			neighbours.append(Vector2(col + 1, row))
	# Check Down
	if is_in_grid(Vector2(col, row - 1)):
		if all_pieces[col][row - 1] != null:
			neighbours.append(Vector2(col, row - 1))
	# Check Left
	if is_in_grid(Vector2(col - 1, row)):
		if all_pieces[col - 1][row] != null:
			neighbours.append(Vector2(col - 1, row))
	# Check Up
	if is_in_grid(Vector2(col, row + 1)):
		if all_pieces[col][row + 1] != null:
			neighbours.append(Vector2(col, row + 1))
	
	if neighbours.size() > 0:
		return neighbours[floor(rand_range(0, neighbours.size()))]
	else:
		return null


func make_bomb(bomb_type, colour):
	for i in current_matches.size():
		var col = current_matches[i].x
		var row = current_matches[i].y
		if all_pieces[col][row] == piece_one and piece_one.colour == colour:
			piece_one.matched = false
			change_bomb(bomb_type, piece_one)
		if all_pieces[col][row] == piece_two and piece_two.colour == colour:
			piece_two.matched = false
			change_bomb(bomb_type, piece_two)


func change_bomb(bomb_type, piece):
	if bomb_type == 0:
		piece.make_adj_bomb()
	elif bomb_type == 1:
		piece.make_col_bomb()
	elif bomb_type == 2:
		piece.make_row_bomb()


func _on_collapse_timer_timeout():
	collapse_columns()


func _on_lock_holder_remove_lock(place):
	lock_spaces = remove_from_array(lock_spaces, place)


func _on_concrete_holder_remove_concrete(place):
	concrete_spaces = remove_from_array(concrete_spaces, place)


func _on_slime_holder_remove_slime(place):
	damaged_slime = true
	slime_spaces = remove_from_array(slime_spaces, place)

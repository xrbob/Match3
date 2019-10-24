extends Node2D

export (String) var colour
export (Texture) var row_texture
export (Texture) var col_texture
export (Texture) var adj_texture

var is_row_bomb = false
var is_col_bomb = false
var is_adj_bomb = false

var move_tween
var matched = false


func _ready():
	move_tween = $move_tween
	

func _process(delta):
	pass


func matched():
	matched = true
	dim()
	

func dim():
	$Sprite.modulate = Color(1, 1, 1, 0.5)
	

func move(target):
	move_tween.interpolate_property(self, "position", position, target, 0.6, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	move_tween.start()


func make_col_bomb():
	is_col_bomb = true
	$Sprite.texture = col_texture
	$Sprite.modulate = Color(1, 1, 1, 1)


func make_row_bomb():
	is_row_bomb = true
	$Sprite.texture = row_texture
	$Sprite.modulate = Color(1, 1, 1, 1)


func make_adj_bomb():
	is_adj_bomb = true
	$Sprite.texture = adj_texture
	$Sprite.modulate = Color(1, 1, 1, 1)
extends Car

@export var MOVE_TIME := 0.06
@export var slow_mult := 1.5

var home_cell := Vector2i.ZERO
var chasing := false


func setup(main_node: Node2D, start_cell: Vector2i) -> void:
	super.setup(main_node, start_cell)
	home_cell = start_cell
	chasing = false


func _process(_delta: float) -> void:
	if moving or grid == null or grid.game_over:
		return

	var target: Vector2i = grid.player.cell if chasing else home_cell
	# defaite du joueur
	if cell == target:
		return

	var path: Array[Vector2i] = grid.find_path(cell, target, chasing and not grid.hint_active)
	if path.size() > 1:
		step(path[1] - cell, MOVE_TIME, slow_mult)

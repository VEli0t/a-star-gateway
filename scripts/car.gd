class_name Car
extends Node2D

signal moved(new_cell: Vector2i)

var cell := Vector2i.ZERO
var moving := false
var grid: Node2D


func setup(main_node: Node2D, start_cell: Vector2i) -> void:
	grid = main_node
	cell = start_cell
	position = grid.cell_to_pixel(cell)
	moving = false


func step(direction: Vector2i, base_time: float, slow_mult := 1.0) -> void:
	var target := cell + direction
	if not grid.is_road(target):
		return
	cell = target
	moving = true

	var cost: float = grid.get_cost(cell)
	var duration: float = base_time * (cost * slow_mult if cost > 1.0 else 1.0)
	var start_angle := rotation
	var target_angle := Vector2(direction).angle() + PI / 2.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", grid.cell_to_pixel(cell), duration)
	tween.tween_method(func(t: float): rotation = lerp_angle(start_angle, target_angle, t), 0.0, 1.0, duration * 0.6)
	tween.chain().tween_callback(func():
		moving = false
		moved.emit(cell)
	)

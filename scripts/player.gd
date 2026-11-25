extends Car

const MOVE_TIME := 0.05


func _process(_delta: float) -> void:
	if moving or grid == null or grid.game_over:
		return

	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"): dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): dir = Vector2i.RIGHT

	if dir != Vector2i.ZERO:
		step(dir, MOVE_TIME)

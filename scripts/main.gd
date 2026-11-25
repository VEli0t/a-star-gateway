extends Node2D

@export var TARGET_DELIVERIES := 5
@export var max_hints := 3

@onready var layer: TileMapLayer = $TileMapLayer
@onready var spawn: Node2D = $Spawn
@onready var police_spawn: Node2D = $PoliceSpawn
@onready var player: Car = $Player
@onready var enemy: Car = $Enemy
@onready var hud_label: Label = $CanvasLayer/HudLabel

const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

# Base pour l'implementation du FSM dans le prochain update du jeu
enum State { PICKUP, DROPOFF }

var road: Dictionary = {}
var state := State.PICKUP
var target_cell := Vector2i(-1, -1)
var deliveries := 0
var hint_active := false
var debug_mode := true
var game_over := false
var victory := false
var hints_left : int

var current_path: Array[Vector2i] = []
var explored_nodes: Array[Vector2i] = []


func _ready() -> void:
	randomize()
	for tile in layer.get_used_cells():
		var data := layer.get_cell_tile_data(tile)
		if data and data.get_custom_data("is_road"):
			var c: float = data.get_custom_data("cost")
			road[tile] = c if c > 0.0 else 1.0

	player.moved.connect(_on_player_moved)
	enemy.moved.connect(_on_enemy_moved)
	reset_game()


func reset_game() -> void:
	deliveries = 0
	hints_left = max_hints
	game_over = false
	victory = false
	player.setup(self, layer.local_to_map(layer.to_local(spawn.global_position)))
	enemy.setup(self, layer.local_to_map(layer.to_local(police_spawn.global_position)))
	start_phase(State.PICKUP)


func is_road(cell: Vector2i) -> bool: return road.has(cell)
func get_cost(cell: Vector2i) -> float: return road.get(cell, INF)
func cell_to_pixel(cell: Vector2i) -> Vector2: return to_local(layer.to_global(layer.map_to_local(cell)))


func start_phase(new_state: State) -> void:
	state = new_state
	enemy.chasing = (state == State.DROPOFF)
	var candidates := road.keys().filter(func(c): return c != player.cell and c != enemy.cell and c != target_cell)
	target_cell = player.cell if candidates.is_empty() else candidates.pick_random()
	hint_active = false
	current_path.clear()
	explored_nodes.clear()
	refresh()


func end_game(has_won: bool) -> void:
	game_over = true
	victory = has_won
	enemy.chasing = false
	refresh()


func _on_player_moved(new_cell: Vector2i) -> void:
	if game_over:
		return
	if state == State.DROPOFF and new_cell == enemy.cell:
		end_game(false)
	elif new_cell == target_cell:
		if state == State.PICKUP:
			start_phase(State.DROPOFF)
		elif deliveries + 1 >= TARGET_DELIVERIES:
			deliveries += 1
			end_game(true)
		else:
			deliveries += 1
			start_phase(State.PICKUP)
	else:
		if hint_active:
			current_path = find_path(player.cell, target_cell, true)
		refresh()


func _on_enemy_moved(new_cell: Vector2i) -> void:
	if not game_over and state == State.DROPOFF and new_cell == player.cell:
		end_game(false)
	else:
		refresh()


# Algorithme A*
func heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))


func find_path(start: Vector2i, goal: Vector2i, record_debug := false) -> Array[Vector2i]:
	# initialisation et securite
	if record_debug:
		explored_nodes.clear()
	if not is_road(start) or not is_road(goal):
		return []

	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	
	# Selection meilleur noeud
	while not open_set.is_empty():
		var current := open_set[0]
		var best_f: float = g_score[current] + heuristic(current, goal)
		for node in open_set:
			var f: float = g_score[node] + heuristic(node, goal)
			if f < best_f:
				best_f = f
				current = node

		if current == goal:
			var path: Array[Vector2i] = [current]
			while came_from.has(current):
				current = came_from[current]
				path.push_front(current)
			if record_debug:
				current_path = path
			return path

		open_set.erase(current)
		if record_debug:
			explored_nodes.append(current)

		for dir in DIRS:
			var neighbor: Vector2i = current + dir
			if not is_road(neighbor):
				continue
			var tentative_g: float = g_score[current] + get_cost(neighbor)
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				if not open_set.has(neighbor):
					open_set.append(neighbor)

	return []


# Controles et Affichage
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and game_over:
			reset_game()
		elif not game_over and event.keycode == KEY_SPACE and not hint_active and hints_left > 0:
			hints_left -= 1
			hint_active = true
			current_path = find_path(player.cell, target_cell, true)
			refresh()
		elif event.keycode == KEY_V:
			debug_mode = not debug_mode
			queue_redraw()


func refresh() -> void:
	if game_over:
		hud_label.text = "VICTOIRE ! \n5 braquages réussis \n(Appuie sur R pour restart)" if victory else "ARRÊTÉ PAR LA POLICE ! \n(Appuie sur R pour restart)"
	else:
		var status := "Va chercher le braqueur (Jaune)" if state == State.PICKUP else "POURSUITE EN COURS ! Fuis vers la planque (Vert)"
		hud_label.text = "Braquages : %d/%d  \nIndices [Espace] : %d  \nIA : A* (Explorés : %d)\n%s" % [
			deliveries, TARGET_DELIVERIES, hints_left, explored_nodes.size(), status
		]
	queue_redraw()


func _draw() -> void:
	var s := float(layer.tile_set.tile_size.x)
	var half := Vector2(s, s) * 0.5

	if debug_mode and (hint_active or state == State.DROPOFF):
		var area_col := Color(0.2, 0.6, 1.0, 0.28) if hint_active else Color(1.0, 0.2, 0.2, 0.22)
		var line_col := Color(0.1, 0.85, 1.0, 0.85) if hint_active else Color(1.0, 0.3, 0.3, 0.7)
		for cell in explored_nodes:
			draw_rect(Rect2(cell_to_pixel(cell) - half, Vector2(s, s)), area_col)
		if current_path.size() > 1:
			draw_polyline(PackedVector2Array(current_path.map(cell_to_pixel)), line_col, s * 0.2)

	if not game_over and is_road(target_cell):
		var target_col := Color(1.0, 0.75, 0.0, 0.95) if state == State.PICKUP else Color(0.1, 0.9, 0.3, 0.95)
		draw_circle(cell_to_pixel(target_cell), s * 0.38, target_col)

	if hint_active and current_path.size() > 1:
		var from_px := cell_to_pixel(current_path[0])
		var dir := (cell_to_pixel(current_path[1]) - from_px).normalized()
		var tip := from_px + dir * (s * 0.75)
		var perp := Vector2(-dir.y, dir.x) * (s * 0.25)
		draw_line(from_px, tip, Color(0.1, 0.9, 1.0, 1.0), s * 0.2)
		draw_colored_polygon(PackedVector2Array([tip + dir * (s * 0.25), tip - dir * (s * 0.15) + perp, tip - dir * (s * 0.15) - perp]), Color(0.1, 0.9, 1.0, 1.0))

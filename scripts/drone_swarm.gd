class_name DroneSwarm
extends Node2D

@export var drone_scene: PackedScene
@export var drone_count: int = 4
@export var area_bounds: Rect2 = Rect2(0, 0, 800, 440)

var _drones: Array[Drone] = []

func _ready() -> void:
	if not drone_scene:
		push_warning("DroneSwarm : Aucune drone_scene assignée !")
		return
		
	for i in range(drone_count):
		var drone := drone_scene.instantiate() as Drone
		add_child(drone)
		drone.global_position = Vector2(
			randf_range(area_bounds.position.x + 50, area_bounds.end.x - 50),
			randf_range(area_bounds.position.y + 50, area_bounds.end.y - 50)
		)
		_drones.append(drone)

func _physics_process(delta: float) -> void:
	for drone in _drones:
		drone.update_boid(_drones, area_bounds, delta)

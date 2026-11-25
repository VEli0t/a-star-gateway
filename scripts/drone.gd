class_name Drone
extends Node2D

@export_group("Mouvement")
@export var max_speed: float = 250.0
@export var rotation_speed: float = 10.0
@export var max_tilt_degrees: float = 15.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export_group("Règles Boids")
@export var perception_radius: float = 200.0
@export var min_distance: float = 35.0
@export var cohesion_factor: float = 1.0
@export var alignment_factor: float = 1.0
@export var separation_factor: float = 1.0
@export var chase_factor: float = 15.0
@export var hover_height: float = 70.0

enum States {WANDERING, CHASING}

var state: States = States.WANDERING
var velocity: Vector2 = Vector2.ZERO
var target: Node2D = null # Référence vers le joueur détecté

func _ready() -> void:
	velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * (max_speed * 0.5)
	sprite.play("walk_scan")
	$Area2D.connect("area_shape_entered", chasing)

func update_boid(all_drones: Array[Drone], bounds: Rect2, delta: float) -> void:
	var close_boids: Array[Drone] = []
	
	for other in all_drones:
		if other == self:
			continue
		if global_position.distance_to(other.global_position) < perception_radius:
			close_boids.append(other)
	
	match state:
		States.WANDERING:
			if close_boids.size() > 0:
				_move_closer(close_boids)
				_move_with(close_boids)
				_move_away(close_boids)
			_keep_within_bounds(bounds)
			
		States.CHASING:
			if is_instance_valid(target):
				_chase_target()
				if close_boids.size() > 0:
					_move_away(close_boids)
					_alert_nearby_drones(close_boids)
			else:
				state = States.WANDERING
	_move(delta)
	
func _move_closer(boids: Array[Drone]) -> void:
	var avg_diff := Vector2.ZERO
	for boid in boids:
		avg_diff += (global_position - boid.global_position)
	
	avg_diff /= boids.size()
	velocity -= (avg_diff / 100.0) * cohesion_factor

func _move_with(boids: Array[Drone]) -> void:
	var avg_vel := Vector2.ZERO
	for boid in boids:
		avg_vel += boid.velocity
		
	avg_vel /= boids.size()
	velocity += (avg_vel / 40.0) * alignment_factor

func _move_away(boids: Array[Drone]) -> void:
	var distance_vec := Vector2.ZERO
	var num_close := 0
	
	for boid in boids:
		var dist := global_position.distance_to(boid.global_position)
		if dist < min_distance and dist > 0.0:
			num_close += 1
			var diff := global_position - boid.global_position
			var repulse := diff.normalized() * (min_distance - dist)
			distance_vec += repulse
			
	if num_close > 0:
		velocity += (distance_vec / 5.0) * separation_factor

func _chase_target() -> void:
	var target_pos := target.global_position - Vector2(0, hover_height)
	var direction := (target_pos - global_position).normalized()
	velocity += direction * chase_factor
	
func _keep_within_bounds(bounds: Rect2) -> void:
	var margin := 50.0
	if global_position.x < bounds.position.x + margin and velocity.x < 0:
		velocity.x = -velocity.x * randf_range(0.5, 1.0)
	elif global_position.x > bounds.end.x - margin and velocity.x > 0:
		velocity.x = -velocity.x * randf_range(0.5, 1.0)
		
	if global_position.y < bounds.position.y + margin and velocity.y < 0:
		velocity.y = -velocity.y * randf_range(0.5, 1.0)
	elif global_position.y > bounds.end.y - margin and velocity.y > 0:
		velocity.y = -velocity.y * randf_range(0.5, 1.0)

func _move(delta: float) -> void:
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
		
	global_position += velocity * delta
	
	if abs(velocity.x) > 5.0:
		sprite.flip_h = velocity.x < 0
		
	var target_tilt := deg_to_rad(max_tilt_degrees) * (velocity.x / max_speed)
	rotation = lerp_angle(rotation, target_tilt, rotation_speed * delta)

# Signal function
func chasing(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if area.get_parent().is_in_group("player"):
		target = area.get_parent()
		state = States.CHASING
		

# Propagation function
func _alert_nearby_drones(boids: Array[Drone]) -> void:
	for boid in boids:
		if boid.state == States.WANDERING:
			boid.receive_alert(target)

func receive_alert(new_target: Node2D) -> void:
	target = new_target
	state = States.CHASING

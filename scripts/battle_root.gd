extends Node2D

signal enemy_turn_started

@export var sphere_paths: Array[NodePath] = [
	NodePath("Sphere1"),
	NodePath("Sphere2"),
	NodePath("Sphere3")
]

var spheres: Array[RigidBody2D] = []
var launched_count: int = 0


func _ready() -> void:
	for sphere_path: NodePath in sphere_paths:
		if not has_node(sphere_path):
			continue
		var sphere: RigidBody2D = get_node(sphere_path) as RigidBody2D
		if sphere == null:
			continue
		spheres.append(sphere)
		sphere.set_launch_enabled(false)
		sphere.sphere_launched.connect(_on_sphere_launched)
		sphere.sphere_stopped.connect(_on_sphere_stopped)

	_start_player_turn()


func _start_player_turn() -> void:
	launched_count = 0
	for sphere: RigidBody2D in spheres:
		sphere.start_new_turn()


func _on_sphere_launched(launched_sphere: RigidBody2D) -> void:
	for sphere: RigidBody2D in spheres:
		if sphere == launched_sphere:
			continue
		sphere.lock_launch()


func _on_sphere_stopped(stopped_sphere: RigidBody2D) -> void:
	launched_count += 1

	if launched_count >= spheres.size():
		emit_signal("enemy_turn_started")
		print("敵のターンだ")
		return

	for sphere: RigidBody2D in spheres:
		if sphere == stopped_sphere:
			continue
		sphere.unlock_launch()

extends Node2D

signal enemy_turn_started

@export var sphere_paths: Array[NodePath] = [
	NodePath("Sphere1"),
	NodePath("Sphere2"),
	NodePath("Sphere3")
]
@export var enemy_turn_duration: float = 1.0
@export var enemy_manager_path: NodePath = NodePath("EnemyManager")

var spheres: Array[RigidBody2D] = []
var launched_count: int = 0
var is_enemy_turn: bool = false
var enemy_manager: Node = null


func _ready() -> void:
	if has_node(enemy_manager_path):
		enemy_manager = get_node(enemy_manager_path)
		if enemy_manager.has_method("on_enemy_turn_started"):
			enemy_turn_started.connect(enemy_manager.on_enemy_turn_started)

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
	is_enemy_turn = false
	launched_count = 0
	for sphere: RigidBody2D in spheres:
		sphere.start_new_turn()


func _on_sphere_launched(launched_sphere: RigidBody2D) -> void:
	if is_enemy_turn:
		return

	for sphere: RigidBody2D in spheres:
		if sphere == launched_sphere:
			continue
		sphere.lock_launch()


func _on_sphere_stopped(stopped_sphere: RigidBody2D) -> void:
	if is_enemy_turn:
		return

	launched_count += 1

	if launched_count >= spheres.size():
		_start_enemy_turn()
		return

	for sphere: RigidBody2D in spheres:
		if sphere == stopped_sphere:
			continue
		sphere.unlock_launch()


func _start_enemy_turn() -> void:
	is_enemy_turn = true
	for sphere: RigidBody2D in spheres:
		sphere.set_launch_enabled(false)

	emit_signal("enemy_turn_started")
	print("敵のターンだ")
	await get_tree().create_timer(enemy_turn_duration).timeout
	print("プレイヤーのターンだ")
	_start_player_turn()

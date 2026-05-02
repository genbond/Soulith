extends RigidBody2D

signal sphere_launched(sphere: RigidBody2D)
signal sphere_stopped(sphere: RigidBody2D)
signal sphere_hit_enemy(sphere: RigidBody2D, enemy: Node, attack_power: int)

const SOUL_LIBRARY: Dictionary = {
	"stone": {
		"id": "stone",
		"display_name": "石ころ",
		"attack": 2
	},
	"sword": {
		"id": "sword",
		"display_name": "ソード",
		"attack": 5
	},
	"shield": {
		"id": "shield",
		"display_name": "盾",
		"attack": 2
	}
}

@export var max_drag_distance: float = 180.0
@export var min_drag_distance: float = 16.0
@export var launch_force: float = 10.0
@export var deceleration_per_second: float = 550.0
@export var stop_speed_threshold: float = 20.0
@export var collision_radius: float = 24.0
@export var aim_line_path: NodePath = NodePath("AimLine")
@export var sphere_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var initial_soul_ids: Array[StringName] = [
	StringName("stone"),
	StringName("stone"),
	StringName("stone")
]

var is_dragging: bool = false
var can_launch: bool = false
var has_launched_this_turn: bool = false
var is_in_flight: bool = false
var souls: Array[Dictionary] = []
var current_soul_index: int = 0

@onready var aim_line: Line2D = get_node(aim_line_path) as Line2D
@onready var sprite_2d: Sprite2D = $Sprite2D


func _ready() -> void:
	gravity_scale = 0.0
	lock_rotation = true
	freeze = true
	aim_line.visible = false
	sprite_2d.modulate = sphere_color
	_initialize_souls()
	body_entered.connect(_on_body_entered)


func _unhandled_input(event: InputEvent) -> void:
	if not can_launch or has_launched_this_turn:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_world: Vector2 = get_global_mouse_position()
		if event.pressed and _is_mouse_on_sphere(mouse_world):
			is_dragging = true
			_update_aim_line(mouse_world)
			get_viewport().set_input_as_handled()
		elif (not event.pressed) and is_dragging:
			is_dragging = false
			_launch(mouse_world)
			aim_line.visible = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging:
		_update_aim_line(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not is_in_flight:
		return

	var speed: float = linear_velocity.length()
	if speed > 0.0:
		var decelerated_speed: float = move_toward(speed, 0.0, deceleration_per_second * _delta)
		if decelerated_speed <= 0.0:
			linear_velocity = Vector2.ZERO
		else:
			linear_velocity = linear_velocity.normalized() * decelerated_speed

	if linear_velocity.length() <= stop_speed_threshold:
		linear_velocity = Vector2.ZERO
		freeze = true
		is_in_flight = false
		emit_signal("sphere_stopped", self)


func _is_mouse_on_sphere(mouse_world: Vector2) -> bool:
	return global_position.distance_to(mouse_world) <= collision_radius


func _drag_vector_from_mouse(mouse_world: Vector2) -> Vector2:
	var drag_vector: Vector2 = global_position - mouse_world
	if drag_vector.length() > max_drag_distance:
		drag_vector = drag_vector.normalized() * max_drag_distance
	return drag_vector


func _update_aim_line(mouse_world: Vector2) -> void:
	var drag_vector: Vector2 = _drag_vector_from_mouse(mouse_world)
	aim_line.points = PackedVector2Array([
		Vector2.ZERO,
		-drag_vector
	])
	aim_line.visible = true


func _launch(mouse_world: Vector2) -> void:
	var drag_vector: Vector2 = _drag_vector_from_mouse(mouse_world)
	if drag_vector.length() < min_drag_distance:
		return

	freeze = false
	sleeping = false
	linear_velocity = drag_vector * launch_force
	can_launch = false
	has_launched_this_turn = true
	is_in_flight = true
	emit_signal("sphere_launched", self)


func set_launch_enabled(enabled: bool) -> void:
	can_launch = enabled


func start_new_turn() -> void:
	is_dragging = false
	has_launched_this_turn = false
	is_in_flight = false
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	can_launch = true
	aim_line.visible = false


func lock_launch() -> void:
	if has_launched_this_turn:
		return
	can_launch = false


func unlock_launch() -> void:
	if has_launched_this_turn or is_in_flight:
		return
	can_launch = true


func has_launched_in_turn() -> bool:
	return has_launched_this_turn


func is_currently_in_flight() -> bool:
	return is_in_flight


func get_current_soul() -> Dictionary:
	if souls.is_empty():
		return {}
	return souls[current_soul_index]


func get_current_soul_name() -> String:
	var soul: Dictionary = get_current_soul()
	return String(soul.get("display_name", "未設定"))


func get_current_soul_attack() -> int:
	var soul: Dictionary = get_current_soul()
	return int(soul.get("attack", 0))


func advance_soul_cycle() -> void:
	if souls.is_empty():
		return
	current_soul_index = (current_soul_index + 1) % souls.size()


func _on_body_entered(body: Node) -> void:
	if not is_in_flight:
		return
	if not body.has_method("apply_damage"):
		return

	emit_signal("sphere_hit_enemy", self, body, get_current_soul_attack())


func _initialize_souls() -> void:
	souls.clear()
	for soul_id_name: StringName in initial_soul_ids:
		var soul_id: String = String(soul_id_name)
		var soul_data: Dictionary = SOUL_LIBRARY.get(soul_id, {})
		if soul_data.is_empty():
			continue
		souls.append(soul_data.duplicate(true))

	if souls.is_empty():
		souls.append(SOUL_LIBRARY["stone"].duplicate(true))
	current_soul_index = 0

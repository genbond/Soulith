extends Node2D

signal enemy_turn_started

enum BattlePhase {
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLVE,
	REWARD
}

@export var sphere_paths: Array[NodePath] = [
	NodePath("Sphere1"),
	NodePath("Sphere2"),
	NodePath("Sphere3")
]
@export var enemy_turn_duration: float = 1.0
@export var enemy_manager_path: NodePath = NodePath("EnemyManager")

var spheres: Array[RigidBody2D] = []
var enemies: Array[Node] = []
var launched_count: int = 0
var enemy_manager: Node = null
var current_phase: BattlePhase = BattlePhase.PLAYER_TURN


func _ready() -> void:
	_ensure_end_turn_input()

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
		sphere.sphere_hit_enemy.connect(_on_sphere_hit_enemy)
		sphere.sphere_stopped.connect(_on_sphere_stopped)

	_collect_and_connect_enemies()
	_enter_phase(BattlePhase.PLAYER_TURN)


func _start_player_turn() -> void:
	launched_count = 0
	for sphere: RigidBody2D in spheres:
		sphere.start_new_turn()
	_log_current_souls()


func _unhandled_input(event: InputEvent) -> void:
	if current_phase != BattlePhase.PLAYER_TURN:
		return

	if event.is_action_pressed("end_turn"):
		if _any_sphere_in_flight():
			return
		_end_player_turn_manually()
		get_viewport().set_input_as_handled()


func _on_sphere_launched(launched_sphere: RigidBody2D) -> void:
	if current_phase != BattlePhase.PLAYER_TURN:
		return

	for sphere: RigidBody2D in spheres:
		if sphere == launched_sphere:
			continue
		sphere.lock_launch()


func _on_sphere_stopped(stopped_sphere: RigidBody2D) -> void:
	if current_phase != BattlePhase.PLAYER_TURN:
		return

	launched_count += 1

	if launched_count >= spheres.size():
		_enter_phase(BattlePhase.ENEMY_TURN)
		return

	for sphere: RigidBody2D in spheres:
		if sphere == stopped_sphere:
			continue
		sphere.unlock_launch()


func _on_sphere_hit_enemy(source_sphere: RigidBody2D, enemy: Node, attack_power: int) -> void:
	if current_phase != BattlePhase.PLAYER_TURN:
		return
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("apply_damage"):
		return

	enemy.apply_damage(attack_power)
	print("%s -> %s に %d ダメージ (ヒット毎計算)" % [source_sphere.name, enemy.name, attack_power])


func _start_enemy_turn() -> void:
	for sphere: RigidBody2D in spheres:
		sphere.set_launch_enabled(false)

	emit_signal("enemy_turn_started")
	print("敵のターンだ")
	await get_tree().create_timer(enemy_turn_duration).timeout
	_enter_phase(BattlePhase.RESOLVE)


func _start_resolve_phase() -> void:
	# TODO: Apply end-of-turn effects (poison, block, etc.).
	_apply_soul_cycle_per_sphere()
	_enter_phase(BattlePhase.PLAYER_TURN)


func _start_reward_phase() -> void:
	# TODO: Implement reward selection UI flow.
	print("報酬フェーズ（未実装）")


func _enter_phase(next_phase: BattlePhase) -> void:
	current_phase = next_phase
	print("フェーズ遷移: %s" % _phase_to_text(current_phase))

	match current_phase:
		BattlePhase.PLAYER_TURN:
			_start_player_turn()
		BattlePhase.ENEMY_TURN:
			_start_enemy_turn()
		BattlePhase.RESOLVE:
			_start_resolve_phase()
		BattlePhase.REWARD:
			_start_reward_phase()


func _phase_to_text(phase: BattlePhase) -> String:
	match phase:
		BattlePhase.PLAYER_TURN:
			return "PLAYER_TURN"
		BattlePhase.ENEMY_TURN:
			return "ENEMY_TURN"
		BattlePhase.RESOLVE:
			return "RESOLVE"
		BattlePhase.REWARD:
			return "REWARD"
	return "UNKNOWN"


func _end_player_turn_manually() -> void:
	_enter_phase(BattlePhase.ENEMY_TURN)


func _count_launched_spheres() -> int:
	var launched_spheres: int = 0
	for sphere: RigidBody2D in spheres:
		if sphere.has_launched_in_turn():
			launched_spheres += 1
	return launched_spheres


func _apply_soul_cycle_per_sphere() -> void:
	for index: int in spheres.size():
		var sphere: RigidBody2D = spheres[index]
		var previous_soul_name: String = sphere.get_current_soul_name()
		if sphere.has_launched_in_turn():
			sphere.advance_soul_cycle()
			print(
				"スフィア%d: %s -> %s (投球済みのためサイクル進行)"
				% [index + 1, previous_soul_name, sphere.get_current_soul_name()]
			)
		else:
			print(
				"スフィア%d: %s を維持 (未投球のため据え置き)"
				% [index + 1, previous_soul_name]
			)


func _any_sphere_in_flight() -> bool:
	for sphere: RigidBody2D in spheres:
		if sphere.is_currently_in_flight():
			return true
	return false


func _ensure_end_turn_input() -> void:
	if InputMap.has_action("end_turn"):
		return

	InputMap.add_action("end_turn")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_SPACE
	key_event.physical_keycode = KEY_SPACE
	InputMap.action_add_event("end_turn", key_event)


func _log_current_souls() -> void:
	for index: int in spheres.size():
		var sphere: RigidBody2D = spheres[index]
		print("スフィア%d: 現在ソウル %s" % [index + 1, sphere.get_current_soul_name()])


func _collect_and_connect_enemies() -> void:
	enemies.clear()
	for child: Node in get_children():
		if not child.has_method("apply_damage"):
			continue
		enemies.append(child)
		if child.has_signal("enemy_defeated") and not child.enemy_defeated.is_connected(_on_enemy_defeated):
			child.enemy_defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(enemy: Node) -> void:
	print("撃破: %s を倒した！" % enemy.name)

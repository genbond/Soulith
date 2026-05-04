extends Node2D

signal enemy_turn_started

enum BattlePhase {
	PLAYER_TURN,
	RESOLVE_PLAYER_END,
	ENEMY_TURN,
	RESOLVE_ENEMY_END,
	REWARD
}

@export var sphere_paths: Array[NodePath] = [
	NodePath("Sphere1"),
	NodePath("Sphere2"),
	NodePath("Sphere3")
]
@export var enemy_turn_duration: float = 1.0
@export var enemy_manager_path: NodePath = NodePath("EnemyManager")
@export var reward_panel_path: NodePath = NodePath("RewardPanel")
## 戦闘勝利時のマネー（撃破数による加算はしない）。将来: 敵の種別（通常 / エリート等）で変動させる想定。
@export var reward_gold: int = 40

var spheres: Array[RigidBody2D] = []
var enemies: Array[Node] = []
var launched_count: int = 0
var enemy_manager: Node = null
var current_phase: BattlePhase = BattlePhase.PLAYER_TURN
var battle_cleared: bool = false
var combat_has_enemies: bool = false
var player_money: int = 0
var reward_panel: RewardPanel = null


func _ready() -> void:
	_ensure_end_turn_input()

	if has_node(enemy_manager_path):
		enemy_manager = get_node(enemy_manager_path)
		if enemy_manager.has_method("on_enemy_turn_started"):
			enemy_turn_started.connect(enemy_manager.on_enemy_turn_started)

	if has_node(reward_panel_path):
		reward_panel = get_node(reward_panel_path) as RewardPanel

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
	combat_has_enemies = not enemies.is_empty()
	_enter_phase(BattlePhase.PLAYER_TURN)


func _start_player_turn() -> void:
	if battle_cleared:
		return
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
	if battle_cleared:
		return
	if current_phase != BattlePhase.PLAYER_TURN:
		return

	launched_count += 1

	if launched_count >= spheres.size():
		_enter_phase(BattlePhase.RESOLVE_PLAYER_END)
		return

	for sphere: RigidBody2D in spheres:
		if sphere == stopped_sphere:
			continue
		sphere.unlock_launch()


func _on_sphere_hit_enemy(source_sphere: RigidBody2D, enemy: Node, attack_power: int) -> void:
	if battle_cleared:
		return
	if current_phase != BattlePhase.PLAYER_TURN:
		return
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("apply_damage"):
		return

	enemy.apply_damage(attack_power)
	print("%s -> %s に %d ダメージ (ヒット毎計算)" % [source_sphere.name, enemy.name, attack_power])
	_try_enter_reward_if_all_enemies_defeated()


func _start_enemy_turn() -> void:
	if battle_cleared:
		return
	if not combat_has_enemies:
		_enter_phase(BattlePhase.PLAYER_TURN)
		return
	if enemies.is_empty():
		_enter_phase(BattlePhase.REWARD)
		return
	for sphere: RigidBody2D in spheres:
		sphere.set_launch_enabled(false)

	emit_signal("enemy_turn_started")
	print("敵のターンだ")
	await get_tree().create_timer(enemy_turn_duration).timeout
	_enter_phase(BattlePhase.RESOLVE_ENEMY_END)


func _start_resolve_player_end() -> void:
	if battle_cleared:
		return
	# 自ターン（プレイヤー）終了時: スフィア側の毒・ブロック等 → ソウルサイクル → 敵ターン
	_apply_player_turn_resolve_effects()
	if current_phase != BattlePhase.RESOLVE_PLAYER_END:
		return
	if battle_cleared:
		return
	_apply_soul_cycle_per_sphere()
	if current_phase != BattlePhase.RESOLVE_PLAYER_END:
		return
	if battle_cleared:
		return
	_enter_phase(BattlePhase.ENEMY_TURN)


func _start_resolve_enemy_end() -> void:
	if battle_cleared:
		return
	# 敵ターン終了時: 敵側の毒・ブロック等（プレイヤー側とは別枠）→ 次プレイヤーターン
	_apply_enemy_turn_resolve_effects()
	if current_phase != BattlePhase.RESOLVE_ENEMY_END:
		return
	if battle_cleared:
		return
	_enter_phase(BattlePhase.PLAYER_TURN)


func _apply_player_turn_resolve_effects() -> void:
	print("RESOLVE_PLAYER_END: プレイヤー側ターン終了効果")
	for sphere: RigidBody2D in spheres:
		if not is_instance_valid(sphere):
			continue
		if sphere.has_method("on_player_turn_resolve_end"):
			sphere.call("on_player_turn_resolve_end", self)


func _apply_enemy_turn_resolve_effects() -> void:
	print("RESOLVE_ENEMY_END: 敵側ターン終了効果")
	for enemy: Node in enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("on_enemy_turn_resolve_end"):
			enemy.call("on_enemy_turn_resolve_end", self)


func _start_reward_phase() -> void:
	print("報酬フェーズ: 全敵撃破")
	battle_cleared = true
	for sphere: RigidBody2D in spheres:
		sphere.set_launch_enabled(false)

	var money: int = _roll_money_reward()
	var soul_options: Array[String] = _roll_soul_offerings()
	var sphere_labels: Array[String] = _sphere_reward_target_labels()
	if reward_panel != null:
		reward_panel.begin_reward(money, soul_options, sphere_labels)
		await reward_panel.done
		_apply_post_battle_rewards(
			money,
			reward_panel.last_chosen_soul_id,
			reward_panel.last_skipped_soul,
			reward_panel.last_target_sphere_index
		)
	else:
		push_warning("RewardPanel が見つかりません。マネーのみ付与します。")
		_apply_post_battle_rewards(money, StringName(""), true, -1)

	combat_has_enemies = false
	battle_cleared = false
	_enter_phase(BattlePhase.PLAYER_TURN)


func _roll_money_reward() -> int:
	return reward_gold


func _sphere_reward_target_labels() -> Array[String]:
	var labels: Array[String] = []
	for sphere: RigidBody2D in spheres:
		if is_instance_valid(sphere):
			labels.append(sphere.name)
	return labels


func _roll_soul_offerings() -> Array[String]:
	var pool: Array[String] = ["stone", "sword", "shield"]
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))


func _apply_post_battle_rewards(
	money: int, chosen_soul_id: StringName, skipped_soul: bool, target_sphere_index: int
) -> void:
	player_money += money
	print("マネー +%d（所持 %d）" % [money, player_money])
	if skipped_soul or String(chosen_soul_id).is_empty():
		print("ソウル報酬: スキップ")
		return
	if target_sphere_index < 0 or target_sphere_index >= spheres.size():
		push_warning("ソウル付与先インデックスが無効のため付与しません: %d" % target_sphere_index)
		return
	var target: RigidBody2D = spheres[target_sphere_index]
	if target.has_method("append_acquired_soul"):
		target.append_acquired_soul(String(chosen_soul_id))


func _enter_phase(next_phase: BattlePhase) -> void:
	current_phase = next_phase
	print("フェーズ遷移: %s" % _phase_to_text(current_phase))

	match current_phase:
		BattlePhase.PLAYER_TURN:
			_start_player_turn()
		BattlePhase.RESOLVE_PLAYER_END:
			_start_resolve_player_end()
		BattlePhase.ENEMY_TURN:
			_start_enemy_turn()
		BattlePhase.RESOLVE_ENEMY_END:
			_start_resolve_enemy_end()
		BattlePhase.REWARD:
			_start_reward_phase()


func _phase_to_text(phase: BattlePhase) -> String:
	match phase:
		BattlePhase.PLAYER_TURN:
			return "PLAYER_TURN"
		BattlePhase.RESOLVE_PLAYER_END:
			return "RESOLVE_PLAYER_END"
		BattlePhase.ENEMY_TURN:
			return "ENEMY_TURN"
		BattlePhase.RESOLVE_ENEMY_END:
			return "RESOLVE_ENEMY_END"
		BattlePhase.REWARD:
			return "REWARD"
	return "UNKNOWN"


func _end_player_turn_manually() -> void:
	_enter_phase(BattlePhase.RESOLVE_PLAYER_END)


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
		if enemy_manager != null and enemy_manager.has_method("register_enemy"):
			enemy_manager.register_enemy(child)
		if child.has_signal("enemy_defeated") and not child.enemy_defeated.is_connected(_on_enemy_defeated):
			child.enemy_defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(enemy: Node) -> void:
	print("撃破: %s を倒した！" % enemy.name)
	_unregister_enemy(enemy)
	print("残り敵: %d" % enemies.size())
	_try_enter_reward_if_all_enemies_defeated()


func _try_enter_reward_if_all_enemies_defeated() -> void:
	if battle_cleared:
		return
	if current_phase == BattlePhase.REWARD:
		return
	if not combat_has_enemies:
		return
	if not enemies.is_empty():
		return
	_enter_phase(BattlePhase.REWARD)


func _unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if enemy_manager != null and enemy_manager.has_method("unregister_enemy"):
		enemy_manager.unregister_enemy(enemy)
	if enemy.has_signal("enemy_defeated") and enemy.enemy_defeated.is_connected(_on_enemy_defeated):
		enemy.enemy_defeated.disconnect(_on_enemy_defeated)
	enemies.erase(enemy)

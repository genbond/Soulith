extends Node

var enemies: Array[Node] = []


func register_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if enemies.has(enemy):
		return
	enemies.append(enemy)


func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	enemies.erase(enemy)


func on_enemy_turn_started() -> void:
	print("敵の攻撃ログ: %d体が行動する" % enemies.size())

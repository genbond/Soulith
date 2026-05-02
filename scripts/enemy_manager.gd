extends Node

@export var enemy_paths: Array[NodePath] = [
	NodePath("../Enemy1")
]

var enemies: Array[Node] = []


func _ready() -> void:
	for enemy_path: NodePath in enemy_paths:
		if not has_node(enemy_path):
			continue
		var enemy: Node = get_node(enemy_path)
		if enemy == null:
			continue
		enemies.append(enemy)


func on_enemy_turn_started() -> void:
	print("敵の攻撃ログ: %d体が行動する" % enemies.size())

extends Node

@export var enemy_paths: Array[NodePath] = [
	NodePath("../Enemy1")
]

var enemies: Array[Area2D] = []


func _ready() -> void:
	for enemy_path: NodePath in enemy_paths:
		if not has_node(enemy_path):
			continue
		var enemy: Area2D = get_node(enemy_path) as Area2D
		if enemy == null:
			continue
		enemies.append(enemy)


func on_enemy_turn_started() -> void:
	print("敵の攻撃ログ: %d体が行動する" % enemies.size())

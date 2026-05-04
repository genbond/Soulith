extends StaticBody2D

signal enemy_defeated(enemy: StaticBody2D)

@export var max_hp: int = 40
@export var attack_power: int = 6

var current_hp: int = 0


func _ready() -> void:
	current_hp = max_hp


func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	if current_hp <= 0:
		return

	current_hp = max(current_hp - amount, 0)
	print("%s に %d ダメージ (HP: %d/%d)" % [name, amount, current_hp, max_hp])
	if current_hp == 0:
		emit_signal("enemy_defeated", self)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		visible = false
		call_deferred("queue_free")

extends StaticBody2D

signal enemy_defeated(enemy: StaticBody2D)

@export var max_hp: int = 40
@export var attack_power: int = 6
@export var poison_stacks: int = 0
@export var block_stacks: int = 0

var current_hp: int = 0


func _ready() -> void:
	current_hp = max_hp


func add_poison_stacks(amount: int) -> void:
	if amount <= 0:
		return
	poison_stacks += amount
	print("%s: 毒 +%d（合計 %d）" % [name, amount, poison_stacks])


func add_block_stacks(amount: int) -> void:
	if amount <= 0:
		return
	block_stacks += amount
	print("%s: ブロック +%d（合計 %d）" % [name, amount, block_stacks])


func apply_damage(amount: int, ignore_block: bool = false) -> void:
	if amount <= 0:
		return
	if current_hp <= 0:
		return

	var hp_damage: int = amount
	if not ignore_block and block_stacks > 0:
		var absorbed: int = mini(amount, block_stacks)
		block_stacks -= absorbed
		hp_damage = amount - absorbed
		if absorbed > 0:
			print("%s: ブロックで %d 吸収（残りブロック %d）" % [name, absorbed, block_stacks])

	if hp_damage <= 0:
		return

	current_hp = max(current_hp - hp_damage, 0)
	print("%s に %d ダメージ (HP: %d/%d)" % [name, hp_damage, current_hp, max_hp])
	if current_hp == 0:
		emit_signal("enemy_defeated", self)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		visible = false
		call_deferred("queue_free")


## 仕様 8.4: 敵ターン終了時（RESOLVE_ENEMY_END）。毒はブロックを無視して HP に入る想定。
func on_enemy_turn_resolve_end(_battle_root: Node) -> void:
	if poison_stacks <= 0:
		return
	var dmg: int = poison_stacks
	print("%s: 毒 %d" % [name, dmg])
	apply_damage(dmg, true)
	poison_stacks = maxi(poison_stacks - 1, 0)

extends CanvasLayer
class_name RewardPanel

## 報酬 UI を閉じ、選択が確定したときに一度だけ飛ぶ
signal done

var last_chosen_soul_id: StringName = StringName("")
var last_skipped_soul: bool = false
## 付与先スフィアの `spheres` 配列インデックス（ソウルスキップ時は -1）
var last_target_sphere_index: int = -1

var _money_label: Label
var _hint: Label
var _soul_buttons: Array[Button] = []
var _sphere_row: HBoxContainer
var _sphere_hint: Label
var _sphere_buttons: Array[Button] = []
var _confirm_btn: Button

var _money: int = 0
var _soul_ids: Array[String] = []
var _skipped_mode: bool = false
var _selected_soul_idx: int = -1
var _selected_sphere_idx: int = -1


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "UiRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.05, 0.12, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -220.0
	panel.offset_right = 280.0
	panel.offset_bottom = 220.0
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "戦闘勝利"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_money_label = Label.new()
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_money_label)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hint)

	var soul_label := Label.new()
	soul_label.text = "ソウル報酬（1つ選択）"
	soul_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(soul_label)

	var soul_row := HBoxContainer.new()
	soul_row.alignment = BoxContainer.ALIGNMENT_CENTER
	soul_row.add_theme_constant_override("separation", 8)
	vbox.add_child(soul_row)

	for i: int in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 36)
		b.pressed.connect(_on_soul_pressed.bind(i))
		soul_row.add_child(b)
		_soul_buttons.append(b)

	var skip := Button.new()
	skip.text = "ソウルを受け取らない"
	skip.pressed.connect(_on_skip_soul)
	vbox.add_child(skip)

	_sphere_hint = Label.new()
	_sphere_hint.text = "付与先スフィア"
	_sphere_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_sphere_hint)

	_sphere_row = HBoxContainer.new()
	_sphere_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sphere_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_sphere_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "報酬を確定"
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_btn)


func begin_reward(money: int, soul_ids: Array[String], sphere_target_labels: Array[String]) -> void:
	last_chosen_soul_id = StringName("")
	last_skipped_soul = false
	last_target_sphere_index = -1
	_skipped_mode = false
	_selected_soul_idx = -1
	_selected_sphere_idx = -1
	_money = money
	_soul_ids = soul_ids.duplicate()
	_money_label.text = "マネー +%d" % money
	_hint.text = "マネーは確定で獲得。ソウルを選ぶ場合は付与先スフィアも選び、「報酬を確定」を押してください。"

	for c: Node in _sphere_row.get_children():
		_sphere_row.remove_child(c)
		c.free()
	_sphere_buttons.clear()

	for i: int in sphere_target_labels.size():
		var sb := Button.new()
		sb.custom_minimum_size = Vector2(112, 36)
		sb.text = sphere_target_labels[i]
		sb.disabled = true
		sb.pressed.connect(_on_sphere_pressed.bind(i))
		_sphere_row.add_child(sb)
		_sphere_buttons.append(sb)

	for i: int in _soul_buttons.size():
		if i < soul_ids.size():
			_soul_buttons[i].text = _display_name_for(soul_ids[i])
			_soul_buttons[i].visible = true
			_soul_buttons[i].disabled = false
		else:
			_soul_buttons[i].visible = false
			_soul_buttons[i].disabled = true

	_refresh_soul_visuals()
	_refresh_sphere_visuals()
	_update_confirm()
	visible = true


func _display_name_for(id: String) -> String:
	match id:
		"stone":
			return "石ころ"
		"sword":
			return "ソード"
		"shield":
			return "盾"
		_:
			return id


func _on_soul_pressed(idx: int) -> void:
	if idx < 0 or idx >= _soul_ids.size():
		return
	_skipped_mode = false
	_selected_soul_idx = idx
	_selected_sphere_idx = -1
	for b: Button in _sphere_buttons:
		b.disabled = false
	_refresh_soul_visuals()
	_refresh_sphere_visuals()
	_update_confirm()


func _on_skip_soul() -> void:
	_skipped_mode = true
	_selected_soul_idx = -1
	_selected_sphere_idx = -1
	for b: Button in _sphere_buttons:
		b.disabled = true
	_refresh_soul_visuals()
	_refresh_sphere_visuals()
	_update_confirm()


func _on_sphere_pressed(idx: int) -> void:
	if _skipped_mode:
		return
	if idx < 0 or idx >= _sphere_buttons.size():
		return
	_selected_sphere_idx = idx
	_refresh_sphere_visuals()
	_update_confirm()


func _refresh_soul_visuals() -> void:
	for i: int in _soul_buttons.size():
		var b: Button = _soul_buttons[i]
		if not b.visible:
			continue
		if _skipped_mode:
			b.self_modulate = Color(1, 1, 1, 0.55)
		elif i == _selected_soul_idx:
			b.self_modulate = Color(0.75, 1.0, 1.0, 1.0)
		else:
			b.self_modulate = Color.WHITE


func _refresh_sphere_visuals() -> void:
	for i: int in _sphere_buttons.size():
		var b: Button = _sphere_buttons[i]
		if b.disabled:
			b.self_modulate = Color(1, 1, 1, 0.45)
		elif i == _selected_sphere_idx:
			b.self_modulate = Color(0.85, 1.0, 0.75, 1.0)
		else:
			b.self_modulate = Color.WHITE


func _update_confirm() -> void:
	if _skipped_mode:
		_confirm_btn.disabled = false
		return
	if _selected_soul_idx >= 0 and _selected_soul_idx < _soul_ids.size() and _selected_sphere_idx >= 0:
		_confirm_btn.disabled = false
	else:
		_confirm_btn.disabled = true


func _on_confirm() -> void:
	if _skipped_mode:
		_close_with_result(StringName(""), true, -1)
		return
	if _selected_soul_idx < 0 or _selected_soul_idx >= _soul_ids.size():
		return
	if _selected_sphere_idx < 0 or _selected_sphere_idx >= _sphere_buttons.size():
		return
	_close_with_result(StringName(_soul_ids[_selected_soul_idx]), false, _selected_sphere_idx)


func _close_with_result(soul_id: StringName, skipped: bool, sphere_idx: int) -> void:
	last_chosen_soul_id = soul_id
	last_skipped_soul = skipped
	last_target_sphere_index = -1 if skipped else sphere_idx
	visible = false
	done.emit()

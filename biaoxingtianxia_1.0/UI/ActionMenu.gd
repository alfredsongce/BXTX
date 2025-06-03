extends Panel

signal action_selected(action_type: String) # 行动类型信号
signal menu_closed() # 菜单关闭信号

var target_character = null # 当前操作的角色

func _ready():
	print("🚀 [ActionMenu] _ready 被调用")
	# 🚀 添加到action_menus组，方便全局管理
	add_to_group("action_menus")
	
	# 连接按钮信号
	print("🔗 [ActionMenu] 开始连接按钮信号")
	$VBoxContainer/MoveButton.pressed.connect(_on_move_pressed)
	print("✅ [ActionMenu] MoveButton 信号已连接")
	$VBoxContainer/SkillButton.pressed.connect(_on_skill_pressed)
	print("✅ [ActionMenu] SkillButton 信号已连接")
	$VBoxContainer/ItemButton.pressed.connect(_on_item_pressed)
	print("✅ [ActionMenu] ItemButton 信号已连接")
	$VBoxContainer/SpecialButton.pressed.connect(_on_special_pressed)
	print("✅ [ActionMenu] SpecialButton 信号已连接")
	$VBoxContainer/RestButton.pressed.connect(_on_rest_pressed)
	print("✅ [ActionMenu] RestButton 信号已连接")
	$VBoxContainer/CancelButton.pressed.connect(_on_cancel_pressed)
	print("✅ [ActionMenu] CancelButton 信号已连接")
	
	# 默认隐藏菜单
	visible = false
	print("✅ [ActionMenu] _ready 完成，菜单已隐藏")

# 打开菜单
func open_menu(character):
	print("\n=== 🎯 [ActionMenu] open_menu被调用 ===")
	print("🔥 [ActionMenu] 菜单正在被打开！")
	print("🔍 [ActionMenu] 传入角色: %s" % (character.name if character else "null"))
	
	target_character = character
	var character_data = character.get_character_data()
	print("🔍 [ActionMenu] 角色数据: %s" % (character_data.name if character_data else "null"))
	
	$VBoxContainer/TitleLabel.text = "行动菜单 - " + character_data.name
	print("🔧 [ActionMenu] 设置标题: %s" % $VBoxContainer/TitleLabel.text)
	
	# 🚀 更新按钮状态
	print("🔧 [ActionMenu] 更新按钮状态")
	_update_button_states(character_data)
	
	# 显示并定位菜单到鼠标位置
	print("🔧 [ActionMenu] 显示菜单并定位")
	visible = true
	global_position = get_global_mouse_position()
	print("✅ [ActionMenu] 菜单已显示，位置: %s" % global_position)
	
	# 确保菜单在屏幕内
	var viewport_size = get_viewport_rect().size
	if global_position.x + size.x > viewport_size.x:
		global_position.x = viewport_size.x - size.x
	if global_position.y + size.y > viewport_size.y:
		global_position.y = viewport_size.y - size.y

# 🚀 新增：更新按钮状态
func _update_button_states(character_data):
	if not character_data:
		return
	
	# 获取ActionSystem
	var action_system = get_tree().current_scene.get_node_or_null("ActionSystem")
	if not action_system:
		return
	
	# 获取角色行动点数
	var points = action_system.get_character_action_points(character_data)
	
	# 更新移动按钮
	var move_button = $VBoxContainer/MoveButton
	var can_move = action_system.can_character_perform_action(character_data, "move")
	move_button.disabled = not can_move
	if can_move:
		move_button.text = "移动 (%d点)" % points.move_points
	else:
		move_button.text = "移动 (无点数)"
	
	# 更新技能按钮
	var skill_button = $VBoxContainer/SkillButton
	var can_attack = action_system.can_character_perform_action(character_data, "skill")
	skill_button.disabled = not can_attack
	if can_attack:
		skill_button.text = "技能 (%d点)" % points.attack_points
	else:
		skill_button.text = "技能 (无点数)"
	
	# 更新道具按钮
	var item_button = $VBoxContainer/ItemButton
	item_button.disabled = not can_attack
	if can_attack:
		item_button.text = "道具 (%d点)" % points.attack_points
	else:
		item_button.text = "道具 (无点数)"
	
	# 更新特殊按钮
	var special_button = $VBoxContainer/SpecialButton
	special_button.disabled = not can_attack
	if can_attack:
		special_button.text = "特殊 (%d点)" % points.attack_points
	else:
		special_button.text = "特殊 (无点数)"
	
	# 休息按钮总是可用
	$VBoxContainer/RestButton.text = "休息 (结束回合)"
	
	# 🚀 添加行动点数状态提示
	var status_text = "剩余行动点数：移动%d，攻击%d" % [points.move_points, points.attack_points]
	if not $VBoxContainer.has_node("StatusLabel"):
		var status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.add_theme_font_size_override("font_size", 12)
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		$VBoxContainer.add_child(status_label)
		$VBoxContainer.move_child(status_label, 1)  # 放在标题下面
	
	$VBoxContainer/StatusLabel.text = status_text

# 关闭菜单
func close_menu():
	visible = false
	target_character = null
	menu_closed.emit()

# 按钮事件处理
func _on_move_pressed():
	print("角色 [", target_character.get_character_data().name, "] 选择了 [移动] 行动")
	action_selected.emit("move")
	close_menu()

func _on_skill_pressed():
	print("🎯 [ActionMenu] _on_skill_pressed 被调用!")
	print("🔍 [ActionMenu] target_character: %s" % (target_character.name if target_character else "null"))
	if target_character:
		print("角色 [", target_character.get_character_data().name, "] 选择了 [技能] 行动")
	else:
		print("❌ [ActionMenu] target_character 为空!")
	print("📡 [ActionMenu] 即将发射 action_selected 信号: skill")
	action_selected.emit("skill")
	print("✅ [ActionMenu] action_selected 信号已发射")
	close_menu()
	print("✅ [ActionMenu] 菜单已关闭")

func _on_item_pressed():
	print("角色 [", target_character.get_character_data().name, "] 选择了 [道具] 行动")
	action_selected.emit("item")
	close_menu()

func _on_special_pressed():
	print("角色 [", target_character.get_character_data().name, "] 选择了 [特殊] 行动")
	action_selected.emit("special")
	close_menu()

func _on_rest_pressed():
	print("角色 [", target_character.get_character_data().name, "] 选择了 [休息] 行动")
	action_selected.emit("rest")
	close_menu()

func _on_cancel_pressed():
	print("取消行动选择")
	close_menu()

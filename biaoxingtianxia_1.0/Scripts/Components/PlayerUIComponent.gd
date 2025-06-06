# 玩家UI组件
extends Node
class_name PlayerUIComponent

# UI相关信号
signal action_selected(action_type: String)
signal menu_closed()

# 引用
var player_node: Node2D
var character_data: GameCharacter

# UI节点和资源
var tooltip: Node = null
var tooltip_scene: PackedScene
var action_menu_scene: PackedScene

# 静态变量跟踪当前打开的菜单，确保同一时间只有一个菜单
static var current_open_menu = null

func _init(player: Node2D = null):
	if player:
		setup(player)

func setup(player: Node2D) -> void:
	player_node = player
	if player.has_method("get_character_data"):
		character_data = player.get_character_data()
	
	# 预加载UI资源
	tooltip_scene = preload("res://UI/CharacterTooltip.tscn")
	action_menu_scene = preload("res://UI/ActionMenu.tscn")
	
	# 检查预加载的资源
	if tooltip_scene == null:
		push_error("无法加载角色属性提示场景")
	
	if action_menu_scene == null:
		push_error("无法加载行动菜单场景")

# 显示tooltip
func show_tooltip() -> void:
	# 先清理可能存在的旧tooltip
	hide_tooltip()
	
	# 创建并显示角色属性提示
	if tooltip_scene:
		tooltip = tooltip_scene.instantiate()
		if tooltip:
			# 更新并添加到场景
			update_tooltip()
			var current_scene = player_node.get_tree().current_scene
			if current_scene:
				current_scene.add_child(tooltip)
				
				# 🚀 修复：智能设置tooltip位置，确保不超出屏幕边界
				_position_tooltip_smartly()

# 隐藏tooltip
func hide_tooltip() -> void:
	if tooltip != null and is_instance_valid(tooltip):
		if tooltip.get_parent() != null:
			tooltip.get_parent().remove_child(tooltip)
		tooltip = null

# 更新tooltip内容
func update_tooltip() -> void:
	if tooltip == null or not character_data:
		return
		
	# 更新tooltip中的各项属性
	tooltip.get_node("VBoxContainer/NameLabel").text = character_data.name
	tooltip.get_node("VBoxContainer/HBoxContainer/LevelValue").text = str(character_data.level)
	tooltip.get_node("VBoxContainer/HBoxContainer2/HPValue").text = "%d/%d" % [character_data.current_hp, character_data.max_hp]
	tooltip.get_node("VBoxContainer/HBoxContainer3/AttackValue").text = str(character_data.attack)
	tooltip.get_node("VBoxContainer/HBoxContainer4/DefenseValue").text = str(character_data.defense)
	
	# 添加轻功和高度信息
	_update_tooltip_qinggong()
	_update_tooltip_height()
	
	# 🚀 修复：调整Panel大小以适应内容
	_adjust_tooltip_size()

# 更新tooltip的轻功信息
func _update_tooltip_qinggong() -> void:
	if tooltip.get_node("VBoxContainer").has_node("HBoxContainer5"):
		tooltip.get_node("VBoxContainer/HBoxContainer5/QinggongValue").text = str(character_data.qinggong_skill)
	else:
		var qinggong_box = HBoxContainer.new()
		qinggong_box.name = "HBoxContainer5"
		
		var qinggong_label = Label.new()
		qinggong_label.text = "轻功:"
		qinggong_label.name = "QinggongLabel"
		
		var qinggong_value = Label.new()
		qinggong_value.text = str(character_data.qinggong_skill)
		qinggong_value.name = "QinggongValue"
		
		qinggong_box.add_child(qinggong_label)
		qinggong_box.add_child(qinggong_value)
		tooltip.get_node("VBoxContainer").add_child(qinggong_box)

# 更新tooltip的高度信息
func _update_tooltip_height() -> void:
	if tooltip.get_node("VBoxContainer").has_node("HBoxContainer6"):
		tooltip.get_node("VBoxContainer/HBoxContainer6/HeightValue").text = str(character_data.get_height_level())
	else:
		var height_box = HBoxContainer.new()
		height_box.name = "HBoxContainer6"
		
		var height_label = Label.new()
		height_label.text = "高度:"
		height_label.name = "HeightLabel"
		
		var height_value = Label.new()
		height_value.text = str(character_data.get_height_level())
		height_value.name = "HeightValue"
		
		height_box.add_child(height_label)
		height_box.add_child(height_value)
		tooltip.get_node("VBoxContainer").add_child(height_box)

# 打开行动菜单
func open_action_menu() -> void:
	print("\n=== 🎯 [PlayerUIComponent] open_action_menu被调用 ===")
	print("🔥 [PlayerUIComponent] 这是菜单创建的关键方法！")
	print("🔍 [PlayerUIComponent] 角色: %s" % (character_data.name if character_data else "未知"))
	print("🔍 [PlayerUIComponent] 当前打开的菜单: %s" % (current_open_menu.name if current_open_menu and is_instance_valid(current_open_menu) else "无"))
	
	# 先检查并关闭场景中已打开的菜单
	if current_open_menu != null and is_instance_valid(current_open_menu):
		print("🔄 [PlayerUIComponent] 关闭已存在的菜单: %s" % current_open_menu.name)
		current_open_menu.close_menu()
	
	# 移除tooltip（如果存在）
	hide_tooltip()
	
	# 检查行动菜单资源是否正确加载
	print("🔍 [PlayerUIComponent] 检查action_menu_scene: %s" % ("已加载" if action_menu_scene else "未加载"))
	if not action_menu_scene:
		print("❌ [PlayerUIComponent] 行动菜单资源未正确加载")
		push_error("行动菜单资源未正确加载")
		return
	
	# 创建行动菜单实例
	print("🔧 [PlayerUIComponent] 实例化行动菜单")
	var current_menu = action_menu_scene.instantiate()
	if not current_menu:
		print("❌ [PlayerUIComponent] 行动菜单实例化失败")
		push_error("行动菜单实例化失败")
		return
		
	# 添加到场景
	print("🔧 [PlayerUIComponent] 将菜单添加到场景")
	player_node.get_tree().current_scene.add_child(current_menu)
	
	# 记录当前打开的菜单
	current_open_menu = current_menu
	print("✅ [PlayerUIComponent] 菜单已设置为current_open_menu: %s" % current_menu.name)
	
	# 计算菜单位置
	var menu_position = _calculate_menu_position()
	
	# 使用 Input 类暂时设置鼠标位置，影响菜单弹出位置
	var original_mouse_pos = player_node.get_global_mouse_position()
	Input.warp_mouse(menu_position)
	
	# 打开菜单
	print("📞 [PlayerUIComponent] 调用current_menu.open_menu()")
	current_menu.open_menu(player_node)
	print("✅ [PlayerUIComponent] current_menu.open_menu()调用完成")
	
	# 立即恢复鼠标位置
	Input.warp_mouse(original_mouse_pos)
	
	# 连接信号
	print("🔗 [PlayerUIComponent] 连接菜单信号")
	current_menu.action_selected.connect(_on_action_selected)
	current_menu.menu_closed.connect(_on_menu_closed)
	print("✅ [PlayerUIComponent] 行动菜单打开流程完成")

# 计算菜单理想位置
func _calculate_menu_position() -> Vector2:
	var ideal_menu_pos = Vector2()
	
	# 1. 获取角色尺寸和屏幕尺寸
	var char_size = Vector2(64, 64)  # 角色点击区域大小
	var viewport_size = player_node.get_viewport_rect().size
	
	# 2. 根据角色位置确定理想的菜单弹出方向
	if player_node.global_position.x < viewport_size.x / 2:
		# 角色在左侧，菜单放右侧
		ideal_menu_pos.x = player_node.global_position.x + char_size.x + 20
	else:
		# 角色在右侧，菜单放左侧
		ideal_menu_pos.x = player_node.global_position.x - 200
	
	if player_node.global_position.y < viewport_size.y / 2:
		# 角色在上方，菜单放下方
		ideal_menu_pos.y = player_node.global_position.y + 20
	else:
		# 角色在下方，菜单放上方
		ideal_menu_pos.y = player_node.global_position.y - 200
	
	# 确保菜单不会超出屏幕
	ideal_menu_pos.x = clamp(ideal_menu_pos.x, 10, viewport_size.x - 210)
	ideal_menu_pos.y = clamp(ideal_menu_pos.y, 10, viewport_size.y - 210)
	
	return ideal_menu_pos

# 处理行动选择
func _on_action_selected(action_type: String) -> void:
	action_selected.emit(action_type)
	
	# 🚀 修复：检查ActionSystem是否已经处理了技能选择
	if action_type == "skill":
		print("🎯 [UI组件] 角色选择了技能行动")
		
		# 🚀 检查ActionSystem的状态，如果已经在处理技能，则不重复处理
		var battle_scene = AutoLoad.get_battle_scene()
		var action_system = battle_scene.get_node_or_null("ActionSystem") if battle_scene else null
		if action_system and action_system.current_state == action_system.SystemState.EXECUTING_ACTION:
			print("🔧 [UI组件] ActionSystem已处理技能选择，跳过重复处理")
			return
		
		# 只有当ActionSystem没有处理时，才调用BattleScene的技能菜单
		if battle_scene and battle_scene.has_method("show_skill_menu"):
			battle_scene.show_skill_menu(character_data)
		else:
			print("⚠️ [UI组件] 无法找到BattleScene或show_skill_menu方法")
	
	# 🚀 其他行动类型的处理...
	# 移动、道具、特殊、休息等行动继续使用原有的ActionSystem处理

# 处理菜单关闭
func _on_menu_closed() -> void:
	# 清除当前菜单引用
	current_open_menu = null
	menu_closed.emit() 

# 🚀 修复：智能设置tooltip位置，确保不超出屏幕边界
func _position_tooltip_smartly() -> void:
	if not tooltip:
		return
	
	# 获取鼠标位置和视口大小
	var mouse_pos = player_node.get_global_mouse_position()
	var viewport_size = player_node.get_viewport_rect().size
	
	# 初始位置：鼠标右下方
	var tooltip_pos = mouse_pos + Vector2(20, 20)
	
	# 设置初始位置
	tooltip.global_position = tooltip_pos
	
	# 🚀 使用call_deferred在下一帧调整位置，确保tooltip大小已计算
	call_deferred("_adjust_tooltip_position")

func _adjust_tooltip_position() -> void:
	if not tooltip or not is_instance_valid(tooltip):
		return
	
	# 🚀 先调整tooltip大小，再调整位置
	await _adjust_tooltip_size()
	
	if not tooltip or not is_instance_valid(tooltip):
		return
	
	var viewport_size = player_node.get_viewport_rect().size
	var mouse_pos = player_node.get_global_mouse_position()
	
	# 获取调整后的tooltip大小
	var tooltip_size = tooltip.size
	
	# 🚀 智能位置调整逻辑
	var offset_x = 20
	var offset_y = 20
	var margin = 10  # 距离屏幕边缘的最小距离
	
	# 默认位置：鼠标右下方
	var new_pos = mouse_pos + Vector2(offset_x, offset_y)
	
	# 检查右边界，如果超出则放到鼠标左边
	if new_pos.x + tooltip_size.x > viewport_size.x - margin:
		new_pos.x = mouse_pos.x - tooltip_size.x - offset_x
	
	# 检查下边界，如果超出则放到鼠标上方
	if new_pos.y + tooltip_size.y > viewport_size.y - margin:
		new_pos.y = mouse_pos.y - tooltip_size.y - offset_y
	
	# 确保不会超出左边界和上边界
	new_pos.x = max(margin, new_pos.x)
	new_pos.y = max(margin, new_pos.y)
	
	# 最终检查：如果tooltip太大，强制在屏幕范围内
	if new_pos.x + tooltip_size.x > viewport_size.x - margin:
		new_pos.x = viewport_size.x - tooltip_size.x - margin
	if new_pos.y + tooltip_size.y > viewport_size.y - margin:
		new_pos.y = viewport_size.y - tooltip_size.y - margin
	
	# 应用新位置
	tooltip.global_position = new_pos

# 🚀 修复：调整Panel大小以适应内容
func _adjust_tooltip_size() -> void:
	if not tooltip or not is_instance_valid(tooltip):
		return
	
	# 等待一帧让UI计算其真实大小
	await get_tree().process_frame
	
	# 🚀 修复：检查tooltip是否在异步操作期间被销毁
	if not tooltip or not is_instance_valid(tooltip):
		print("🎨 [Tooltip] 在等待过程中tooltip被销毁，停止大小调整")
		return
	
	# 获取VBoxContainer的内容大小
	var vbox = tooltip.get_node_or_null("VBoxContainer")
	if not vbox:
		print("⚠️ [Tooltip] 无法找到VBoxContainer")
		return
	
	# 让VBoxContainer重新计算其大小
	vbox.queue_sort()
	await get_tree().process_frame
	
	# 🚀 修复：再次检查tooltip是否在异步操作期间被销毁
	if not tooltip or not is_instance_valid(tooltip):
		print("🎨 [Tooltip] 在第二次等待过程中tooltip被销毁，停止大小调整")
		return
	
	# 获取VBoxContainer的最小大小
	var content_size = vbox.get_combined_minimum_size()
	
	# 添加padding（左右各10，上下各10）
	var panel_size = content_size + Vector2(20, 20)
	
	# 🚀 修复：最终检查tooltip是否仍然有效
	if not tooltip or not is_instance_valid(tooltip):
		print("🎨 [Tooltip] 在设置大小前tooltip被销毁")
		return
	
	# 设置Panel的大小
	tooltip.custom_minimum_size = panel_size
	tooltip.size = panel_size
	
	print("🎨 [Tooltip] 调整大小 - 内容大小: %s, Panel大小: %s" % [content_size, panel_size])

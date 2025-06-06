# 新的Player脚本 - 使用组件化架构
extends Node2D
class_name PlayerNew

# 预加载行动系统脚本
const ActionSystemScript = preload("res://Scripts/ActionSystemNew.gd")

# 核心节点引用
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var data: CharacterData = $Data

# 组件引用 - 直接引用场景中的节点
@onready var movement_component = $ComponentContainer/MovementComponent
@onready var input_component = $ComponentContainer/InputComponent
@onready var visuals_component = $ComponentContainer/VisualsComponent
@onready var ui_component = $ComponentContainer/UIComponent

# 初始化
func _init():
	set_process_input(true)  # 确保能接收输入

func _ready() -> void:
	# 初始化组件
	_initialize_components()
	
	# 设置基础动画
	animation.play("idle")
	
	# 根据角色类型添加到正确的组
	var character = get_character_data()
	if character:
		if character.is_ai_controlled():
			add_to_group("enemies")
		else:
			add_to_group("party_members")
		
		# 初始化角色位置
		character.position = position
		character.ground_position = position
	
	# 设置角色的碰撞区域
	_setup_collision_area()
	
	# 确保转换更新通知
	set_notify_transform(true)
	
	# 等待一帧后初始更新高度显示（确保组件完全初始化）
	await get_tree().process_frame
	if visuals_component:
		visuals_component.update_height_display()

# 初始化所有组件
func _initialize_components() -> void:
	print("开始初始化组件...")
	
	# 验证组件节点存在
	if not movement_component:
		push_error("未找到MovementComponent节点")
		return
	if not input_component:
		push_error("未找到InputComponent节点")
		return
	if not visuals_component:
		push_error("未找到VisualsComponent节点")
		return
	if not ui_component:
		push_error("未找到UIComponent节点")
		return
	
	# 设置组件（不再需要创建和添加子节点）
	movement_component.setup(self)
	input_component.setup(self)
	visuals_component.setup(self)
	ui_component.setup(self)
	
	# 连接组件信号
	_connect_component_signals()
	
	print("组件初始化完成（使用场景节点结构）")

# 连接组件间的信号
func _connect_component_signals() -> void:
	print("连接组件信号...")
	
	# 输入组件信号
	if input_component.mouse_entered.connect(_on_mouse_entered) != OK:
		print("警告：mouse_entered信号连接失败")
	if input_component.mouse_exited.connect(_on_mouse_exited) != OK:
		print("警告：mouse_exited信号连接失败")
	if input_component.action_menu_requested.connect(_on_action_menu_requested) != OK:
		print("警告：action_menu_requested信号连接失败")
	
	# UI组件信号
	if ui_component.action_selected.connect(_on_action_selected) != OK:
		print("警告：action_selected信号连接失败")
	if ui_component.menu_closed.connect(_on_menu_closed) != OK:
		print("警告：menu_closed信号连接失败")
	
	# 移动组件信号
	if movement_component.move_completed.connect(_on_move_completed) != OK:
		print("警告：move_completed信号连接失败")
	
	print("信号连接完成")

# 设置碰撞区域
func _setup_collision_area() -> void:
	var character_area = $CharacterArea
	if character_area:
		character_area.monitoring = true
		character_area.monitorable = true
		character_area.position = Vector2.ZERO
		
		# 添加碰撞检测信号
		character_area.area_entered.connect(_on_area_entered)
		character_area.area_exited.connect(_on_area_exited)
		print("碰撞区域设置完成")
	else:
		print("警告：未找到CharacterArea节点")

# 公共接口方法
func get_character_data() -> GameCharacter:
	if not data:
		print("⚠️ [PlayerNew] Data节点未初始化")
		return null
	return data.get_character()

func set_character_data(new_data: GameCharacter) -> void:
	# 设置新数据
	data.set_character(new_data)
	
	# 初始化位置
	if new_data:
		new_data.position = position
		new_data.ground_position = position
	
	# 通知组件更新
	if visuals_component:
		visuals_component.character_data = new_data
		visuals_component.update_height_display()
	
	if movement_component:
		movement_component.character_data = new_data
	
	if ui_component:
		ui_component.character_data = new_data

# 委托给移动组件的方法
func move_to(new_position: Vector2, target_height: float = 0.0) -> void:
	if movement_component:
		movement_component.move_to(new_position, target_height)
	else:
		print("错误：移动组件未初始化")

func set_base_position(base_pos: Vector2) -> void:
	if movement_component:
		movement_component.set_base_position(base_pos)
	if visuals_component:
		visuals_component.update_height_display()

func get_base_position() -> Vector2:
	if movement_component:
		return movement_component.get_base_position()
	return position

func show_move_range() -> void:
	if movement_component:
		movement_component.show_move_range()
	else:
		print("错误：移动组件未初始化")

# 输入处理 - 委托给输入组件
func _input(event) -> void:
	if input_component:
		input_component.handle_input(event)

# 信号处理函数
func _on_mouse_entered() -> void:
	# print("鼠标进入角色区域")  # 移除频繁打印
	if visuals_component:
		visuals_component.show_debug_rect()
	if ui_component:
		ui_component.show_tooltip()

func _on_mouse_exited() -> void:
	# print("鼠标离开角色区域")  # 移除频繁打印
	if visuals_component:
		visuals_component.hide_debug_rect()
	if ui_component:
		ui_component.hide_tooltip()

func _on_action_menu_requested() -> void:
	print("请求打开行动菜单")
	
	# 🚀 检查是否是当前回合的角色
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene and battle_scene.has_method("get_node_or_null"):
		var battle_manager = battle_scene.get_node_or_null("BattleManager")
		if battle_manager and battle_manager.turn_manager:
			var current_character = battle_manager.turn_manager.get_current_character()
			var my_character_data = get_character_data()
			if current_character and my_character_data and current_character != my_character_data:
				print("🚫 [角色节点] 非当前回合角色不能打开行动菜单：%s (当前回合：%s)" % [my_character_data.name, current_character.name])
				return
	
	if ui_component:
		ui_component.open_action_menu()

func _on_action_selected(action_type: String) -> void:
	print("选择行动: " + action_type)
	
	# 特殊处理移动行动
	if action_type == "move":
		# 在关闭菜单前先获取行动系统
		var battle_scene = AutoLoad.get_battle_scene()
		var action_system = battle_scene.get_node_or_null("ActionSystem") if battle_scene else null
		
		if action_system:
			print("找到行动系统，通知选择移动行动")
			# 先通知行动系统我们要移动
			action_system.select_action("move")
			# 通知系统选择当前角色
			action_system.selected_character = self
			
			# 然后关闭菜单，但不取消行动
			if ui_component and ui_component.current_open_menu and is_instance_valid(ui_component.current_open_menu):
				# 断开menu_closed信号，防止触发取消行动
				if ui_component.current_open_menu.is_connected("menu_closed", ui_component._on_menu_closed):
					ui_component.current_open_menu.menu_closed.disconnect(ui_component._on_menu_closed)
				ui_component.current_open_menu.close_menu()
				ui_component.current_open_menu = null
			# 注意：不需要手动调用show_move_range()，因为ActionSystem.select_action("move")会自动调用
		else:
			push_error("严重错误：无法找到行动系统！")
		return
		
	# 获取行动系统，通知行动选择
	var battle_scene = AutoLoad.get_battle_scene()
	var action_system = battle_scene.get_node_or_null("ActionSystem") if battle_scene else null
	
	if action_system:
		action_system.select_action(action_type)
	else:
		# 如果没有找到行动系统，则记录错误
		push_error("无法找到行动系统")

func _on_menu_closed() -> void:
	print("菜单关闭")
	# 🚀 修复：菜单关闭不应该自动取消行动
	# 只是简单记录菜单关闭事件，不进行任何行动取消操作
	# 行动的取消应该由用户明确的取消操作或其他逻辑触发

func _on_move_completed() -> void:
	print("移动完成")
	if visuals_component:
		visuals_component.update_height_display()

# 碰撞检测处理
func _on_area_entered(area: Area2D) -> void:
	# 跳过自己的区域
	var area_parent = area.get_parent()
	if area_parent == self:
		return
		
	# 检查是否为角色区域 - 添加类型检查
	if area_parent is Node and area_parent.is_in_group("party_members"):
		# 安全获取角色数据
		var self_data = null
		var other_data = null
		
		# 获取自己的数据
		var self_char_data = get_character_data() if has_method("get_character_data") else null
		if self_char_data:
			self_data = self_char_data.name
			
		# 安全获取其他角色的数据
		if area_parent.has_method("get_character_data"):
			var other_char_data = area_parent.get_character_data()
			if other_char_data:
				other_data = other_char_data.name
		
		print("角色 %s 与角色 %s 发生碰撞" % [
			self_data if self_data else "未知",
			other_data if other_data else "未知"
		])

func _on_area_exited(area: Area2D) -> void:
	# 跳过自己的区域
	var area_parent = area.get_parent()
	if area_parent == self:
		return
		
	# 检查是否为角色区域 - 添加类型检查
	if area_parent is Node and area_parent.is_in_group("party_members"):
		# 安全获取角色数据
		var self_data = null
		var other_data = null
		
		# 获取自己的数据
		var self_char_data = get_character_data() if has_method("get_character_data") else null
		if self_char_data:
			self_data = self_char_data.name
			
		# 安全获取其他角色的数据
		if area_parent.has_method("get_character_data"):
			var other_char_data = area_parent.get_character_data()
			if other_char_data:
				other_data = other_char_data.name
		
		print("角色 %s 离开角色 %s 碰撞区域" % [
			self_data if self_data else "未知",
			other_data if other_data else "未知"
		])
 

# 玩家输入组件
extends Node
class_name PlayerInputComponent

# 输入相关信号
signal mouse_entered()
signal mouse_exited()
signal clicked()
signal action_menu_requested()

# 引用
var player_node: Node2D
var character_data: GameCharacter

# 输入检测相关变量
var click_rect: Rect2 = Rect2(Vector2(-32, -32), Vector2(64, 64))  # 点击检测区域
var mouse_over: bool = false

func _init(player: Node2D = null):
	if player:
		setup(player)

func setup(player: Node2D) -> void:
	player_node = player
	if player.has_method("get_character_data"):
		character_data = player.get_character_data()
	
	# 启用输入处理
	player_node.set_process_input(true)

# 全局输入处理 - 适用于2D场景中的点击检测
func handle_input(event: InputEvent) -> void:
	# 获取鼠标位置并计算相对位置
	var mouse_pos = player_node.get_global_mouse_position()
	var local_pos = mouse_pos - player_node.global_position
	
	# 处理鼠标按钮事件
	if event is InputEventMouseButton:
		# 检查是否在点击区域内
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and click_rect.has_point(local_pos):
			_handle_click()
	
	# 处理鼠标移动事件 - 用于悬停检测
	if event is InputEventMouseMotion:
		_handle_mouse_motion(local_pos)

# 处理点击事件
func _handle_click() -> void:
	print("🔍 [输入组件] 角色 %s 被点击，开始检查" % (character_data.name if character_data else "未知"))
	
	# 🚀 添加控制类型检查：只有玩家控制的角色才能弹出菜单
	if not character_data or not character_data.is_player_controlled():
		print("🛡️ [输入组件] 敌人角色不响应点击菜单：%s" % (character_data.name if character_data else "未知"))
		return
	
	print("✅ [输入组件] 角色 %s 是玩家控制，继续检查回合" % character_data.name)
	
	# 🚀 检查是否是当前回合的角色
	var battle_scene = player_node.get_tree().current_scene
	print("🔍 [输入组件] 获取战斗场景：%s" % (battle_scene.name if battle_scene else "null"))
	
	if battle_scene and battle_scene.has_method("get_node_or_null"):
		var battle_manager = battle_scene.get_node_or_null("BattleManager")
		print("🔍 [输入组件] 获取战斗管理器：%s" % (battle_manager.name if battle_manager else "null"))
		
		if battle_manager and battle_manager.turn_manager:
			var current_character = battle_manager.turn_manager.get_current_character()
			print("🔍 [输入组件] 当前回合角色：%s，点击角色：%s" % [(current_character.name if current_character else "null"), character_data.name])
			
			if current_character and current_character != character_data:
				print("🚫 [输入组件] 非当前回合角色不响应点击：%s (当前回合：%s)" % [character_data.name, current_character.name])
				return
			else:
				print("✅ [输入组件] 当前回合角色检查通过：%s" % character_data.name)
		else:
			print("⚠️ [输入组件] 无法获取回合管理器，允许打开菜单")
	else:
		print("⚠️ [输入组件] 无法获取战斗场景，允许打开菜单")
	
	# 获取行动系统
	var action_system_script = preload("res://Scripts/ActionSystemNew.gd")
	var action_system = player_node.get_tree().current_scene.get_node_or_null("ActionSystem")
	
	if action_system and action_system.current_state == action_system_script.SystemState.SELECTING_CHARACTER:
		# 如果行动系统正在等待选择角色，则通知行动系统
		print("🎯 [输入组件] 行动系统正在选择角色，通知选择：%s" % character_data.name)
		action_system.select_character(player_node)
		clicked.emit()
	else:
		# 其他情况下，仅显示菜单
		print("🎮 [输入组件] 当前回合角色请求打开行动菜单：%s" % character_data.name)
		action_menu_requested.emit()

# 处理鼠标移动
func _handle_mouse_motion(local_pos: Vector2) -> void:
	# 鼠标悬停检测
	if click_rect.has_point(local_pos) and not mouse_over:
		_on_mouse_entered()
	elif not click_rect.has_point(local_pos) and mouse_over:
		_on_mouse_exited()

# 鼠标进入事件
func _on_mouse_entered() -> void:
	mouse_over = true
	mouse_entered.emit()

# 鼠标离开事件
func _on_mouse_exited() -> void:
	mouse_over = false
	mouse_exited.emit()

# 获取鼠标悬停状态
func is_mouse_over() -> bool:
	return mouse_over

class_name BattleActionCoordinator
extends RefCounted

## 战斗行动协调器
## 负责管理战斗场景中所有行动菜单、回合切换、AI行动等职责

# 组件引用
var battle_scene: Node2D
var action_system: Node
var battle_manager: Node
var character_manager: BattleCharacterManager
var battle_event_manager: BattleEventManager
var battle_ai_manager: BattleAIManager

# 状态管理
var action_coordinator_initialized: bool = false
var current_action_character: GameCharacter = null

## 初始化行动协调器
func initialize(scene: Node2D) -> void:
	print("🎯 [BattleActionCoordinator] 开始初始化行动协调器")
	battle_scene = scene
	
	# 获取组件引用
	action_system = scene.get_node("ActionSystem")
	battle_manager = scene.get_node("BattleManager")
	character_manager = scene.get_character_manager()
	battle_event_manager = scene.get_node("BattleSystems/BattleEventManager")
	battle_ai_manager = scene.get_node("BattleSystems/BattleAIManager")
	
	action_coordinator_initialized = true
	print("✅ [BattleActionCoordinator] 行动协调器初始化完成")

## 为指定角色节点打开行动菜单（从BattleScene迁移）
func open_character_action_menu(character_node: Node2D) -> void:
	print("\n=== 🎯 [BattleActionCoordinator] open_character_action_menu被调用 ===")
	print("🔍 [BattleActionCoordinator] 传入的character_node: %s" % character_node.name)
	print("🔍 [BattleActionCoordinator] 这是菜单自动打开的关键方法！")
	
	# 添加当前回合角色检查
	var character_data = character_node.get_character_data()
	var current_character = battle_manager.turn_manager.get_current_character()
	
	if current_character == null:
		print("🚫 [BattleActionCoordinator] 无法获取当前回合角色，可能回合队列为空或索引越界")
		return
	
	if current_character.id != character_data.id:
		print("🚫 [BattleActionCoordinator] 非当前回合角色请求打开行动菜单被拒绝：%s (当前回合：%s)" % [character_data.name, current_character.name])
		return
	
	print("✅ [BattleActionCoordinator] 当前回合角色请求打开行动菜单：%s" % character_data.name)
	
	# 重要：在打开菜单前，先设置ActionSystem的selected_character
	var ActionSystemScript = battle_scene.ActionSystemScript
	action_system.selected_character = character_node
	action_system.current_state = ActionSystemScript.SystemState.SELECTING_ACTION
	current_action_character = character_data
	print("🔧 [BattleActionCoordinator] 设置ActionSystem选中角色: %s" % character_node.get_character_data().name)
	
	# 尝试通过UI组件打开菜单
	print("🔍 [BattleActionCoordinator] 查找UI组件: ComponentContainer/UIComponent")
	var ui_component = character_node.get_node_or_null("ComponentContainer/UIComponent")
	print("🔍 [BattleActionCoordinator] UI组件查找结果: %s" % (ui_component.name if ui_component else "未找到"))
	
	if ui_component and ui_component.has_method("open_action_menu"):
		print("📞 [BattleActionCoordinator] 调用ui_component.open_action_menu()")
		ui_component.open_action_menu()
		print("✅ [BattleActionCoordinator] UI组件的open_action_menu()调用完成")
	else:
		print("⚠️ [BattleActionCoordinator] UI组件不存在或没有open_action_menu方法")
		# 备用方案：直接触发action_menu_requested信号
		if character_node.has_signal("action_menu_requested"):
			print("📞 [BattleActionCoordinator] 发送action_menu_requested信号")
			character_node.emit_signal("action_menu_requested")
			print("✅ [BattleActionCoordinator] action_menu_requested信号已发送")
		else:
			print("❌ [BattleActionCoordinator] 角色节点没有action_menu_requested信号")

## 切换到下一个角色（从BattleScene迁移）
func proceed_to_next_character() -> void:
	print("🎯 [BattleActionCoordinator] 切换到下一个角色")
	
	# 重置当前行动角色
	current_action_character = null
	
	# 委托给BattleEventManager处理
	if battle_event_manager and battle_event_manager.has_method("_proceed_to_next_character"):
		battle_event_manager._proceed_to_next_character()
	else:
		# 回退到原有逻辑
		battle_manager.turn_manager.next_turn()
		print("✅ [BattleActionCoordinator] 已切换到下一个角色")

## 执行AI角色的自动行动（从BattleScene迁移）
func execute_ai_action(ai_character: GameCharacter) -> void:
	print("🚀 [BattleActionCoordinator] execute_ai_action被调用，角色: %s" % ai_character.name)
	print("🔍 [BattleActionCoordinator] battle_manager.is_battle_active: %s" % battle_manager.is_battle_active)
	print("🔍 [BattleActionCoordinator] battle_manager.is_battle_in_progress(): %s" % battle_manager.is_battle_in_progress())
	
	# AI回合开始时，强制关闭所有玩家行动菜单
	force_close_all_player_menus()
	
	# 重要：确保AI角色的位置数据与节点同步
	var ai_node = find_character_node_by_character_data(ai_character)
	if ai_node:
		# 同步位置数据
		ai_character.position = ai_node.position
		print("🔧 [BattleActionCoordinator] 同步AI角色位置: %s -> %s" % [ai_character.name, ai_character.position])
	
	# 设置当前行动角色
	current_action_character = ai_character
	
	# 委托给BattleAIManager处理AI行动
	print("🤖 [BattleActionCoordinator] 委托给BattleAIManager处理AI行动")
	battle_ai_manager.execute_ai_turn(ai_character)

## 强制关闭所有玩家行动菜单
func force_close_all_player_menus() -> void:
	print("🎯 [BattleActionCoordinator] 强制关闭所有玩家行动菜单")
	
	# 通过character_manager获取所有玩家角色
	var player_characters = character_manager.get_party_members()
	for character in player_characters:
		var character_node = find_character_node_by_character_data(character)
		if character_node:
			var ui_component = character_node.get_node_or_null("ComponentContainer/UIComponent")
			if ui_component and ui_component.has_method("close_action_menu"):
				ui_component.close_action_menu()
				print("🔧 [BattleActionCoordinator] 关闭角色 %s 的行动菜单" % character.name)

## 查找角色数据对应的节点（从BattleScene迁移辅助方法）
func find_character_node_by_character_data(character_data: GameCharacter) -> Node2D:
	if not character_data:
		return null
	
	# 在Players容器中查找
	var players_container = battle_scene.get_node_or_null("Players")
	if players_container:
		for child in players_container.get_children():
			if child.has_method("get_character_data"):
				var char_data = child.get_character_data()
				if char_data and char_data.id == character_data.id:
					return child
	
	# 在TheLevel中查找（敌人）
	var the_level = battle_scene.get_node_or_null("TheLevel")
	if the_level:
		for child in the_level.get_children():
			if child.has_method("get_character_data"):
				var char_data = child.get_character_data()
				if char_data and char_data.id == character_data.id:
					return child
	
	return null

## 处理行动完成
func handle_action_completed(character: GameCharacter, action_result: Dictionary) -> void:
	print("🎯 [BattleActionCoordinator] 处理行动完成，角色: %s" % character.name)
	
	# 如果是当前行动角色，清除状态
	if current_action_character and current_action_character.id == character.id:
		current_action_character = null
	
	# 可以在这里添加行动完成后的额外逻辑
	print("✅ [BattleActionCoordinator] 行动完成处理结束")

## 处理行动菜单请求
func handle_action_menu_requested(character_node: Node2D = null) -> void:
	print("🎯 [BattleActionCoordinator] 处理行动菜单请求")
	
	if character_node:
		open_character_action_menu(character_node)
	else:
		# 如果没有指定角色，尝试为当前回合角色打开菜单
		var current_character = battle_manager.turn_manager.get_current_character()
		if current_character:
			var character_node_found = find_character_node_by_character_data(current_character)
			if character_node_found:
				open_character_action_menu(character_node_found)
			else:
				print("⚠️ [BattleActionCoordinator] 无法找到当前角色对应的节点")
		else:
			print("⚠️ [BattleActionCoordinator] 无法获取当前回合角色")

## 检查是否可以执行行动
func can_perform_action(character: GameCharacter) -> bool:
	# 检查是否是当前回合角色
	var current_character = battle_manager.turn_manager.get_current_character()
	if not current_character or current_character.id != character.id:
		return false
	
	# 检查战斗是否在进行中
	if not battle_manager.is_battle_in_progress():
		return false
	
	# 检查角色是否还有行动点
	if character.current_action_points <= 0:
		return false
	
	return true

## 获取当前行动角色
func get_current_action_character() -> GameCharacter:
	return current_action_character

## 设置当前行动角色
func set_current_action_character(character: GameCharacter) -> void:
	current_action_character = character
	print("🎯 [BattleActionCoordinator] 设置当前行动角色: %s" % (character.name if character else "null"))

## 重置行动状态
func reset_action_state() -> void:
	current_action_character = null
	print("🎯 [BattleActionCoordinator] 重置行动状态")

## 检查协调器是否已初始化
func is_initialized() -> bool:
	return action_coordinator_initialized 
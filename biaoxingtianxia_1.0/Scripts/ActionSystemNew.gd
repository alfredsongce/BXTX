extends Node
class_name ActionSystem

# 行动类型枚举
enum ActionType {MOVE, SKILL, ITEM, SPECIAL, REST}

# 系统状态
enum SystemState {IDLE, SELECTING_CHARACTER, SELECTING_ACTION, SELECTING_MOVE_TARGET, SELECTING_ATTACK_TARGET, EXECUTING_ACTION}

# 当前状态
var current_state: SystemState = SystemState.IDLE

# 当前选中的角色
var selected_character = null

# 当前选择的行动
var current_action = null

# 🚀 新增：角色行动点数管理
var character_action_points: Dictionary = {}  # 每个角色的行动点数记录

# 每回合基础行动点数配置
const BASE_MOVE_POINTS: int = 1
const BASE_ATTACK_POINTS: int = 1

# 初始化
func _init():
	pass

# 准备工作 - 连接移动范围显示器的信号
func _ready():
	print("📋 [行动系统] 行动系统初始化...")
	
	# 🚀 新架构：连接到MoveRange/Controller
	var move_range_controller = get_node_or_null("../MoveRange/Controller")
	if move_range_controller:
		# 确保不重复连接信号
		if not move_range_controller.is_connected("move_confirmed", _on_move_confirmed_new):
			move_range_controller.connect("move_confirmed", _on_move_confirmed_new)
			print("✅ [行动系统] 成功连接移动确认信号")
	else:
		push_warning("⚠️ [行动系统] 未找到移动范围控制器，无法连接信号")

# 🚀 新增：初始化角色行动点数
func initialize_character_action_points(character: GameCharacter) -> void:
	if not character:
		return
	
	var character_id = character.id
	character_action_points[character_id] = {
		"move_points": BASE_MOVE_POINTS,
		"attack_points": BASE_ATTACK_POINTS,
		"has_acted": false
	}
	
	print("🎯 [行动系统] 初始化角色 %s 的行动点数：移动%d，攻击%d" % [
		character.name, BASE_MOVE_POINTS, BASE_ATTACK_POINTS
	])

# 🚀 新增：获取角色剩余行动点数
func get_character_action_points(character: GameCharacter) -> Dictionary:
	if not character:
		return {"move_points": 0, "attack_points": 0, "has_acted": true}
	
	var character_id = character.id
	if not character_action_points.has(character_id):
		initialize_character_action_points(character)
	
	return character_action_points[character_id]

# 🚀 新增：检查角色是否还能进行指定行动
func can_character_perform_action(character: GameCharacter, action_type: String) -> bool:
	var points = get_character_action_points(character)
	
	match action_type:
		"move":
			return points.move_points > 0
		"skill", "attack":
			return points.attack_points > 0
		"item", "special":
			return points.attack_points > 0  # 道具和特殊行动消耗攻击点数
		"rest":
			return true  # 休息总是可用
		_:
			return false

# 🚀 新增：消耗角色行动点数
func consume_action_points(character: GameCharacter, action_type: String) -> bool:
	if not character:
		return false
	
	var character_id = character.id
	if not character_action_points.has(character_id):
		initialize_character_action_points(character)
	
	var points = character_action_points[character_id]
	
	match action_type:
		"move":
			if points.move_points > 0:
				points.move_points -= 1
				print("📉 [行动系统] %s 消耗移动点数，剩余：%d" % [character.name, points.move_points])
				return true
		"skill", "attack":
			if points.attack_points > 0:
				points.attack_points -= 1
				print("📉 [行动系统] %s 消耗攻击点数，剩余：%d" % [character.name, points.attack_points])
				return true
		"item", "special":
			if points.attack_points > 0:
				points.attack_points -= 1
				print("📉 [行动系统] %s 消耗攻击点数（%s），剩余：%d" % [character.name, action_type, points.attack_points])
				return true
		"rest":
			# 休息消耗所有剩余点数，强制结束回合
			points.move_points = 0
			points.attack_points = 0
			points.has_acted = true
			print("😴 [行动系统] %s 选择休息，结束回合" % character.name)
			return true
	
	return false

# 🚀 新增：检查角色回合是否结束
func is_character_turn_finished(character: GameCharacter) -> bool:
	var points = get_character_action_points(character)
	return points.move_points <= 0 and points.attack_points <= 0

# 🚀 新增：重置角色行动点数（新回合开始时调用）
func reset_character_action_points(character: GameCharacter) -> void:
	if not character:
		return
	
	initialize_character_action_points(character)
	print("🔄 [行动系统] 重置角色 %s 的行动点数" % character.name)

# 开始行动选择
func start_action_selection():
	if current_state != SystemState.IDLE:
		print("⚠️ [行动系统] 行动系统正忙，无法开始新的行动选择")
		return
		
	current_state = SystemState.SELECTING_CHARACTER
	print("🎯 [行动系统] 请选择一个角色进行行动")

# 处理角色选择
func select_character(character):
	if current_state != SystemState.SELECTING_CHARACTER:
		print("⚠️ [行动系统] 当前状态不允许选择角色")
		return
		
	selected_character = character
	current_state = SystemState.SELECTING_ACTION
	
	# 🚀 显示角色剩余行动点数
	var character_data = null
	if character and character.has_method("get_character_data"):
		character_data = character.get_character_data()
	
	if character_data:
		var points = get_character_action_points(character_data)
		print("🎯 [行动系统] 已选择角色: %s，剩余行动点数：移动%d，攻击%d" % [
			character_data.name, points.move_points, points.attack_points
		])
	
	print("📋 [行动系统] 请选择行动类型")

# 处理行动选择
func select_action(action: String):
	# 检查当前状态
	if current_state != SystemState.SELECTING_ACTION and current_state != SystemState.IDLE:
		print("⚠️ [行动系统] 当前状态(%s)不允许选择行动，需要状态: SELECTING_ACTION或IDLE" % SystemState.keys()[current_state])
		return
		
	print("📋 [行动系统] 选择行动类型 [%s]，当前状态: %s" % [action, SystemState.keys()[current_state]])
	current_action = action
	
	# 🚀 获取角色数据并检查行动点数
	var character_data = null
	if selected_character and selected_character.has_method("get_character_data"):
		character_data = selected_character.get_character_data()
	
	if character_data:
		# 检查是否还能进行该行动
		if not can_character_perform_action(character_data, action):
			var points = get_character_action_points(character_data)
			print("⚠️ [行动系统] %s 无法进行 %s 行动，剩余点数：移动%d，攻击%d" % [
				character_data.name, action, points.move_points, points.attack_points
			])
			reset_action_system()
			return
	
	# 处理不同的行动类型
	match action:
		"move":
			# 进入移动目标选择状态
			current_state = SystemState.SELECTING_MOVE_TARGET
			print("🚶 [行动系统] 进入移动目标选择状态")
			
			# 显示移动范围
			if selected_character and selected_character.has_method("show_move_range"):
				selected_character.show_move_range()
			return
		
		"skill":
			# 🚀 使用新的SkillManager处理技能
			current_state = SystemState.EXECUTING_ACTION
			print("⚔️ [行动系统] 委托给SkillManager处理技能")
			
			if character_data:
				# 委托给BattleScene处理技能选择，但保持ActionSystem状态等待技能选择结果
				var battle_scene = AutoLoad.get_battle_scene()
				if battle_scene and battle_scene.has_method("show_skill_menu"):
					print("🎯 [行动系统] 委托BattleScene处理技能选择")
					print("🔧 [行动系统] 调用参数: character_data=%s" % character_data.name)
					# 实际调用show_skill_menu方法
					battle_scene.show_skill_menu(character_data)
					print("✅ [行动系统] show_skill_menu调用完成")
					# 不要重置状态，等待技能选择的结果
					return
				else:
					print("❌ [行动系统] 无法找到BattleScene或show_skill_menu方法")
				reset_action_system()
			else:
				print("⚠️ [行动系统] 无法获取角色数据")
				reset_action_system()
			return
		
		"rest":
			# 🚀 休息行动：结束当前角色的回合
			print("😴 [行动系统] 执行休息行动")
			current_state = SystemState.EXECUTING_ACTION
			_execute_rest_action()
			return
		
		_:
			# 其他行动类型直接执行
			current_state = SystemState.EXECUTING_ACTION
			print("🎬 [行动系统] 执行行动: %s" % action)
			
			# 🚀 为非移动行动发出完成信号
			_execute_non_move_action(action)

# 🚀 新增：输出回合状态调试信息的辅助函数
func _print_turn_debug_info(context: String):
	print("\n=== 🔍 [%s] 回合状态调试信息 ===" % context)
	var battle_scene = AutoLoad.get_battle_scene()
	var battle_manager = battle_scene.get_node_or_null("BattleManager") if battle_scene else null
	if battle_manager and battle_manager.turn_manager:
		var turn_manager = battle_manager.turn_manager
		print("📊 [调试] 当前回合: %d" % turn_manager.get_current_turn())
		print("📊 [调试] 当前角色索引: %d" % turn_manager.current_character_index)
		print("📊 [调试] 回合队列大小: %d" % turn_manager.turn_queue.size())
		
		var current_character = turn_manager.get_current_character()
		if current_character:
			print("📊 [调试] 当前角色: %s (控制类型: %d)" % [current_character.name, current_character.control_type])
			var points = get_character_action_points(current_character)
			print("📊 [调试] 行动点数：移动%d，攻击%d" % [points.move_points, points.attack_points])
		else:
			print("📊 [调试] 当前角色: null")
		
		print("📊 [调试] 回合队列:")
		for i in range(turn_manager.turn_queue.size()):
			var char = turn_manager.turn_queue[i]
			var is_current = (i == turn_manager.current_character_index)
			var char_type = "友方" if char.is_player_controlled() else "敌方"
			var marker = "👉 " if is_current else "   "
			print("📊 [调试] %s%d. %s (%s) - HP: %d/%d" % [marker, i, char.name, char_type, char.current_hp, char.max_hp])
		
		print("📊 [调试] 战斗状态: is_battle_active = %s" % battle_manager.is_battle_active)
		print("📊 [调试] ActionSystem状态: %s" % ActionSystem.SystemState.keys()[current_state])
	else:
		print("⚠️ [调试] BattleManager或TurnManager未找到")
	print("=== [%s] 调试信息结束 ===\n" % context)

# 🚀 新增：执行休息行动
func _execute_rest_action():
	# 获取当前角色数据
	var character_data = null
	if selected_character and selected_character.has_method("get_character_data"):
		character_data = selected_character.get_character_data()
	
	if character_data:
		# 消耗所有剩余行动点数
		consume_action_points(character_data, "rest")
		
		# 🚀 添加调试信息
		_print_turn_debug_info("休息行动完成")
		
		# 创建行动结果
		var action_result = {
			"type": "rest",
			"success": true,
			"message": "选择了休息，回合结束"
		}
		
		# 🚀 通知BattleManager行动完成
		var battle_scene = AutoLoad.get_battle_scene()
		var battle_manager = battle_scene.get_node_or_null("BattleManager") if battle_scene else null
		if battle_manager and character_data:
			print("😴 [行动系统] 通知BattleManager休息行动完成")
			print("😴 [行动系统] 角色: %s, 休息结束回合" % character_data.name)
			battle_manager.character_action_completed.emit(character_data, action_result)
			print("✅ [行动系统] character_action_completed信号已发出（休息）")
		else:
			print("⚠️ [行动系统] 无法通知BattleManager：管理器不存在")
	
	# 完成行动后重置
	reset_action_system()

# 🚀 执行非移动行动并发出完成信号
func _execute_non_move_action(action: String):
	# 获取当前角色数据
	var character_data = null
	if selected_character and selected_character.has_method("get_character_data"):
		character_data = selected_character.get_character_data()
	
	if character_data:
		# 🚀 消耗对应的行动点数
		if not consume_action_points(character_data, action):
			print("⚠️ [行动系统] 无法消耗行动点数，取消行动")
			reset_action_system()
			return
	
	# 创建行动结果
	var action_result = {
		"type": action,
		"success": true,
		"message": ""
	}
	
	# 这里只是模拟执行行动
	match action:
		"skill":
			action_result.message = "使用了技能"
		"item":
			action_result.message = "使用了道具"
		"special":
			action_result.message = "使用了特殊技能"
		_:
			action_result.message = "执行了未知行动"
	
	# 🚀 通知BattleManager行动完成
	var battle_scene = AutoLoad.get_battle_scene()
	var battle_manager = battle_scene.get_node_or_null("BattleManager") if battle_scene else null
	if battle_manager and character_data:
	# 🚀 检查角色回合是否结束
		if is_character_turn_finished(character_data):
			print("🕐 [信号追踪] 时间戳: %s" % Time.get_datetime_string_from_system())
			print("🎯 [信号追踪] 来源: ACTION_SYSTEM_NON_MOVE")
			print("✅ [行动系统] 角色 %s 行动点数耗尽，回合结束" % character_data.name)
			print("🎯 [行动系统] 这应该会触发下一个角色的回合")
			battle_manager.character_action_completed.emit(character_data, action_result)
		reset_action_system()
	else:
		# 如果还有行动点数，继续显示行动菜单
		if character_data:
			var points = get_character_action_points(character_data)
			print("🔄 [行动系统] 角色 %s 还有行动点数：移动%d，攻击%d，继续行动" % [
				character_data.name, points.move_points, points.attack_points
			])
			# 重置状态但保持选中角色
			current_state = SystemState.SELECTING_ACTION
	
	# 🚀 新增：自动输出回合状态调试信息
	_print_turn_debug_info("非移动行动完成后")

# 🚀 新的移动确认处理 - 适配新架构的信号格式
func _on_move_confirmed_new(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float):
	print("🚶 [行动系统] 收到移动确认信号: 角色=%s, 位置=%s, 高度=%.1f级" % [character.name, target_position, target_height])
	
	# 检查状态是否正确
	if current_state != SystemState.SELECTING_MOVE_TARGET:
		print("⚠️ [行动系统] 当前状态(%s)不允许确认移动，需要状态: %s" % [
			SystemState.keys()[current_state], 
			SystemState.keys()[SystemState.SELECTING_MOVE_TARGET]
		])
		return
	
	# 🚀 消耗移动点数
	if not consume_action_points(character, "move"):
		print("⚠️ [行动系统] 无法消耗移动点数，取消移动")
		reset_action_system()
		return
	
	print("✅ [行动系统] 确认移动: 角色=%s, 位置=%s, 高度=%.1f" % [character.name, target_position, target_height])
	
	# 🚀 修复：移除重复的移动处理，让BattleScene统一处理移动动画
	# 原来的代码会导致双重移动处理，产生残影问题
	# selected_character.move_to(target_position)
	
	# 🚀 直接调用MovementCoordinator处理移动动画
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene:
		var movement_coordinator = battle_scene.get_node_or_null("BattleSystems/MovementCoordinator")
		if movement_coordinator and movement_coordinator.has_method("_on_move_confirmed"):
			print("📞 [ActionSystem] 调用MovementCoordinator处理移动")
			movement_coordinator._on_move_confirmed(character, target_position, target_height, movement_cost)
		else:
			print("❌ [ActionSystem] MovementCoordinator不可用，路径: BattleSystems/MovementCoordinator")
			print("🔍 [ActionSystem] MovementCoordinator存在检查: %s" % (movement_coordinator != null))
			if movement_coordinator:
				print("🔍 [ActionSystem] MovementCoordinator方法检查: %s" % movement_coordinator.has_method("_on_move_confirmed"))
	else:
		print("❌ [ActionSystem] BattleScene不可用")
	
	# 🚀 检查角色回合是否结束
	if is_character_turn_finished(character):
		print("🕐 [信号追踪] 时间戳: %s" % Time.get_datetime_string_from_system())
		print("🎯 [信号追踪] 来源: ACTION_SYSTEM_MOVE")
		print("✅ [行动系统] 角色 %s 移动后行动点数耗尽，回合结束" % character.name)
		print("🎯 [行动系统] 发出移动完成+回合结束信号")
		
		# 🚀 发出行动完成信号（移动版本）
		var move_end_result = {
			"type": "move_and_turn_end",
			"success": true,
			"message": "移动完成且回合结束",
			"final_position": target_position,
			"final_height": target_height
		}
		
		var battle_manager_scene = AutoLoad.get_battle_scene()
		var battle_manager = battle_manager_scene.get_node_or_null("BattleManager") if battle_manager_scene else null
		if battle_manager:
			battle_manager.character_action_completed.emit(character, move_end_result)
			
		reset_action_system()
	else:
		# 移动完成但回合未结束，重置到选择行动状态
		print("🔄 [行动系统] 角色 %s 移动完成但回合未结束，继续选择行动" % character.name)
		current_state = SystemState.SELECTING_ACTION
		
		# 🚀 发出移动完成信号（非回合结束版本）
		var move_result = {
			"type": "move_only",
			"success": true,
			"message": "移动完成，回合继续",
			"final_position": target_position,
			"final_height": target_height
		}
		
		var battle_manager_scene2 = AutoLoad.get_battle_scene()
		var battle_manager = battle_manager_scene2.get_node_or_null("BattleManager") if battle_manager_scene2 else null
		if battle_manager:
			print("🕐 [信号追踪] 时间戳: %s" % Time.get_datetime_string_from_system())
			print("🎯 [信号追踪] 来源: ACTION_SYSTEM_MOVE_ONLY")
			battle_manager.character_action_completed.emit(character, move_result)
	
	# 🚀 新增：自动输出回合状态调试信息
	_print_turn_debug_info("移动确认后")

# 取消当前行动
func cancel_action():
	print("❌ [行动系统] 取消当前行动")
	reset_action_system()

# 🚀 新增：技能选择取消处理
func on_skill_selection_cancelled():
	print("🔙 [行动系统] 技能选择已取消")
	
	# 如果当前状态是EXECUTING_ACTION，恢复到SELECTING_ACTION状态
	if current_state == SystemState.EXECUTING_ACTION:
		current_state = SystemState.SELECTING_ACTION
		print("🔄 [行动系统] 状态从 EXECUTING_ACTION 恢复到 SELECTING_ACTION")
	
	# 确保选中角色状态正确
	if not selected_character:
		# 尝试从回合管理器获取当前角色
		var battle_scene = AutoLoad.get_battle_scene()
		var battle_manager = battle_scene.get_node_or_null("BattleManager") if battle_scene else null
		if battle_manager and battle_manager.turn_manager:
			var current_character_data = battle_manager.turn_manager.get_current_character()
			if current_character_data:
				# 通过角色数据找到对应的节点
				var character_node = _find_character_node_by_character_data(current_character_data)
				if character_node:
					selected_character = character_node
					print("🔧 [行动系统] 重新设置选中角色: %s" % current_character_data.name)
	
	print("✅ [行动系统] 技能选择取消处理完成，当前状态: %s" % SystemState.keys()[current_state])

# 🚀 辅助方法：通过角色数据查找角色节点
func _find_character_node_by_character_data(character_data: GameCharacter):
	var battle_scene = AutoLoad.get_battle_scene()
	if not battle_scene:
		return null
	
	var character_manager = battle_scene.get_node_or_null("CharacterManager")
	if not character_manager:
		return null
	
	# 在友方角色中查找
	var ally_nodes = character_manager.get_party_member_nodes()
	for ally_id in ally_nodes:
		var ally_node = ally_nodes[ally_id]
		if ally_node and ally_node.get_character_data() == character_data:
			return ally_node
	
	# 在敌方角色中查找
	var enemy_nodes = character_manager.get_enemy_nodes()
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node and enemy_node.get_character_data() == character_data:
			return enemy_node
	
	return null

# 重置系统状态
func reset_action_system():
	current_state = SystemState.IDLE
	selected_character = null
	current_action = null
	print("🔄 [行动系统] 行动系统已重置，等待下一次行动")

# 🚀 新增：开始新回合（由BattleManager调用）
func start_new_turn_for_character(character: GameCharacter):
	print("🎯 [ActionSystem] start_new_turn_for_character被调用")
	print("🔍 [ActionSystem] 传入角色: %s" % (character.name if character else "null"))
	print("🔍 [ActionSystem] 当前状态: %s" % current_state)
	
	if not character:
		print("❌ [ActionSystem] 角色为空，返回")
		return
	
	# 重置该角色的行动点数
	print("🔧 [ActionSystem] 重置角色行动点数")
	reset_character_action_points(character)
	
	# 设置系统状态
	current_state = SystemState.SELECTING_ACTION
	selected_character = null  # 这里先清空，等待UI组件设置
	current_action = null
	
	print("🎯 [ActionSystem] 开始角色 %s 的新回合，状态设置为: %s" % [character.name, current_state])

# 🚀 新增：获取角色行动状态信息（用于UI显示）
func get_character_action_status(character: GameCharacter) -> String:
	if not character:
		return "无效角色"
	
	var points = get_character_action_points(character)
	var status_parts = []
	
	if points.move_points > 0:
		status_parts.append("移动")
	if points.attack_points > 0:
		status_parts.append("攻击")
	
	if status_parts.is_empty():
		return "行动结束"
	else:
		return "可进行: " + ", ".join(status_parts)

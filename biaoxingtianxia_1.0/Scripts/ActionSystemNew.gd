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
				# 委托给BattleScene处理技能选择
				var battle_scene = AutoLoad.get_battle_scene()
				# if battle_scene and battle_scene.has_method("show_skill_selection_menu"):  # 已移除SkillSelectionMenu
				#	var skill_manager = battle_scene.get_node_or_null("SkillManager")
				#	if skill_manager:
				#		print("🎯 [行动系统] 获取角色可用技能")
				#		var available_skills = skill_manager.get_available_skills(character_data)
				#		print("🎯 [行动系统] 委托BattleScene处理技能选择")
				#		battle_scene.show_skill_selection_menu(character_data, available_skills)
				#	else:
				#		print("❌ [行动系统] SkillManager不存在")
				#		reset_action_system()
				# else:
				#	print("❌ [行动系统] 无法找到BattleScene或show_skill_selection_menu方法")
				#	reset_action_system()
				
				# 已移除SkillSelectionMenu，现在使用VisualSkillSelector进行技能选择
				print("⚠️ [行动系统] SkillSelectionMenu已移除，请使用VisualSkillSelector进行技能选择")
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

# 🚀 新增：执行休息行动
func _execute_rest_action():
	# 获取当前角色数据
	var character_data = null
	if selected_character and selected_character.has_method("get_character_data"):
		character_data = selected_character.get_character_data()
	
	if character_data:
		# 消耗所有剩余行动点数
		consume_action_points(character_data, "rest")
		
		# 创建行动结果
		var action_result = {
			"type": "rest",
			"success": true,
			"message": "选择了休息，回合结束"
		}
		
		# 🚀 通知BattleManager行动完成
		var battle_scene = AutoLoad.get_battle_scene()
		var battle_manager = battle_scene.get_node_or_null("BattleManager") if battle_scene else null
		if battle_manager:
			print("😴 [行动系统] 通知BattleManager休息行动完成")
			battle_manager.character_action_completed.emit(character_data, action_result)
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
		print("🎯 [行动系统] 通知BattleManager行动完成: %s" % action_result.message)
		battle_manager.character_action_completed.emit(character_data, action_result)
	else:
		print("⚠️ [行动系统] 无法通知BattleManager：管理器或角色数据不存在")
	
	# 🚀 检查角色回合是否结束
	if character_data and is_character_turn_finished(character_data):
		print("✅ [行动系统] 角色 %s 行动点数耗尽，回合结束" % character_data.name)
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
	# selected_character.move_to(target_position, target_height) # 已删除
	print("🚶 [行动系统] 移动处理已委托给BattleScene")
	
	# 🚀 移动完成后，检查是否还有行动点数
	if is_character_turn_finished(character):
		print("✅ [行动系统] 角色 %s 行动点数耗尽，回合结束" % character.name)
		current_state = SystemState.IDLE
		selected_character = null
		current_action = null
	else:
		# 还有行动点数，可以继续行动
		var points = get_character_action_points(character)
		print("🔄 [行动系统] 角色 %s 移动完成，剩余行动点数：移动%d，攻击%d" % [
			character.name, points.move_points, points.attack_points
		])
		# 重置状态到行动选择，让玩家可以继续选择其他行动
		current_state = SystemState.SELECTING_ACTION

# 取消当前行动
func cancel_action():
	print("❌ [行动系统] 取消当前行动")
	reset_action_system()

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

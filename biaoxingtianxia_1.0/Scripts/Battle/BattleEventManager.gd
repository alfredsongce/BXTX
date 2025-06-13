# =============================================================================
# BattleEventManager.gd
# 战斗事件管理器 - 负责处理和协调各种战斗事件
# =============================================================================

class_name BattleEventManager
extends Node

# 🚀 事件类型枚举
enum EventType {
	SKILL_EXECUTION_COMPLETED,
	SKILL_CANCELLED,
	VISUAL_SKILL_CAST_COMPLETED,
	VISUAL_SKILL_SELECTION_CANCELLED,
	CHARACTER_ACTION_COMPLETED,
	MOVE_ANIMATION_COMPLETED,
	NEXT_CHARACTER_REQUESTED,
	ANIMATION_COMPLETED
}

# 🚀 组件引用
var battle_scene: Node
var battle_manager: Node
var battle_ui_manager: Node
var skill_manager: Node
var skill_selection_coordinator: Node
var movement_coordinator: Node
var battle_combat_manager: Node
var character_manager: Node
var battle_flow_manager: Node
var battle_ai_manager: Node

# 🚀 事件处理状态
var is_processing_event: bool = false
var event_queue: Array = []
var debug_enabled: bool = false

# 🚀 信号定义
signal event_processed(event_type: EventType, event_data: Dictionary)
signal event_queue_empty()
signal event_processing_started()
signal event_processing_completed()

# 🚀 初始化
func _ready() -> void:
	_find_component_references()
	_connect_signals()
	if debug_enabled:
		print("[BattleEventManager] 初始化完成")

func _find_component_references() -> void:
	"""查找组件引用"""
	# 查找BattleScene
	battle_scene = AutoLoad.get_battle_scene()
	if not battle_scene:
		battle_scene = get_parent()
	
	# 查找其他组件
	battle_manager = get_node_or_null("../../BattleManager")
	battle_ui_manager = get_node_or_null("../BattleUIManager")
	skill_manager = get_node_or_null("../../SkillManager")
	skill_selection_coordinator = get_node_or_null("../SkillSelectionCoordinator")
	movement_coordinator = get_node_or_null("../MovementCoordinator")
	battle_combat_manager = get_node_or_null("../BattleCombatManager")
	character_manager = get_node_or_null("../CharacterManager")
	battle_flow_manager = get_node_or_null("../BattleFlowManager")
	battle_ai_manager = get_node_or_null("../BattleAIManager")

func _connect_signals() -> void:
	"""连接信号"""
	# 连接各组件的事件信号
	print("🔧 [事件管理器] 开始连接信号")
	print("🔧 [事件管理器] skill_manager节点: ", skill_manager)
	if skill_manager:
		print("🔧 [事件管理器] skill_manager找到，开始连接信号")
		if skill_manager.has_signal("skill_execution_completed"):
			skill_manager.skill_execution_completed.connect(_on_skill_execution_completed)
			print("✅ [事件管理器] skill_execution_completed信号连接成功")
		else:
			print("❌ [事件管理器] skill_execution_completed信号不存在")
		if skill_manager.has_signal("skill_cancelled"):
			skill_manager.skill_cancelled.connect(_on_skill_cancelled)
			print("✅ [事件管理器] skill_cancelled信号连接成功")
	else:
		print("❌ [事件管理器] skill_manager节点未找到")
	
	if skill_selection_coordinator:
		if skill_selection_coordinator.has_signal("visual_skill_cast_completed"):
			skill_selection_coordinator.visual_skill_cast_completed.connect(_on_visual_skill_cast_completed)
		if skill_selection_coordinator.has_signal("visual_skill_selection_cancelled"):
			skill_selection_coordinator.visual_skill_selection_cancelled.connect(_on_visual_skill_selection_cancelled)
	
	if movement_coordinator:
		if movement_coordinator.has_signal("move_animation_completed"):
			movement_coordinator.move_animation_completed.connect(_on_move_animation_completed)
	
	if battle_manager:
		if battle_manager.has_signal("character_action_completed"):
			battle_manager.character_action_completed.connect(_on_character_action_completed)
	
	# 注意：不再连接BattleFlowManager的next_character_requested信号，避免重复触发
	# BattleFlowManager会直接调用battle_manager处理回合切换
	if battle_flow_manager:
		print("🔧 [事件管理器] battle_flow_manager找到，但不连接next_character_requested信号")
	else:
		print("❌ [事件管理器] battle_flow_manager节点未找到")
	
	# 🚀 连接AI管理器信号
	if battle_ai_manager:
		if battle_ai_manager.has_signal("ai_action_completed"):
			battle_ai_manager.ai_action_completed.connect(_on_ai_action_completed)
			print("✅ [事件管理器] ai_action_completed信号连接成功")
		else:
			print("❌ [事件管理器] ai_action_completed信号不存在")
	else:
		print("❌ [事件管理器] battle_ai_manager节点未找到")

# 🚀 事件处理函数
# 注意：已移除_on_next_character_requested_from_flow_manager函数，避免重复触发

func _on_skill_execution_completed(skill: SkillData, results: Dictionary, caster: GameCharacter) -> void:
	"""技能执行完成事件处理"""
	if debug_enabled:
		print("📡 [BattleEventManager] 接收到技能执行完成信号: %s, 施法者: %s" % [skill.name if skill else "null", caster.name if caster else "null"])
	
	var event_data = {
		"skill": skill,
		"results": results,
		"caster": caster
	}
	_queue_event(EventType.SKILL_EXECUTION_COMPLETED, event_data)
	
	if debug_enabled:
		print("📋 [BattleEventManager] 技能执行完成事件已加入队列")

func _on_skill_cancelled() -> void:
	"""技能取消事件处理"""
	var event_data = {}
	_queue_event(EventType.SKILL_CANCELLED, event_data)

func _on_visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	"""视觉技能施放完成事件处理"""
	var event_data = {
		"skill": skill,
		"caster": caster,
		"targets": targets
	}
	_queue_event(EventType.VISUAL_SKILL_CAST_COMPLETED, event_data)

func _on_visual_skill_selection_cancelled() -> void:
	"""视觉技能选择取消事件处理"""
	var event_data = {}
	_queue_event(EventType.VISUAL_SKILL_SELECTION_CANCELLED, event_data)

func _on_character_action_completed(character: GameCharacter, action_result: Dictionary) -> void:
	print("🕐 [信号接收] 时间戳: %s" % Time.get_datetime_string_from_system())
	print("📡 [BattleEventManager] 收到character_action_completed信号")
	print("🔍 [信号分析] 角色: %s" % (character.name if character else "null"))
	print("🔍 [信号分析] 行动类型: %s" % action_result.get("type", "unknown"))
	print("🔍 [信号分析] 行动消息: %s" % action_result.get("message", "无消息"))
	
	# 🚀 分析可能的信号来源
	var action_type = action_result.get("type", "")
	match action_type:
		"skill":
			print("🎯 [信号分析] 这是技能完成信号，来源可能是: BattleCombatManager")
		"move_and_turn_end":
			print("🎯 [信号分析] 这是移动+回合结束信号，来源可能是: ActionSystemNew")
		"move_only":
			print("🎯 [信号分析] 这是仅移动信号，来源可能是: ActionSystemNew")
		"rest":
			print("🎯 [信号分析] 这是休息信号，来源可能是: ActionSystemNew")
		_:
			print("🎯 [信号分析] 未知的行动类型: %s" % action_type)
	
	# 🚀 检查是否应该切换回合
	var should_switch_turn = false
	match action_type:
		"skill", "rest", "move_and_turn_end":
			should_switch_turn = true
			print("✅ [回合判断] 这个行动会结束回合，应该切换到下一个角色")
		"move_only":
			should_switch_turn = false
			print("🔄 [回合判断] 这是移动行动，回合不结束，不切换角色")
		_:
			should_switch_turn = true
			print("❓ [回合判断] 未知类型，默认切换回合")
	
	if should_switch_turn:
		print("🎯 [BattleEventManager] 即将调用request_next_character()")
		request_next_character()
	else:
		print("⏸️ [BattleEventManager] 回合不结束，不调用request_next_character()")

# 🚀 AI行动完成处理
func _on_ai_action_completed(ai_character: GameCharacter, result: Dictionary) -> void:
	print("🕐 [AI信号接收] 时间戳: %s" % Time.get_datetime_string_from_system())
	print("📡 [BattleEventManager] 收到ai_action_completed信号")
	print("🔍 [AI信号分析] 角色: %s" % (ai_character.name if ai_character else "null"))
	print("🔍 [AI信号分析] 行动类型: %s" % result.get("type", "unknown"))
	print("🔍 [AI信号分析] 行动消息: %s" % result.get("message", "无消息"))
	print("🔍 [AI信号分析] 执行的行动: %s" % str(result.get("actions", [])))
	
	# AI回合完成，总是切换到下一个角色
	print("✅ [AI回合判断] AI回合完成，切换到下一个角色")
	print("🎯 [BattleEventManager] AI回合结束，即将调用request_next_character()")
	request_next_character()

func _on_move_animation_completed(character_node: Node2D, character_id: String, final_position: Vector2) -> void:
	"""移动动画完成事件处理"""
	var event_data = {
		"character_node": character_node,
		"character_id": character_id,
		"final_position": final_position
	}
	_queue_event(EventType.MOVE_ANIMATION_COMPLETED, event_data)

func _on_animation_completed(animation_name: String, character_node: Node2D) -> void:
	"""动画完成事件处理"""
	var event_data = {
		"animation_name": animation_name,
		"character_node": character_node
	}
	_queue_event(EventType.ANIMATION_COMPLETED, event_data)

# 🚀 事件队列管理
func _queue_event(event_type: EventType, event_data: Dictionary) -> void:
	"""将事件加入队列"""
	event_queue.append({
		"type": event_type,
		"data": event_data,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	if debug_enabled:
		print("[BattleEventManager] 事件入队: ", EventType.keys()[event_type])
	
	# 如果当前没有在处理事件，立即开始处理
	if not is_processing_event:
		_process_next_event()

func _process_next_event() -> void:
	"""处理下一个事件"""
	if event_queue.is_empty():
		is_processing_event = false
		event_queue_empty.emit()
		return
	
	is_processing_event = true
	event_processing_started.emit()
	
	var event = event_queue.pop_front()
	var event_type = event["type"]
	var event_data = event["data"]
	
	if debug_enabled:
		print("[BattleEventManager] 处理事件: ", EventType.keys()[event_type])
	
	# 根据事件类型分发处理
	match event_type:
		EventType.SKILL_EXECUTION_COMPLETED:
			_handle_skill_execution_completed(event_data)
		EventType.SKILL_CANCELLED:
			_handle_skill_cancelled(event_data)
		EventType.VISUAL_SKILL_CAST_COMPLETED:
			_handle_visual_skill_cast_completed(event_data)
		EventType.VISUAL_SKILL_SELECTION_CANCELLED:
			_handle_visual_skill_selection_cancelled(event_data)
		EventType.CHARACTER_ACTION_COMPLETED:
			_handle_character_action_completed(event_data)
		EventType.MOVE_ANIMATION_COMPLETED:
			_handle_move_animation_completed(event_data)
		# EventType.NEXT_CHARACTER_REQUESTED: # 已移除，避免重复触发
		EventType.ANIMATION_COMPLETED:
			_handle_animation_completed(event_data)
	
	# 发出事件处理完成信号
	event_processed.emit(event_type, event_data)
	event_processing_completed.emit()
	
	# 继续处理下一个事件
	is_processing_event = false
	call_deferred("_process_next_event")

# 🚀 具体事件处理实现
func _handle_skill_execution_completed(event_data: Dictionary) -> void:
	"""处理技能执行完成"""
	var skill = event_data.get("skill")
	var results = event_data.get("results", {})
	var caster = event_data.get("caster")
	
	if debug_enabled:
		print("🎯 [BattleEventManager] 处理技能执行完成事件")
		print("🔧 [BattleEventManager] 技能: %s, 施法者: %s" % [skill.name if skill else "null", caster.name if caster else "null"])
	
	# 🚀 修复：通知BattleCombatManager技能执行完成
	# 这将触发character_action_completed信号，由_handle_character_action_completed统一处理回合切换
	if battle_combat_manager and battle_combat_manager.has_method("on_skill_executed"):
		if debug_enabled:
			print("🎯 [BattleEventManager] 通知BattleCombatManager技能执行完成")
		battle_combat_manager.on_skill_executed(caster, skill, [], [results])
	else:
		if debug_enabled:
			print("⚠️ [BattleEventManager] BattleCombatManager不可用，直接处理回合切换")
		# 备用方案：直接切换回合
		request_next_character()
	
	if debug_enabled:
		print("✅ [BattleEventManager] 技能执行完成处理结束")

func _handle_skill_cancelled(event_data: Dictionary) -> void:
	"""处理技能取消"""
	# 委托给BattleCombatManager处理
	if battle_combat_manager and battle_combat_manager.has_method("handle_skill_cancelled"):
		battle_combat_manager.handle_skill_cancelled()

func _handle_visual_skill_cast_completed(event_data: Dictionary) -> void:
	"""处理视觉技能施放完成"""
	var skill = event_data.get("skill")
	var caster = event_data.get("caster")
	var targets = event_data.get("targets", [])
	
	# 检查技能管理器是否可用
	if skill_manager and skill_manager.has_method("execute_skill"):
		skill_manager.execute_skill(skill, caster, targets)

func _handle_visual_skill_selection_cancelled(event_data: Dictionary) -> void:
	"""处理视觉技能选择取消"""
	# 重置技能管理器状态
	if skill_manager and skill_manager.has_method("reset_state"):
		skill_manager.reset_state()
	
	# 查找技能选择协调器
	var skill_selection_coordinator_node = null
	
	# 尝试多种路径查找 SkillSelectionCoordinator
	if battle_scene:
		skill_selection_coordinator_node = battle_scene.get_node_or_null("SkillSelectionCoordinator")
		if not skill_selection_coordinator_node:
			skill_selection_coordinator_node = battle_scene.get_node_or_null("UI/SkillSelectionCoordinator")
		if not skill_selection_coordinator_node:
			skill_selection_coordinator_node = battle_scene.get_node_or_null("Managers/SkillSelectionCoordinator")
	
	# 如果还是找不到，尝试通过已有的引用
	if not skill_selection_coordinator_node:
		skill_selection_coordinator_node = skill_selection_coordinator
	
	if skill_selection_coordinator_node and skill_selection_coordinator_node.has_method("restore_action_menu"):
		skill_selection_coordinator_node.restore_action_menu()
	else:
		# 备选方案：直接实现恢复逻辑
		_restore_action_menu_directly()

func _restore_action_menu_directly() -> void:
	"""直接恢复行动菜单"""
	# 获取当前角色
	var current_character_node = null
	
	# 首先尝试从 battle_scene 的 action_system 获取
	if battle_scene and battle_scene.has_method("get") and battle_scene.get("action_system"):
		var action_system = battle_scene.action_system
		if action_system and action_system.selected_character:
			current_character_node = action_system.selected_character
	
	# 如果没有找到，尝试从 battle_manager 获取当前回合角色
	if not current_character_node and battle_manager and battle_manager.has_method("get") and battle_manager.get("turn_manager"):
		var turn_manager = battle_manager.turn_manager
		if turn_manager and turn_manager.has_method("get_current_character"):
			var current_character = turn_manager.get_current_character()
			if current_character and battle_scene and battle_scene.has_method("_find_character_node_by_character_data"):
				current_character_node = battle_scene._find_character_node_by_character_data(current_character)
	
	# 如果找到了角色节点，尝试恢复行动菜单
	if current_character_node:
		var ui_component = current_character_node.get_node_or_null("ComponentContainer/UIComponent")
		if ui_component and ui_component.has_method("open_action_menu"):
			ui_component.open_action_menu()
		else:
			# 最后的备选方案：重置行动系统
			if battle_scene and battle_scene.has_method("get") and battle_scene.get("action_system"):
				var action_system = battle_scene.action_system
				if action_system and action_system.has_method("reset_action_system"):
					action_system.reset_action_system()

func _handle_character_action_completed(event_data: Dictionary) -> void:
	"""处理角色行动完成"""
	var character = event_data.get("character")
	var action_result = event_data.get("action_result", {})
	
	# 更新UI
	if battle_ui_manager and battle_ui_manager.has_method("update_character_info"):
		battle_ui_manager.update_character_info(character)
	
	# 请求下一个角色
	request_next_character()

func _handle_move_animation_completed(event_data: Dictionary) -> void:
	"""处理移动动画完成"""
	var character_node = event_data.get("character_node")
	var character_id = event_data.get("character_id")
	var final_position = event_data.get("final_position")
	
	# 更新角色地面位置
	if character_node and character_node.has_method("get_movement_component"):
		var movement_component = character_node.get_movement_component()
		if movement_component and movement_component.has_method("set_ground_position"):
			movement_component.set_ground_position(final_position)
	
	# 重置行动系统
	if battle_scene and battle_scene.has_method("reset_action_system"):
		battle_scene.reset_action_system()

# 注意：已移除_handle_next_character_requested函数，避免重复触发

func _handle_animation_completed(event_data: Dictionary) -> void:
	"""处理动画完成"""
	var animation_name = event_data.get("animation_name")
	var character_node = event_data.get("character_node")
	
	if debug_enabled:
		print("[BattleEventManager] 动画完成: ", animation_name)

# 🚀 辅助函数
func request_next_character() -> void:
	"""请求下一个角色"""
	if battle_manager and battle_manager.has_method("proceed_to_next_character"):
		battle_manager.proceed_to_next_character()
	elif battle_manager and battle_manager.turn_manager and battle_manager.turn_manager.has_method("next_turn"):
		battle_manager.turn_manager.next_turn()

func _proceed_to_next_character() -> void:
	"""处理下一个角色的回合 - 从BattleScene迁移的方法"""
	if debug_enabled:
		print("🔄 [BattleEventManager] 处理下一个角色的回合")
	
	# 🚀 检查战斗是否已结束
	if not battle_manager or not battle_manager.is_battle_in_progress():
		if debug_enabled:
			print("⚠️ [BattleEventManager] 战斗已结束，停止回合切换")
		return
	
	if not battle_manager.turn_manager:
		if debug_enabled:
			print("⚠️ [BattleEventManager] 无法切换角色：TurnManager不存在")
		return
	
	# 调用TurnManager的next_turn方法
	battle_manager.turn_manager.next_turn()
	if debug_enabled:
		print("✅ [BattleEventManager] 已切换到下一个角色")

func _get_current_character() -> GameCharacter:
	"""获取当前角色"""
	if battle_manager and battle_manager.has_method("get_current_character"):
		return battle_manager.get_current_character()
	return null

# 🚀 公共接口
func set_debug_enabled(enabled: bool) -> void:
	"""设置调试模式"""
	debug_enabled = enabled

func get_event_queue_size() -> int:
	"""获取事件队列大小"""
	return event_queue.size()

func clear_event_queue() -> void:
	"""清空事件队列"""
	event_queue.clear()
	is_processing_event = false

func force_process_events() -> void:
	"""强制处理所有事件"""
	while not event_queue.is_empty():
		_process_next_event()
		await get_tree().process_frame

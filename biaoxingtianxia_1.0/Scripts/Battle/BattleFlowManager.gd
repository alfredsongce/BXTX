# 🚀 战斗流程管理器 - 集中管理战斗状态和输入
class_name BattleFlowManager
extends Node

func _init():
	pass

# 🎯 战斗流程状态枚举
enum BattleFlowState {
	IDLE,        # 空闲状态
	PREPARING,   # 准备阶段
	ACTIVE,      # 战斗进行中
	PAUSED,      # 暂停状态
	ENDING,      # 结束阶段
	COMPLETED    # 完成状态
}

# 🎯 输入模式枚举
enum InputMode {
	NORMAL,      # 正常模式
	DEBUG,       # 调试模式
	DISABLED     # 禁用输入
}

# 🚀 当前状态
var current_state: BattleFlowState = BattleFlowState.IDLE
var current_input_mode: InputMode = InputMode.NORMAL

# 🚀 组件引用
var battle_manager: Node  # BattleManager引用
var battle_ui_manager: Node  # BattleUIManager引用
var character_manager: Node  # CharacterManager引用
var battle_scene: Node  # BattleScene引用
var skill_manager: Node  # SkillManager引用
var skill_selection_coordinator: Node  # SkillSelectionCoordinator引用
var movement_coordinator: Node  # MovementCoordinator引用
var battle_combat_manager: Node  # BattleCombatManager引用

# 🚀 信号定义
signal battle_flow_started()
signal battle_flow_ended(reason: String)
signal battle_flow_paused()
signal battle_flow_resumed()
signal input_mode_changed(new_mode: String)
signal state_changed(old_state: BattleFlowState, new_state: BattleFlowState)

# 🚀 战斗事件处理信号
signal skill_execution_completed(skill: SkillData, results: Dictionary, caster: GameCharacter)
signal skill_cancelled()
signal visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array)
signal visual_skill_selection_cancelled()
signal character_action_completed(character: GameCharacter, action_result: Dictionary)
signal move_animation_completed(character_node: Node2D, character_id: String, final_position: Vector2)
signal next_character_requested()

# 🚀 输入映射配置
var input_mappings = {
	KEY_F11: "start_battle",
	KEY_F10: "toggle_collision_display", 
	KEY_F9: "test_victory_condition",
	KEY_F8: "toggle_debug_mode",
	KEY_F7: "pause_resume_battle"
}

# 🚀 调试状态
var debug_mode_enabled: bool = false
var debug_logging_enabled: bool = false
var collision_display_enabled: bool = false

# 🚀 信号定义（调试相关）
signal debug_mode_toggled(enabled: bool)

func _ready() -> void:
	_find_component_references()
	_connect_signals()
	_set_state(BattleFlowState.IDLE)
	
	# 延迟获取BattleScene引用
	call_deferred("_find_battle_scene_reference")

func _debug_print(message: String) -> void:
	if debug_logging_enabled:
		print(message)

func toggle_debug_logging() -> void:
	debug_logging_enabled = not debug_logging_enabled
	
	debug_mode_toggled.emit(debug_logging_enabled)

# 🚀 查找组件引用
func _find_component_references() -> void:
	# 查找BattleManager
	battle_manager = get_node_or_null("../BattleManager")
	if not battle_manager:
		battle_manager = AutoLoad.get_battle_scene().get_node_or_null("BattleSystems/BattleManager") if AutoLoad.get_battle_scene() else null
	
	# 查找BattleUIManager
	battle_ui_manager = get_node_or_null("../BattleUIManager")
	if not battle_ui_manager:
		battle_ui_manager = AutoLoad.get_battle_scene().get_node_or_null("UI/BattleUIManager") if AutoLoad.get_battle_scene() else null
	
	# 查找CharacterManager
	character_manager = get_node_or_null("../CharacterManager")
	if not character_manager:
		character_manager = AutoLoad.get_battle_scene().get_node_or_null("BattleSystems/CharacterManager") if AutoLoad.get_battle_scene() else null
	
	# 查找SkillManager
	skill_manager = AutoLoad.get_battle_scene().get_node_or_null("SkillManager") if AutoLoad.get_battle_scene() else null
	if not skill_manager:
		skill_manager = get_node_or_null("../SkillManager")
	
	# 查找SkillSelectionCoordinator
	skill_selection_coordinator = get_node_or_null("../SkillSelectionCoordinator")
	if not skill_selection_coordinator:
		skill_selection_coordinator = AutoLoad.get_battle_scene().get_node_or_null("BattleSystems/SkillSelectionCoordinator") if AutoLoad.get_battle_scene() else null
	
	# 查找MovementCoordinator
	movement_coordinator = get_node_or_null("../MovementCoordinator")
	if not movement_coordinator:
		movement_coordinator = AutoLoad.get_battle_scene().get_node_or_null("BattleSystems/MovementCoordinator") if AutoLoad.get_battle_scene() else null
	
	# 查找BattleCombatManager
	battle_combat_manager = get_node_or_null("../BattleCombatManager")
	if not battle_combat_manager:
		battle_combat_manager = AutoLoad.get_battle_scene().get_node_or_null("BattleSystems/BattleCombatManager") if AutoLoad.get_battle_scene() else null
	



# 🚀 查找BattleScene引用
func _find_battle_scene_reference() -> void:
	battle_scene = AutoLoad.get_battle_scene()
	if not battle_scene:
		# 尝试通过父节点查找
		var current = get_parent()
		while current and not battle_scene:
			if current.name == "BattleScene" or current.has_method("_check_victory_condition"):
				battle_scene = current
				break
			current = current.get_parent()
	


func _connect_signals() -> void:
	# 连接自身信号
	next_character_requested.connect(_on_next_character_requested)
	print("✅ [BattleFlowManager] next_character_requested信号连接成功")
	
	# 连接BattleManager信号
	if battle_manager:
		if battle_manager.has_signal("battle_started"):
			battle_manager.battle_started.connect(_on_battle_started)
		if battle_manager.has_signal("battle_ended"):
			battle_manager.battle_ended.connect(_on_battle_ended)
		# 注意：不再连接character_action_completed和turn_changed信号，避免重复处理
		# BattleEventManager会统一处理这些信号
	
	# 连接BattleUIManager信号
	if battle_ui_manager:
		if battle_ui_manager.has_signal("start_battle_requested"):
			battle_ui_manager.start_battle_requested.connect(_on_start_battle_requested)
	
	# 连接SkillManager信号
	if skill_manager:
		if skill_manager.has_signal("skill_execution_completed"):
			skill_manager.skill_execution_completed.connect(_on_skill_execution_completed)
			print("✅ [BattleFlowManager] skill_execution_completed信号连接成功")
		if skill_manager.has_signal("skill_cancelled"):
			skill_manager.skill_cancelled.connect(_on_skill_cancelled)
	
	# 连接SkillSelectionCoordinator信号
	if skill_selection_coordinator:
		if skill_selection_coordinator.has_signal("visual_skill_cast_completed"):
			skill_selection_coordinator.visual_skill_cast_completed.connect(_on_visual_skill_cast_completed)
		if skill_selection_coordinator.has_signal("visual_skill_selection_cancelled"):
			skill_selection_coordinator.visual_skill_selection_cancelled.connect(_on_visual_skill_selection_cancelled)
	
	# 连接MovementCoordinator信号
	if movement_coordinator:
		if movement_coordinator.has_signal("move_animation_completed"):
			movement_coordinator.move_animation_completed.connect(_on_move_animation_completed)
	


# 🚀 输入处理主函数
func handle_input(event: InputEvent) -> bool:
	if current_input_mode == InputMode.DISABLED:
		return false
	
	if event is InputEventKey and event.pressed:
		return _handle_key_input(event.keycode)
	
	return false

# 🚀 按键输入处理
func _handle_key_input(keycode: int) -> bool:
	if keycode in input_mappings:
		var action = input_mappings[keycode]
		_execute_input_action(action)
		return true
	
	return false

# 🚀 执行输入动作
func _execute_input_action(action: String) -> void:
	print("🎮 [BattleFlowManager] 执行输入动作: %s" % action)
	
	match action:
		"start_battle":
			_handle_start_battle()
		"toggle_collision_display":
			_handle_toggle_collision_display()
		"test_victory_condition":
			_handle_test_victory_condition()
		"toggle_debug_mode":
			_handle_toggle_debug_mode()
		"pause_resume_battle":
			_handle_pause_resume_battle()
		_:
			print("⚠️ [BattleFlowManager] 未知输入动作: %s" % action)

# 🚀 具体的输入处理方法
func _handle_start_battle() -> void:
	
	start_battle_flow()

func _handle_toggle_collision_display() -> void:
	
	collision_display_enabled = !collision_display_enabled
	print("🔍 [BattleFlowManager] 碰撞显示: %s" % ("开启" if collision_display_enabled else "关闭"))
	# 委托给BattleScene处理
	if battle_scene and battle_scene.has_method("toggle_collision_display"):
		battle_scene.toggle_collision_display()

func _handle_test_victory_condition() -> void:
	
	# 委托给BattleScene处理
	if battle_scene and battle_scene.has_method("_test_victory_condition"):
		battle_scene._test_victory_condition()
	else:
		pass

func _handle_toggle_debug_mode() -> void:
	
	toggle_debug_mode()

func _handle_pause_resume_battle() -> void:
	
	if current_state == BattleFlowState.ACTIVE:
		pause_battle_flow()
	elif current_state == BattleFlowState.PAUSED:
		resume_battle_flow()
	else:
		print("⚠️ [BattleFlowManager] 当前状态不支持暂停/恢复操作")

# 🚀 战斗流程控制方法
func start_battle_flow() -> void:
	print("🚀 [BattleFlowManager] 开始战斗流程")
	
	if current_state != BattleFlowState.IDLE:
		print("⚠️ [BattleFlowManager] 战斗已在进行中，无法重新开始")
		return
	
	_set_state(BattleFlowState.PREPARING)
	
	# 通过BattleManager开始战斗
	if battle_manager and battle_manager.has_method("start_battle"):
		battle_manager.start_battle()
		_set_state(BattleFlowState.ACTIVE)
		battle_flow_started.emit()
		print("✅ [BattleFlowManager] 战斗流程启动成功")
	else:
		print("❌ [BattleFlowManager] 无法启动战斗 - BattleManager不可用")
		_set_state(BattleFlowState.IDLE)

func end_battle_flow(reason: String = "normal") -> void:
	print("🏁 [BattleFlowManager] 结束战斗流程，原因: %s" % reason)
	
	if current_state not in [BattleFlowState.ACTIVE, BattleFlowState.PAUSED]:
		print("⚠️ [BattleFlowManager] 当前没有进行中的战斗")
		return
	
	_set_state(BattleFlowState.ENDING)
	
	# 通过BattleManager结束战斗
	if battle_manager and battle_manager.has_method("end_battle"):
		battle_manager.end_battle(reason)
	
	_set_state(BattleFlowState.COMPLETED)
	battle_flow_ended.emit(reason)
	print("✅ [BattleFlowManager] 战斗流程结束")

func pause_battle_flow() -> void:
	print("⏸️ [BattleFlowManager] 暂停战斗流程")
	
	if current_state != BattleFlowState.ACTIVE:
		print("⚠️ [BattleFlowManager] 当前状态无法暂停")
		return
	
	_set_state(BattleFlowState.PAUSED)
	battle_flow_paused.emit()
	print("✅ [BattleFlowManager] 战斗已暂停")

func resume_battle_flow() -> void:
	print("▶️ [BattleFlowManager] 恢复战斗流程")
	
	if current_state != BattleFlowState.PAUSED:
		print("⚠️ [BattleFlowManager] 当前状态无法恢复")
		return
	
	_set_state(BattleFlowState.ACTIVE)
	battle_flow_resumed.emit()
	print("✅ [BattleFlowManager] 战斗已恢复")

func force_end_battle() -> void:
	print("🛑 [BattleFlowManager] 强制结束战斗")
	end_battle_flow("force_end")

# 🚀 状态管理
func _set_state(new_state: BattleFlowState) -> void:
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	print("🔄 [BattleFlowManager] 状态变更: %s -> %s" % [BattleFlowState.keys()[old_state], BattleFlowState.keys()[new_state]])

func get_current_state() -> BattleFlowState:
	return current_state

func is_battle_active() -> bool:
	return current_state == BattleFlowState.ACTIVE

func is_battle_paused() -> bool:
	return current_state == BattleFlowState.PAUSED

# 🚀 调试模式管理
func toggle_debug_mode() -> void:
	debug_mode_enabled = !debug_mode_enabled
	
	
	# 切换输入模式
	if debug_mode_enabled:
		_set_input_mode(InputMode.DEBUG)
	else:
		_set_input_mode(InputMode.NORMAL)

func enable_debug_mode() -> void:
	if not debug_mode_enabled:
		toggle_debug_mode()

func disable_debug_mode() -> void:
	if debug_mode_enabled:
		toggle_debug_mode()

# 🚀 输入模式管理
func _set_input_mode(mode: InputMode) -> void:
	if current_input_mode != mode:
		current_input_mode = mode
		input_mode_changed.emit(InputMode.keys()[mode])
		print("🎮 [BattleFlowManager] 输入模式切换: %s" % InputMode.keys()[mode])

func set_input_enabled(enabled: bool) -> void:
	if enabled:
		_set_input_mode(InputMode.NORMAL)
	else:
		_set_input_mode(InputMode.DISABLED)

func get_input_mode() -> InputMode:
	return current_input_mode

# 🚀 公共API
func get_battle_flow_info() -> Dictionary:
	return {
		"current_state": BattleFlowState.keys()[current_state],
		"input_mode": InputMode.keys()[current_input_mode],
		"debug_mode": debug_mode_enabled,
		"collision_display": collision_display_enabled,
		"components": {
			"battle_manager": battle_manager != null,
			"battle_ui_manager": battle_ui_manager != null,
			"character_manager": character_manager != null,
			"battle_scene": battle_scene != null
		}
	}

# 🚀 信号回调
func _on_battle_started() -> void:
	print("📢 [BattleFlowManager] 收到战斗开始信号")
	_set_state(BattleFlowState.ACTIVE)

func _on_battle_ended(reason: String) -> void:
	print("📢 [BattleFlowManager] 收到战斗结束信号: %s" % reason)
	end_battle_flow(reason)

func _on_start_battle_requested() -> void:
	print("📢 [BattleFlowManager] 收到开始战斗请求")
	start_battle_flow()

# 🚀 战斗事件处理函数
func _on_skill_execution_completed(skill: SkillData, results: Dictionary, caster: GameCharacter) -> void:
	print("✅ [BattleFlowManager] 收到技能执行完成信号: %s, 施法者: %s" % [skill.name if skill else "未知技能", caster.name if caster else "未知"])
	
	# 发出信号供其他系统监听
	skill_execution_completed.emit(skill, results, caster)
	print("📡 [BattleFlowManager] 重新发出skill_execution_completed信号")
	
	# 注意：移除对BattleCombatManager的直接调用，避免与BattleEventManager的处理产生冲突
	# BattleEventManager会接收skill_execution_completed信号并委托给BattleCombatManager处理

func _on_skill_cancelled() -> void:
	if debug_logging_enabled:
		print("[BattleFlowManager] 技能取消")
	
	# 发出信号供其他系统监听
	skill_cancelled.emit()
	
	# 委托给BattleCombatManager处理
	if battle_combat_manager and battle_combat_manager.has_method("handle_skill_cancelled"):
		battle_combat_manager.handle_skill_cancelled()
	else:
		if debug_logging_enabled:
			print("[BattleFlowManager] BattleCombatManager不可用，使用默认处理")

func _on_visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	if debug_logging_enabled:
		print("[BattleFlowManager] 视觉技能施放完成: %s" % (skill.name if skill else "未知技能"))
	
	# 发出信号供其他系统监听
	visual_skill_cast_completed.emit(skill, caster, targets)
	
	# 直接执行技能
	if skill_manager and skill_manager.has_method("execute_skill"):
		skill_manager.execute_skill(skill, caster, targets)
	else:
		if debug_logging_enabled:
			print("[BattleFlowManager] SkillManager不可用")

func _on_visual_skill_selection_cancelled() -> void:
	if debug_logging_enabled:
		print("[BattleFlowManager] 视觉技能选择取消")
	
	# 发出信号供其他系统监听
	visual_skill_selection_cancelled.emit()
	
	# 重置技能管理器状态
	if skill_manager and skill_manager.has_method("reset_state"):
		skill_manager.reset_state()
	
	# 恢复UI到行动菜单状态
	if battle_ui_manager and battle_ui_manager.has_method("show_action_menu"):
		# 获取当前角色
		var current_character = null
		if battle_manager and battle_manager.has_method("get_current_character"):
			current_character = battle_manager.get_current_character()
		
		if current_character:
			battle_ui_manager.show_action_menu(current_character)

func _on_character_action_completed(character: GameCharacter, action_result: Dictionary) -> void:
	if debug_logging_enabled:
		print("[BattleFlowManager] 角色行动完成: %s" % (character.name if character else "未知角色"))
	
	# 发出信号供其他系统监听
	character_action_completed.emit(character, action_result)
	
	# 更新UI
	if battle_ui_manager and battle_ui_manager.has_method("update_character_info"):
		battle_ui_manager.update_character_info(character)
	
	# 注意：不再发射next_character_requested信号，避免重复触发
	# BattleEventManager会统一处理回合切换

func _on_move_animation_completed(character_node: Node2D, character_id: String, final_position: Vector2) -> void:
	if debug_logging_enabled:
		print("[BattleFlowManager] 移动动画完成: %s 到位置: %s" % [character_id, final_position])
	
	# 发出信号供其他系统监听
	move_animation_completed.emit(character_node, character_id, final_position)
	
	# 更新角色地面位置
	if character_node and character_node.has_method("get_movement_component"):
		var movement_component = character_node.get_movement_component()
		if movement_component and movement_component.has_method("set_ground_position"):
			movement_component.set_ground_position(final_position)
	
	# 重置行动系统
	if battle_scene and battle_scene.has_method("reset_action_system"):
		battle_scene.reset_action_system()

func _on_next_character_requested() -> void:
	print("✅ [BattleFlowManager] 收到next_character_requested信号")
	print("🔍 [BattleFlowManager] battle_manager: %s" % battle_manager)
	
	# 委托给TurnManager处理
	if battle_manager and battle_manager.has_method("proceed_to_next_character"):
		print("🎯 [BattleFlowManager] 调用battle_manager.proceed_to_next_character()")
		battle_manager.proceed_to_next_character()
	elif battle_manager and battle_manager.turn_manager and battle_manager.turn_manager.has_method("next_turn"):
		print("🎯 [BattleFlowManager] 调用battle_manager.turn_manager.next_turn()")
		battle_manager.turn_manager.next_turn()
	else:
		print("❌ [BattleFlowManager] 无法找到有效的回合管理器")
		if battle_manager:
			print("🔍 [BattleFlowManager] battle_manager.turn_manager: %s" % battle_manager.turn_manager)
		else:
			print("🔍 [BattleFlowManager] battle_manager为null")

# 🚀 战斗事件处理辅助函数
func handle_move_request(character_node: Node2D, target_position: Vector2) -> void:
	"""处理移动请求"""
	if debug_logging_enabled:
		print("[BattleFlowManager] 处理移动请求: %s" % target_position)
	
	# 委托给MovementCoordinator处理
	if movement_coordinator and movement_coordinator.has_method("handle_move_request"):
		movement_coordinator.handle_move_request(character_node, target_position)
	else:
		# 回退到BattleScene的移动处理
		if battle_scene and battle_scene.has_method("_on_move_requested"):
			battle_scene._on_move_requested(character_node, target_position)

func proceed_to_next_character() -> void:
	"""进入下一个角色回合"""
	if debug_logging_enabled:
		print("[BattleFlowManager] 进入下一个角色回合")
	
	_on_next_character_requested()

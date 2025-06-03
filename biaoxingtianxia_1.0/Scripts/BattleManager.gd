# 战斗管理器 - 协调者模式
# 职责：作为抽象接口，协调各个子系统
# 设计理念：组合优于继承，单一职责，易于扩展
extends Node

#region 战斗信号接口
signal battle_started()
signal battle_ended(result: Dictionary)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal character_action_completed(character, action_result: Dictionary)
# 🚀 新增：表现层信号
signal battle_visual_update_requested(visual_type: String, data: Dictionary)
signal player_turn_started(character: GameCharacter)
signal ai_turn_started(character: GameCharacter)
#endregion

#region 调试日志控制
var debug_logging_enabled: bool = true  # 🚀 修改：默认开启调试日志，方便查看胜负判定过程
#endregion

#region 子系统引用
@onready var turn_manager: Node = null
@onready var participant_manager: Node = null  
@onready var action_manager: Node = null
@onready var state_manager: Node = null
#endregion

#region 基础状态（委托给StateManager）
var is_battle_active: bool = false
var current_turn: int = 0
#endregion

#region 场景引用
@onready var battle_scene: Node = get_tree().current_scene  # 🚀 修复：使用current_scene获取场景引用
#endregion

func _ready() -> void:
	_debug_print("⚔️ [BattleManager] 战斗协调器初始化")
	_setup_subsystems()

#region 调试日志方法
func _debug_print(message: String) -> void:
	if debug_logging_enabled:
		print(message)

func toggle_debug_logging() -> void:
	debug_logging_enabled = not debug_logging_enabled
	
#endregion

#region 子系统初始化
func _setup_subsystems() -> void:
	# 获取子系统引用
	turn_manager = get_node_or_null("TurnManager")
	participant_manager = get_node_or_null("ParticipantManager")
	action_manager = get_node_or_null("ActionManager")
	state_manager = get_node_or_null("StateManager")
	
	# 连接子系统信号
	_connect_subsystem_signals()
	
	_debug_print("🔗 [BattleManager] 子系统连接完成")

func _connect_subsystem_signals() -> void:
	# StateManager信号
	if state_manager:
		if state_manager.has_signal("battle_state_changed"):
			state_manager.battle_state_changed.connect(_on_battle_state_changed)
	
	# TurnManager信号  
	if turn_manager:
		if turn_manager.has_signal("turn_changed"):
			turn_manager.turn_changed.connect(_on_turn_changed)
	
	# ActionManager信号
	if action_manager:
		if action_manager.has_signal("action_completed"):
			action_manager.action_completed.connect(_on_action_completed)
#endregion

#region 公共API接口
func start_battle(participants: Array = []) -> void:
	if is_battle_active:
		_debug_print("⚠️ [BattleManager] 战斗已在进行中")
		return
	
	_debug_print("🚀 [BattleManager] 开始战斗协调")
	
	# 🚀 重要：设置战斗状态为激活
	is_battle_active = true
	current_turn = 1
	_debug_print("✅ [BattleManager] 战斗状态已激活: is_battle_active = %s" % is_battle_active)
	
	# 委托给StateManager
	if state_manager and state_manager.has_method("start_battle"):
		state_manager.start_battle()
	# 移除 _fallback_start_battle 调用，避免重复发射 turn_started 信号
	# TurnManager 会通过 turn_changed 信号正确触发 turn_started
	
	# 委托给ParticipantManager
	var final_participants = participants
	if final_participants.is_empty():
		final_participants = _get_default_participants()
	
	_debug_print("🔍 [BattleManager] 获取到参战者数量: %d" % final_participants.size())
	
	# 🚀 添加详细的参战者信息调试
	for i in range(final_participants.size()):
		var char = final_participants[i]
		var char_type = "友方" if char.is_player_controlled() else "敌方"
		_debug_print("  参战者 %d: %s (%s) - 控制类型: %d" % [i+1, char.name, char_type, char.control_type])
	
	if participant_manager and participant_manager.has_method("setup_participants"):
		_debug_print("🔧 [BattleManager] 委托ParticipantManager设置参战者")
		participant_manager.setup_participants(final_participants)
	
	# 委托给TurnManager开始回合管理
	if turn_manager and turn_manager.has_method("start_new_battle"):
		_debug_print("🔧 [BattleManager] 委托TurnManager开始回合管理")
		turn_manager.start_new_battle(final_participants)
	
	# 发出信号
	battle_started.emit()

func end_battle(reason: String = "unknown") -> void:
	if not is_battle_active:
		return
	
	_debug_print("🏁 [BattleManager] 战斗结束协调")
	
	# 委托给StateManager
	if state_manager and state_manager.has_method("end_battle"):
		var result = state_manager.end_battle(reason)
		battle_ended.emit(result)
	else:
		_fallback_end_battle(reason)

func is_battle_in_progress() -> bool:
	_debug_print("🔍 [BattleManager] is_battle_in_progress被调用")
	_debug_print("🔍 [BattleManager] state_manager存在: %s" % (state_manager != null))
	_debug_print("🔍 [BattleManager] is_battle_active值: %s" % is_battle_active)
	
	# 优先从StateManager获取
	if state_manager and state_manager.has_method("is_active"):
		var state_result = state_manager.is_active()
		_debug_print("🔍 [BattleManager] StateManager.is_active(): %s" % state_result)
		return state_result
	
	_debug_print("🔍 [BattleManager] 使用回退状态 is_battle_active: %s" % is_battle_active)
	return is_battle_active

func get_current_turn() -> int:
	# 优先从TurnManager获取
	if turn_manager and turn_manager.has_method("get_current_turn"):
		return turn_manager.get_current_turn()
	return current_turn
#endregion

#region 子系统信号回调
func _on_battle_state_changed(new_state: String, data: Dictionary = {}) -> void:
	_debug_print("📊 [BattleManager] 战斗状态变更: %s" % new_state)
	is_battle_active = (new_state == "active")

func _on_turn_changed(turn_number: int, active_character = null) -> void:
	_debug_print("🎯 [BattleManager] 回合变更: %d" % turn_number)
	_debug_print("🔍 [BattleManager] 当前战斗状态 is_battle_active: %s" % is_battle_active)
	current_turn = turn_number
	
	# 🚀 新增：处理角色类型判断逻辑
	if active_character:
		_debug_print("🎯 [BattleManager] 当前回合角色: %s (控制类型: %d)" % [active_character.name, active_character.control_type])
		
		if active_character.is_player_controlled():
			_debug_print("👤 [BattleManager] 检测到玩家角色，发出player_turn_started信号")
			player_turn_started.emit(active_character)
		else:
			_debug_print("🤖 [BattleManager] 检测到AI角色，发出ai_turn_started信号")
			ai_turn_started.emit(active_character)
	else:
		_debug_print("⚠️ [BattleManager] 当前角色为空")
	
	# 发出通用回合信号（保持兼容性）
	_debug_print("📡 [BattleManager] 即将发出turn_started信号: 回合%d" % turn_number)
	turn_started.emit(turn_number)
	_debug_print("✅ [BattleManager] turn_started信号已发出")

func _on_action_completed(character, action_result: Dictionary) -> void:
	_debug_print("✅ [BattleManager] 行动完成协调")
	
	# 转发信号
	character_action_completed.emit(character, action_result)
	
	# 检查战斗是否结束
	_check_battle_end_condition()
#endregion

#region 辅助方法
func _get_default_participants() -> Array:
	var participants = []
	if battle_scene and battle_scene.has_method("get_all_characters"):
		_debug_print("🔍 [BattleManager] 调用 BattleScene.get_all_characters() 获取所有角色")
		participants = battle_scene.get_all_characters()
		if participants.is_empty():
			_debug_print("⚠️ [BattleManager] BattleScene.get_all_characters() 返回为空，尝试备用方案")
			#保留原来的备用扫描逻辑，以防get_all_characters()也暂时失效
			for child in battle_scene.get_children():
				if child.is_in_group("party_members") or child.is_in_group("enemies"):
					var character_data = null
					if child.has_method("get_character_data"):
						character_data = child.get_character_data()
					elif child.has_node("Data") and child.get_node("Data").has_method("get_character"):
						character_data = child.get_node("Data").get_character()
					
					if character_data:
						participants.append(character_data)
						var char_type = "友方" if child.is_in_group("party_members") else "敌方"
						_debug_print("✅ [BattleManager] 备用方案添加%s角色: %s" % [char_type, character_data.name])
	else:
		_debug_print("⚠️ [BattleManager] battle_scene 未找到或没有 get_all_characters 方法")

	_debug_print("🔍 [BattleManager] 最终参战者数量: %d" % participants.size())
	
	for i in range(participants.size()):
		var char = participants[i]
		var char_type = "友方" if char.is_player_controlled() else "敌方"
		_debug_print("  %d. %s (%s) - HP: %d/%d" % [i+1, char.name, char_type, char.current_hp, char.max_hp])
	
	return participants

func _check_battle_end_condition() -> void:
	_debug_print("🔍 [BattleManager] 检查战斗结束条件")
	_debug_print("🔍 [BattleManager] 当前战斗状态 is_battle_active: %s" % is_battle_active)
	if participant_manager and participant_manager.has_method("check_battle_end"):
		_debug_print("🔍 [BattleManager] 调用participant_manager.check_battle_end()")
		var end_result = participant_manager.check_battle_end()
		_debug_print("🔍 [BattleManager] 战斗结束检查结果: %s" % end_result)
		if end_result.has("should_end") and end_result.should_end:
			_debug_print("⚠️ [BattleManager] 检测到战斗应该结束，原因: %s" % end_result.get("reason", "victory_condition"))
			_debug_print("🚨 [BattleManager] 即将调用end_battle，这将设置is_battle_active为false")
			end_battle(end_result.get("reason", "victory_condition"))
		else:
			_debug_print("✅ [BattleManager] 战斗继续进行")
	else:
		_debug_print("⚠️ [BattleManager] participant_manager不存在或没有check_battle_end方法")

# 回退实现（当子系统不存在时）
func _fallback_start_battle() -> void:
	_debug_print("⚪ [BattleManager] 使用回退实现启动战斗")
	is_battle_active = true
	current_turn = 1
	turn_started.emit(current_turn)

func _fallback_end_battle(reason: String) -> void:
	_debug_print("⚪ [BattleManager] 使用回退实现结束战斗，原因: %s" % reason)
	
	# 🚀 修复：根据reason正确设置winner
	var winner = "unknown"
	match reason:
		"enemy_defeat":
			winner = "player"
			_debug_print("🎉 [BattleManager] 敌方败北，我方胜利")
		"player_defeat":
			winner = "enemy"
			_debug_print("💀 [BattleManager] 我方败北，敌方胜利")
		"draw":
			winner = "draw"
			_debug_print("🤝 [BattleManager] 平局")
		_:
			winner = "unknown"
			_debug_print("❓ [BattleManager] 未知结束原因")
	
	var result = {
		"winner": winner, 
		"reason": reason, 
		"total_turns": current_turn,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	_debug_print("📊 [BattleManager] 战斗结果: %s" % result)
	
	# 🚀 新增：处理胜负判定逻辑并发送表现层信号
	_process_battle_result(result)
	
	# 发出信号
	battle_ended.emit(result)
	is_battle_active = false
	current_turn = 0
#endregion

#region 胜利条件处理
func handle_victory_condition(victory_type: String, details: Dictionary) -> void:
	_debug_print("🏆 [BattleManager] 处理胜利条件: %s" % victory_type)
	
	# 根据胜利类型确定获胜方
	var winner: String
	match victory_type:
		"enemy_defeat":
			winner = "player"
			_debug_print("🎉 [BattleManager] 我方胜利！")
		"player_defeat":
			winner = "enemy"
			_debug_print("💀 [BattleManager] 我方失败！")
		_:
			winner = "draw"
			_debug_print("🤝 [BattleManager] 平局")
	
	# 🚀 修改：使用新的信号系统而不是直接调用BattleScene方法
	var visual_data = {
		"winner": winner,
		"battle_result_text": _generate_result_text(winner),
		"marker_type": _determine_marker_type(winner)
	}
	battle_visual_update_requested.emit("battle_end", visual_data)
	_debug_print("✅ [BattleManager] 已发送战斗结果表现层信号")
	
	# 结束战斗
	end_battle(victory_type)

# 🚀 新增：处理战斗结果的业务逻辑
func _process_battle_result(result: Dictionary) -> void:
	var winner = result.get("winner", "unknown")
	_debug_print("📊 [BattleManager] 处理战斗结果: %s" % winner)
	
	var visual_data = {
		"winner": winner,
		"battle_result_text": _generate_result_text(winner),
		"marker_type": _determine_marker_type(winner)
	}
	
	battle_visual_update_requested.emit("battle_end", visual_data)
	_debug_print("✅ [BattleManager] 已发送战斗结果表现层信号")

# 🚀 新增：生成结果文本
func _generate_result_text(winner: String) -> String:
	match winner:
		"player":
			return "🎉 我方胜利！"
		"enemy":
			return "💀 我方失败..."
		"draw":
			return "🤝 平局"
		_:
			return "胜负未定"

# 🚀 新增：确定标记类型
func _determine_marker_type(winner: String) -> String:
	match winner:
		"player":
			return "victory"
		"enemy":
			return "defeat"
		"draw":
			return "draw"
		_:
			return "unknown"
#endregion

#region 调试接口
func get_subsystem_status() -> Dictionary:
	return {
		"turn_manager": turn_manager != null,
		"participant_manager": participant_manager != null,
		"action_manager": action_manager != null,
		"state_manager": state_manager != null,
		"battle_active": is_battle_active,
		"current_turn": current_turn
	}

func print_subsystem_status() -> void:
	print("📋 [BattleManager] 子系统状态:")
	var status = get_subsystem_status()
	for key in status:
		print("  - %s: %s" % [key, status[key]])
#endregion

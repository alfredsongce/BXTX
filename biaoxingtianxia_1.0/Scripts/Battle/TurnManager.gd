# 回合管理器
# 职责：专门负责回合顺序、回合切换等逻辑
# 上级：BattleManager
extends Node

#region 信号
signal turn_changed(turn_number: int, active_character)
signal turn_order_calculated(turn_queue: Array)
#endregion

#region 调试日志控制
var debug_logging_enabled: bool = true  # 🚀 修改：开启调试日志以帮助定位回合切换问题
#endregion

#region 状态
var current_turn: int = 0
var turn_queue: Array = []
var current_character_index: int = 0
#endregion

func _ready() -> void:
	_debug_print("🎯 [TurnManager] 回合管理器初始化")

#region 调试日志方法
func _debug_print(message: String) -> void:
	if debug_logging_enabled:
		print(message)

func toggle_debug_logging() -> void:
	debug_logging_enabled = not debug_logging_enabled
	
#endregion

#region 公共API
func start_new_battle(participants: Array) -> void:
	_debug_print("🔄 [TurnManager] 开始新战斗的回合管理")
	current_turn = 0
	_calculate_turn_order(participants)
	_start_first_turn()

func _calculate_turn_order(participants: Array) -> void:
	# 🚀 首先过滤掉死亡角色
	var alive_participants = participants.filter(func(char): return char.is_alive())
	
	# 按速度排序
	turn_queue = alive_participants.duplicate()
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)
	
	# 🚀 详细的回合队列调试信息
	_debug_print("📋 [TurnManager] 计算回合顺序，存活参战者数量: %d/%d" % [turn_queue.size(), participants.size()])
	
	var names = []
	for i in range(turn_queue.size()):
		var char = turn_queue[i]
		var char_type = "友方" if char.is_player_controlled() else "敌方"
		names.append("%s(%s)" % [char.name, char_type])
		_debug_print("  顺序 %d: %s - %s，速度: %d，控制类型: %d，HP: %d/%d" % [
			i+1, char.name, char_type, char.speed, char.control_type, char.current_hp, char.max_hp
		])
	
	_debug_print("📋 [TurnManager] 回合顺序: %s" % str(names))
	
	turn_order_calculated.emit(turn_queue)

func _start_first_turn() -> void:
	if turn_queue.is_empty():
		_debug_print("⚠️ [TurnManager] 没有存活参战者，无法开始回合")
		return
	
	current_turn = 1
	current_character_index = 0
	_emit_turn_change()

func next_turn() -> void:
	print("🔄 [TurnManager] NEXT_TURN被调用，当前索引: %d, 队列大小: %d" % [current_character_index, turn_queue.size()])
	
	if turn_queue.is_empty():
		print("⚠️ [TurnManager] 回合队列为空，返回")
		return
	
	var old_index = current_character_index
	var old_character = get_current_character()
	print("🔄 [TurnManager] 切换前角色: %s (索引: %d)" % [old_character.name if old_character else "null", old_index])
	
	current_character_index += 1
	
	# 如果一轮结束，开始新的一轮
	if current_character_index >= turn_queue.size():
		print("🔄 [TurnManager] 一轮结束，重置索引为0")
		current_character_index = 0
		current_turn += 1
		print("🔄 [TurnManager] 新的一轮开始，回合: %d" % current_turn)
		
		# 🚀 新的一轮开始时，重新检查存活角色
		_refresh_turn_queue()
	
	var next_character = get_current_character()
	print("🎯 [TurnManager] 索引从%d -> %d，下一个角色: %s" % [old_index, current_character_index, next_character.name if next_character else "null"])
	
	_emit_turn_change()

# 🚀 新增：刷新回合队列，移除死亡角色
func _refresh_turn_queue() -> void:
	var original_size = turn_queue.size()
	turn_queue = turn_queue.filter(func(char): return char.is_alive())
	
	var removed_count = original_size - turn_queue.size()
	if removed_count > 0:
		_debug_print("💀 [TurnManager] 移除 %d 个死亡角色，剩余: %d" % [removed_count, turn_queue.size()])
		
		# 调整当前角色索引
		if current_character_index >= turn_queue.size():
			current_character_index = 0
	
	# 如果所有角色都死亡，结束战斗
	if turn_queue.is_empty():
		_debug_print("💀 [TurnManager] 所有角色都已死亡，战斗应该结束")

func _emit_turn_change() -> void:
	print("📡 [TurnManager] _EMIT_TURN_CHANGE被调用")
	# 🚀 再次检查当前角色是否存活
	var active_character = get_current_character()
	print("🔍 [TurnManager] 当前角色: %s" % (active_character.name if active_character else "null"))
	
	if active_character and not active_character.is_alive():
		print("💀 [TurnManager] 角色%s已死亡，跳过" % active_character.name)
		next_turn()  # 递归调用下一个角色
		return
	
	print("🎯 [TurnManager] 回合%d，轮到: %s (控制类型: %d)" % [
		current_turn, 
		active_character.name if active_character else "null",
		active_character.control_type if active_character else -1
	])
	
	# 🚀 在发出信号前输出回合队列状态
	print("📊 [TurnManager] 当前回合队列状态:")
	for i in range(turn_queue.size()):
		var char = turn_queue[i]
		var is_current = (i == current_character_index)
		var char_type = "友方" if char.is_player_controlled() else "敌方"
		var marker = "👉 " if is_current else "   "
		print("📊 [TurnManager] %s%d. %s (%s) - HP: %d/%d" % [marker, i, char.name, char_type, char.current_hp, char.max_hp])
	
	print("📡 [TurnManager] 发出turn_changed信号")
	turn_changed.emit(current_turn, active_character)
	print("✅ [TurnManager] turn_changed信号已发出")

func get_current_turn() -> int:
	return current_turn

func get_current_character():
	if turn_queue.is_empty() or current_character_index >= turn_queue.size():
		return null
	
	var character = turn_queue[current_character_index]
	
	# 🚀 如果当前角色已死亡，自动跳到下一个
	if character and not character.is_alive():
		_debug_print("💀 [TurnManager] 当前角色 %s 已死亡，自动跳过" % character.name)
		next_turn()
		return get_current_character()  # 递归获取下一个存活角色
	
	return character

func get_turn_queue() -> Array:
	return turn_queue.duplicate()
#endregion
 

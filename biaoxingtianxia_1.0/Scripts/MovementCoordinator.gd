# 🚀 移动协调器 - 统一管理角色移动逻辑
# Movement Coordinator - Unified character movement logic management

class_name MovementCoordinator
extends Node

# 移动相关信号
signal movement_started(character: GameCharacter, target_position: Vector2)
signal movement_completed(character: GameCharacter, final_position: Vector2)
signal movement_cancelled(character: GameCharacter, reason: String)

# 移动配置
@export var base_move_speed: float = 400.0  # 基础移动速度(像素/秒)
@export var min_move_duration: float = 0.5  # 最短移动时间(秒)
@export var max_move_duration: float = 1.5  # 最长移动时间(秒)

# 内部状态
var characters_moving = {}  # 用于存储正在移动的角色信息
var character_manager: Node  # BattleCharacterManager或ParticipantManager
var move_range_controller: Node
var action_system: Node
var position_collision_manager: Node2D

# 统计数据
var coordination_requests: int = 0
var successful_coordinations: int = 0
var validation_failures: int = 0
var manager_connection_attempts: int = 0

func _ready():
	print("🎬 [MovementCoordinator] 移动协调器初始化开始")
	_setup_node_references()
	_connect_signals()
	print("✅ [MovementCoordinator] 移动协调器初始化完成")

func _setup_node_references():
	print("🔍 [MovementCoordinator] 开始设置节点引用...")
	
	# 获取必要的节点引用
	move_range_controller = get_node_or_null("../../MoveRange/Controller")
	print("📍 [MovementCoordinator] MoveRange控制器: ", "找到" if move_range_controller else "未找到")
	
	action_system = get_node_or_null("../../ActionSystem")
	print("⚡ [MovementCoordinator] 行动系统: ", "找到" if action_system else "未找到")
	
	position_collision_manager = get_node_or_null("../PositionCollisionManager")
	print("🎯 [MovementCoordinator] 统一位置碰撞管理器: ", "找到" if position_collision_manager else "未找到")
	
	if position_collision_manager:
		print("✅ [MovementCoordinator] 成功连接到统一位置碰撞管理器!")
		print("📍 [MovementCoordinator] 管理器路径: ../PositionCollisionManager")
		print("🔗 [MovementCoordinator] 管理器类型: ", position_collision_manager.get_class())
	else:
		print("❌ [MovementCoordinator] 警告: 未找到统一位置碰撞管理器")
	
	# 等待 BattleCharacterManager 被创建
	await get_tree().process_frame
	character_manager = AutoLoad.get_battle_scene().get_node_or_null("BattleCharacterManager") if AutoLoad.get_battle_scene() else null
	print("👥 [MovementCoordinator] 角色管理器: ", "找到" if character_manager else "未找到")
	
	# 如果还是找不到，尝试通过 BattleScene 获取
	if not character_manager:
		var battle_scene = AutoLoad.get_battle_scene()
		if battle_scene and battle_scene.has_method("get_character_manager"):
			character_manager = battle_scene.get_character_manager()
			print("🔄 [MovementCoordinator] 通过BattleScene获取角色管理器: ", "成功" if character_manager else "失败")
	
	# 尝试其他可能的路径
	if not move_range_controller:
		move_range_controller = AutoLoad.get_battle_scene().get_node_or_null("MoveRange/Controller") if AutoLoad.get_battle_scene() else null
		print("🔄 [MovementCoordinator] 备用路径查找MoveRange控制器: ", "找到" if move_range_controller else "未找到")
	if not action_system:
		action_system = AutoLoad.get_battle_scene().get_node_or_null("ActionSystem") if AutoLoad.get_battle_scene() else null
		print("🔄 [MovementCoordinator] 备用路径查找行动系统: ", "找到" if action_system else "未找到")
	if not position_collision_manager:
		position_collision_manager = AutoLoad.get_battle_scene().get_node_or_null("BattleSystems/PositionCollisionManager") if AutoLoad.get_battle_scene() else null
		print("🔄 [MovementCoordinator] 备用路径查找统一管理器: ", "找到" if position_collision_manager else "未找到")
		
		if position_collision_manager:
			print("✅ [MovementCoordinator] 通过备用路径成功连接到统一位置碰撞管理器!")
			print("📍 [MovementCoordinator] 备用管理器路径: BattleSystems/PositionCollisionManager")
	
	print("📊 [MovementCoordinator] 节点引用设置完成 - 统一管理器状态: ", "已连接" if position_collision_manager else "未连接")

func _connect_signals():
	# 🚫 移除直接信号连接 - 通过BattleScene委托处理
	# 注释：move_confirmed信号现在通过BattleScene._on_move_confirmed_new委托处理
	# 避免重复连接导致信号被处理多次
	print("📡 [MovementCoordinator] 初始化完成，等待通过BattleScene委托的信号")

# 🎯 主要移动确认处理函数
func _on_move_confirmed(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float):
	print("🚶 [MovementCoordinator] 收到移动确认: %s -> %s" % [character.name, str(target_position)])
	print("📊 [MovementCoordinator] 移动参数 - 高度: %.1f, 成本: %.1f" % [target_height, movement_cost])
	
	# 验证移动的合法性
	if not _validate_movement(character, target_position, target_height, movement_cost):
		print("❌ [MovementCoordinator] 移动验证失败，取消移动")
		return
	
	# 获取角色节点
	var character_node = _get_character_node(character)
	if not character_node:
		push_error("[MovementCoordinator] 无法找到角色节点: %s" % character.name)
		print("❌ [MovementCoordinator] 角色节点查找失败: %s" % character.name)
		return
	
	print("✅ [MovementCoordinator] 移动验证通过，开始执行移动")
	print("📍 [MovementCoordinator] 角色当前位置: %s" % str(character_node.position))
	
	# 执行移动
	_execute_movement(character, character_node, target_position, target_height, movement_cost)

# 🔍 验证移动的合法性
func _validate_movement(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float) -> bool:
	coordination_requests += 1
	# 移除频繁的移动验证日志输出
	# print("\n🔍 [MovementCoordinator] 开始移动验证 #", coordination_requests)
	# print("👤 [MovementCoordinator] 验证角色: ", character.name, " (ID: ", character.id, ")")
	# print("📍 [MovementCoordinator] 目标位置: ", target_position)
	# print("🏔️ [MovementCoordinator] 目标高度: ", target_height)
	# print("⚡ [MovementCoordinator] 移动成本: ", movement_cost)
	
	# 检查角色是否已在移动中
	if characters_moving.has(character.id):
		print("⚠️ [MovementCoordinator] 角色 %s 已在移动中" % character.name)
		print("📊 [MovementCoordinator] 当前移动中的角色: %s" % str(characters_moving.keys()))
		return false
	print("✅ [MovementCoordinator] 角色移动状态检查通过")
	
	# 获取角色节点
	var character_node = _get_character_node(character)
	if not character_node:
		print("❌ [MovementCoordinator] 错误: 无法获取角色节点")
		validation_failures += 1
		return false
	
	# 🚀 使用统一的位置碰撞检测管理器进行统一验证（包含物理碰撞和轻功技能检查）
	print("🎯 [MovementCoordinator] 开始使用统一管理器进行位置碰撞检测...")
	if not position_collision_manager:
		print("❌ [MovementCoordinator] 错误: 统一管理器不可用")
		validation_failures += 1
		return false
	
	# print("📋 [MovementCoordinator] 验证参数 - 位置: ", target_position, " 排除角色: ", character_node.name)
	var validation_result = position_collision_manager.validate_position(target_position, character_node)
	
	# 🐛 添加详细的实际移动验证日志
	print("🔍 [实际移动验证] 位置: %s, 角色节点: %s, 验证结果: %s" % [target_position, character_node.name if character_node else "null", validation_result])
	
	# print("📊 [MovementCoordinator] 统一管理器验证结果: ", validation_result)
	
	if not validation_result:
		validation_failures += 1
		# print("❌ [MovementCoordinator] 位置验证失败 #", validation_failures, " - 移动被统一管理器阻止")
		# print("🚫 [MovementCoordinator] 统一管理器检测到位置冲突")
		return false
	
	successful_coordinations += 1
	# print("✅ [MovementCoordinator] 所有移动验证通过 #", successful_coordinations)
	# print("📊 [MovementCoordinator] 验证统计 - 成功: ", successful_coordinations, " 失败: ", validation_failures, "\n")
	return true

# 🚀 执行角色移动
func _execute_movement(character: GameCharacter, character_node: Node2D, target_position: Vector2, target_height: float, movement_cost: float):
	var start_position = character_node.position
	var distance = start_position.distance_to(target_position)
	var move_duration = _calculate_move_duration(distance)
	
	print("🎬 [MovementCoordinator] 准备移动动画")
	print("📍 [MovementCoordinator] 起始位置: %s" % str(start_position))
	print("🎯 [MovementCoordinator] 目标位置: %s" % str(target_position))
	print("📏 [MovementCoordinator] 移动距离: %.1f" % distance)
	print("⏱️ [MovementCoordinator] 动画时长: %.2fs" % move_duration)
	
	# 记录移动状态
	var move_data = {
		"character": character,
		"node": character_node,
		"start_position": start_position,
		"target_position": target_position,
		"target_height": target_height,
		"movement_cost": movement_cost,
		"duration": move_duration,
		"start_time": Time.get_time_dict_from_system()
	}
	characters_moving[character.id] = move_data
	print("📝 [MovementCoordinator] 移动状态已记录，当前移动中角色数量: %d" % characters_moving.size())
	
	# 发出移动开始信号
	movement_started.emit(character, target_position)
	print("📡 [MovementCoordinator] 移动开始信号已发出")
	
	# 更新角色数据中的位置
	character.position = start_position
	print("📊 [MovementCoordinator] 角色数据位置已更新: %s" % str(character.position))
	
	# 创建移动动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_node, "position", target_position, move_duration)
	tween.tween_callback(_on_movement_animation_completed.bind(character, target_position))
	
	print("✅ [MovementCoordinator] 移动动画已创建并启动")
	print("🎬 [MovementCoordinator] Tween对象: %s" % str(tween))
	print("✅ [MovementCoordinator] 开始移动动画: %s, 持续时间: %.2fs" % [character.name, move_duration])

# 🎬 移动动画完成回调
func _on_movement_animation_completed(character: GameCharacter, final_position: Vector2):
	print("🎬 [MovementCoordinator] 移动动画完成回调触发")
	print("📍 [MovementCoordinator] 角色: %s, 最终位置: %s" % [character.name, str(final_position)])
	
	# 检查移动数据是否存在
	if not characters_moving.has(character.id):
		print("⚠️ [MovementCoordinator] 未找到角色移动数据: %s" % character.name)
		return
	
	var move_data = characters_moving[character.id]
	print("📊 [MovementCoordinator] 移动数据: %s" % str(move_data))
	
	# 获取角色节点
	var character_node = move_data.node
	if not character_node:
		print("❌ [MovementCoordinator] 角色节点无效: %s" % character.name)
		characters_moving.erase(character.id)
		return
	
	print("📍 [MovementCoordinator] 角色节点当前位置: %s" % str(character_node.position))
	
	# 确保角色节点位置正确
	character_node.position = final_position
	print("📍 [MovementCoordinator] 角色节点位置已设置为: %s" % str(character_node.position))
	
	# 更新角色数据位置
	character.position = final_position
	character.ground_position = Vector2(final_position.x, final_position.y)
	print("📊 [MovementCoordinator] 角色数据已更新 - position: %s, ground_position: %s" % [str(character.position), str(character.ground_position)])
	
	# 清除移动状态
	characters_moving.erase(character.id)
	print("🗑️ [MovementCoordinator] 移动状态已清除，剩余移动中角色: %d" % characters_moving.size())
	
	# 发出移动完成信号
	movement_completed.emit(character, final_position)
	print("📡 [MovementCoordinator] 移动完成信号已发出")
	
	print("✅ [MovementCoordinator] 移动完成处理结束")
	
	# 🚀 通知BattleScene的移动完成处理（保持现有游戏逻辑）
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene and battle_scene.has_method("_on_move_completed"):
		print("📞 [MovementCoordinator] 通知BattleScene移动完成: %s" % character.name)
		# 获取最终位置用于通知BattleScene
		var final_pos = character.position
		battle_scene._on_move_completed(character, final_pos)
	else:
		print("⚠️ [MovementCoordinator] 未找到BattleScene，直接重置行动系统")
		# 如果找不到BattleScene，直接重置行动系统
		if action_system and action_system.has_method("reset_action_system"):
			action_system.reset_action_system()

# 🚫 移动取消处理
func _on_move_cancelled():
	print("❌ [MovementCoordinator] 移动被取消")
	# 这里可以添加取消移动的逻辑

# 🔧 辅助函数：获取角色节点
func _get_character_node(character: GameCharacter) -> Node2D:
	if not character_manager:
		push_error("[MovementCoordinator] character_manager为空")
		return null
	
	if not character_manager.has_method("get_character_node_by_data"):
		push_error("[MovementCoordinator] character_manager没有get_character_node_by_data方法")
		return null
	
	var character_node = character_manager.get_character_node_by_data(character)
	if not character_node:
		push_error("[MovementCoordinator] 无法找到角色节点: %s (ID: %s)" % [character.name, character.id])
	
	return character_node

# 🔧 辅助函数：计算移动持续时间
func _calculate_move_duration(distance: float) -> float:
	var base_duration = distance / base_move_speed
	return clamp(base_duration, min_move_duration, max_move_duration)

# 🔧 辅助函数：检查位置是否有角色碰撞
func _has_character_collision_at(position: Vector2, exclude_character_id: String) -> bool:
	print("🔍 [MovementCoordinator] 检查目标位置 %s 的碰撞，排除角色: %s" % [position, exclude_character_id])
	
	# 使用统一的物理空间查询碰撞检测管理器
	if not position_collision_manager:
		print("❌ [MovementCoordinator] 位置碰撞管理器不可用")
		return false  # 无法验证时返回false（位置有效）
	
	# 获取排除的角色节点
	var exclude_node = _get_character_node_by_id(exclude_character_id)
	var result = not position_collision_manager.validate_position(position, exclude_node)
	print("✅ [MovementCoordinator] 物理查询验证结果: %s" % ("有碰撞" if result else "无碰撞"))
	return result

# 🔧 公共接口：验证位置是否有效（无碰撞）
func validate_position(target_position: Vector2, character: GameCharacter) -> bool:
	"""验证位置是否有效（无碰撞）"""
	print("🎯 [MovementCoordinator] 开始位置验证: 位置%s, 角色%s" % [target_position, character.character_id])
	
	if not position_collision_manager:
		print("❌ [MovementCoordinator] PositionCollisionManager 不可用")
		return false
	
	var character_node = _get_character_node(character)
	if not character_node:
		print("❌ [MovementCoordinator] 无法找到角色节点: %s" % character.character_id)
		return false
	
	print("🔗 [MovementCoordinator] 使用统一的PositionCollisionManager进行物理查询")
	var result = position_collision_manager.validate_position(target_position, character_node)
	print("📋 [MovementCoordinator] 位置验证结果: %s" % ("有效" if result else "无效"))
	return result



# 🔧 公共接口：直接移动角色（用于AI等）
func move_character_direct(character: GameCharacter, target_position: Vector2) -> bool:
	print("🤖 [MovementCoordinator] 直接移动角色: %s -> %s" % [character.name, str(target_position)])
	
	var character_node = _get_character_node(character)
	if not character_node:
		print("❌ [MovementCoordinator] 无法找到角色节点")
		return false
	
	# 🚀 修复：添加完整的移动验证，包括地面高度检查
	var distance = character_node.position.distance_to(target_position)
	if distance > character.qinggong_skill:
		print("❌ [MovementCoordinator] 移动距离超出轻功限制")
		return false
	
	# 🚀 修复：检查地面高度限制，防止移动到地面以下
	const GROUND_LEVEL: float = 1000.0
	if target_position.y > GROUND_LEVEL:
		print("❌ [MovementCoordinator] 目标位置在地面以下: %.1f > %.1f" % [target_position.y, GROUND_LEVEL])
		return false
	
	# 🚀 修复：添加碰撞检测，防止敌人重叠
	if _has_character_collision_at(target_position, character.id):
		print("❌ [MovementCoordinator] 目标位置被其他角色占用，AI移动取消")
		return false
	
	# 执行移动并等待完成
	_execute_movement(character, character_node, target_position, 0.0, distance)
	
	# 等待移动完成
	await movement_completed
	print("📞 [MovementCoordinator] 通知BattleScene移动完成: %s" % character.name)
	return true

# 🔧 公共接口：检查角色是否在移动中
func is_character_moving(character: GameCharacter) -> bool:
	return characters_moving.has(character.id)

# 🔧 公共接口：获取移动状态信息
func get_movement_info(character: GameCharacter) -> Dictionary:
	if characters_moving.has(character.id):
		return characters_moving[character.id]
	return {}

# 🔧 公共接口：强制停止角色移动
func stop_character_movement(character: GameCharacter) -> void:
	if characters_moving.has(character.id):
		print("🛑 [MovementCoordinator] 强制停止角色移动: %s" % character.name)
		characters_moving.erase(character.id)
		movement_cancelled.emit(character, "强制停止")

# 🔧 公共接口：添加移动中的角色
func add_moving_character(character_id: String, move_data: Dictionary) -> void:
	characters_moving[character_id] = move_data

# 🔧 公共接口：清除所有移动中的角色
func clear_all_moving_characters() -> void:
	characters_moving.clear()

# 🔧 辅助函数：根据角色ID获取角色节点
func _get_character_node_by_id(character_id: String) -> Node2D:
	if not character_manager:
		return null
	
	# 检查队友
	if character_manager.has_method("get_party_member_nodes"):
		var party_nodes = character_manager.get_party_member_nodes()
		if party_nodes.has(character_id):
			return party_nodes[character_id]
	
	# 检查敌人
	if character_manager.has_method("get_enemy_nodes"):
		var enemy_nodes = character_manager.get_enemy_nodes()
		if enemy_nodes.has(character_id):
			return enemy_nodes[character_id]
	
	return null

# 获取统计信息
func get_coordination_statistics() -> Dictionary:
	var stats = {
		"coordination_requests": coordination_requests,
		"successful_coordinations": successful_coordinations,
		"validation_failures": validation_failures,
		"manager_connection_attempts": manager_connection_attempts,
		"success_rate": float(successful_coordinations) / max(coordination_requests, 1) * 100.0,
		"validation_failure_rate": float(validation_failures) / max(coordination_requests, 1) * 100.0
	}
	print("📊 [MovementCoordinator] 协调统计: ", stats)
	return stats

# 打印协调器状态
func print_coordinator_status():
	print("\n=== MovementCoordinator 状态报告 ===")
	print("🎯 统一管理器: ", "已连接" if position_collision_manager else "未连接")
	print("👥 角色管理器: ", "已连接" if character_manager else "未连接")
	print("📍 移动范围控制器: ", "已连接" if move_range_controller else "未连接")
	print("⚡ 行动系统: ", "已连接" if action_system else "未连接")
	print("🚀 正在移动的角色数: ", characters_moving.size())
	print("📊 协调统计:")
	print("   - 协调请求总数: ", coordination_requests)
	print("   - 成功协调次数: ", successful_coordinations)
	print("   - 验证失败次数: ", validation_failures)
	if coordination_requests > 0:
		print("   - 成功率: ", "%.1f%%" % (float(successful_coordinations) / coordination_requests * 100.0))
		print("   - 验证失败率: ", "%.1f%%" % (float(validation_failures) / coordination_requests * 100.0))
	print("=== 状态报告结束 ===\n")

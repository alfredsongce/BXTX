# 玩家移动组件
extends Node
class_name PlayerMovementComponent

# 移动相关信号
signal move_requested(target_position: Vector2, target_height: float)
signal move_completed()

# 引用
var player_node: Node2D
var character_data: GameCharacter
var position_collision_manager: Node2D

# 移动相关变量
var is_moving: bool = false

# 统计数据
var move_requests: int = 0
var successful_moves: int = 0
var failed_validations: int = 0

func _init(player: Node2D = null):
	if player:
		setup(player)

func setup(player: Node2D) -> void:
	print("🔧 [PlayerMovementComponent] 开始设置玩家移动组件")
	player_node = player
	print("✅ [PlayerMovementComponent] 玩家节点设置完成: ", player.name)
	
	if player.has_method("get_character_data"):
		character_data = player.get_character_data()
		print("✅ [PlayerMovementComponent] 角色数据获取成功: ", character_data.name if character_data else "null")
	
	# 获取位置碰撞管理器引用
	print("🔍 [PlayerMovementComponent] 正在查找PositionCollisionManager...")
	var battle_scene = player.get_tree().current_scene
	if battle_scene:
		position_collision_manager = battle_scene.get_node_or_null("BattleSystems/PositionCollisionManager")
		if position_collision_manager:
			print("🎯 [PlayerMovementComponent] 成功连接到统一位置碰撞管理器!")
			print("📍 [PlayerMovementComponent] 管理器路径: BattleSystems/PositionCollisionManager")
			print("🔗 [PlayerMovementComponent] 管理器类型: ", position_collision_manager.get_class())
		else:
			print("❌ [PlayerMovementComponent] 错误: 未找到PositionCollisionManager")
			print("🔍 [PlayerMovementComponent] 请检查BattleScene中是否正确配置了管理器")
	else:
		print("❌ [PlayerMovementComponent] 错误: 无法获取当前场景")

# 处理移动到指定位置
func move_to(new_position: Vector2, target_height: float = 0.0) -> void:
	move_requests += 1
	print("\n🚀 [PlayerMovementComponent] 移动请求 #", move_requests, " 开始处理")
	
	if not character_data or is_moving:
		print("❌ [PlayerMovementComponent] 移动被拒绝 - 角色数据: ", character_data != null, " 正在移动: ", is_moving)
		return
		
	print("********** 🎯 移动确认详情 **********")
	print("📍 目标坐标: (%s, %s), 当前坐标: (%s, %s)" % [new_position.x, new_position.y, player_node.position.x, player_node.position.y])
	print("📏 移动距离: %.2f 像素" % player_node.position.distance_to(new_position))
	print("🏔️ 目标高度: %.1f, 当前高度: %.1f" % [target_height, character_data.get_height_level()])
	print("👤 发起移动的角色: %s (ID: %s)" % [character_data.name, character_data.id])
	print("*********************************")
	
	# 🚀 使用统一的位置碰撞检测管理器验证位置
	print("🔍 [PlayerMovementComponent] 开始使用统一物理查询管理器验证位置...")
	var validation_result = true  # 默认为true，如果没有管理器则跳过验证
	if position_collision_manager:
		print("✅ [PlayerMovementComponent] 统一PositionCollisionManager可用，调用validate_position方法")
		print("📋 [PlayerMovementComponent] 验证参数 - 位置: %s, 排除角色: %s" % [new_position, player_node.name])
		print("🔗 [PlayerMovementComponent] 使用统一的物理空间查询系统进行碰撞检测")
		
		# 使用统一的位置碰撞管理器进行验证
		validation_result = position_collision_manager.validate_position(new_position, player_node)
		print("📊 [PlayerMovementComponent] 统一物理查询验证结果: %s" % ("通过" if validation_result else "失败"))
		
		if not validation_result:
			failed_validations += 1
			print("❌ [PlayerMovementComponent] 位置验证失败 #", failed_validations, " - 无法移动到目标位置")
			print("🚫 [PlayerMovementComponent] 移动被统一管理器阻止")
			return
		else:
			print("✅ [PlayerMovementComponent] 位置验证通过 - 统一管理器确认位置安全")
	else:
		print("⚠️ [PlayerMovementComponent] 警告: 统一管理器不可用，跳过位置验证")
		print("🔧 [PlayerMovementComponent] 建议检查PositionCollisionManager的配置")
	
	print("🎬 [PlayerMovementComponent] 开始执行移动动画...")
	# 执行移动
	is_moving = true
	successful_moves += 1
	print("📈 [PlayerMovementComponent] 成功移动计数: ", successful_moves)
	
	# 发出移动请求信号
	move_requested.emit(new_position, target_height)
	print("📡 [PlayerMovementComponent] 移动请求信号已发出")
	
	# 更新角色位置
	player_node.position = new_position
	character_data.set_height_level(target_height)
	print("✅ [PlayerMovementComponent] 角色位置已更新")
	print("📍 [PlayerMovementComponent] 新位置: ", player_node.position)
	print("🏔️ [PlayerMovementComponent] 新高度: ", character_data.get_height_level())
	
	# 移动完成
	is_moving = false
	move_completed.emit()
	print("🎉 [PlayerMovementComponent] 移动完成信号已发出")
	print("✅ [PlayerMovementComponent] 移动请求 #", move_requests, " 处理完毕\n")

# 设置角色的基准位置（地面位置）
func set_base_position(base_pos: Vector2) -> void:
	if not character_data:
		return
	
	# 保存当前高度等级（浮点数值）
	var current_height_level = character_data.get_height_level()
	
	# 使用GroundAnchor节点计算地面对齐位置
	var ground_anchor = player_node.get_node_or_null("GroundAnchor")
	var ground_offset = Vector2.ZERO
	if ground_anchor:
		ground_offset = ground_anchor.position
	
	# 计算角色中心位置，使GroundAnchor对齐到目标地面位置
	var character_center_pos = Vector2(base_pos.x, base_pos.y - ground_offset.y)
	
	# 更新角色的地面位置（记录GroundAnchor应该对齐的位置）
	character_data.ground_position = base_pos
	
	# 根据当前高度设置实际位置 - 使用精确的浮点数高度值
	var height_pixels = current_height_level * 40.0  # 确保浮点数乘法
	
	# 计算最终位置 - 位置Y坐标 = 角色中心Y坐标 - 高度(越高Y值越小)
	player_node.position = Vector2(character_center_pos.x, character_center_pos.y - height_pixels)
	character_data.position = player_node.position  # 同步GameCharacter的position
	
	# 确保碰撞区域也正确更新位置
	var character_area = player_node.get_node_or_null("CharacterArea")
	if character_area:
		character_area.position = Vector2.ZERO  # 保持相对于角色的位置为0
	
	print("设置基准位置: (%s, %s), 当前高度级别: %.2f, 高度像素: %.1f, 实际位置: (%s, %s)" % [
		base_pos.x, base_pos.y, 
		current_height_level, height_pixels, 
		player_node.position.x, player_node.position.y
	])

# 获取角色的基准位置（地面位置）
func get_base_position() -> Vector2:
	if character_data:
		return character_data.ground_position
	return player_node.position

# 显示移动范围
func show_move_range() -> void:
	if not character_data:
		print("错误：无法获取角色数据")
		return
	
	print("显示移动范围 - 角色: %s, 轻功值: %s像素, 轻功等级: %s, 当前高度: %s" % [
		character_data.name, 
		character_data.qinggong_skill, 
		int(character_data.qinggong_skill / 40),
		character_data.get_height_level()
	])
	
	# 获取行动系统，确保状态正确
	var action_system_script = preload("res://Scripts/ActionSystemNew.gd")
	var action_system = player_node.get_tree().current_scene.get_node_or_null("ActionSystem")
	if action_system:
		if action_system.current_state != action_system_script.SystemState.SELECTING_MOVE_TARGET:
			print("警告：行动系统状态不是SELECTING_MOVE_TARGET，将其设置为正确状态")
			action_system.current_state = action_system_script.SystemState.SELECTING_MOVE_TARGET
			action_system.selected_character = player_node
	
	# 🚀 新架构：使用MoveRange组件系统
	var battle_scene = player_node.get_tree().current_scene
	var move_range_controller = battle_scene.get_node_or_null("MoveRange/Controller")
	
	if move_range_controller:
		print("🚀 找到新的移动范围控制器，显示移动范围")
		move_range_controller.show_move_range(character_data)
	else:
		# 🔧 fallback：尝试旧的移动范围显示器（向后兼容）
		var range_display = battle_scene.get_node_or_null("MoveRangeDisplay")
		if range_display:
			print("⚠️ 使用旧的移动范围显示器（兼容模式）")
			range_display.display_for_character(character_data, player_node.position)
		else:
			push_error("❌ 严重错误：未找到移动范围显示系统！请确保场景中有MoveRange或MoveRangeDisplay节点")

# 获取统计信息
func get_movement_statistics() -> Dictionary:
	var stats = {
		"move_requests": move_requests,
		"successful_moves": successful_moves,
		"failed_validations": failed_validations,
		"success_rate": float(successful_moves) / max(move_requests, 1) * 100.0,
		"validation_failure_rate": float(failed_validations) / max(move_requests, 1) * 100.0
	}
	print("📊 [PlayerMovementComponent] 移动统计: ", stats)
	return stats

# 打印组件状态
func print_component_status():
	print("\n=== PlayerMovementComponent 状态报告 ===")
	print("👤 绑定角色: ", character_data.name if character_data else "未绑定")
	print("🎯 统一管理器: ", "已连接" if position_collision_manager else "未连接")
	print("🚀 移动状态: ", "移动中" if is_moving else "空闲")
	print("📊 移动统计:")
	print("   - 移动请求总数: ", move_requests)
	print("   - 成功移动次数: ", successful_moves)
	print("   - 验证失败次数: ", failed_validations)
	if move_requests > 0:
		print("   - 成功率: ", "%.1f%%" % (float(successful_moves) / move_requests * 100.0))
		print("   - 验证失败率: ", "%.1f%%" % (float(failed_validations) / move_requests * 100.0))
	print("=== 状态报告结束 ===\n")

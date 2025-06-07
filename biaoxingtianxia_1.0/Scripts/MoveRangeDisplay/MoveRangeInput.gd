# 🎮 移动范围显示系统 - 输入处理组件（增强版）
extends Node2D
class_name MoveRangeInput

# 🎮 输入状态
var _is_handling_input: bool = false
var _input_enabled: bool = true  # 🚀 新增：输入启用状态
var _current_character: GameCharacter = null
var _mouse_position: Vector2 = Vector2.ZERO
# 🚀 移除冗余状态变量，统一使用PositionCollisionManager的缓存
# var _is_valid_position: bool = true  # 已移除
# var _movement_cost: float = 0.0      # 已移除

# 🔧 性能优化
var _last_mouse_update_time: int = 0
var _mouse_update_interval: int = 16  # 约60FPS的更新频率
var _cached_query: PhysicsShapeQueryParameters2D = null
var _physics_space: PhysicsDirectSpaceState2D
var _use_physics_query: bool = true  # 启用物理查询优化

# 📡 信号
signal move_confirmed(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float)
signal move_cancelled()
signal mouse_moved(position: Vector2)
signal height_changed(new_height: float)
signal validation_changed(is_valid: bool, reason: String)

# 🔧 组件引用
var config  # 改为动态类型
var position_collision_manager: Node2D  # 🚀 统一位置碰撞管理器

# 📊 统计变量
var input_events: int = 0
var validation_requests: int = 0
var successful_validations: int = 0
var failed_validations: int = 0

func _ready():
	# 移除过度日志输出 - 初始化时不输出
	
	# 🚀 初始化物理空间
	_physics_space = get_world_2d().direct_space_state
	print("🌍 [MoveRangeInput] 物理空间状态获取完成")
	
	# 获取配置组件引用
	call_deferred("_setup_config_reference")
	# 延迟调用position_collision_manager设置
	call_deferred("_setup_position_collision_manager")
	
	# 移除过度日志输出 - 初始化完成时不输出

func _setup_config_reference():
	config = get_node("../Config")
	if not config:
		push_warning("[MoveRangeInput] 未找到Config组件")
	else:
		print("✅ [MoveRangeInput] Config组件连接成功")

# 🚀 移除Validator引用设置函数（已不需要）

func _setup_position_collision_manager():
	print("🔍 [MoveRangeInput] 开始查找统一位置碰撞管理器...")
	# 获取位置碰撞管理器引用
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene:
		print("🔍 [MoveRangeInput] 当前场景名称: ", battle_scene.name)
		print("🔍 [MoveRangeInput] 当前场景类型: ", battle_scene.get_class())
		
		# 尝试多种路径查找PositionCollisionManager
		var paths_to_try = [
			"BattleSystems/PositionCollisionManager",
			"PositionCollisionManager",
			"./BattleSystems/PositionCollisionManager"
		]
		
		for path in paths_to_try:
			print("🔍 [MoveRangeInput] 尝试路径: ", path)
			position_collision_manager = battle_scene.get_node_or_null(path)
			if position_collision_manager:
				print("✅ [MoveRangeInput] 成功连接到统一位置碰撞管理器!")
				print("📍 [MoveRangeInput] 管理器路径: ", path)
				print("🔗 [MoveRangeInput] 管理器类型: ", position_collision_manager.get_class())
				break
		
		if not position_collision_manager:
			print("🔍 [MoveRangeInput] 常规路径查找失败，尝试递归查找...")
			position_collision_manager = _find_node_recursive(battle_scene, "PositionCollisionManager")
			if position_collision_manager:
				print("✅ [MoveRangeInput] 递归查找成功!")
			else:
				print("❌ [MoveRangeInput] 警告: 未找到统一位置碰撞管理器，尝试重试...")
				# 延迟重试，给PositionCollisionManager更多时间初始化
				get_tree().create_timer(0.1).timeout.connect(_retry_setup_position_collision_manager)
	else:
		print("❌ [MoveRangeInput] 错误: 无法获取当前场景")
	
	print("📊 [MoveRangeInput] 统一管理器状态: ", "已连接" if position_collision_manager else "未连接")

# 重试计数器
var _retry_count: int = 0
var _max_retries: int = 5

func _retry_setup_position_collision_manager():
	_retry_count += 1
	print("🔄 [MoveRangeInput] 重试连接统一位置碰撞管理器... (第%d次/共%d次)" % [_retry_count, _max_retries])
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene:
		# 尝试多种路径查找PositionCollisionManager
		var paths_to_try = [
			"BattleSystems/PositionCollisionManager",
			"PositionCollisionManager",
			"./BattleSystems/PositionCollisionManager"
		]
		
		for path in paths_to_try:
			position_collision_manager = battle_scene.get_node_or_null(path)
			if position_collision_manager:
				print("✅ [MoveRangeInput] 重试成功！连接到统一位置碰撞管理器")
				print("📍 [MoveRangeInput] 管理器路径: ", path)
				print("🔗 [MoveRangeInput] 管理器类型: ", position_collision_manager.get_class())
				break
		
		if not position_collision_manager:
			# 尝试递归查找
			position_collision_manager = _find_node_recursive(battle_scene, "PositionCollisionManager")
		
		if not position_collision_manager:
			if _retry_count < _max_retries:
				print("⏳ [MoveRangeInput] 第%d次重试失败，将在0.5秒后再次重试..." % _retry_count)
				get_tree().create_timer(0.5).timeout.connect(_retry_setup_position_collision_manager)
			else:
				print("❌ [MoveRangeInput] 所有重试都失败，统一位置碰撞管理器不可用")
				printerr("[MoveRangeInput] 统一位置碰撞管理器不可用，系统无法正常工作")
	else:
		print("❌ [MoveRangeInput] 无法获取当前场景")
	
	print("📊 [MoveRangeInput] 统一管理器状态: ", "已连接" if position_collision_manager else "未连接")

# 递归查找节点的辅助函数
func _find_node_recursive(parent: Node, node_name: String) -> Node:
	if parent.name == node_name:
		return parent
	
	for child in parent.get_children():
		var result = _find_node_recursive(child, node_name)
		if result:
			return result
	
	return null

# 🎯 输入处理控制
func start_input_handling(character: GameCharacter):
	# 移除过度日志输出 - 开始输入时不输出
	print("👤 [MoveRangeInput] 处理角色: ", character.name if character else "null", " (ID: ", character.id if character else "null", ")")
	
	if not character:
		push_warning("[MoveRangeInput] 角色参数为空")
		return
	
	_is_handling_input = true
	_current_character = character
	
	print("✅ [MoveRangeInput] 输入处理已启动 - 角色: %s" % character.name)
	print("📊 [MoveRangeInput] 统一管理器可用: ", "是" if position_collision_manager else "否")

func stop_input_handling():
	_is_handling_input = false
	_current_character = null
	_mouse_position = Vector2.ZERO
	print("🛑 [MoveRangeInput] 停止处理输入")
	print("📊 [MoveRangeInput] 输入统计 - 事件: ", input_events, " 验证: ", validation_requests, " 成功: ", successful_validations, " 失败: ", failed_validations)

# 🎯 输入启用控制
func set_input_enabled(enabled: bool):
	_input_enabled = enabled
	# 移除过度日志输出 - 状态切换时不输出

func _input(event):
	if not _is_handling_input or not _current_character or not _input_enabled:
		return
	
	# 🖱️ 鼠标移动处理
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	
	# 🖱️ 鼠标点击处理
	elif event is InputEventMouseButton:
		_handle_mouse_click(event)
	
	# ⌨️ 键盘输入处理
	elif event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)
		if event.keycode == KEY_W:
			_output_physical_validation_debug()

# 🖱️ 鼠标移动处理（优化版）
func _handle_mouse_motion(event: InputEventMouseMotion):
	var current_time = Time.get_ticks_msec()
	
	# 🚀 性能优化：限制更新频率
	if current_time - _last_mouse_update_time < _mouse_update_interval:
		return
	
	_last_mouse_update_time = current_time
	_mouse_position = event.global_position
	
	# 🧲 地面吸附功能：当鼠标接近地面线时自动吸附
	_apply_ground_snap()
	
	# 🚀 立即更新渲染器的鼠标指示器
	var renderer = get_node("../Renderer")
	if renderer:
		renderer.update_mouse_indicator(_mouse_position)
	
	# 🚀 异步验证位置
	call_deferred("_validate_target_position_async")
	
	# 发射鼠标移动信号
	mouse_moved.emit(_mouse_position)

# 🚀 异步位置验证
func _validate_target_position_async():
	if not _current_character or _mouse_position == Vector2.ZERO:
		# 移除频繁的鼠标移动调试输出
		return
	
	# 🚀 简化：直接使用鼠标位置作为目标位置
	var target_position = _mouse_position
	# 移除频繁的位置验证调试输出
	
	# 🚀 修复：获取角色节点的实际位置
	var actual_character_position = _get_character_actual_position()
	if actual_character_position == Vector2.ZERO:
		# 无法获取节点位置时直接报错，不使用fallback
		push_error("[MoveRangeInput] 无法获取角色实际位置，移动验证失败")
		# 已移除 _is_valid_position 状态变量
		return
	
	# 🚀 优化后的验证流程 - 使用统一的PositionCollisionManager引用
	if not position_collision_manager:
		validation_changed.emit(false, "位置碰撞管理器不可用")
		return
	
	var character_node = _get_character_node(_current_character)
	if not character_node:
		validation_changed.emit(false, "无法找到角色节点")
		return
	
	# 使用统一的验证接口获取详细结果
	# 移除过度日志输出 - 调用验证时不输出
	var validation_details = position_collision_manager.get_validation_details(target_position, character_node)
	# 移除过度日志输出 - 验证结果时不输出
	
	# 🔧 修复：保持真实鼠标位置，不要被调整后位置覆盖
	if validation_details.is_valid and validation_details.has("adjusted_position"):
		var adjusted_pos = validation_details.adjusted_position
		if adjusted_pos != target_position:
			# 🎯 关键修复：保持_mouse_position为真实鼠标位置，不要替换为调整后位置
			# 这样Renderer就能收到真实的原始位置和调整后位置，实现"所见即所得"的视觉效果
			# _mouse_position = adjusted_pos  # ❌ 删除这行！这是问题根源
			# 发送位置更新信号（使用调整后位置用于实际移动）
			mouse_moved.emit(adjusted_pos)
			# 移除过度日志 - 仅在按键调试时输出
			if Input.is_key_pressed(KEY_D):
				print("🔍 [调试] 已发送mouse_moved信号，位置: %s" % adjusted_pos)
			# 验证渲染器是否存在 - 移除过度日志
			var renderer = get_node("../Renderer")
			if not renderer and Input.is_key_pressed(KEY_D):
				print("🚨 [错误] 渲染器不存在！")
		else:
			# 移除过度日志输出 - 位置无需调整时不输出
			pass
	else:
		if validation_details.is_valid:
			# 移除过度日志输出 - 验证通过但无调整位置时不输出
			pass
		else:
			# 移除过度日志输出 - 验证失败时不输出，只在F2调试时显示
			pass
	
	# 🐛 添加详细的验证对比日志
	# print("🔍 [优化验证] 位置: %s, 角色: %s, 验证结果: %s, 原因: %s" % [target_position, _current_character.name, validation_details.is_valid, validation_details.reason])
	
	# 发送验证结果信号
	validation_changed.emit(validation_details.is_valid, validation_details.reason)

# 🚀 获取角色节点的实际位置
func _get_character_actual_position() -> Vector2:
	if not _current_character:
		# print("⚠️ [Input] _current_character为空")  # 移除频繁打印
		return Vector2.ZERO
	
	# 尝试通过BattleScene查找角色节点
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if not battle_scene:
		# print("⚠️ [Input] 通过group查找BattleScene失败，尝试父节点方式")  # 移除频繁打印
		# 尝试通过父节点查找BattleScene
		var parent = get_parent()
		while parent and parent.name != "BattleScene":
			parent = parent.get_parent()
		battle_scene = parent
	
	if not battle_scene:
		# print("⚠️ [Input] 无法找到BattleScene，返回Vector2.ZERO")  # 移除频繁打印
		return Vector2.ZERO
	
	# 查找对应的角色节点
	if battle_scene.has_method("_find_character_node_by_id"):
		var character_node = battle_scene._find_character_node_by_id(_current_character.id)
		if character_node:
			# print("✅ [Input] 成功获取角色节点位置: %s" % str(character_node.position))  # 移除频繁打印
			return character_node.position
		else:
			# print("⚠️ [Input] 找不到角色ID为%s的节点" % _current_character.id)  # 移除频繁打印
			pass
	else:
		# print("⚠️ [Input] BattleScene没有_find_character_node_by_id方法")  # 移除频繁打印
		pass
	
	# 如果找不到，返回零向量表示失败
	# print("⚠️ [Input] 获取角色节点位置失败，返回Vector2.ZERO")  # 移除频繁打印
	return Vector2.ZERO

# 🚀 已删除 _validate_position_comprehensive 方法
# 该方法已被优化，现在直接使用 PositionCollisionManager.get_validation_details()

# 🖱️ 鼠标点击处理
func _handle_mouse_click(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("🔥 [信号追踪] 鼠标左键点击，即将调用_confirm_move()")
		_confirm_move()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_move()

# ⌨️ 键盘输入处理（简化版）
func _handle_keyboard_input(event: InputEventKey):
	match event.keycode:
		# 确认/取消
		KEY_ENTER, KEY_SPACE:
			_confirm_move()
		KEY_ESCAPE:
			_cancel_move()
		
		KEY_C:  # 清空缓存
			_clear_position_cache()

		KEY_T:  # 调试信息输出
			_output_debug_info()
		
		KEY_D:  # 按住D键移动鼠标可查看详细的位置更新调试信息
			if event.pressed:
				print("🔍 [调试模式] 按住D键移动鼠标可查看详细的位置更新流程")
		
		KEY_Q:  # Q键调试WALL障碍物吸附问题
			if event.pressed:
				_debug_wall_obstacle_snap()

# 🎯 调整鼠标高度（简化版）
func _adjust_mouse_height(delta_y: float):
	if not _current_character:
		return
	
	_mouse_position.y += delta_y
	
	# 重新验证位置
	call_deferred("_validate_target_position_async")
	
	# 🚀 立即更新渲染器的鼠标指示器
	var renderer = get_node("../Renderer")
	if renderer:
		renderer.update_mouse_indicator(_mouse_position)
	
	# print("🎮 [Input] 鼠标高度调整到: Y=%.1f" % _mouse_position.y)

func _reset_to_character_height():
	if _current_character:
		_mouse_position.y = _current_character.position.y
		call_deferred("_validate_target_position_async")
		var renderer = get_node("../Renderer")
		if renderer:
			renderer.update_mouse_indicator(_mouse_position)
		# print("🎮 [Input] 重置到角色当前高度")

# 🚀 快捷键功能
func _toggle_visual_effects():
	if config:
		var current = config.is_visual_effects_enabled()
		config.set_visual_effects_enabled(not current)
		# print("🎮 [Input] 视觉效果: %s" % ("启用" if not current else "禁用"))

func _toggle_animation():
	if config:
		var speed = config.animation_speed
		config.set_animation_speed(0.1 if speed > 0.5 else 2.0)
		# print("🎮 [Input] 动画: %s" % ("暂停" if speed > 0.5 else "恢复"))

func _toggle_batch_mode():
	if config:
		var current = config.is_batch_computation_enabled()
		config.batch_computation = not current
		# print("🎮 [Input] 批量模式: %s" % ("启用" if not current else "禁用"))

# 🎯 移动确认和取消（完整验证版）
func _confirm_move():
	print("🔥 [信号追踪] ========== _confirm_move() 开始执行 ==========\n")
	print("🔥 [信号追踪] 调用栈信息: %s" % str(get_stack()))
	# 移除过度日志输出 - 确认移动时不输出位置信息
	
	if not _current_character or _mouse_position == Vector2.ZERO:
		print("🔥 [信号追踪] 移动确认失败：角色或位置无效")
		return

	# 🚀 步骤1：快速预检测
	var quick_check = _quick_collision_precheck(_mouse_position, _current_character)
	print("🐛 [调试-移动确认] 快速预检测结果: %s" % ("通过" if quick_check else "失败"))
	
	# 🚀 步骤2：使用统一的PositionCollisionManager进行验证（与MovementCoordinator保持一致）
	var target_position = _mouse_position
	
	# 使用统一的位置碰撞管理器引用
	print("🐛 [调试-移动确认] 获取PositionCollisionManager: %s" % ("成功" if position_collision_manager else "失败"))
	if not position_collision_manager:
		# 已移除 _is_valid_position 状态变量
		validation_changed.emit(false, "位置碰撞管理器不可用")
		print("🔥 [信号追踪] 移动确认失败：位置碰撞管理器不可用")
		return
	
	# 获取角色节点（与MovementCoordinator使用相同的方式）
	var character_node = _get_character_node(_current_character)
	print("🐛 [调试-移动确认] 获取角色节点: %s" % ("成功" if character_node else "失败"))
	if not character_node:
		print("🐛 [调试-移动确认] 无法找到角色节点")
		# 已移除 _is_valid_position 状态变量
		validation_changed.emit(false, "无法找到角色节点")
		print("🔥 [信号追踪] 移动确认失败：无法找到角色节点")
		return
	
	# 使用与MovementCoordinator完全相同的验证方法
	var final_validation = position_collision_manager.validate_position(target_position, character_node)
	print("🐛 [调试-移动确认] PositionCollisionManager.validate_position返回: %s" % final_validation)
	
	print("🐛 [调试-移动确认] 统一验证结果: %s" % ("通过" if final_validation else "失败"))
	if not final_validation:
		print("🐛 [调试-移动确认] 验证失败 - 使用统一验证器")
		print("🚨 [Input] 统一验证器确认位置无效")
		# 已移除 _is_valid_position 状态变量
		validation_changed.emit(false, "位置被统一管理器阻止")
		print("🔥 [信号追踪] 移动确认失败：位置被统一管理器阻止")
		return
	
	# 🚀 步骤3：计算实际移动距离
	var actual_character_position = _get_character_actual_position()
	if actual_character_position == Vector2.ZERO:
		actual_character_position = _current_character.position
	var final_distance = actual_character_position.distance_to(target_position)
	print("🐛 [调试-移动确认] 移动距离: %.2f, 轻功限制: %d" % [final_distance, _current_character.qinggong_skill])
	
	# 🚀 步骤4：最后一道防线：确保距离不超过轻功限制
	if final_distance > _current_character.qinggong_skill:
		print("🐛 [调试-移动确认] 距离检查失败: %.1f > %d" % [final_distance, _current_character.qinggong_skill])
		# 已移除 _is_valid_position 状态变量
		validation_changed.emit(false, "移动距离超出轻功限制")
		print("🔥 [信号追踪] 移动确认失败：移动距离超出轻功限制")
		return
	
	print("🔥 [信号追踪] 所有验证通过，即将发送move_confirmed信号")
	print("🔥 [信号追踪] 信号参数: 角色=%s, 位置=%s, 距离=%.2f" % [_current_character.name, target_position, final_distance])
	print("🔥 [信号追踪] ========== 发送move_confirmed信号 ==========\n")
	
	move_confirmed.emit(_current_character, target_position, 0.0, final_distance)
	
	print("🔥 [信号追踪] move_confirmed信号已发送")
	print("🔥 [信号追踪] ========== _confirm_move() 执行结束 ==========\n")

func _cancel_move():
	# print("❌ [Input] 取消移动")
	move_cancelled.emit()

# 🔧 状态查询接口
func is_handling_input() -> bool:
	return _is_handling_input

func get_current_target_position() -> Vector2:
	# 🚀 简化：直接返回鼠标位置
	return _mouse_position

func get_target_height() -> float:
	return 0.0  # 因为已经包含在position中

# 🚀 优化后的位置验证 - 直接使用PositionCollisionManager
func is_position_valid() -> bool:
	if not _current_character:
		return false
	
	var target_position = get_global_mouse_position()
	if not position_collision_manager:
		return false
	
	var character_node = _get_character_node(_current_character)
	if not character_node:
		return false
	
	# 直接使用PositionCollisionManager的缓存结果
	return position_collision_manager.validate_position(target_position, character_node)

# 🚀 优化后的移动成本获取 - 直接使用PositionCollisionManager
func get_movement_cost() -> float:
	if not _current_character:
		return 0.0
	
	var target_position = get_global_mouse_position()
	var actual_character_position = _get_character_actual_position()
	if position_collision_manager:
		return position_collision_manager.get_movement_cost(actual_character_position, target_position)
	return 0.0

# 🚀 性能监控
# 🚀 优化后的性能监控 - 使用新的获取方法
func get_input_stats() -> Dictionary:
	return {
		"is_handling_input": _is_handling_input,
		"mouse_update_interval": _mouse_update_interval,
		"last_update_time": _last_mouse_update_time,
		"target_height": 0.0,
		"is_valid_position": is_position_valid(),  # 使用新方法
		"movement_cost": get_movement_cost()      # 使用新方法
	}

func set_mouse_update_interval(interval_ms: int):
	_mouse_update_interval = clamp(interval_ms, 8, 100)  # 8-100ms范围
	# print("🎮 [Input] 鼠标更新间隔: %dms" % _mouse_update_interval)

# 🧲 地面吸附功能
func _apply_ground_snap():
	# 动态检测最近的平台上边缘
	var platform_top_y = _find_nearest_platform_top()
	if platform_top_y == null:
		print("🧲 [Input] 吸附失败: 没有找到平台")
		return  # 没有找到平台，不进行吸附
	
	# 获取实际的GroundAnchor偏移量
	var ground_offset = _get_ground_anchor_offset()
	# 🚀 第三步修复：从配置文件获取吸附范围
	var snap_range = float(_get_ground_platform_snap_distance())  # 吸附范围（像素）
	# Delta偏移量，避免精确贴合导致的边界检测问题
	var snap_delta = 1.0
	
	# 计算角色GroundAnchor应该对齐到地面线时，鼠标应该在的位置
	# 鼠标位置应该是角色中心位置，即地面线位置向上偏移GroundAnchor的Y值，再加上Delta偏移
	var target_mouse_y = platform_top_y - ground_offset.y - snap_delta
	
	# 检查鼠标是否在吸附范围内
	var distance_to_target = abs(_mouse_position.y - target_mouse_y)
	# print("🧲 [Input] 吸附检查: 鼠标Y=%.1f, 目标Y=%.1f, 距离=%.1f, 范围=%.1f" % [_mouse_position.y, target_mouse_y, distance_to_target, snap_range])
	if distance_to_target <= snap_range:
		# 设置鼠标位置为角色中心位置，这样GroundAnchor会正确对齐到地面线
		_mouse_position.y = target_mouse_y
		# print("🧲 [Input] 鼠标吸附到角色中心位置: Y=%.1f (GroundAnchor将对齐到平台顶部Y=%.1f，Delta=%.1f)" % [_mouse_position.y, platform_top_y, snap_delta])

# 🔧 获取地面锚点偏移
func _get_ground_anchor_offset() -> Vector2:
	"""从当前角色节点获取GroundAnchor偏移量"""
	if not _current_character:
		push_error("当前角色为空，无法获取GroundAnchor")
		return Vector2.ZERO
	
	var character_node = _get_character_node(_current_character)
	if not character_node:
		push_error("无法获取角色节点，无法获取GroundAnchor")
		return Vector2.ZERO
	
	var ground_anchor = character_node.get_node_or_null("GroundAnchor")
	if ground_anchor:
		# 移除过度日志输出 - 只在按键调试时输出
		return ground_anchor.position
	else:
		push_error("角色 %s 缺少GroundAnchor节点" % character_node.name)
		return Vector2.ZERO  # 🚀 强制要求每个角色都有GroundAnchor

# 🚀 第三步修复：获取地面平台吸附距离
func _get_ground_platform_snap_distance() -> int:
	"""从配置文件获取地面平台吸附距离"""
	# 尝试从config获取
	var config = get_node("../Config")
	if config and config.has_method("get_ground_platform_snap_distance"):
		return config.get_ground_platform_snap_distance()
	else:
		print("⚠️ [Input] 无法获取ground_platform_snap_distance配置，使用默认值: 30像素")
		return 30  # 默认值

# 🔍 查找最近的平台顶部位置
func _find_nearest_platform_top():
	"""动态查找最近的PlatformObstacle的上边缘位置"""
	# 获取障碍物管理器
	# 通过场景树查找障碍物管理器
	var battle_scene = AutoLoad.get_battle_scene()
	var obstacle_manager = battle_scene.get_node_or_null("TheLevel/ObstacleManager")
	if not obstacle_manager:
		print("🔍 [Input] 未找到障碍物管理器")
		return null
	
	# 获取所有平台障碍物
	var platforms = []
	for obstacle in obstacle_manager.obstacles:
		# 检查是否是平台类型（枚举值4对应PLATFORM）
		if obstacle.obstacle_type == Obstacle.ObstacleType.PLATFORM:
			platforms.append(obstacle)
	
	# print("🔍 [Input] 找到 %d 个平台障碍物" % platforms.size())
	if platforms.is_empty():
		printerr("🚫 [Input] 没有找到平台障碍物")
		return null
	
	# 找到最接近鼠标Y坐标的平台
	var nearest_platform = null
	var min_distance = INF
	
	for platform in platforms:
		# 计算平台顶部Y坐标（平台位置 - 碰撞形状高度的一半）
		var platform_top = platform.position.y - (platform.collision_shape.shape.size.y * platform.collision_shape.scale.y) / 2.0
		var distance = abs(_mouse_position.y - platform_top)
		# print("🔍 [Input] 平台位置: Y=%.1f, 顶部: Y=%.1f, 距离: %.1f" % [platform.position.y, platform_top, distance])
		
		if distance < min_distance:
			min_distance = distance
			nearest_platform = platform_top
	
	# print("🔍 [Input] 找到最近平台顶部: Y=%.1f, 距离: %.1f" % [nearest_platform, min_distance])
	return nearest_platform

# 🔧 工具方法
func force_validate_position():
	"""强制验证当前位置"""
	call_deferred("_validate_target_position_async")

func reset_target_height():
	"""重置目标高度为角色当前高度"""
	if _current_character:
		_mouse_position.y = _current_character.position.y
		call_deferred("_validate_target_position_async")
		var renderer = get_node("../Renderer")
		if renderer:
			renderer.update_mouse_indicator(_mouse_position)
		# print("🎮 [Input] 重置到角色当前高度")

# 🚀 快速碰撞预检测 - 基于物理空间查询
func _quick_collision_precheck(position: Vector2, character: GameCharacter) -> bool:
	"""快速碰撞预检测，使用统一的物理空间查询管理器"""
	print("🎯 [MoveRangeInput] 开始快速碰撞预检查: 位置%s" % position)
	
	# 使用统一的物理空间查询碰撞检测管理器
	if position_collision_manager:
		var character_node = _get_character_node(character)
		if character_node:
			print("🔗 [MoveRangeInput] 使用统一的PositionCollisionManager进行物理查询")
			var result = position_collision_manager.validate_position(position, character_node)
			print("📋 [MoveRangeInput] 快速预检查结果: %s" % ("通过" if result else "失败"))
			return result
	
	# 无管理器时返回false（位置无效）
	print("❌ [MoveRangeInput] PositionCollisionManager 不可用，预检查失败")
	return false

func _physics_collision_check(position: Vector2, character: GameCharacter) -> bool:
	"""使用物理查询检测碰撞"""
	# 获取角色的真实碰撞形状
	var character_shape = _get_character_collision_shape(character)
	
	# 必须获取到角色的真实碰撞形状
	if not character_shape:
		push_error("[MoveRangeInput] 无法获取角色碰撞形状，碰撞检测失败")
		return false
	
	# 创建物理查询
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = character_shape
	query.transform.origin = position
	query.collision_mask = 14  # 静态障碍物、角色、障碍物
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	# 排除当前角色
	var exclude_rids = []
	var character_node = _get_character_node(character)
	if character_node:
		var char_area = character_node.get_node_or_null("CharacterArea")
		if char_area:
			exclude_rids.append(char_area.get_rid())
	query.exclude = exclude_rids
	
	var results = _physics_space.intersect_shape(query)
	return results.size() == 0



# 获取角色碰撞形状
func _get_character_collision_shape(character: GameCharacter) -> Shape2D:
	"""获取角色的碰撞形状"""
	var character_node = _get_character_node(character)
	if not character_node:
		return null
	
	# 尝试从CharacterArea获取碰撞形状
	var char_area = character_node.get_node_or_null("CharacterArea")
	if char_area and char_area.has_method("get_shape_owners"):
		var shape_owners = char_area.get_shape_owners()
		if shape_owners.size() > 0:
			var shape = char_area.shape_owner_get_shape(shape_owners[0], 0)
			if shape:
				return shape
	
	# 如果没有找到，返回默认的胶囊形状
	var capsule = CapsuleShape2D.new()
	capsule.radius = 16.0
	capsule.height = 42.0
	return capsule





# 🔧 获取角色节点
func _get_character_node(character: GameCharacter) -> Node2D:
	"""获取角色节点（与MovementCoordinator保持一致）"""
	if not character:
		return null
	
	# 获取character_manager（与MovementCoordinator使用完全相同的方式）
	# 首先尝试绝对路径
	var character_manager = AutoLoad.get_battle_scene().get_node_or_null("BattleCharacterManager") if AutoLoad.get_battle_scene() else null
	# 移除频繁的角色节点获取调试输出
	
	# 如果找不到，尝试通过BattleScene获取
	if not character_manager:
		var battle_scene = AutoLoad.get_battle_scene()
		if battle_scene and battle_scene.has_method("get_character_manager"):
			character_manager = battle_scene.get_character_manager()
	
	if not character_manager:
		push_error("[MoveRangeInput] character_manager为空")
		return null
	
	if not character_manager.has_method("get_character_node_by_data"):
		push_error("[MoveRangeInput] character_manager没有get_character_node_by_data方法")
		return null
	
	var character_node = character_manager.get_character_node_by_data(character)
	if not character_node:
		print("🐛 [调试-获取角色节点] 无法找到角色节点: %s (ID: %s)" % [character.name, character.id])
		push_error("[MoveRangeInput] 无法找到角色节点: %s (ID: %s)" % [character.name, character.id])
	
	return character_node

# 🚀 优化的位置验证流程 - 使用PositionCollisionManager
func _validate_position_optimized(position: Vector2, character: GameCharacter) -> Dictionary:
	"""优化的位置验证流程，直接使用PositionCollisionManager"""
	# 第一步：快速碰撞预检测
	if not _quick_collision_precheck(position, character):
		return {
			"is_valid": false,
			"cost": float('inf'),
			"reason": "collision_detected_precheck"
		}
	
	# 第二步：使用统一的PositionCollisionManager引用进行详细验证
	if not position_collision_manager:
		return {"is_valid": false, "cost": float('inf'), "reason": "位置碰撞管理器不可用"}
	
	var character_node = _get_character_node(character)
	if not character_node:
		return {"is_valid": false, "cost": float('inf'), "reason": "无法找到角色节点"}
	
	var validation_details = position_collision_manager.get_validation_details(position, character_node)
	var actual_position = _get_character_actual_position()
	var movement_cost = position_collision_manager.get_movement_cost(actual_position, position)
	
	return {
		"is_valid": validation_details.is_valid,
		"cost": movement_cost if validation_details.is_valid else float('inf'),
		"reason": validation_details.reason
	}

# 🐛 调试信息输出（按T键触发）
func _output_debug_info():
	if not _current_character or _mouse_position == Vector2.ZERO:
		print("🐛 [调试-T键] 当前无角色或鼠标位置无效")
		return
	
	print("\n=== 🐛 调试信息输出 (T键触发) ===")
	print("📍 当前鼠标位置: %s" % _mouse_position)
	print("👤 当前角色: %s (ID: %s)" % [_current_character.name, _current_character.id])
	print("📏 角色位置: %s" % _current_character.position)
	
	# 获取角色节点
	var character_node = _get_character_node(_current_character)
	if character_node:
		print("🎭 角色节点: %s" % character_node.name)
		print("📍 角色节点位置: %s" % character_node.global_position)

# 🐛 物理验证详细调试信息输出（按W键触发）
func _output_physical_validation_debug():
	if not _current_character or _mouse_position == Vector2.ZERO:
		print("🐛 [调试-W键] 当前无角色或鼠标位置无效")
		return
	
	var target_position = _mouse_position
	print("\n=== 🐛 物理验证详细调试 (W键触发) ===")
	print("🎯 目标位置: %s" % target_position)
	print("👤 当前角色: %s (ID: %s)" % [_current_character.name, _current_character.id])
	
	# 使用统一的PositionCollisionManager引用
	if not position_collision_manager:
		print("❌ 无法获取PositionCollisionManager")
		return
	
	# 获取角色节点
	var character_node = _get_character_node(_current_character)
	if not character_node:
		print("❌ 无法获取角色节点")
		return
	
	print("🏃 角色节点位置: %s" % character_node.position)
	
	# GroundAnchor偏移测试
	var ground_anchor_offset = position_collision_manager.get_character_ground_anchor_offset(character_node)
	print("📍 GroundAnchor偏移量: %s" % ground_anchor_offset)
	print("📍 目标位置的GroundAnchor实际位置: %s" % (target_position + ground_anchor_offset))
	
	# 轻功范围检查调试
	print("\n🏃 轻功范围检查:")
	var character_position = character_node.position
	var distance = character_position.distance_to(target_position)
	var max_range = _current_character.qinggong_skill
	print("  - 距离: %.1f" % distance)
	print("  - 限制: %d" % max_range)
	print("  - 结果: %s" % ("✅通过" if distance <= max_range else "❌失败"))
	
	# 地面约束验证调试
	print("\n🏔️ 地面约束验证:")
	print("  - 开始验证位置: %s" % target_position)
	
	# 获取角色数据
	var character_data = null
	if character_node.has_method("get_character_data"):
		character_data = character_node.get_character_data()
		print("  - 角色数据获取: %s" % ("✅成功" if character_data else "❌失败"))
	else:
		print("  - 角色数据获取: ❌角色节点没有get_character_data方法")
	
	# 飞行能力检查
	if character_data and character_data.has_method("can_fly"):
		var can_fly = character_data.can_fly()
		print("  - 飞行能力检查: %s" % ("✅可以飞行" if can_fly else "❌不能飞行"))
		if can_fly:
			print("  - ✈️ 角色拥有飞行能力，跳过地面约束检查")
	else:
		print("  - 飞行能力检查: ❌角色数据无效或没有can_fly方法")
	
	# 🎯 第二步验证：统一高度差计算基准
	print("\n🎯 [第二步验证] 统一高度差计算基准:")
	var ground_anchor_position = target_position + ground_anchor_offset
	print("  - GroundAnchor位置计算: %s + %s = %s" % [target_position, ground_anchor_offset, ground_anchor_position])
	print("  - ✅ 第二步修复生效：高度差计算基于GroundAnchor位置")
	
	# 🎯 第三步验证：统一吸附距离配置
	print("\n🎯 [第三步验证] 统一吸附距离配置:")
	var platform_snap_distance = _get_ground_platform_snap_distance()
	print("  - 地面平台吸附距离: %d像素" % platform_snap_distance)
	var config = get_node("../Config")
	if config and config.has_method("get_ground_platform_snap_distance"):
		print("  - ✅ 第三步修复生效：从配置文件读取吸附距离")
		print("  - 配置路径: ../Config.ground_platform_snap_distance")
	else:
		print("  - ⚠️ 使用默认值，配置文件不可用")
	
	# 位置验证详细信息
	print("\n🔍 位置验证调试:")
	var validation_details = position_collision_manager.get_validation_details(target_position, character_node)
	print("  - 调用get_validation_details - 位置: %s, 角色: %s" % [target_position, character_node.name])
	print("  - 🔧 内部使用GroundAnchor位置: %s 进行表面检测" % ground_anchor_position)
	print("  - 验证结果: %s" % validation_details)
	
	if validation_details.is_valid and validation_details.has("adjusted_position"):
		var adjusted_pos = validation_details.adjusted_position
		if adjusted_pos != target_position:
			print("  - 🧲 位置吸附调整: %s -> %s" % [target_position, adjusted_pos])
		else:
			print("  - ✅ 验证通过，位置无需调整")
	else:
		if validation_details.is_valid:
			print("  - ⚠️ 验证通过但没有adjusted_position字段")
		else:
			print("  - ❌ 验证失败: %s" % validation_details.reason)
	
	# 调用PositionCollisionManager的详细调试方法
	if position_collision_manager.has_method("output_physical_validation_debug"):
		position_collision_manager.output_physical_validation_debug(_mouse_position, character_node)
	else:
		print("❌ PositionCollisionManager没有output_physical_validation_debug方法")
	
	# 获取预览区域的X号显示状态
	# 获取MovePreviewArea管理器实例
	var preview_area_manager = get_node_or_null("../PreviewArea")
	if preview_area_manager:
		print("\n🎯 预览区域状态:")
		print("  - 预览区域管理器存在: 是")
		print("  - 管理器类型: %s" % preview_area_manager.get_class())
		print("  - 当前碰撞状态: %s" % ("有碰撞" if preview_area_manager.is_colliding else "无碰撞"))
		
		# 检查内部Area2D节点
		if preview_area_manager.preview_area:
			var internal_area = preview_area_manager.preview_area
			print("  - 内部Area2D节点存在: 是")
			print("  - 内部Area2D类型: %s" % internal_area.get_class())
			print("  - 内部Area2D子节点数量: %d" % internal_area.get_child_count())
			
			# 列出所有子节点
			print("  - 内部Area2D子节点列表:")
			for i in range(internal_area.get_child_count()):
				var child = internal_area.get_child(i)
				print("    [%d] %s (%s)" % [i, child.name, child.get_class()])
		else:
			print("  - 内部Area2D节点: 不存在")
		
		# 检查visual_drawer
		if "visual_drawer" in preview_area_manager:
			print("  - 管理器有visual_drawer属性: 是")
			if preview_area_manager.visual_drawer:
				print("  - visual_drawer对象存在: 是")
				print("  - visual_drawer父节点: %s" % (preview_area_manager.visual_drawer.get_parent().name if preview_area_manager.visual_drawer.get_parent() else "无"))
				# 检查可视化绘制器的属性
				var visual_drawer = preview_area_manager.visual_drawer
				if "show_x_mark" in visual_drawer:
					print("  - X标记显示状态: %s" % ("显示" if visual_drawer.show_x_mark else "隐藏"))
				else:
					print("  - X标记显示状态: 属性不存在")
				if "shape_color" in visual_drawer:
					print("  - 当前颜色: %s" % str(visual_drawer.shape_color))
			else:
				print("  - visual_drawer对象存在: 否")
		else:
			print("  - 管理器有visual_drawer属性: 否")
	else:
		print("❌ 预览区域管理器不存在")
	
	# 位置碰撞管理器详细调试
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if battle_scene:
		var collision_manager = battle_scene.get_node_or_null("BattleSystems/PositionCollisionManager")
		if collision_manager:
			print("🔗 位置碰撞管理器: 已连接")
			# 调用详细调试信息输出
			if collision_manager.has_method("output_debug_info_for_position"):
				collision_manager.output_debug_info_for_position(_mouse_position, character_node)
			else:
				print("❌ 位置碰撞管理器没有调试信息输出方法")
		else:
			print("❌ 位置碰撞管理器: 未找到")
	else:
		print("❌ 战斗场景: 未找到")
	
	print("=== 调试信息输出结束 ===\n")

# 🧹 清空位置缓存
func _clear_position_cache():
	if position_collision_manager and position_collision_manager.has_method("clear_cache"):
		position_collision_manager.clear_cache()
		print("🧹 [MoveRangeInput] 位置缓存已清空")
	else:
		print("❌ [MoveRangeInput] 无法清空缓存：位置碰撞管理器未找到或方法不存在")

# 🧱 障碍物吸附调试（按Q键触发）
func _debug_wall_obstacle_snap():
	print("\n=== 🏗️ 障碍物吸附问题调试 (Q键触发) ===")
	
	# 获取PositionCollisionManager
	if not position_collision_manager:
		print("❌ 无法找到PositionCollisionManager")
		return
	
	# 获取玩家角色
	if not _current_character:
		print("❌ 当前无选中角色")
		return
	
	var character_node = _get_character_node(_current_character)
	if not character_node:
		print("❌ 无法获取角色节点")
		return
	
	print("✅ 找到PositionCollisionManager和玩家角色")
	
	# 查找所有障碍物
	var all_obstacles = _find_all_obstacles()
	if all_obstacles.is_empty():
		print("❌ 场景中未找到任何障碍物")
		return
	
	print("✅ 找到 %d 个障碍物:" % all_obstacles.size())
	var wall_obstacles = []
	var platform_obstacles = []
	
	for i in range(all_obstacles.size()):
		var obstacle = all_obstacles[i]
		print("  [%d] %s 位置: %s, 碰撞层: %d" % [i, obstacle.name, obstacle.global_position, obstacle.collision_layer])
		
		if obstacle.name.contains("WALL"):
			wall_obstacles.append(obstacle)
		elif obstacle.name.contains("PLATFORM"):
			platform_obstacles.append(obstacle)
	
	# 只测试平台障碍物
	if not platform_obstacles.is_empty():
		var test_platform = platform_obstacles[0]
		print("\n🏢 选择平台障碍物进行测试: %s (位置: %s)" % [test_platform.name, test_platform.global_position])
		_test_obstacle_snap(test_platform, character_node, "PLATFORM")
	else:
		print("❌ 没有找到平台障碍物")
	
	print("\n=== 障碍物吸附调试完成 ===\n")
	
	# 🔍 关键问题调试（简化版）
	print("=== 🔍 关键问题调试 ===")
	var current_pos = character_node.global_position
	print("📍 角色当前位置: %s" % current_pos)
	
	# 获取角色轻功值
	var character_data = character_node.get_character_data() if character_node.has_method("get_character_data") else null
	if character_data and "qinggong_skill" in character_data:
		print("⚡ 角色轻功值: %d" % character_data.qinggong_skill)
	
	# 测试实际鼠标位置验证
	var mouse_pos = get_global_mouse_position()
	print("\n🏢 测试鼠标位置 %s:" % mouse_pos)
	var platform_test_pos = mouse_pos
	
	# 手动计算轻功范围
	var distance = current_pos.distance_to(platform_test_pos)
	if character_data and "qinggong_skill" in character_data:
		var max_range = character_data.qinggong_skill
		print("  📏 计算距离: %.2f像素 (当前位置%s -> 目标位置%s)" % [distance, current_pos, platform_test_pos])
		print("  ⚡ 轻功范围: %d像素" % max_range)
		print("  📊 距离比较: %s" % ("✅在范围内" if distance <= max_range else "❌超出范围"))
		
		# 详细调试轻功验证逻辑
		print("\\n🔍 详细轻功验证:")
		print("  角色节点类型: %s" % character_node.get_class())
		print("  角色节点有get_character_data方法: %s" % character_node.has_method("get_character_data"))
		if character_node.has_method("get_character_data"):
			var test_character_data = character_node.get_character_data()
			print("  get_character_data返回: %s" % test_character_data)
			if test_character_data:
				print("  轻功值属性存在: %s" % ("qinggong_skill" in test_character_data))
				if "qinggong_skill" in test_character_data:
					print("  轻功值: %d" % test_character_data.qinggong_skill)
					print("  计算验证: %.2f %s %d = %s" % [distance, ">" if distance > test_character_data.qinggong_skill else "<=", test_character_data.qinggong_skill, "超出范围" if distance > test_character_data.qinggong_skill else "在范围内"])
	
	var validation_result = position_collision_manager.get_validation_details(platform_test_pos, character_node)
	print("  验证结果: %s" % ("✅有效" if validation_result.is_valid else "❌无效"))
	print("  验证原因: %s" % validation_result.reason)
	
	# 手动测试地面约束验证
	print("\n🔍 详细地面约束验证:")
	if position_collision_manager.has_method("_get_ground_anchor_position"):
		var ground_anchor_pos = position_collision_manager._get_ground_anchor_position(platform_test_pos, character_node)
		print("  GroundAnchor位置: %s" % ground_anchor_pos)
		
		if position_collision_manager.has_method("_check_unified_surface"):
			var surface_result = position_collision_manager._check_unified_surface(ground_anchor_pos)
			print("  表面检测结果: %s" % ("✅有效" if surface_result.is_valid else "❌无效"))
			print("  表面类型: %s" % surface_result.surface_type)
			print("  表面Y坐标: %.1f" % surface_result.surface_y)
			
			if surface_result.has("collider") and surface_result.collider:
				print("  碰撞体: %s" % surface_result.collider.name)
	
	# 直接调用轻功范围验证函数
	print("\n🔍 直接轻功验证测试:")
	if position_collision_manager.has_method("_validate_qinggong_range"):
		var qinggong_result = position_collision_manager._validate_qinggong_range(platform_test_pos, character_node)
		print("  轻功验证结果: %s" % ("✅通过" if qinggong_result else "❌失败"))
	else:
		print("  无法访问_validate_qinggong_range方法")
	
	# 直接检查平台障碍物的碰撞形状
	print("\n🔍 检查平台碰撞形状:")
	var platform_obstacles_check = _find_all_obstacles()
	for obstacle in platform_obstacles_check:
		if "PLATFORM" in obstacle.name and obstacle.global_position.x == 1000.0:
			print("  平台: %s, 位置: %s" % [obstacle.name, obstacle.global_position])
			for child in obstacle.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					var shape = child.shape
					var actual_top = obstacle.global_position.y - shape.size.y / 2.0
					print("  实际顶部Y: %.1f, 形状大小: %.0fx%.0f" % [actual_top, shape.size.x, shape.size.y])
			break
	
	print("=== 关键问题调试完成 ===\n")

# 🔍 查找场景中的WALL类型障碍物
func _find_wall_obstacles() -> Array:
	var wall_obstacles = []
	
	# 查找战斗场景
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if not battle_scene:
		print("❌ 无法找到战斗场景")
		return wall_obstacles
	
	print("✅ 找到战斗场景: %s" % battle_scene.name)
	
	# 递归搜索所有节点，查找WALL类型障碍物
	_find_wall_obstacles_recursive(battle_scene, wall_obstacles)
	
	return wall_obstacles

# 🔍 递归查找WALL障碍物
func _find_wall_obstacles_recursive(node: Node, wall_obstacles: Array) -> void:
	# 检查当前节点是否是WALL障碍物
	if node.name.contains("WALL") and node is StaticBody2D:
		wall_obstacles.append(node)
		print("🎯 找到WALL障碍物: %s (位置: %s)" % [node.name, node.global_position])
	
	# 递归检查子节点
	for child in node.get_children():
		_find_wall_obstacles_recursive(child, wall_obstacles)

# 🎯 获取障碍物顶部吸附距离配置
func _get_obstacle_top_snap_distance() -> int:
	var config = get_node("../Config")
	if config and config.has_method("get_obstacle_top_snap_distance"):
		return config.get_obstacle_top_snap_distance()
	else:
		return 8  # 默认值

# 🔍 查找场景中的所有障碍物
func _find_all_obstacles() -> Array:
	var obstacles = []
	_find_all_obstacles_recursive(get_tree().current_scene, obstacles)
	return obstacles

# 递归查找所有障碍物
func _find_all_obstacles_recursive(node: Node, obstacles: Array):
	# 检查当前节点是否是障碍物
	if (node.name.contains("Obstacle") or node.name.contains("WALL") or node.name.contains("PLATFORM")) and (node is RigidBody2D or node is StaticBody2D):
		obstacles.append(node)
	
	# 递归搜索子节点
	for child in node.get_children():
		_find_all_obstacles_recursive(child, obstacles)

# 🧪 测试单个障碍物的吸附效果
func _test_obstacle_snap(obstacle: Node, character_node: Node2D, obstacle_type: String):
	# 获取障碍物的碰撞体信息
	var collision_shape = null
	for child in obstacle.get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break
	
	if not collision_shape:
		print("❌ %s障碍物没有碰撞体" % obstacle_type)
		return
	
	var shape = collision_shape.shape
	if not shape:
		print("❌ %s障碍物碰撞体没有形状" % obstacle_type)
		return
	
	print("✅ %s碰撞体类型: %s" % [obstacle_type, shape.get_class()])
	
	# 计算障碍物顶部位置
	var obstacle_top_y = obstacle.global_position.y
	if shape is RectangleShape2D:
		obstacle_top_y = obstacle.global_position.y - shape.size.y / 2.0
		print("📏 %s顶部Y坐标: %.1f (RectangleShape2D)" % [obstacle_type, obstacle_top_y])
	else:
		print("⚠️ 非RectangleShape2D类型，使用障碍物中心Y坐标")
	
	# 获取GroundAnchor偏移
	var ground_anchor_offset = position_collision_manager.get_character_ground_anchor_offset(character_node)
	print("📍 角色GroundAnchor偏移: %s" % ground_anchor_offset)
	
	# 在障碍物顶部附近测试不同高度的吸附效果
	var obstacle_x = obstacle.global_position.x
	var test_positions = [
		Vector2(obstacle_x, obstacle_top_y - 20),  # 障碍物顶部上方20像素
		Vector2(obstacle_x, obstacle_top_y - 10),  # 障碍物顶部上方10像素
		Vector2(obstacle_x, obstacle_top_y - 5),   # 障碍物顶部上方5像素
		Vector2(obstacle_x, obstacle_top_y - 1),   # 障碍物顶部上方1像素
		Vector2(obstacle_x, obstacle_top_y),       # 障碍物顶部精确位置
		Vector2(obstacle_x, obstacle_top_y + 1),   # 障碍物顶部下方1像素
		Vector2(obstacle_x, obstacle_top_y + 5),   # 障碍物顶部下方5像素
		Vector2(obstacle_x, obstacle_top_y + 10),  # 障碍物顶部下方10像素
	]
	
	print("\n🔍 在%s顶部附近测试吸附效果:" % obstacle_type)
	for i in range(test_positions.size()):
		var test_pos = test_positions[i]
		var ground_anchor_pos = test_pos + ground_anchor_offset
		var height_diff = ground_anchor_pos.y - obstacle_top_y
		
		print("\n  [测试%d] 角色位置: %s" % [i+1, test_pos])
		print("         GroundAnchor位置: %s" % ground_anchor_pos)
		print("         与%s顶部高度差: %.1f像素" % [obstacle_type, height_diff])
		
		# 使用PositionCollisionManager验证位置
		var validation_result = position_collision_manager.get_validation_details(test_pos, character_node)
		print("         验证结果: %s" % ("✅有效" if validation_result.is_valid else "❌无效"))
		print("         验证原因: %s" % validation_result.reason)
		
		if validation_result.is_valid and validation_result.has("adjusted_position"):
			var adjusted_pos = validation_result.adjusted_position
			if adjusted_pos != test_pos:
				var adjustment = adjusted_pos - test_pos
				print("         🧲 位置调整: %s -> %s (调整量: %s)" % [test_pos, adjusted_pos, adjustment])
			else:
				print("         ✅ 位置无需调整")
		
		# 检查是否识别为障碍物顶部
		if validation_result.has("surface_type"):
			print("         表面类型: %s" % validation_result.surface_type)
		
		# 分析吸附距离
		var obstacle_snap_distance = _get_obstacle_top_snap_distance()
		print("         障碍物顶部吸附距离配置: %d像素" % obstacle_snap_distance)
		
		if abs(height_diff) <= obstacle_snap_distance:
			print("         🎯 在吸附范围内 (≤%d像素)" % obstacle_snap_distance)
		else:
			print("         🚫 超出吸附范围 (>%d像素)" % obstacle_snap_distance)

# 🥋 轻功范围问题调试
func _debug_movement_range_issue(character_node: Node2D):
	print("🎯 开始轻功范围问题调试...")
	
	# 获取角色当前位置
	var current_pos = character_node.global_position
	print("📍 角色当前位置: %s" % current_pos)
	
	# 获取角色数据
	var character_data = null
	if character_node.has_method("get_character_data"):
		character_data = character_node.get_character_data()
	elif "character_data" in character_node:
		character_data = character_node.character_data
	
	if character_data:
		print("✅ 成功获取角色数据: %s" % character_data.get_class())
		
		# 安全地获取角色属性
		if "qinggong_skill" in character_data:
			print("⚡ 角色轻功值: %d" % character_data.qinggong_skill)
		elif "movement_points" in character_data:
			print("⚡ 角色轻功值: %d" % character_data.movement_points)
		elif "light_skill_points" in character_data:
			print("⚡ 角色轻功值: %d" % character_data.light_skill_points)
		elif character_data.has_method("get_movement_points"):
			print("⚡ 角色轻功值: %d" % character_data.get_movement_points())
		else:
			print("❓ 未找到轻功值属性")
		
		if "name" in character_data:
			print("👤 角色名称: %s" % character_data.name)
		elif character_data.has_method("get_name"):
			print("👤 角色名称: %s" % character_data.get_name())
		else:
			print("❓ 未找到角色名称")
			
		# 列出所有可用属性
		print("🔍 角色数据可用属性:")
		if character_data.has_method("get_property_list"):
			var props = character_data.get_property_list()
			for prop in props:
				if prop.has("name"):
					print("  - %s" % prop.name)
	else:
		print("❌ 无法获取角色数据")
		print("🔍 角色节点类型: %s" % character_node.get_class())
		print("🔍 角色节点名称: %s" % character_node.name)
		
		# 尝试获取轻功组件
		if character_node.has_method("get_movement_component"):
			var movement_comp = character_node.get_movement_component()
			if movement_comp:
				print("📱 找到移动组件: %s" % movement_comp.get_class())
		
		# 尝试查找子节点中的数据
		for child in character_node.get_children():
			if "character" in child.name.to_lower() or "data" in child.name.to_lower():
				print("🔍 找到可能的数据子节点: %s (%s)" % [child.name, child.get_class()])
	
	# 测试几个简单的地面位置
	var test_positions = [
		current_pos + Vector2(0, 0),      # 当前位置
		current_pos + Vector2(50, 0),     # 右侧50像素
		current_pos + Vector2(-50, 0),    # 左侧50像素
		current_pos + Vector2(0, 50),     # 下方50像素
		current_pos + Vector2(0, -50),    # 上方50像素
	]
	
	print("\n🔍 测试简单地面位置的轻功范围验证:")
	for i in range(test_positions.size()):
		var test_pos = test_positions[i]
		var offset_desc = ""
		if i == 0: offset_desc = "当前位置"
		elif i == 1: offset_desc = "右侧50px"
		elif i == 2: offset_desc = "左侧50px"
		elif i == 3: offset_desc = "下方50px"
		elif i == 4: offset_desc = "上方50px"
		
		print("\n  [轻功测试%d] %s: %s" % [i+1, offset_desc, test_pos])
		
		# 使用PositionCollisionManager验证
		var validation_result = position_collision_manager.get_validation_details(test_pos, character_node)
		print("         验证结果: %s" % ("✅有效" if validation_result.is_valid else "❌无效"))
		print("         验证原因: %s" % validation_result.reason)
		
		# 如果有详细信息，输出更多调试数据
		if validation_result.has("details"):
			print("         详细信息: %s" % validation_result.details)
		
		# 检查是否有轻功范围相关的信息
		if validation_result.has("movement_cost"):
			print("         移动消耗: %s" % validation_result.movement_cost)
		if validation_result.has("remaining_movement"):
			print("         剩余轻功: %s" % validation_result.remaining_movement)
	
	# 检查缓存状态
	print("\n🧹 检查缓存状态:")
	if position_collision_manager.has_method("get_cache_stats"):
		var cache_stats = position_collision_manager.get_cache_stats()
		print("  缓存统计: %s" % cache_stats)
	else:
		print("  缓存统计方法不可用")
	
	# 强制清空缓存重试
	print("\n🔄 清空缓存后重新测试:")
	_clear_position_cache()
	
	# 重新测试当前位置
	var retry_result = position_collision_manager.get_validation_details(current_pos, character_node)
	print("  当前位置重试结果: %s" % ("✅有效" if retry_result.is_valid else "❌无效"))
	print("  重试验证原因: %s" % retry_result.reason)
	
	print("=== 轻功范围问题调试完成 ===\n")
	
	# 🚨 地面约束问题深度调试
	print("=== 🚨 地面约束问题深度调试 ===")
	_debug_ground_constraint_issue(character_node)

# 🚨 地面约束问题深度调试
func _debug_ground_constraint_issue(character_node: Node2D):
	print("🚨 开始地面约束问题调试...")
	
	var current_pos = character_node.global_position
	print("📍 当前角色位置: %s" % current_pos)
	
	# 获取GroundAnchor偏移
	var ground_anchor_offset = position_collision_manager.get_character_ground_anchor_offset(character_node)
	var ground_anchor_pos = current_pos + ground_anchor_offset
	print("⚓ GroundAnchor偏移: %s" % ground_anchor_offset)
	print("⚓ GroundAnchor位置: %s" % ground_anchor_pos)
	
	# 检查地面高度配置
	var config = get_node("../Config")
	if config:
		print("\n📋 地面约束配置检查:")
		if config.has_method("get_ground_height_offset"):
			var ground_height_offset = config.get_ground_height_offset()
			print("  ground_height_offset: %s" % ground_height_offset)
		if config.has_method("get_ground_platform_snap_distance"):
			var snap_distance = config.get_ground_platform_snap_distance()
			print("  ground_platform_snap_distance: %s" % snap_distance)
	
	# 使用PositionCollisionManager的内部调试方法
	print("\n🔍 使用PositionCollisionManager内部调试:")
	if position_collision_manager.has_method("debug_ground_constraint_at_position"):
		position_collision_manager.debug_ground_constraint_at_position(current_pos, character_node)
	elif position_collision_manager.has_method("output_physical_validation_debug"):
		position_collision_manager.output_physical_validation_debug(current_pos, character_node)
	else:
		print("❌ PositionCollisionManager没有调试方法")
	
	# 手动检查物理空间
	print("\n🌍 手动物理空间检查:")
	var space_state = get_world_2d().direct_space_state
	if space_state:
		# 在GroundAnchor位置向下检测
		var query = PhysicsRayQueryParameters2D.create(
			ground_anchor_pos,
			ground_anchor_pos + Vector2(0, 100)  # 向下100像素
		)
		query.collision_mask = 31  # 检测所有层
		
		var result = space_state.intersect_ray(query)
		if result:
			var hit_object = result.collider
			print("  ✅ 检测到碰撞:")
			print("    碰撞对象: %s" % hit_object.name)
			print("    碰撞位置: %s" % result.position)
			print("    碰撞距离: %.1f像素" % ground_anchor_pos.distance_to(result.position))
			print("    碰撞层: %d" % hit_object.collision_layer)
			
			# 检查是否是地面平台
			if hit_object.collision_layer & 1:  # 检查第1层（地面平台）
				print("    🏢 这是地面平台 (层1)")
			elif hit_object.collision_layer & 8:  # 检查第4层（障碍物）
				print("    🧱 这是障碍物 (层4)")
			else:
				print("    ❓ 未知碰撞层类型")
		else:
			print("  ❌ 没有检测到任何碰撞")
			print("    GroundAnchor可能悬空!")
	
	print("=== 地面约束问题调试完成 ===\n")
	
	# 🧪 测试平台位置验证
	print("=== 🧪 测试已知平台位置验证 ===")
	var platform_positions = [
		Vector2(500.0, 978.0),   # 平台1上方
		Vector2(1000.0, 978.0),  # 平台2上方
	]
	
	for i in range(platform_positions.size()):
		var test_pos = platform_positions[i]
		print("\n🏢 测试平台%d位置: %s" % [i+1, test_pos])
		
		var validation_result = position_collision_manager.get_validation_details(test_pos, character_node)
		print("  验证结果: %s" % ("✅有效" if validation_result.is_valid else "❌无效"))
		print("  验证原因: %s" % validation_result.reason)
		
		# 检查这个位置的GroundAnchor
		var test_ground_anchor_pos = test_pos + ground_anchor_offset
		print("  GroundAnchor位置: %s" % test_ground_anchor_pos)
		
		# 手动检测这个位置下方的地面
		var test_space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			test_ground_anchor_pos,
			test_ground_anchor_pos + Vector2(0, 50)
		)
		query.collision_mask = 31
		var result = test_space_state.intersect_ray(query)
		if result:
			print("  ✅ 检测到地面: %s, 距离: %.1f像素" % [result.collider.name, test_ground_anchor_pos.distance_to(result.position)])
		else:
			print("  ❌ 没有检测到地面")
	
	print("=== 平台位置测试完成 ===\n")
	
	# 🔍 直接检查平台障碍物
	print("=== 🔍 直接检查平台障碍物 ===")
	var all_obstacles = _find_all_obstacles()
	for obstacle in all_obstacles:
		if "PLATFORM" in obstacle.name:
			print("\n🏢 检查平台: %s" % obstacle.name)
			print("  位置: %s" % obstacle.global_position)
			print("  碰撞层: %d" % obstacle.collision_layer)
			
			# 获取碰撞形状
			for child in obstacle.get_children():
				if child is CollisionShape2D:
					var shape = child.shape
					if shape is RectangleShape2D:
						var size = shape.size
						var actual_top = obstacle.global_position.y - size.y / 2.0
						var actual_bottom = obstacle.global_position.y + size.y / 2.0
						print("  碰撞形状: 矩形 %.0fx%.0f" % [size.x, size.y])
						print("  实际顶部Y: %.1f" % actual_top)
						print("  实际底部Y: %.1f" % actual_bottom)
						
						# 测试从GroundAnchor到平台顶部的检测
						var test_from = Vector2(obstacle.global_position.x, 990.0)  # 平台上方10像素
						var test_to = Vector2(obstacle.global_position.x, actual_bottom + 10)  # 平台底部下方10像素
						
						print("  🔍 测试射线从 %s 到 %s" % [test_from, test_to])
						var test_space = get_world_2d().direct_space_state
						var ray_query = PhysicsRayQueryParameters2D.create(test_from, test_to)
						ray_query.collision_mask = 31
						
						var ray_result = test_space.intersect_ray(ray_query)
						if ray_result:
							print("  ✅ 射线命中: %s 在 %s" % [ray_result.collider.name, ray_result.position])
						else:
							print("  ❌ 射线未命中任何对象")
						
						# 测试形状检测
						var shape_query = PhysicsShapeQueryParameters2D.new()
						var test_shape = RectangleShape2D.new()
						test_shape.size = Vector2(10, 10)
						shape_query.shape = test_shape
						shape_query.transform = Transform2D(0, Vector2(obstacle.global_position.x, actual_top - 5))
						shape_query.collision_mask = 31
						
						var shape_results = test_space.intersect_shape(shape_query)
						if shape_results.size() > 0:
							print("  ✅ 形状检测命中 %d 个对象" % shape_results.size())
							for result in shape_results:
								print("    - %s" % result.collider.name)
						else:
							print("  ❌ 形状检测未命中")
	
	print("=== 平台障碍物检查完成 ===\n")

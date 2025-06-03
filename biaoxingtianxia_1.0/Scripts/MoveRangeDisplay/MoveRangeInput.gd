# 🎮 移动范围显示系统 - 输入处理组件（增强版）
extends Node2D
class_name MoveRangeInput

# 🎮 输入状态
var _is_handling_input: bool = false
var _input_enabled: bool = true  # 🚀 新增：输入启用状态
var _current_character: GameCharacter = null
var _mouse_position: Vector2 = Vector2.ZERO
var _is_valid_position: bool = true
var _movement_cost: float = 0.0

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
var validator: MoveRangeValidator  # 🚀 新增：验证器节点引用
var position_collision_manager: Node2D

# 📊 统计变量
var input_events: int = 0
var validation_requests: int = 0
var successful_validations: int = 0
var failed_validations: int = 0

func _ready():
	print("🎮 [MoveRangeInput] 移动范围输入处理器初始化开始")
	
	# 🚀 初始化物理空间
	_physics_space = get_world_2d().direct_space_state
	print("🌍 [MoveRangeInput] 物理空间状态获取完成")
	
	# 获取配置组件引用
	call_deferred("_setup_config_reference")
	call_deferred("_setup_validator_reference")
	call_deferred("_setup_position_collision_manager")
	
	print("✅ [MoveRangeInput] 移动范围输入处理器已初始化 (物理查询: %s)" % str(_use_physics_query))

func _setup_config_reference():
	config = get_node("../Config")
	if not config:
		push_warning("[MoveRangeInput] 未找到Config组件")
	else:
		print("✅ [MoveRangeInput] Config组件连接成功")

func _setup_validator_reference():
	validator = get_node("../Validator")
	if not validator:
		push_warning("[MoveRangeInput] 未找到Validator组件")
	else:
		print("✅ [MoveRangeInput] Validator组件连接成功")

func _setup_position_collision_manager():
	print("🔍 [MoveRangeInput] 开始查找统一位置碰撞管理器...")
	# 获取位置碰撞管理器引用
	var battle_scene = get_tree().current_scene
	if battle_scene:
		position_collision_manager = battle_scene.get_node_or_null("BattleSystems/PositionCollisionManager")
		if position_collision_manager:
			print("✅ [MoveRangeInput] 成功连接到统一位置碰撞管理器!")
			print("📍 [MoveRangeInput] 管理器路径: BattleSystems/PositionCollisionManager")
			print("🔗 [MoveRangeInput] 管理器类型: ", position_collision_manager.get_class())
		else:
			print("❌ [MoveRangeInput] 警告: 未找到统一位置碰撞管理器")
			push_error("[MoveRangeInput] 统一位置碰撞管理器不可用，系统无法正常工作")
	else:
		print("❌ [MoveRangeInput] 错误: 无法获取当前场景")
	
	print("📊 [MoveRangeInput] 统一管理器状态: ", "已连接" if position_collision_manager else "未连接")

# 🎯 输入处理控制
func start_input_handling(character: GameCharacter):
	print("\n🎮 [MoveRangeInput] 开始输入处理")
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
	print("🎮 [MoveRangeInput] 输入状态设置为: ", "启用" if enabled else "禁用")

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
		_is_valid_position = false
		return
	
	# 🚀 使用实际位置计算移动成本
	_movement_cost = actual_character_position.distance_to(target_position)
	
	# 🚀 使用统一的PositionCollisionManager进行验证（与MovementCoordinator保持一致）
	var validation_result = _validate_position_comprehensive(target_position)
	_is_valid_position = validation_result.is_valid
	
	# 🐛 添加详细的验证对比日志
	# print("🔍 [显示验证] 位置: %s, 角色: %s, 验证结果: %s, 原因: %s" % [target_position, _current_character.name, validation_result.is_valid, validation_result.reason])

	if not validation_result.is_valid:
		validation_changed.emit(false, validation_result.reason)
	else:
		validation_changed.emit(true, "")

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

# 🚀 综合位置验证（使用统一的PositionCollisionManager）
func _validate_position_comprehensive(target_position: Vector2) -> Dictionary:
	# 获取统一的位置碰撞管理器（与MovementCoordinator使用相同路径）
	var position_collision_manager = get_node_or_null("/root/战斗场景/BattleSystems/PositionCollisionManager")
	# 移除频繁的管理器获取调试输出
	if not position_collision_manager:
		return {"is_valid": false, "reason": "位置碰撞管理器不可用"}
	
	# 获取角色节点（与MovementCoordinator使用相同的方式）
	var character_node = _get_character_node(_current_character)
	# 移除频繁的角色节点获取调试输出
	if not character_node:
		return {"is_valid": false, "reason": "无法找到角色节点"}
	
	# 使用与MovementCoordinator完全相同的验证方法
	var validation_result = position_collision_manager.validate_position(target_position, character_node)
	
	# 🐛 添加详细的PositionCollisionManager验证日志
	# print("🔍 [PositionCollisionManager验证] 位置: %s, 角色节点: %s, 验证结果: %s" % [target_position, character_node.name if character_node else "null", validation_result])
	
	# 转换为Dictionary格式以保持兼容性
	if validation_result:
		return {"is_valid": true, "reason": "位置有效"}
	else:
		return {"is_valid": false, "reason": "位置被统一管理器阻止"}

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
		

		KEY_T:  # 调试信息输出
			_output_debug_info()

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
	print("🎮 [Input] 确认移动到: %s" % _mouse_position)
	
	if not _current_character or _mouse_position == Vector2.ZERO:
		print("🔥 [信号追踪] 移动确认失败：角色或位置无效")
		return

	# 🚀 步骤1：快速预检测
	var quick_check = _quick_collision_precheck(_mouse_position, _current_character)
	print("🐛 [调试-移动确认] 快速预检测结果: %s" % ("通过" if quick_check else "失败"))
	
	# 🚀 步骤2：使用统一的PositionCollisionManager进行验证（与MovementCoordinator保持一致）
	var target_position = _mouse_position
	
	# 获取统一的位置碰撞管理器（与MovementCoordinator使用相同路径）
	var position_collision_manager = get_node_or_null("/root/战斗场景/BattleSystems/PositionCollisionManager")
	print("🐛 [调试-移动确认] 获取PositionCollisionManager: %s" % ("成功" if position_collision_manager else "失败"))
	if not position_collision_manager:
		_is_valid_position = false
		validation_changed.emit(false, "位置碰撞管理器不可用")
		print("🔥 [信号追踪] 移动确认失败：位置碰撞管理器不可用")
		return
	
	# 获取角色节点（与MovementCoordinator使用相同的方式）
	var character_node = _get_character_node(_current_character)
	print("🐛 [调试-移动确认] 获取角色节点: %s" % ("成功" if character_node else "失败"))
	if not character_node:
		print("🐛 [调试-移动确认] 无法找到角色节点")
		_is_valid_position = false
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
		_is_valid_position = false
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
		_is_valid_position = false
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

func is_position_valid() -> bool:
	return _is_valid_position

func get_movement_cost() -> float:
	return _movement_cost

# 🚀 性能监控
func get_input_stats() -> Dictionary:
	return {
		"is_handling_input": _is_handling_input,
		"mouse_update_interval": _mouse_update_interval,
		"last_update_time": _last_mouse_update_time,
		"target_height": 0.0,
		"is_valid_position": _is_valid_position,
		"movement_cost": _movement_cost
	}

func set_mouse_update_interval(interval_ms: int):
	_mouse_update_interval = clamp(interval_ms, 8, 100)  # 8-100ms范围
	# print("🎮 [Input] 鼠标更新间隔: %dms" % _mouse_update_interval)

# 🧲 地面吸附功能
func _apply_ground_snap():
	# 地面线位置（平台上边缘）
	var ground_y = 1000.0
	# 获取实际的GroundAnchor偏移量
	var ground_offset = _get_ground_anchor_offset()
	# 吸附范围（像素）
	var snap_range = 30.0
	
	# 计算角色GroundAnchor应该对齐到地面线时，鼠标应该在的位置
	# 鼠标位置应该是角色中心位置，即地面线位置向上偏移GroundAnchor的Y值
	var target_mouse_y = ground_y - ground_offset.y
	
	# 检查鼠标是否在吸附范围内
	var distance_to_target = abs(_mouse_position.y - target_mouse_y)
	if distance_to_target <= snap_range:
		# 设置鼠标位置为角色中心位置，这样GroundAnchor会正确对齐到地面线
		_mouse_position.y = target_mouse_y
		# print("🧲 [Input] 鼠标吸附到角色中心位置: Y=%.1f (GroundAnchor将对齐到地面线Y=%.1f)" % [_mouse_position.y, ground_y])

# 🔧 获取地面锚点偏移
func _get_ground_anchor_offset() -> Vector2:
	"""获取GroundAnchor节点的偏移量"""
	# 从当前角色节点获取GroundAnchor
	if _current_character:
		var character_node = _get_character_node(_current_character)
		if character_node:
			var ground_anchor = character_node.get_node_or_null("GroundAnchor")
			if ground_anchor:
				return ground_anchor.position
	
	# 如果没有找到GroundAnchor，尝试从player.tscn的默认配置获取
	# 默认偏移量（胶囊高度的一半，21像素）
	return Vector2(0, 21.0)

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
	var character_manager = get_node_or_null("/root/战斗场景/BattleCharacterManager")
	# 移除频繁的角色节点获取调试输出
	
	# 如果找不到，尝试通过BattleScene获取
	if not character_manager:
		var battle_scene = get_node_or_null("/root/战斗场景")
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

# 🚀 优化的位置验证流程
func _validate_position_optimized(position: Vector2, character: GameCharacter) -> Dictionary:
	"""优化的位置验证流程，结合快速预检测和详细验证"""
	# 第一步：快速碰撞预检测
	if not _quick_collision_precheck(position, character):
		return {
			"is_valid": false,
			"cost": float('inf'),
			"reason": "collision_detected_precheck"
		}
	
	# 第二步：详细验证
	return _validate_position_comprehensive(position)

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
	else:
		print("❌ 无法获取角色节点")
	
	# 轻功技能检查
	if "qinggong_skill" in _current_character:
		var qinggong_skill = _current_character.qinggong_skill
		var distance = _current_character.position.distance_to(_mouse_position)
		print("🏃 轻功技能值: %d" % qinggong_skill)
		print("📏 移动距离: %.1f" % distance)
		print("✅ 轻功检查结果: %s" % ("通过" if distance <= qinggong_skill else "失败"))
	else:
		print("❌ 角色没有轻功技能属性")
	
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
		var position_collision_manager = battle_scene.get_node_or_null("BattleSystems/PositionCollisionManager")
		if position_collision_manager:
			print("🔗 位置碰撞管理器: 已连接")
			# 调用详细调试信息输出
			if position_collision_manager.has_method("output_debug_info_for_position"):
				position_collision_manager.output_debug_info_for_position(_mouse_position, character_node)
			else:
				print("❌ 位置碰撞管理器没有调试信息输出方法")
		else:
			print("❌ 位置碰撞管理器: 未找到")
	else:
		print("❌ 战斗场景: 未找到")
	
	print("=== 调试信息输出结束 ===\n")
 

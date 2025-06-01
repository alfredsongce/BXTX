# 🎮 移动范围显示系统 - 输入处理组件（增强版）
extends Node
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

# 📡 信号
signal move_confirmed(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float)
signal move_cancelled()
signal mouse_moved(position: Vector2)
signal height_changed(new_height: float)
signal validation_changed(is_valid: bool, reason: String)

# 🔧 组件引用
var config  # 改为动态类型
var validator: MoveRangeValidator  # 🚀 新增：验证器节点引用

func _ready():
	print("🎮 [Input] 输入处理组件初始化完成")
	
	# 获取配置组件引用
	call_deferred("_setup_config_reference")
	call_deferred("_setup_validator_reference")

func _setup_config_reference():
	config = get_node("../Config")
	if not config:
		push_warning("[Input] 未找到Config组件")

func _setup_validator_reference():
	validator = get_node("../Validator")
	if not validator:
		push_warning("[Input] 未找到Validator组件")

# 🎯 输入处理控制
func start_input_handling(character: GameCharacter):
	if not character:
		push_warning("[Input] 角色参数为空")
		return
	
	_is_handling_input = true
	_current_character = character
	
	print("🎮 [Input] 开始处理输入 - 角色: %s" % character.name)

func stop_input_handling():
	_is_handling_input = false
	_current_character = null
	_mouse_position = Vector2.ZERO
	print("🎮 [Input] 停止处理输入")

# 🚀 新增：输入启用/禁用控制
func set_input_enabled(enabled: bool):
	_input_enabled = enabled
	var status = "启用" if enabled else "禁用"
	print("🎮 [Input] 输入处理%s" % status)

# 🎮 输入事件处理
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
		return
	
	# 🚀 简化：直接使用鼠标位置作为目标位置
	var target_position = _mouse_position
	
	# 🚀 修复：获取角色节点的实际位置
	var actual_character_position = _get_character_actual_position()
	var fallback_used = false
	if actual_character_position == Vector2.ZERO:
		# 如果无法获取节点位置，fallback到角色数据位置
		actual_character_position = _current_character.position
		fallback_used = true
	
	# 🚀 使用实际位置计算移动成本
	_movement_cost = actual_character_position.distance_to(target_position)
	
	# 🚀 移除频繁的调试信息，避免鼠标移动时的干扰
	# if OS.is_debug_build():
	#     print("🔍 [Input调试] 位置计算详情:")
	#     print("   角色数据位置: %s" % str(_current_character.position))
	#     print("   节点实际位置: %s" % str(actual_character_position))
	#     print("   使用fallback: %s" % str(fallback_used))
	#     print("   目标位置: %s" % str(target_position))
	#     print("   计算距离: %.1f" % _movement_cost)
	
	# 验证位置有效性
	var validation_result = _validate_position_comprehensive(target_position)
	_is_valid_position = validation_result.is_valid
	
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

# 🚀 综合位置验证（使用验证器节点）
func _validate_position_comprehensive(target_position: Vector2) -> Dictionary:
	# 🚀 获取角色实际位置
	var actual_character_position = _get_character_actual_position()
	
	# 🚀 使用验证器节点进行验证
	if validator:
		return validator.validate_position_comprehensive(
			_current_character, 
			target_position, 
			actual_character_position
		)
	else:
		# 降级处理：如果验证器不可用
		return {"is_valid": false, "reason": "验证器不可用"}

# 🖱️ 鼠标点击处理
func _handle_mouse_click(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_confirm_move()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_move()

# ⌨️ 键盘输入处理（简化版）
func _handle_keyboard_input(event: InputEventKey):
	match event.keycode:
		# 🚀 简化：W/S直接调整鼠标Y坐标
		KEY_W, KEY_UP:
			_adjust_mouse_height(-10)  # 向上移动
		KEY_S, KEY_DOWN:
			_adjust_mouse_height(10)   # 向下移动
		
		# 确认/取消
		KEY_ENTER, KEY_SPACE:
			_confirm_move()
		KEY_ESCAPE:
			_cancel_move()
		
		# 🚀 新增：快捷键
		KEY_G:  # 回到角色当前高度
			_reset_to_character_height()
		KEY_V:  # 切换视觉效果
			_toggle_visual_effects()
		KEY_P:  # 暂停/恢复动画
			_toggle_animation()
		KEY_B:  # 批量处理模式
			_toggle_batch_mode()

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
	
	print("🎮 [Input] 鼠标高度调整到: Y=%.1f" % _mouse_position.y)

func _reset_to_character_height():
	if _current_character:
		_mouse_position.y = _current_character.position.y
		call_deferred("_validate_target_position_async")
		var renderer = get_node("../Renderer")
		if renderer:
			renderer.update_mouse_indicator(_mouse_position)
		print("🎮 [Input] 重置到角色当前高度")

# 🚀 快捷键功能
func _toggle_visual_effects():
	if config:
		var current = config.is_visual_effects_enabled()
		config.set_visual_effects_enabled(not current)
		print("🎮 [Input] 视觉效果: %s" % ("启用" if not current else "禁用"))

func _toggle_animation():
	if config:
		var speed = config.animation_speed
		config.set_animation_speed(0.1 if speed > 0.5 else 2.0)
		print("🎮 [Input] 动画: %s" % ("暂停" if speed > 0.5 else "恢复"))

func _toggle_batch_mode():
	if config:
		var current = config.is_batch_computation_enabled()
		config.batch_computation = not current
		print("🎮 [Input] 批量模式: %s" % ("启用" if not current else "禁用"))

# 🎯 移动确认和取消（完整验证版）
func _confirm_move():
	if not _current_character or _mouse_position == Vector2.ZERO:
		print("🎮 [Input] 无效的移动确认")
		return
	
	# 🚀 最终确认前再次进行完整验证（双重保险）
	var target_position = _mouse_position
	var final_validation = _validate_position_comprehensive(target_position)
	
	if not final_validation.is_valid:
		print("🚀 [Input] 最终验证失败: %s" % final_validation.reason)
		_is_valid_position = false
		validation_changed.emit(false, final_validation.reason)
		return
	
	# 🚀 计算实际移动距离
	var actual_character_position = _get_character_actual_position()
	if actual_character_position == Vector2.ZERO:
		actual_character_position = _current_character.position
	var final_distance = actual_character_position.distance_to(target_position)
	
	# 🚀 最后一道防线：确保距离不超过轻功限制
	if final_distance > _current_character.qinggong_skill:
		print("🚀 [Input] 最终距离检查失败: %.1f > %d" % [final_distance, _current_character.qinggong_skill])
		_is_valid_position = false
		validation_changed.emit(false, "移动距离超出轻功限制")
		return
	
	print("✅ [Input] 移动验证通过 - 角色: %s, 距离: %.1f, 轻功: %d" % [
		_current_character.name, final_distance, _current_character.qinggong_skill
	])
	
	move_confirmed.emit(_current_character, target_position, 0.0, final_distance)

func _cancel_move():
	print("❌ [Input] 取消移动")
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
	print("🎮 [Input] 鼠标更新间隔: %dms" % _mouse_update_interval)

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
		print("🎮 [Input] 重置到角色当前高度") 
 

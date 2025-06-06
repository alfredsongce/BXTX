# 🚀 移动预览Area2D系统
# 实现实时碰撞检测和视觉反馈
extends Node
class_name MovePreviewArea

# 🎯 预览Area2D节点
var preview_area: Area2D = null
var preview_collision_shape: CollisionShape2D = null
var current_character = null
var current_character_node = null

# 🎨 可视化组件
var visual_drawer: Node2D = null
const CollisionShapeDrawer = preload("res://Scripts/CollisionShapeDrawer.gd")

# 🔧 碰撞状态
var is_colliding: bool = false
var collision_objects: Array = []
var last_update_time: int = 0
var update_interval: int = 16  # 约60FPS

# 🎯 统一位置碰撞管理器
var position_collision_manager: Node2D

# 📡 信号
signal collision_state_changed(is_colliding: bool, objects: Array)
signal preview_position_updated(position: Vector2)

func _ready():
	# 初始化统一位置碰撞管理器
	call_deferred("_setup_position_collision_manager")
	print("🚀 [PreviewArea] 移动预览系统初始化完成")

func _setup_position_collision_manager():
	# 尝试获取统一位置碰撞管理器
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if not battle_scene:
		battle_scene = AutoLoad.get_battle_scene()
	
	if battle_scene:
		position_collision_manager = battle_scene.get_node_or_null("BattleSystems/PositionCollisionManager")
		if position_collision_manager:
			print("🔗 [PreviewArea] 统一位置碰撞管理器连接成功")
			print("🔗 [PreviewArea] 管理器类型: ", position_collision_manager.get_class())
		else:
			printerr("❌ [PreviewArea] 无法找到统一位置碰撞管理器")
	else:
		printerr("❌ [PreviewArea] 无法找到战斗场景")
	
	print("📊 [PreviewArea] 统一管理器状态: ", "已连接" if position_collision_manager else "未连接")

# 🚀 为角色设置预览Area2D
func setup_movement_preview_area(character_node: Node2D) -> Area2D:
	print("🔧 [PreviewArea] 开始为角色设置预览区域: %s" % character_node.name)
	# 清理旧的预览区域
	if preview_area:
		_cleanup_preview_area()
	
	current_character = character_node
	current_character_node = character_node
	
	# 创建Area2D用于实时预览
	preview_area = Area2D.new()
	preview_area.name = "MovementPreviewArea"
	
	# 设置碰撞层和掩码
	preview_area.collision_layer = 0  # 不与任何层碰撞
	preview_area.collision_mask = 14  # 检测静态障碍物(2)、角色(4)和障碍物(8)
	
	# 设置监控模式
	preview_area.monitoring = true
	preview_area.monitorable = false  # 其他对象不能检测到这个预览区域
	
	# 创建碰撞形状
	preview_collision_shape = CollisionShape2D.new()
	
	# 复制角色的碰撞形状
	var character_shape = _get_character_collision_shape(character_node)
	if character_shape:
		preview_collision_shape.shape = character_shape.duplicate()
	else:
		# 如果无法获取角色形状，不设置碰撞形状
		preview_collision_shape.shape = null
		print("⚠️ [PreviewArea] 无法获取角色碰撞形状，禁用碰撞检测")
	
	# 调用设置碰撞形状函数
	_setup_collision_shape()
	
	# 🎨 创建可视化碰撞体
	_create_visual_collision_shape(character_shape if character_shape else preview_collision_shape.shape)
	
	# 组装节点结构
	preview_area.add_child(preview_collision_shape)
	if visual_drawer:
		preview_area.add_child(visual_drawer)
	AutoLoad.get_battle_scene().add_child(preview_area)
	
	# 连接信号
	preview_area.area_entered.connect(_on_preview_collision_entered)
	preview_area.area_exited.connect(_on_preview_collision_exited)
	preview_area.body_entered.connect(_on_preview_body_entered)
	preview_area.body_exited.connect(_on_preview_body_exited)
	
	# print("✅ [PreviewArea] 预览区域创建完成 - 角色: %s" % character_node.name)
	return preview_area

# 🔧 获取角色的碰撞形状
func _get_character_collision_shape(character_node: Node2D) -> Shape2D:
	var character_area = character_node.get_node_or_null("CharacterArea")
	if not character_area:
		# print("⚠️ [PreviewArea] 角色没有CharacterArea")
		return null
	
	var collision_shape = character_area.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		# print("⚠️ [PreviewArea] 角色没有有效的碰撞形状")
		return null
	
	return collision_shape.shape

# 🔧 设置碰撞形状
func _setup_collision_shape():
	"""设置碰撞形状"""
	if not preview_collision_shape:
		return
	
	# 获取角色的真实碰撞形状
	var character_shape = _get_character_collision_shape(current_character)
	if character_shape:
		# 使用角色的真实碰撞形状
		preview_collision_shape.shape = character_shape
	else:
		# 如果无法获取角色形状，不设置碰撞形状
		# 这样可以避免使用默认的圆形形状
		preview_collision_shape.shape = null
		print("⚠️ [MovePreviewArea] 无法获取角色碰撞形状，禁用碰撞检测")

# 🎯 更新预览位置
func update_preview_position(target_position: Vector2):
	# 移除鼠标移动时的频繁日志输出
	if not preview_area:
		print("⚠️ [PreviewArea] preview_area为空，无法更新位置")
		return
	
	# 限制更新频率
	var current_time = Time.get_ticks_msec()
	if current_time - last_update_time < update_interval:
		return
	last_update_time = current_time
	
	# 更新位置
	preview_area.position = target_position
	
	# 处理Transform2D的旋转和缩放
	if current_character:
		# 同步角色的旋转
		preview_area.rotation = current_character.rotation
		
		# 处理缩放问题（修复Area2D缩放）
		var character_scale = current_character.scale
		if character_scale != Vector2.ONE:
			# 通过调整碰撞形状大小来模拟缩放
			_apply_scale_to_collision_shape(character_scale)
	
	# 更新碰撞状态和X标记显示
	_update_collision_state()
	
	preview_position_updated.emit(target_position)

# 🔧 应用缩放到碰撞形状（修复Area2D缩放问题）
func _apply_scale_to_collision_shape(scale: Vector2):
	if not preview_collision_shape or not preview_collision_shape.shape:
		return
	
	var shape = preview_collision_shape.shape
	var original_shape = _get_character_collision_shape(current_character)
	
	if not original_shape:
		return
	
	if shape is CircleShape2D and original_shape is CircleShape2D:
		# 对圆形使用平均缩放
		var circle = shape as CircleShape2D
		var original_circle = original_shape as CircleShape2D
		circle.radius = original_circle.radius * (scale.x + scale.y) / 2.0
	
	elif shape is CapsuleShape2D and original_shape is CapsuleShape2D:
		# 对胶囊形状分别缩放宽度和高度
		var capsule = shape as CapsuleShape2D
		var original_capsule = original_shape as CapsuleShape2D
		capsule.radius = original_capsule.radius * scale.x
		capsule.height = original_capsule.height * scale.y
	
	elif shape is RectangleShape2D and original_shape is RectangleShape2D:
		# 对矩形形状缩放尺寸
		var rect = shape as RectangleShape2D
		var original_rect = original_shape as RectangleShape2D
		rect.size = original_rect.size * scale

# 📡 碰撞信号处理
func _on_preview_collision_entered(area: Area2D):
	# 排除自身角色的Area2D
	if _is_own_character_area(area):
		print("🔍 [PreviewArea] 忽略自身角色Area2D: %s" % area.name)
		return
	
	collision_objects.append(area)
	print("🔍 [PreviewArea] 检测到Area2D碰撞: %s (总碰撞对象: %d)" % [area.name, collision_objects.size()])
	_update_collision_state()

func _on_preview_collision_exited(area: Area2D):
	if _is_own_character_area(area):
		return
	
	collision_objects.erase(area)
	print("🔍 [PreviewArea] Area2D碰撞结束: %s (剩余碰撞对象: %d)" % [area.name, collision_objects.size()])
	_update_collision_state()

func _on_preview_body_entered(body: Node2D):
	# 处理RigidBody2D或StaticBody2D碰撞
	collision_objects.append(body)
	print("🔍 [PreviewArea] 检测到Body碰撞: %s (总碰撞对象: %d)" % [body.name, collision_objects.size()])
	_update_collision_state()

func _on_preview_body_exited(body: Node2D):
	collision_objects.erase(body)
	print("🔍 [PreviewArea] Body碰撞结束: %s (剩余碰撞对象: %d)" % [body.name, collision_objects.size()])
	_update_collision_state()

# 🔧 检查是否是自身角色的Area2D
func _is_own_character_area(area: Area2D) -> bool:
	if not current_character:
		return false
	
	# 检查是否是角色的CharacterArea
	var character_area = current_character.get_node_or_null("CharacterArea")
	return character_area == area

# 🎨 创建可视化碰撞体
func _create_visual_collision_shape(shape: Shape2D):
	if not shape:
		return
	
	# 创建可视化绘制器
	visual_drawer = CollisionShapeDrawer.new()
	visual_drawer.name = "VisualCollisionShape"
	
	# 根据形状类型设置绘制器
	if shape is CircleShape2D:
		var circle = shape as CircleShape2D
		visual_drawer.setup_circle(circle.radius, "preview")
	elif shape is CapsuleShape2D:
		var capsule = shape as CapsuleShape2D
		visual_drawer.setup_capsule(capsule.radius, capsule.height, "preview")
	elif shape is RectangleShape2D:
		var rect = shape as RectangleShape2D
		visual_drawer.setup_rectangle(rect.size, "preview")
	else:
		# 默认使用圆形
		visual_drawer.setup_circle(20.0, "preview")
	
	# 设置初始颜色为绿色（无碰撞）
	visual_drawer.update_color(Color.GREEN)
	# print("🎨 [PreviewArea] 创建可视化碰撞体")

# 🔧 更新碰撞状态 - 使用统一的PositionCollisionManager
func _update_collision_state():
	if not preview_area or not current_character_node:
		return
	
	var current_pos = preview_area.global_position
	var new_collision_state = false
	var validation_failed_reason = ""
	
	# 移除频繁的碰撞检测日志输出
	# print("🔍 [PreviewArea] 统一碰撞检测详情:")
	# print("  - 当前位置: %s" % str(current_pos))
	# print("  - 当前角色: %s" % (current_character_node.name if current_character_node else "无"))
	
	# 使用统一的PositionCollisionManager进行验证（包含物理碰撞和轻功技能检查）
	if not position_collision_manager:
		printerr("[PreviewArea] 错误: 统一位置碰撞管理器不可用")
		return
	
	if not current_character_node:
		printerr("[PreviewArea] 错误: 角色节点不可用")
		return
	
	# 使用统一管理器进行完整验证
	var final_valid = position_collision_manager.validate_position(current_pos, current_character_node)
	new_collision_state = not final_valid
	
	# 移除鼠标移动时的频繁验证结果日志
	
	# 更新碰撞状态和可视化效果
	if new_collision_state != is_colliding:
		is_colliding = new_collision_state
		collision_state_changed.emit(is_colliding, collision_objects.duplicate())
		
		# 更新可视化效果
		if visual_drawer:
			if is_colliding:
				visual_drawer.update_color(Color(1.0, 0.5, 0.5, 0.8))  # 浅红色
				visual_drawer.set_x_mark(true)  # 显示X号表示不可移动
			else:
				visual_drawer.update_color(Color(0.5, 1.0, 0.5, 0.8))  # 绿色
				visual_drawer.set_x_mark(false)  # 隐藏X号
		
		# 移除频繁的验证结果日志输出
		# var status = "不可移动" if is_colliding else "可移动"
		# var color_status = "浅红色" if is_colliding else "绿色"
		# print("🎯 [PreviewArea] 统一验证结果: %s - 颜色: %s" % [status, color_status])
		# print("🔍 [PreviewArea] 使用统一PositionCollisionManager进行完整验证")
	
	# 移除频繁的当前状态日志输出
	# print("🎯 [PreviewArea] 当前碰撞状态: %s (基于统一验证)" % ("有碰撞" if is_colliding else "无碰撞"))

# 🚀 动态障碍物同步
func force_refresh_collision_detection():
	"""强制刷新碰撞检测，用于同步动态障碍物"""
	if not preview_area:
		return
	
	# 临时禁用和重新启用监控来强制刷新
	preview_area.monitoring = false
	await get_tree().process_frame
	preview_area.monitoring = true
	
	# print("🔄 [PreviewArea] 强制刷新碰撞检测完成")

# 🧹 清理预览区域
func _cleanup_preview_area():
	print("🧹 [PreviewArea] 开始清理预览区域")
	
	# 断开信号连接
	if preview_area:
		if preview_area.area_entered.is_connected(_on_preview_collision_entered):
			preview_area.area_entered.disconnect(_on_preview_collision_entered)
		if preview_area.area_exited.is_connected(_on_preview_collision_exited):
			preview_area.area_exited.disconnect(_on_preview_collision_exited)
		if preview_area.body_entered.is_connected(_on_preview_body_entered):
			preview_area.body_entered.disconnect(_on_preview_body_entered)
		if preview_area.body_exited.is_connected(_on_preview_body_exited):
			preview_area.body_exited.disconnect(_on_preview_body_exited)
		
		# 释放节点
		preview_area.queue_free()
		preview_area = null
	
	# 清理可视化组件
	if visual_drawer:
		visual_drawer.queue_free()
		visual_drawer = null
	
	# 重置状态
	preview_collision_shape = null
	current_character = null
	current_character_node = null
	is_colliding = false
	collision_objects.clear()
	
	print("✅ [PreviewArea] 预览区域清理完成")

# 🎯 获取当前碰撞状态
func get_collision_state() -> Dictionary:
	return {
		"is_colliding": is_colliding,
		"collision_count": collision_objects.size(),
		"collision_objects": collision_objects.duplicate(),
		"preview_active": preview_area != null
	}

# 🚀 启用/禁用预览
func set_preview_enabled(enabled: bool):
	if preview_area:
		preview_area.monitoring = enabled
		preview_area.visible = enabled
		
		var status = "启用" if enabled else "禁用"
		# print("🎯 [PreviewArea] 预览系统%s" % status)

# 🧹 清理资源
func _exit_tree():
	_cleanup_preview_area()

class_name BattleVisualizationManager
extends Node

## BattleVisualizationManager - 战斗可视化管理器
##
## 职责：
## - 碰撞可视化系统管理
## - 战斗结果标记和动画
## - 视觉反馈效果协调 
## - 调试可视化工具

# 引用
var battle_scene: Node2D
var collision_visualization_enabled: bool = false

# 可视化节点容器
var visualization_container: Node2D
var collision_visuals_container: Node2D
var result_markers_container: Node2D

# 初始化
func initialize(scene: Node2D) -> void:
	print("🎨 [BattleVisualizationManager] 初始化可视化管理器")
	battle_scene = scene
	_setup_visualization_containers()

## 设置可视化容器
func _setup_visualization_containers() -> void:
	# 创建主容器
	visualization_container = Node2D.new()
	visualization_container.name = "VisualizationContainer"
	battle_scene.add_child(visualization_container)
	
	# 创建碰撞可视化容器
	collision_visuals_container = Node2D.new()
	collision_visuals_container.name = "CollisionVisuals"
	visualization_container.add_child(collision_visuals_container)
	
	# 创建结果标记容器
	result_markers_container = Node2D.new()
	result_markers_container.name = "ResultMarkers"
	visualization_container.add_child(result_markers_container)

## 设置碰撞可视化系统（从BattleScene迁移）
func setup_collision_visualization() -> void:
	print("🎨 [BattleVisualizationManager] 设置碰撞可视化")
	# 初始设置碰撞可视化为关闭状态
	collision_visualization_enabled = false
	_update_collision_visualization_visibility()

## 切换碰撞可视化显示（从BattleScene迁移）
func toggle_collision_visualization() -> void:
	collision_visualization_enabled = !collision_visualization_enabled
	print("🎨 [BattleVisualizationManager] 切换碰撞可视化: %s" % ("开启" if collision_visualization_enabled else "关闭"))
	_update_collision_visualization_visibility()

## 更新碰撞可视化可见性
func _update_collision_visualization_visibility() -> void:
	if collision_visuals_container:
		collision_visuals_container.visible = collision_visualization_enabled

## 添加碰撞可视化（从BattleScene迁移）
func add_collision_visualization(character_node: Node2D) -> void:
	if not collision_visualization_enabled:
		return
		
	if not character_node or not collision_visuals_container:
		return
		
	print("🎨 [BattleVisualizationManager] 为角色添加碰撞可视化: %s" % character_node.name)
	
	# 获取角色的碰撞形状
	var collision_shape = character_node.get_node_or_null("CollisionShape2D")
	if not collision_shape:
		print("⚠️ [BattleVisualizationManager] 角色没有碰撞形状: %s" % character_node.name)
		return
	
	var shape = collision_shape.shape
	if shape is CapsuleShape2D:
		_create_capsule_visual(character_node, shape as CapsuleShape2D)
	elif shape is RectangleShape2D:
		_create_rectangle_visual(character_node, shape as RectangleShape2D)
	else:
		print("⚠️ [BattleVisualizationManager] 不支持的碰撞形状类型")

## 创建胶囊形状可视化（从BattleScene迁移）
func _create_capsule_visual(character_node: Node2D, capsule_shape: CapsuleShape2D) -> void:
	var visual = Line2D.new()
	visual.name = character_node.name + "_CapsuleVisual"
	visual.width = 2.0
	visual.default_color = Color.CYAN
	visual.z_index = 100
	
	# 胶囊形状的可视化
	var height = capsule_shape.height
	var radius = capsule_shape.radius
	
	# 创建胶囊轮廓点
	var points: PackedVector2Array = []
	var segments = 16
	
	# 上半圆
	for i in range(segments / 2 + 1):
		var angle = PI * i / (segments / 2)
		var x = radius * cos(angle)
		var y = -height/2 + radius * sin(angle)
		points.append(Vector2(x, y))
	
	# 下半圆
	for i in range(segments / 2 + 1):
		var angle = PI + PI * i / (segments / 2)
		var x = radius * cos(angle)
		var y = height/2 + radius * sin(angle)
		points.append(Vector2(x, y))
	
	# 闭合路径
	if points.size() > 0:
		points.append(points[0])
	
	visual.points = points
	visual.position = character_node.global_position
	
	collision_visuals_container.add_child(visual)

## 创建矩形可视化（从BattleScene迁移）
func _create_rectangle_visual(character_node: Node2D, rect_shape: RectangleShape2D) -> void:
	var visual = Line2D.new()
	visual.name = character_node.name + "_RectVisual"
	visual.width = 2.0
	visual.default_color = Color.YELLOW
	visual.z_index = 100
	
	var size = rect_shape.size
	var half_size = size / 2
	
	var points: PackedVector2Array = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
		Vector2(-half_size.x, -half_size.y)  # 闭合
	]
	
	visual.points = points
	visual.position = character_node.global_position
	
	collision_visuals_container.add_child(visual)

## 添加结果标记（从BattleScene迁移）
func add_result_marker(position: Vector2, result_text: String, color: Color = Color.WHITE) -> void:
	print("🎨 [BattleVisualizationManager] 添加结果标记: %s 在位置 %s" % [result_text, position])
	
	if not result_markers_container:
		print("⚠️ [BattleVisualizationManager] 结果标记容器不存在")
		return
	
	# 创建标记标签
	var marker_label = Label.new()
	marker_label.text = result_text
	marker_label.modulate = color
	marker_label.z_index = 200
	
	# 设置字体大小和样式
	marker_label.add_theme_font_size_override("font_size", 24)
	marker_label.add_theme_color_override("font_color", color)
	marker_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	marker_label.add_theme_constant_override("shadow_offset_x", 2)
	marker_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# 设置位置
	marker_label.position = position - Vector2(50, 25)  # 居中偏移
	
	result_markers_container.add_child(marker_label)
	
	# 添加动画效果
	_animate_result_marker(marker_label)

## 动画结果标记（从BattleScene迁移）
func _animate_result_marker(marker: Label) -> void:
	# 创建补间动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 淡入和上升动画
	tween.tween_property(marker, "position", marker.position + Vector2(0, -50), 1.5)
	tween.tween_property(marker, "modulate:a", 0.0, 1.5)
	
	# 动画完成后删除标记
	tween.tween_callback(_remove_marker.bind(marker)).set_delay(1.5)

## 移除标记
func _remove_marker(marker: Label) -> void:
	if marker and is_instance_valid(marker):
		marker.queue_free()

## 创建视觉反馈效果
func create_visual_feedback(target: Node2D, effect_type: String) -> void:
	print("🎨 [BattleVisualizationManager] 创建视觉反馈: %s 对象: %s" % [effect_type, target.name if target else "无"])
	
	if not target:
		return
	
	match effect_type:
		"hit":
			_create_hit_effect(target)
		"heal":
			_create_heal_effect(target)
		"critical":
			_create_critical_effect(target)
		"miss":
			_create_miss_effect(target)
		_:
			print("⚠️ [BattleVisualizationManager] 未知的视觉效果类型: %s" % effect_type)

## 创建击中效果
func _create_hit_effect(target: Node2D) -> void:
	add_result_marker(target.global_position, "击中!", Color.RED)

## 创建治疗效果
func _create_heal_effect(target: Node2D) -> void:
	add_result_marker(target.global_position, "治疗", Color.GREEN)

## 创建暴击效果
func _create_critical_effect(target: Node2D) -> void:
	add_result_marker(target.global_position, "暴击!", Color.ORANGE)

## 创建闪避效果
func _create_miss_effect(target: Node2D) -> void:
	add_result_marker(target.global_position, "闪避", Color.GRAY)

## 清理所有可视化效果
func cleanup_all_visuals() -> void:
	print("🎨 [BattleVisualizationManager] 清理所有可视化效果")
	
	if collision_visuals_container:
		for child in collision_visuals_container.get_children():
			child.queue_free()
	
	if result_markers_container:
		for child in result_markers_container.get_children():
			child.queue_free()

## 获取碰撞可视化状态
func is_collision_visualization_enabled() -> bool:
	return collision_visualization_enabled

## 设置可视化容器的可见性
func set_visualization_visibility(visible: bool) -> void:
	if visualization_container:
		visualization_container.visible = visible 
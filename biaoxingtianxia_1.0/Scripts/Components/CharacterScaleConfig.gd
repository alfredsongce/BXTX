# 角色缩放配置组件
# 添加到角色场景中，用于配置该角色的缩放倍数
# 支持编辑器可视化配置和运行时动态调整

@tool
extends Node
class_name CharacterScaleConfig

# ========== 配置属性 ==========
@export_group("角色缩放设置")
@export_range(0.1, 5.0, 0.1) var scale_factor: float = 1.0:
	set(value):
		scale_factor = value
		if Engine.is_editor_hint():
			_preview_scale_in_editor()
		else:
			_apply_scale_at_runtime()

@export var auto_apply_on_ready: bool = true
@export var override_global_scale: bool = false

@export_group("高级设置") 
@export var custom_anchor_offset: Vector2 = Vector2.ZERO
@export var scale_visual_only: bool = false
@export var preserve_collision_shape: bool = false

# ========== 运行时状态 ==========
var is_applied: bool = false
var original_scale_factor: float = 1.0

# ========== 信号 ==========
signal scale_applied(new_scale: float)
signal scale_reset()

func _ready():
	if not Engine.is_editor_hint():
		if auto_apply_on_ready:
			apply_scale()
	else:
		# 编辑器模式下的预览
		print("🔧 [CharacterScaleConfig] 编辑器模式已激活")

# 应用缩放到角色
func apply_scale() -> void:
	var character_node = get_parent()
	if not character_node:
		printerr("❌ [CharacterScaleConfig] 未找到角色节点")
		return
	
	if is_applied:
		printerr("⚠️ [CharacterScaleConfig] 缩放已经应用过了")
		return
	
	# 保存原始缩放
	original_scale_factor = GameSettings.get_character_scale() if GameSettings else 1.0
	
	# 决定使用哪个缩放值
	var target_scale = scale_factor
	if not override_global_scale and GameSettings:
		target_scale = scale_factor * GameSettings.get_character_scale()
	
	# 应用缩放
	_apply_character_scale_internal(character_node, target_scale)
	
	is_applied = true
	scale_applied.emit(target_scale)
	
	print("✅ [CharacterScaleConfig] 已为角色 %s 应用 %.1f 倍缩放" % [character_node.name, target_scale])

# 重置缩放
func reset_scale() -> void:
	var character_node = get_parent()
	if not character_node or not is_applied:
		return
	
	_apply_character_scale_internal(character_node, 1.0)
	is_applied = false
	scale_reset.emit()
	
	print("🔄 [CharacterScaleConfig] 已重置角色 %s 的缩放" % character_node.name)

# 动态调整缩放
func set_scale_factor_runtime(new_factor: float) -> void:
	if is_applied:
		reset_scale()
	
	scale_factor = new_factor
	apply_scale()

# 内部缩放应用函数
func _apply_character_scale_internal(character_node: Node2D, target_scale: float) -> void:
	if scale_visual_only:
		# 只缩放视觉部分
		_scale_visual_only(character_node, target_scale)
	else:
		# 使用完整的分离式缩放
		_scale_all_components(character_node, target_scale)

# 只缩放视觉组件
func _scale_visual_only(character_node: Node2D, scale: float) -> void:
	var graphic_node = character_node.get_node_or_null("Graphic")
	if graphic_node:
		graphic_node.scale = Vector2(scale, scale)
		print("🎨 [CharacterScaleConfig] 已缩放视觉组件 %.1f 倍" % scale)

# 缩放所有组件（分离式）
func _scale_all_components(character_node: Node2D, scale: float) -> void:
	# 1. 缩放视觉部分
	var graphic_node = character_node.get_node_or_null("Graphic")
	if graphic_node:
		graphic_node.scale = Vector2(scale, scale)
		print("🎨 [CharacterScaleConfig] 已缩放视觉组件 %.1f 倍" % scale)
	
	# 2. 缩放碰撞体（如果不保留原始形状）
	if not preserve_collision_shape:
		var character_area = character_node.get_node_or_null("CharacterArea")
		if character_area:
			var collision_shape = character_area.get_node_or_null("CollisionShape2D")
			if collision_shape and collision_shape.shape:
				_scale_collision_shape(collision_shape.shape, scale)
				print("🎨 [CharacterScaleConfig] 已缩放碰撞体组件 %.1f 倍" % scale)
	
	# 3. 调整GroundAnchor位置
	var ground_anchor = character_node.get_node_or_null("GroundAnchor")
	if ground_anchor:
		var base_position = Vector2(0, 22) + custom_anchor_offset
		ground_anchor.position = base_position * scale
		print("🎨 [CharacterScaleConfig] 已调整GroundAnchor位置 %.1f 倍" % scale)

# 缩放碰撞形状
func _scale_collision_shape(shape: Shape2D, scale_factor: float) -> void:
	if shape is CapsuleShape2D:
		var capsule = shape as CapsuleShape2D
		if not capsule.has_meta("original_radius"):
			capsule.set_meta("original_radius", capsule.radius)
			capsule.set_meta("original_height", capsule.height)
		
		capsule.radius = capsule.get_meta("original_radius") * scale_factor
		capsule.height = capsule.get_meta("original_height") * scale_factor
		
	elif shape is CircleShape2D:
		var circle = shape as CircleShape2D
		if not circle.has_meta("original_radius"):
			circle.set_meta("original_radius", circle.radius)
		circle.radius = circle.get_meta("original_radius") * scale_factor
		
	elif shape is RectangleShape2D:
		var rect = shape as RectangleShape2D
		if not rect.has_meta("original_size"):
			rect.set_meta("original_size", rect.size)
		rect.size = rect.get_meta("original_size") * scale_factor

# 编辑器预览（@tool模式）
func _preview_scale_in_editor() -> void:
	if not Engine.is_editor_hint():
		return
	
	var character_node = get_parent()
	if not character_node:
		return
	
	# 在编辑器中只预览视觉效果
	var graphic_node = character_node.get_node_or_null("Graphic")
	if graphic_node:
		graphic_node.scale = Vector2(scale_factor, scale_factor)

# 运行时应用
func _apply_scale_at_runtime() -> void:
	if not Engine.is_editor_hint() and is_applied:
		# 如果已经应用过，重新应用新的缩放
		reset_scale()
		apply_scale()

# 获取当前有效缩放
func get_effective_scale() -> float:
	if override_global_scale:
		return scale_factor
	else:
		var global_scale = GameSettings.get_character_scale() if GameSettings else 1.0
		return scale_factor * global_scale

# 配置验证
func validate_config() -> bool:
	var character_node = get_parent()
	if not character_node:
		printerr("❌ [CharacterScaleConfig] 必须作为角色节点的子节点")
		return false
	
	var required_nodes = ["Graphic"]
	if not scale_visual_only:
		required_nodes.append_array(["CharacterArea", "GroundAnchor"])
	
	for node_name in required_nodes:
		if not character_node.has_node(node_name):
			printerr("❌ [CharacterScaleConfig] 缺失必要节点: %s" % node_name)
			return false
	
	return true

# 调试信息
func get_debug_info() -> Dictionary:
	return {
		"scale_factor": scale_factor,
		"is_applied": is_applied,
		"effective_scale": get_effective_scale(),
		"auto_apply": auto_apply_on_ready,
		"override_global": override_global_scale,
		"visual_only": scale_visual_only,
		"preserve_collision": preserve_collision_shape
	} 

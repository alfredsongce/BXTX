# 游戏设置管理器
# 管理全局游戏配置，包括角色显示、UI等设置

extends Node

# ========== 角色显示设置 ==========
var character_scale: float = 1.0  # 全局角色缩放倍数
var scale_affects_all_components: bool = true  # 缩放影响所有组件（推荐）

# ========== UI设置 ==========
var ui_scale: float = 1.0
var show_debug_info: bool = false

# ========== 性能设置 ==========
var max_visual_effects: int = 10
var enable_shadows: bool = true

# 信号
signal settings_changed(setting_name: String, old_value, new_value)

func _ready():
	print("⚙️ [GameSettings] 游戏设置管理器初始化完成")

# 设置角色缩放
func set_character_scale(new_scale: float) -> void:
	if new_scale > 0.1 and new_scale <= 5.0:  # 限制缩放范围
		var old_scale = character_scale
		character_scale = new_scale
		settings_changed.emit("character_scale", old_scale, new_scale)
		print("⚙️ [GameSettings] 角色缩放设置为: %.1f" % new_scale)
	else:
		printerr("❌ [GameSettings] 无效的缩放值: %.1f (允许范围: 0.1-5.0)" % new_scale)

# 获取角色缩放
func get_character_scale() -> float:
	return character_scale

# 设置是否影响所有组件
func set_scale_affects_all_components(affects: bool) -> void:
	var old_value = scale_affects_all_components
	scale_affects_all_components = affects
	settings_changed.emit("scale_affects_all_components", old_value, affects)

# 应用角色缩放到节点（修正版：处理碰撞检测问题）
func apply_character_scale(character_node: Node2D) -> void:
	if not character_node:
		return
	
	# 🔧 关键修复：不直接缩放整个节点，而是分别缩放各个组件
	# 这样可以避免碰撞检测系统的混乱
	
	# 1. 缩放视觉部分
	var graphic_node = character_node.get_node_or_null("Graphic")
	if graphic_node:
		graphic_node.scale = Vector2(character_scale, character_scale)
		print("🎨 [GameSettings] 已缩放视觉组件 %.1f 倍" % character_scale)
	
	# 2. 缩放碰撞体（保持物理一致性）
	var character_area = character_node.get_node_or_null("CharacterArea")
	if character_area:
		# 🔧 关键：直接修改碰撞形状的大小，而不是缩放节点
		var collision_shape = character_area.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			_scale_collision_shape(collision_shape.shape, character_scale)
			print("🎨 [GameSettings] 已缩放碰撞体组件 %.1f 倍" % character_scale)
	
	# 3. 缩放GroundAnchor位置
	var ground_anchor = character_node.get_node_or_null("GroundAnchor")
	if ground_anchor:
		# 保持GroundAnchor相对位置的缩放
		var original_position = Vector2(0, 22)  # 原始位置
		ground_anchor.position = original_position * character_scale
		print("🎨 [GameSettings] 已调整GroundAnchor位置 %.1f 倍" % character_scale)
	
	print("🎨 [GameSettings] 已应用分离式缩放到 %s（保持碰撞检测一致性）" % character_node.name)

# 直接修改碰撞形状大小的函数
func _scale_collision_shape(shape: Shape2D, scale_factor: float) -> void:
	if shape is CapsuleShape2D:
		var capsule = shape as CapsuleShape2D
		# 保存原始值（如果还没有保存的话）
		if not capsule.has_meta("original_radius"):
			capsule.set_meta("original_radius", capsule.radius)
			capsule.set_meta("original_height", capsule.height)
		
		# 应用缩放
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

# 保存设置到文件
func save_settings() -> void:
	var config = ConfigFile.new()
	
	config.set_value("display", "character_scale", character_scale)
	config.set_value("display", "scale_affects_all_components", scale_affects_all_components)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "show_debug_info", show_debug_info)
	
	config.set_value("performance", "max_visual_effects", max_visual_effects)
	config.set_value("performance", "enable_shadows", enable_shadows)
	
	var error = config.save("user://game_settings.cfg")
	if error == OK:
		print("💾 [GameSettings] 设置已保存")
	else:
		printerr("❌ [GameSettings] 保存设置失败: %d" % error)

# 加载设置从文件
func load_settings() -> void:
	var config = ConfigFile.new()
	var error = config.load("user://game_settings.cfg")
	
	if error != OK:
		print("📄 [GameSettings] 未找到设置文件，使用默认设置")
		return
	
	character_scale = config.get_value("display", "character_scale", 2.0)
	scale_affects_all_components = config.get_value("display", "scale_affects_all_components", true)
	ui_scale = config.get_value("display", "ui_scale", 1.0)
	show_debug_info = config.get_value("display", "show_debug_info", false)
	
	max_visual_effects = config.get_value("performance", "max_visual_effects", 10)
	enable_shadows = config.get_value("performance", "enable_shadows", true)
	
	print("📄 [GameSettings] 设置已加载，角色缩放: %.1f" % character_scale)

# 重置为默认设置
func reset_to_defaults() -> void:
	character_scale = 1.0
	scale_affects_all_components = true
	ui_scale = 1.0
	show_debug_info = false
	max_visual_effects = 10
	enable_shadows = true
	
	print("🔄 [GameSettings] 已重置为默认设置") 
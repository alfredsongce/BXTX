# 玩家视觉组件
extends Node
class_name PlayerVisualsComponent

# 引用
var player_node: Node2D
var character_data: GameCharacter

# 视觉节点
var shadow: ColorRect
var height_label: Label
var debug_rect: ColorRect

func _init(player: Node2D = null):
	if player:
		setup(player)

func setup(player: Node2D) -> void:
	player_node = player
	if player.has_method("get_character_data"):
		character_data = player.get_character_data()
	
	# 创建视觉节点
	_setup_visual_elements()

# 设置视觉元素
func _setup_visual_elements() -> void:
	# 设置角色阴影
	shadow = ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.3)  # 半透明黑色
	shadow.size = Vector2(64, 16)  # 椭圆形阴影
	shadow.position = Vector2(-32, -8)  # 居中
	player_node.add_child(shadow)
	
	# 设置高度标签
	height_label = Label.new()
	height_label.text = "0"
	height_label.position = Vector2(-10, -50)  # 在角色上方
	height_label.add_theme_color_override("font_color", Color.WHITE)
	height_label.add_theme_color_override("font_outline_color", Color.BLACK)
	height_label.add_theme_constant_override("outline_size", 2)
	player_node.add_child(height_label)
	
	# 设置调试矩形 - 显示可点击区域
	debug_rect = ColorRect.new()
	debug_rect.color = Color(1, 0, 0, 0.3)  # 红色半透明
	debug_rect.size = Vector2(64, 64)  # 点击区域大小
	debug_rect.position = Vector2(-32, -32)  # 居中
	debug_rect.visible = false  # 默认隐藏，只在鼠标悬停时显示
	player_node.add_child(debug_rect)

# 更新高度显示
func update_height_display() -> void:
	if not character_data:
		return
	
	# 获取当前高度等级
	var height_level = character_data.get_height_level()
	
	# 更新高度标签 - 显示一位小数
	height_label.text = "%.1f" % height_level
	height_label.visible = height_level > 0
	
	# 计算阴影大小（随高度增加而变小）
	var shadow_scale = max(0.3, 1.0 - (height_level / 5.0))  # 改变比例使效果更明显
	shadow.scale = Vector2(shadow_scale, shadow_scale)
	
	# 更新角色透明度（可选）
	player_node.modulate.a = max(0.6, 1.0 - (height_level / 10.0))  # 略微调整透明度变化
	
	# 更新角色位置数据
	character_data.position = player_node.position

# 显示调试矩形（鼠标悬停时）
func show_debug_rect() -> void:
	debug_rect.visible = true
	debug_rect.color = Color(0, 1, 0, 0.3)  # 绿色半透明表示可以点击

# 隐藏调试矩形
func hide_debug_rect() -> void:
	debug_rect.visible = false
	debug_rect.color = Color(1, 0, 0, 0.3)  # 红色半透明

# 更新角色透明度（用于高度效果）
func update_modulate(height_level: float) -> void:
	player_node.modulate.a = max(0.6, 1.0 - (height_level / 10.0)) 

# 战斗UI管理器
# 负责管理所有战斗相关的UI元素和交互
class_name BattleUIManager
extends Control

# 信号定义
signal ui_update_requested(title: String, message: String, update_type: String)
signal battle_button_pressed()

# UI组件引用
var battle_ui: Control
var turn_label: Label
var current_character_label: Label
var ui_update_timer: Timer
var last_ui_update_type: String = ""

# 初始化
func _ready() -> void:
	name = "BattleUIManager"
	print("✅ [BattleUIManager] 战斗UI管理器初始化")
	_setup_battle_ui()

# 🚀 设置战斗UI
func _setup_battle_ui() -> void:
	# 创建战斗UI容器
	battle_ui = Control.new()
	battle_ui.name = "BattleUI"
	battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
	add_child(battle_ui)
	
	# 创建回合信息面板
	var turn_panel = Panel.new()
	turn_panel.name = "TurnPanel"
	turn_panel.custom_minimum_size = Vector2(320, 90)
	turn_panel.position = Vector2(20, 20)  # 左上角位置
	
	# 🚀 设置面板样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.2, 0.9)  # 深蓝色半透明背景
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.4, 0.6, 1.0, 1.0)  # 蓝色边框
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	turn_panel.add_theme_stylebox_override("panel", style_box)
	
	battle_ui.add_child(turn_panel)
	
	# 添加边距容器
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	turn_panel.add_child(margin)
	
	# 创建垂直布局容器
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# 创建回合数标签
	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "准备战斗..."
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	turn_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	turn_label.add_theme_constant_override("shadow_offset_x", 1)
	turn_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(turn_label)
	
	# 创建当前角色标签
	current_character_label = Label.new()
	current_character_label.name = "CurrentCharacterLabel"
	current_character_label.text = ""
	current_character_label.add_theme_font_size_override("font_size", 16)
	current_character_label.add_theme_color_override("font_color", Color.YELLOW)
	current_character_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	current_character_label.add_theme_constant_override("shadow_offset_x", 1)
	current_character_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(current_character_label)
	
	# 🚀 添加开始战斗按钮
	_setup_battle_control_button()
	
	print("✅ [BattleUIManager] 战斗UI初始化完成")

# 🚀 更新UI显示
func update_battle_ui(title: String, message: String, update_type: String = "general") -> void:
	# 🚀 如果是临时状态信息（如技能选择、攻击选择），设置自动清理
	var should_auto_clear = update_type in ["skill_action", "attack_select", "action_temp"]
	
	if turn_label:
		turn_label.text = title
		# 🚀 添加淡入动画效果
		_animate_ui_update(turn_label)
	
	if current_character_label:
		current_character_label.text = message
		if message != "":
			_animate_ui_update(current_character_label)
	
	# 🚀 记录更新类型
	last_ui_update_type = update_type
	
	# 🚀 对于临时信息，设置3秒后自动清理
	if should_auto_clear:
		_schedule_ui_cleanup(3.0)

# 🚀 安排UI清理
func _schedule_ui_cleanup(delay: float) -> void:
	# 清除之前的计时器
	if ui_update_timer:
		ui_update_timer.queue_free()
		ui_update_timer = null
	
	# 创建新的计时器
	ui_update_timer = Timer.new()
	ui_update_timer.wait_time = delay
	ui_update_timer.one_shot = true
	add_child(ui_update_timer)
	
	# 连接信号
	ui_update_timer.timeout.connect(_clear_temporary_ui_info)
	ui_update_timer.start()

# 🚀 清理临时UI信息
func _clear_temporary_ui_info() -> void:
	# 只清理临时信息，保留重要的战斗状态
	if last_ui_update_type in ["skill_action", "attack_select", "action_temp"]:
		# 发出信号请求恢复当前回合UI
		ui_update_requested.emit("restore_turn_ui", "", "restore")
	
	# 清理计时器
	if ui_update_timer:
		ui_update_timer.queue_free()
		ui_update_timer = null

# 🚀 UI更新动画
func _animate_ui_update(label: Label) -> void:
	if not label:
		return
	
	# 创建淡入效果
	var tween = create_tween()
	label.modulate.a = 0.3
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.set_ease(Tween.EASE_OUT)

# 🚀 切换战斗UI显示
func toggle_battle_ui():
	battle_ui.visible = not battle_ui.visible
	print("🔍 [BattleUIManager] 战斗UI显示: %s" % ("开启" if battle_ui.visible else "关闭"))

# 🚀 设置战斗控制按钮
func _setup_battle_control_button() -> void:
	# 创建按钮容器
	var button_container = Control.new()
	button_container.name = "BattleControlContainer"
	button_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让容器不拦截鼠标事件
	button_container.z_index = 100  # 确保在最上层
	battle_ui.add_child(button_container)
	
	# 创建开始战斗按钮
	var start_battle_button = Button.new()
	start_battle_button.name = "StartBattleButton"
	start_battle_button.text = "开始战斗"
	start_battle_button.custom_minimum_size = Vector2(120, 50)  # 稍微增大尺寸
	
	# 🚀 修改定位方式：使用绝对位置而不是anchor
	start_battle_button.position = Vector2(get_viewport().get_visible_rect().size.x - 140, get_viewport().get_visible_rect().size.y - 80)
	start_battle_button.z_index = 101  # 确保按钮在最上层
	
	# 设置按钮样式
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.7, 0.2, 0.9)  # 绿色背景
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.4, 1.0, 0.4, 1.0)  # 亮绿色边框
	button_style.corner_radius_top_left = 6
	button_style.corner_radius_top_right = 6
	button_style.corner_radius_bottom_left = 6
	button_style.corner_radius_bottom_right = 6
	start_battle_button.add_theme_stylebox_override("normal", button_style)
	
	# 悬停样式
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.8, 0.3, 1.0)
	start_battle_button.add_theme_stylebox_override("hover", hover_style)
	
	# 按下样式
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.5, 0.1, 1.0)
	start_battle_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# 禁用样式（战斗进行中）
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.4, 0.4, 0.4, 0.7)
	disabled_style.border_width_left = 2
	disabled_style.border_width_right = 2
	disabled_style.border_width_top = 2
	disabled_style.border_width_bottom = 2
	disabled_style.border_color = Color(0.6, 0.6, 0.6, 0.8)
	disabled_style.corner_radius_top_left = 6
	disabled_style.corner_radius_top_right = 6
	disabled_style.corner_radius_bottom_left = 6
	disabled_style.corner_radius_bottom_right = 6
	start_battle_button.add_theme_stylebox_override("disabled", disabled_style)
	
	# 设置字体颜色
	start_battle_button.add_theme_color_override("font_color", Color.WHITE)
	start_battle_button.add_theme_color_override("font_hover_color", Color.WHITE)
	start_battle_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	start_battle_button.add_theme_color_override("font_disabled_color", Color.GRAY)
	start_battle_button.add_theme_font_size_override("font_size", 16)  # 增大字体
	
	# 连接按钮信号
	start_battle_button.pressed.connect(_on_start_battle_button_pressed)
	
	button_container.add_child(start_battle_button)
	
	print("✅ [BattleUIManager] 开始战斗按钮已创建，位置: %s" % start_battle_button.position)

# 🚀 开始战斗按钮点击处理
func _on_start_battle_button_pressed() -> void:
	print("🎮 [BattleUIManager] 战斗按钮被点击")
	battle_button_pressed.emit()

# 🚀 更新开始战斗按钮状态
func update_battle_button_state(is_battle_in_progress: bool) -> void:
	var button = battle_ui.get_node_or_null("BattleControlContainer/StartBattleButton")
	if not button:
		return
	
	if is_battle_in_progress:
		button.disabled = true
		button.text = "战斗中..."
	else:
		button.disabled = false
		button.text = "开始战斗"

# 获取UI容器（供其他组件使用）
func get_ui_container() -> Control:
	return battle_ui

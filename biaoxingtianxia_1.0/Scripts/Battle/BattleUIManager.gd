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
var mouse_coordinate_label: Label  # 鼠标坐标显示标签

# 初始化
func _ready() -> void:
	name = "BattleUIManager"
	print("✅ [BattleUIManager] 战斗UI管理器初始化")
	_setup_battle_ui()
	# 延迟连接战斗管理器信号
	call_deferred("_connect_battle_signals")

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
	
	# 🚀 添加鼠标坐标显示
	_setup_mouse_coordinate_display()
	
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
	print("\n=== 🔥 [BattleUIManager] 战斗按钮被点击！===")
	print("🎮 [BattleUIManager] 战斗按钮被点击")
	battle_button_pressed.emit()
	print("🚀 [BattleUIManager] battle_button_pressed信号已发射")

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

# 🚀 设置鼠标坐标显示
func _setup_mouse_coordinate_display() -> void:
	# 创建坐标显示面板
	var coord_panel = Panel.new()
	coord_panel.name = "MouseCoordinatePanel"
	coord_panel.custom_minimum_size = Vector2(200, 60)
	
	# 定位到右上角
	var viewport_size = get_viewport().get_visible_rect().size
	coord_panel.position = Vector2(viewport_size.x - 220, 20)
	
	# 设置面板样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # 深色半透明背景
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.6, 0.6, 1.0)  # 灰色边框
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6
	coord_panel.add_theme_stylebox_override("panel", style_box)
	
	battle_ui.add_child(coord_panel)
	
	# 添加边距容器
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	coord_panel.add_child(margin)
	
	# 创建垂直布局容器
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	# 创建标题标签
	var title_label = Label.new()
	title_label.text = "鼠标坐标"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 创建坐标标签
	mouse_coordinate_label = Label.new()
	mouse_coordinate_label.name = "MouseCoordinateLabel"
	mouse_coordinate_label.text = "X: 0, Y: 0"
	mouse_coordinate_label.add_theme_font_size_override("font_size", 16)
	mouse_coordinate_label.add_theme_color_override("font_color", Color.WHITE)
	mouse_coordinate_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	mouse_coordinate_label.add_theme_constant_override("shadow_offset_x", 1)
	mouse_coordinate_label.add_theme_constant_override("shadow_offset_y", 1)
	mouse_coordinate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mouse_coordinate_label)
	
	print("✅ [BattleUIManager] 鼠标坐标显示组件已创建")

# 🚀 实时更新鼠标坐标
func _process(_delta: float) -> void:
	if mouse_coordinate_label and mouse_coordinate_label.is_inside_tree():
		var mouse_pos = get_global_mouse_position()
		mouse_coordinate_label.text = "X: %.0f, Y: %.0f" % [mouse_pos.x, mouse_pos.y]

# 🚀 连接战斗管理器信号（简化版，避免重试循环）
func _connect_battle_signals() -> void:
	print("🔍 [BattleUIManager] 尝试连接战斗管理器信号...")
	# 尝试通过实际场景实例查找BattleManager
	var battle_scene = get_tree().current_scene.get_node_or_null("战斗场景")
	if not battle_scene:
		battle_scene = AutoLoad.get_battle_scene()
	if not battle_scene:
		print("⚠️ [BattleUIManager] BattleScene不可用，跳过信号连接")
		return
	
	var battle_manager = battle_scene.get_node_or_null("BattleManager")
	if battle_manager:
		print("✅ [BattleUIManager] 找到BattleManager，开始连接信号")
		if battle_manager.has_signal("battle_started"):
			if not battle_manager.battle_started.is_connected(_on_battle_started):
				battle_manager.battle_started.connect(_on_battle_started)
				print("✅ [BattleUIManager] 已连接battle_started信号")
		if battle_manager.has_signal("turn_started"):
			if not battle_manager.turn_started.is_connected(_on_turn_started):
				battle_manager.turn_started.connect(_on_turn_started)
				print("✅ [BattleUIManager] 已连接turn_started信号")
		if battle_manager.has_signal("player_turn_started"):
			if not battle_manager.player_turn_started.is_connected(_on_player_turn_started):
				battle_manager.player_turn_started.connect(_on_player_turn_started)
				print("✅ [BattleUIManager] 已连接player_turn_started信号")
		if battle_manager.has_signal("ai_turn_started"):
			if not battle_manager.ai_turn_started.is_connected(_on_ai_turn_started):
				battle_manager.ai_turn_started.connect(_on_ai_turn_started)
				print("✅ [BattleUIManager] 已连接ai_turn_started信号")
		if battle_manager.has_signal("battle_ended"):
			if not battle_manager.battle_ended.is_connected(_on_battle_ended):
				battle_manager.battle_ended.connect(_on_battle_ended)
				print("✅ [BattleUIManager] 已连接battle_ended信号")
		print("✅ [BattleUIManager] 所有信号连接完成")
	else:
		print("⚠️ [BattleUIManager] 无法找到BattleManager，这是正常的（可能BattleManager还未初始化）")

# 🚀 战斗开始处理
func _on_battle_started() -> void:
	print("📢 [BattleUIManager] 收到战斗开始信号")
	update_battle_ui("战斗开始", "准备进入战斗状态...", "battle_start")
	update_battle_button_state(true)

# 🚀 回合开始处理
func _on_turn_started(turn_number: int) -> void:
	print("📢 [BattleUIManager] 收到回合开始信号: 回合%d" % turn_number)
	# 只更新回合数，不清空当前角色信息
	if turn_label:
		turn_label.text = "回合 %d" % turn_number
		_animate_ui_update(turn_label)
	# 不调用update_battle_ui，避免清空current_character_label

# 🚀 玩家回合开始处理
func _on_player_turn_started(character) -> void:
	print("📢 [BattleUIManager] 收到玩家回合开始信号: %s" % character.name)
	print("🔧 [BattleUIManager] 更新UI显示当前角色: %s" % character.name)
	# 直接更新当前角色标签，确保信息显示
	if current_character_label:
		current_character_label.text = "当前角色: %s" % character.name
		_animate_ui_update(current_character_label)
		print("✅ [BattleUIManager] 角色标签已更新: %s" % current_character_label.text)

# 🚀 AI回合开始处理
func _on_ai_turn_started(character) -> void:
	print("📢 [BattleUIManager] 收到AI回合开始信号: %s" % character.name)
	print("🔧 [BattleUIManager] 更新UI显示AI角色: %s" % character.name)
	# 直接更新当前角色标签，确保信息显示
	if current_character_label:
		current_character_label.text = "敌方行动: %s" % character.name
		_animate_ui_update(current_character_label)
		print("✅ [BattleUIManager] AI角色标签已更新: %s" % current_character_label.text)

# 🚀 战斗结束处理
func _on_battle_ended(result) -> void:
	print("📢 [BattleUIManager] 收到战斗结束信号: %s" % result)
	if result is Dictionary:
		var winner = result.get("winner", "unknown")
		match winner:
			"player":
				update_battle_ui("战斗胜利！", "恭喜取得胜利", "battle_end")
			"enemy":
				update_battle_ui("战斗失败", "战斗已失败", "battle_end")
			_:
				update_battle_ui("战斗结束", "战斗已结束", "battle_end")
	else:
		update_battle_ui("战斗结束", "战斗已结束", "battle_end")
	update_battle_button_state(false)

# 🚀 强制更新战斗状态显示（用于战斗开始时调用）
func force_update_battle_status() -> void:
	print("🔧 [BattleUIManager] 强制更新战斗状态显示")
	# 只更新回合信息，不覆盖角色信息
	if turn_label:
		turn_label.text = "战斗进行中"
		_animate_ui_update(turn_label)
	update_battle_button_state(true)

# 获取UI容器（供其他组件使用）
func get_ui_container() -> Control:
	return battle_ui

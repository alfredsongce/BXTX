# UIManager.gd - 战斗场景UI管理器
extends Node2D

# UI组件引用
var battle_ui: Control = null
var turn_label: Label = null
var current_character_label: Label = null

# 技能选择UI组件
# var skill_selection_menu: Control = null  # 已移除SkillSelectionMenu

# 目标选择UI组件  
var target_selection_menu: Control = null

# 技能范围显示组件
var skill_range_display: Node2D = null

# 可视化技能选择器
var visual_skill_selector: Node = null

# UI状态管理
var ui_update_timer: Timer = null
var last_ui_update_type: String = ""

# 信号
signal skill_selected(skill_id: String)
signal target_selected(targets: Array)
signal skill_menu_closed()
signal target_menu_closed()
signal visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array)
signal visual_skill_selection_cancelled()

func _ready():
	print("✅ [UIManager] UI管理器初始化开始")
	
	# 初始化各个UI组件
	_setup_battle_ui()
	# _setup_skill_selection_menu()  # 已移除SkillSelectionMenu
	_setup_target_selection_menu()
	_setup_skill_range_display()
	_setup_visual_skill_selector()
	_setup_battle_control_button()
	
	print("✅ [UIManager] UI管理器初始化完成")

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
	
	print("✅ [UIManager] 战斗UI初始化完成")

# 初始化技能选择菜单 - 已移除SkillSelectionMenu
# func _setup_skill_selection_menu() -> void:
#	# 加载技能选择菜单场景
#	var skill_menu_scene = preload("res://UI/SkillSelectionMenu.tscn")
#	skill_selection_menu = skill_menu_scene.instantiate()
#	
#	# 添加到UI容器
#	battle_ui.add_child(skill_selection_menu)
#	
#	# 连接信号
#	skill_selection_menu.skill_selected.connect(_on_skill_selected)
#	skill_selection_menu.menu_closed.connect(_on_skill_menu_closed)
#	
#	print("✅ [UIManager] 技能选择菜单初始化完成")

# 初始化目标选择菜单
func _setup_target_selection_menu() -> void:
	# 加载目标选择菜单场景
	var target_menu_scene = preload("res://UI/TargetSelectionMenu.tscn")
	target_selection_menu = target_menu_scene.instantiate()
	
	# 添加到UI容器
	battle_ui.add_child(target_selection_menu)
	
	# 连接信号
	target_selection_menu.target_selected.connect(_on_target_selected)
	target_selection_menu.menu_closed.connect(_on_target_menu_closed)
	
	print("✅ [UIManager] 目标选择菜单初始化完成")

# 🚀 初始化技能范围显示组件
func _setup_skill_range_display() -> void:
	# 🚀 第一阶段：使用Scripts/SkillRangeDisplay.gd创建范围显示组件
	var SkillRangeDisplayScript = preload("res://Scripts/SkillRangeDisplay.gd")
	skill_range_display = SkillRangeDisplayScript.new()
	
	# 添加到UI容器
	battle_ui.add_child(skill_range_display)
	
	print("✅ [UIManager] 技能范围显示组件初始化完成")

# 🚀 初始化可视化技能选择器
func _setup_visual_skill_selector() -> void:
	# 加载可视化技能选择器脚本
	var VisualSkillSelector = load("res://UI/VisualSkillSelector.gd")
	visual_skill_selector = VisualSkillSelector.new()
	
	# 连接信号
	visual_skill_selector.skill_cast_completed.connect(_on_visual_skill_cast_completed)
	visual_skill_selector.skill_selection_cancelled.connect(_on_visual_skill_selection_cancelled)
	
	# 添加到UI容器
	battle_ui.add_child(visual_skill_selector)
	
	print("✅ [UIManager] 可视化技能选择器初始化完成")

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
	
	print("✅ [UIManager] 开始战斗按钮已创建，位置: %s" % start_battle_button.position)

# ===========================================
# UI 更新方法
# ===========================================

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
		_restore_current_turn_ui()
	
	# 清理计时器
	if ui_update_timer:
		ui_update_timer.queue_free()
		ui_update_timer = null

# 🚀 恢复当前回合UI信息
func _restore_current_turn_ui() -> void:
	# 这个方法需要从BattleManager获取当前回合信息
	# 暂时先发出信号，让BattleScene处理
	pass

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
	print("🔍 战斗UI显示: %s" % ("开启" if battle_ui.visible else "关闭"))

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

# ===========================================
# 显示UI菜单的方法
# ===========================================

# 显示技能选择菜单 - 已移除SkillSelectionMenu
# func show_skill_selection_menu(character: GameCharacter, available_skills: Array) -> void:
#	if not skill_selection_menu:
#		print("⚠️ [UIManager] 技能选择菜单未初始化")
#		return
#	
#	print("🎯 [UIManager] 显示技能选择菜单，角色: %s，技能数量: %d" % [character.name, available_skills.size()])
#	skill_selection_menu.open_menu(character, available_skills)

# 显示目标选择菜单
func show_target_selection_menu(skill: SkillData, caster: GameCharacter, available_targets: Array) -> void:
	if not target_selection_menu:
		print("⚠️ [UIManager] 目标选择菜单未初始化")
		return
	
	print("🎯 [UIManager] 显示目标选择菜单，技能: %s，目标数量: %d" % [skill.name, available_targets.size()])
	target_selection_menu.open_menu(skill, caster, available_targets)

# 🚀 显示可视化技能选择界面
func show_visual_skill_selection(character: GameCharacter, available_skills: Array) -> void:
	if not visual_skill_selector:
		print("⚠️ [UIManager] 可视化技能选择器未初始化")
		return
	
	print("🎯 [UIManager] 显示技能选择界面，角色: %s，技能数量: %d" % [character.name, available_skills.size()])
	
	# 🚀 修复：技能选择开始时，更新UI为技能选择状态
	update_battle_ui("技能选择", "为 %s 选择技能..." % character.name, "skill_action")
	
	visual_skill_selector.start_skill_selection(character, available_skills)

# ===========================================
# 信号处理方法
# ===========================================

# 技能选择回调 - 已移除SkillSelectionMenu
# func _on_skill_selected(skill_id: String) -> void:
#	print("🎯 [UIManager] 玩家选择技能: %s" % skill_id)
#	skill_selected.emit(skill_id)

# 技能菜单关闭回调 - 已移除SkillSelectionMenu
# func _on_skill_menu_closed() -> void:
#	print("❌ [UIManager] 技能选择菜单关闭")
#	skill_menu_closed.emit()

# 目标选择回调
func _on_target_selected(targets: Array) -> void:
	print("🎯 [UIManager] 玩家选择目标: %d 个" % targets.size())
	target_selected.emit(targets)

# 目标菜单关闭回调
func _on_target_menu_closed() -> void:
	print("❌ [UIManager] 目标选择菜单关闭")
	target_menu_closed.emit()

# 🚀 可视化技能选择器信号处理
func _on_visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("✅ [UIManager] 技能释放完成: %s，施法者: %s，目标数量: %d" % [skill.name, caster.name, targets.size()])
	visual_skill_cast_completed.emit(skill, caster, targets)

func _on_visual_skill_selection_cancelled() -> void:
	print("❌ [UIManager] 技能选择被取消")
	visual_skill_selection_cancelled.emit()

# 🚀 开始战斗按钮点击处理
func _on_start_battle_button_pressed() -> void:
	print("\n=== 🔥 [UIManager] 开始战斗按钮被点击！===")
	print("🎮 [UIManager] 开始战斗按钮被点击")
	# 发出信号给BattleScene处理
	get_parent().emit_signal("start_battle_requested")
	print("🚀 [UIManager] start_battle_requested信号已发射")
extends Control
class_name VisualSkillSelector

# 🎯 可视化技能选择器
# 结合技能列表选择和可视化释放功能

signal skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array)
signal skill_selection_cancelled()

# UI状态
enum SelectorState {
	CLOSED,              # 关闭状态
	SELECTING_SKILL,     # 选择技能中
	CASTING_SKILL        # 释放技能中
}

var current_state: SelectorState = SelectorState.CLOSED
var current_character: GameCharacter = null
var available_skills: Array = []

# UI组件
var skill_list_panel: Panel = null
var visual_caster: Node2D = null
var skill_info_panel: Panel = null  # 🚀 新增：技能信息面板
var skill_detail_label: RichTextLabel = null  # 🚀 新增：技能详情标签

# 技能按钮样式配置
const BUTTON_SIZE = Vector2(300, 50)
const BUTTON_SPACING = 8
const PANEL_PADDING = 20
const INFO_PANEL_WIDTH = 350  # 🚀 新增：信息面板宽度

func _ready():
	# 初始化组件
	_setup_ui_components()
	
	# 默认隐藏
	visible = false
	
	print("🎯 [可视化技能选择器] VisualSkillSelector初始化完成")

# 🚀 开始技能选择流程
func start_skill_selection(character: GameCharacter, skills: Array) -> void:
	print("🔍 [可视化技能选择器] 尝试开始技能选择 - 当前状态: %s" % SelectorState.keys()[current_state])
	
	if current_state != SelectorState.CLOSED:
		print("⚠️ [可视化技能选择器] 选择器正忙，当前状态: %s" % SelectorState.keys()[current_state])
		return
	
	current_character = character
	available_skills = skills
	current_state = SelectorState.SELECTING_SKILL
	
	print("🎯 [可视化技能选择器] 开始技能选择，角色: %s，技能数量: %d" % [character.name, skills.size()])
	
	# 显示技能列表
	_show_skill_list()
	
	visible = true

# 🚪 关闭选择器
func close_selector(emit_cancel_signal: bool = true) -> void:
	print("🔧 [调试] close_selector被调用 - emit_cancel_signal: %s" % emit_cancel_signal)
	print("🔧 [调试] 调用堆栈: %s" % str(get_stack()))
	
	# 🚀 防护：如果正在从技能释放模式返回，忽略关闭请求
	if has_meta("returning_from_casting"):
		print("🔙 [可视化技能选择器] 检测到正在从技能释放返回，忽略关闭请求")
		return
	
	print("🔧 [可视化技能选择器] 关闭选择器 - 当前状态: %s，是否发出取消信号: %s" % [SelectorState.keys()[current_state], emit_cancel_signal])
	print("🔧 [调试] 当前角色: %s, 可见性: %s" % [(current_character.name if current_character else "null"), visible])
	
	# 根据当前状态进行清理
	match current_state:
		SelectorState.SELECTING_SKILL:
			print("🔧 [调试] 从技能选择状态关闭")
			_hide_skill_list()
		SelectorState.CASTING_SKILL:
			print("🔧 [调试] 从技能释放状态关闭")
			# 🚀 修复：只在需要时取消技能释放，避免信号循环
			if visual_caster and visual_caster.current_state != visual_caster.CastingState.INACTIVE:
				print("🔧 [可视化技能选择器] 强制取消进行中的技能释放")
				visual_caster.cancel_skill_casting()
		SelectorState.CLOSED:
			print("🔧 [调试] 选择器已经是关闭状态")
	
	# 重置状态
	var old_state = current_state
	current_state = SelectorState.CLOSED
	current_character = null
	available_skills.clear()
	
	visible = false
	
	print("✅ [可视化技能选择器] 选择器已重置为CLOSED状态 (从 %s)" % SelectorState.keys()[old_state])
	
	# 🚀 只在需要时发出取消信号
	if emit_cancel_signal:
		print("📡 [调试] 发出skill_selection_cancelled信号")
		skill_selection_cancelled.emit()
	else:
		print("📡 [调试] 跳过发出取消信号")

# 🎨 设置UI组件
func _setup_ui_components() -> void:
	# 创建技能列表面板
	_create_skill_list_panel()
	
	# 创建可视化技能释放器
	_create_visual_caster()

# 🎨 创建技能列表面板
func _create_skill_list_panel() -> void:
	# 创建主容器（水平布局）
	var main_container = Control.new()
	main_container.name = "SkillSelectionContainer"
	add_child(main_container)
	
	# 🚀 创建技能列表面板
	skill_list_panel = Panel.new()
	skill_list_panel.name = "SkillListPanel"
	
	# 设置面板样式
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.6, 1.0, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	skill_list_panel.add_theme_stylebox_override("panel", panel_style)
	
	main_container.add_child(skill_list_panel)
	
	# 🚀 创建技能信息面板
	_create_skill_info_panel(main_container)
	
	skill_list_panel.visible = false

# 🎨 创建可视化技能释放器
func _create_visual_caster() -> void:
	# 动态加载VisualSkillCaster类
	var VisualSkillCaster = load("res://Scripts/VisualSkillCaster.gd")
	visual_caster = VisualSkillCaster.new()
	
	# 连接信号
	visual_caster.skill_cast_requested.connect(_on_skill_cast_requested)
	visual_caster.skill_casting_cancelled.connect(_on_skill_casting_cancelled)
	
	add_child(visual_caster)

# 🎨 显示技能列表
func _show_skill_list() -> void:
	if not skill_list_panel:
		return
	
	# 🚀 重新构建技能列表内容
	# 清除技能列表面板的所有子节点
	for child in skill_list_panel.get_children():
		child.queue_free()
	
	# 创建垂直布局容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", BUTTON_SPACING)
	skill_list_panel.add_child(vbox)
	
	# 添加边距
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	vbox.add_child(margin)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", BUTTON_SPACING)
	margin.add_child(inner_vbox)
	
	# 添加标题
	var title_label = Label.new()
	title_label.text = "选择技能"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	inner_vbox.add_child(title_label)
	
	# 添加分隔线
	var separator = HSeparator.new()
	inner_vbox.add_child(separator)
	
	# 创建技能按钮
	for skill in available_skills:
		var button = _create_skill_button(skill)
		inner_vbox.add_child(button)
	
	# 添加取消按钮
	var cancel_button = _create_cancel_button()
	inner_vbox.add_child(cancel_button)
	
	# 调整面板大小和位置
	_adjust_panel_layout()
	
	# 显示面板
	skill_list_panel.visible = true
	skill_info_panel.visible = true

# 🎨 隐藏技能列表
func _hide_skill_list() -> void:
	if skill_list_panel:
		skill_list_panel.visible = false
	if skill_info_panel:  # 🚀 新增：同时隐藏信息面板
		skill_info_panel.visible = false

# 🎨 创建技能按钮
func _create_skill_button(skill: SkillData) -> Button:
	var button = Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	
	# 检查技能是否可用
	var can_use = skill.can_use(current_character)
	button.disabled = not can_use
	
	# 设置按钮文本和样式
	if can_use:
		button.text = "%s (MP:%d)" % [skill.name, skill.mp_cost]
		button.add_theme_color_override("font_color", Color.WHITE)
		
		# 可用技能的样式
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color(0.2, 0.4, 0.8, 0.8)  # 蓝色背景
		button_style.border_width_left = 1
		button_style.border_width_right = 1
		button_style.border_width_top = 1
		button_style.border_width_bottom = 1
		button_style.border_color = Color(0.4, 0.6, 1.0, 1.0)
		button_style.corner_radius_top_left = 5
		button_style.corner_radius_top_right = 5
		button_style.corner_radius_bottom_left = 5
		button_style.corner_radius_bottom_right = 5
		button.add_theme_stylebox_override("normal", button_style)
		
		# 悬停样式
		var hover_style = button_style.duplicate()
		hover_style.bg_color = Color(0.3, 0.5, 0.9, 0.9)
		button.add_theme_stylebox_override("hover", hover_style)
		
	else:
		# 不可用技能
		var reason = _get_unusable_reason(skill)
		button.text = "%s (%s)" % [skill.name, reason]
		button.add_theme_color_override("font_color", Color.GRAY)
		
		# 不可用技能的样式
		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.6)
		disabled_style.border_width_left = 1
		disabled_style.border_width_right = 1
		disabled_style.border_width_top = 1
		disabled_style.border_width_bottom = 1
		disabled_style.border_color = Color(0.5, 0.5, 0.5, 0.8)
		disabled_style.corner_radius_top_left = 5
		disabled_style.corner_radius_top_right = 5
		disabled_style.corner_radius_bottom_left = 5
		disabled_style.corner_radius_bottom_right = 5
		button.add_theme_stylebox_override("disabled", disabled_style)
	
	# 连接按钮信号
	button.pressed.connect(_on_skill_button_pressed.bind(skill))
	button.mouse_entered.connect(_on_skill_button_hovered.bind(skill))  # 🚀 新增：悬停事件
	
	return button

# 🎨 创建取消按钮
func _create_cancel_button() -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(BUTTON_SIZE.x, 40)
	button.text = "取消"
	button.add_theme_color_override("font_color", Color.WHITE)
	
	# 取消按钮样式
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.8, 0.2, 0.2, 0.8)  # 红色背景
	cancel_style.border_width_left = 1
	cancel_style.border_width_right = 1
	cancel_style.border_width_top = 1
	cancel_style.border_width_bottom = 1
	cancel_style.border_color = Color(1.0, 0.4, 0.4, 1.0)
	cancel_style.corner_radius_top_left = 5
	cancel_style.corner_radius_top_right = 5
	cancel_style.corner_radius_bottom_left = 5
	cancel_style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", cancel_style)
	
	# 悬停样式
	var hover_style = cancel_style.duplicate()
	hover_style.bg_color = Color(0.9, 0.3, 0.3, 0.9)
	button.add_theme_stylebox_override("hover", hover_style)
	
	# 连接信号
	button.pressed.connect(_on_cancel_button_pressed)
	
	return button

# 🎨 调整面板布局
func _adjust_panel_layout() -> void:
	if not skill_list_panel or not skill_info_panel:
		return
	
	# 获取视口大小
	var viewport_size = get_viewport_rect().size
	
	# 计算技能列表面板大小
	var list_panel_width = BUTTON_SIZE.x + PANEL_PADDING * 2
	var button_count = available_skills.size() + 1  # 技能按钮 + 取消按钮
	var list_panel_height = 80 + button_count * (BUTTON_SIZE.y + BUTTON_SPACING) + PANEL_PADDING * 2  # 标题 + 按钮 + 边距
	
	# 计算信息面板大小
	var info_panel_width = INFO_PANEL_WIDTH
	var info_panel_height = list_panel_height  # 与技能列表面板同高
	
	# 计算总宽度和间距
	var total_width = list_panel_width + info_panel_width + 20  # 20像素间距
	var start_x = (viewport_size.x - total_width) / 2
	var start_y = (viewport_size.y - list_panel_height) / 2
	
	# 🚀 设置技能列表面板位置和大小
	skill_list_panel.position = Vector2(start_x, start_y)
	skill_list_panel.size = Vector2(list_panel_width, list_panel_height)
	
	# 🚀 设置信息面板位置和大小
	skill_info_panel.position = Vector2(start_x + list_panel_width + 20, start_y)
	skill_info_panel.size = Vector2(info_panel_width, info_panel_height)

# 📝 获取技能不可用的原因
func _get_unusable_reason(skill: SkillData) -> String:
	if current_character.current_mp < skill.mp_cost:
		return "MP不足"
	# 这里可以添加其他检查，如冷却时间等
	return "不可用"

# 🎯 技能按钮点击处理
func _on_skill_button_pressed(skill: SkillData) -> void:
	print("🔧 [调试] 技能按钮被点击 - 技能: %s" % skill.name)
	print("🔧 [调试] 当前角色: %s" % (current_character.name if current_character else "null"))
	print("🔧 [调试] visual_caster存在: %s" % (visual_caster != null))
	
	if not skill.can_use(current_character):
		print("⚠️ [可视化技能选择器] 技能不可用: %s" % skill.name)
		return
	
	print("🎯 [可视化技能选择器] 选择技能: %s，切换到可视化释放模式" % skill.name)
	
	# 隐藏技能列表
	_hide_skill_list()
	
	# 切换到技能释放状态
	current_state = SelectorState.CASTING_SKILL
	
	# 启动可视化技能释放
	if visual_caster:
		print("🔧 [调试] 调用visual_caster.start_skill_casting")
		visual_caster.start_skill_casting(skill, current_character)
	else:
		print("❌ [错误] visual_caster为null，无法启动技能释放")

# 🎯 取消按钮点击处理
func _on_cancel_button_pressed() -> void:
	print("🔙 [可视化技能选择器] 用户点击取消按钮")
	# 🚀 关闭选择器，但标记为用户主动取消，应该返回行动菜单
	close_selector(true)

# 🎯 技能释放请求处理
func _on_skill_cast_requested(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("✅ [可视化技能选择器] 技能释放请求: %s，目标数量: %d" % [skill.name, targets.size()])
	print("🔧 [调试] 当前状态: %s" % SelectorState.keys()[current_state])
	print("🔧 [调试] 即将发出skill_cast_completed信号")
	
	# 发出技能释放完成信号
	print("📡 [调试] 发出skill_cast_completed信号")
	skill_cast_completed.emit(skill, caster, targets)
	print("🔧 [调试] skill_cast_completed信号已发出")
	
	# 🚀 修复：延迟关闭选择器，避免立即取消技能
	print("🔧 [调试] 设置延迟关闭选择器")
	get_tree().create_timer(0.1).timeout.connect(func(): 
		print("🔧 [调试] 延迟关闭选择器被触发")
		close_selector(false)
	)

# 🎯 技能释放取消处理
func _on_skill_casting_cancelled() -> void:
	print("❌ [可视化技能选择器] 技能释放被取消，当前状态: %s" % SelectorState.keys()[current_state])
	print("🔧 [调试] 当前角色: %s, 可见性: %s" % [(current_character.name if current_character else "null"), visible])
	
	# 只在技能释放状态下才处理取消
	if current_state != SelectorState.CASTING_SKILL:
		print("⚠️ [可视化技能选择器] 状态不匹配，忽略技能释放取消事件")
		return
	
	print("🔙 [可视化技能选择器] 从技能释放模式返回技能选择模式")
	
	# 从释放模式返回选择模式
	current_state = SelectorState.SELECTING_SKILL
	print("🔧 [调试] 状态已切换到: %s" % SelectorState.keys()[current_state])
	
	# 🚀 使用call_deferred延迟执行，避免在同一帧内被其他逻辑打断
	print("🔧 [调试] 延迟显示技能列表")
	call_deferred("_show_skill_list")
	
	# 🚀 添加标志，防止被立即关闭
	print("🔧 [调试] 设置returning_from_casting标志")
	set_meta("returning_from_casting", true)
	# 在下一帧清除标志
	call_deferred("remove_meta", "returning_from_casting")

# 🎮 输入处理
func _input(event):
	if not visible or current_state == SelectorState.CLOSED:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if current_state == SelectorState.SELECTING_SKILL:
					close_selector()
				elif current_state == SelectorState.CASTING_SKILL:
					# ESC键在释放模式下：只取消技能释放，不关闭整个选择器
					print("🔙 [可视化技能选择器] ESC键：从技能释放模式返回技能选择模式")
					if visual_caster:
						# 直接取消技能释放（会触发skill_casting_cancelled信号）
						visual_caster.cancel_skill_casting()
					# 不调用close_selector()，让信号处理来管理状态切换
			
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				if current_state == SelectorState.SELECTING_SKILL:
					# 数字键快速选择技能
					var skill_index = event.keycode - KEY_1
					if skill_index < available_skills.size():
						var skill = available_skills[skill_index]
						if skill.can_use(current_character):
							_on_skill_button_pressed(skill)

# 🚀 创建技能信息面板
func _create_skill_info_panel(parent_container: Control) -> void:
	skill_info_panel = Panel.new()
	skill_info_panel.name = "SkillInfoPanel"
	
	# 设置信息面板样式
	var info_panel_style = StyleBoxFlat.new()
	info_panel_style.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	info_panel_style.border_width_left = 2
	info_panel_style.border_width_right = 2
	info_panel_style.border_width_top = 2
	info_panel_style.border_width_bottom = 2
	info_panel_style.border_color = Color(0.6, 0.8, 1.0, 1.0)
	info_panel_style.corner_radius_top_left = 8
	info_panel_style.corner_radius_top_right = 8
	info_panel_style.corner_radius_bottom_left = 8
	info_panel_style.corner_radius_bottom_right = 8
	skill_info_panel.add_theme_stylebox_override("panel", info_panel_style)
	
	parent_container.add_child(skill_info_panel)
	
	# 创建信息面板内容
	var info_vbox = VBoxContainer.new()
	info_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_vbox.add_theme_constant_override("separation", 8)
	skill_info_panel.add_child(info_vbox)
	
	# 添加边距
	var info_margin = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 15)
	info_margin.add_theme_constant_override("margin_right", 15)
	info_margin.add_theme_constant_override("margin_top", 15)
	info_margin.add_theme_constant_override("margin_bottom", 15)
	info_vbox.add_child(info_margin)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 10)
	info_margin.add_child(inner_vbox)
	
	# 信息标题
	var info_title = Label.new()
	info_title.text = "技能信息"
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 16)
	info_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	inner_vbox.add_child(info_title)
	
	# 分隔线
	var info_separator = HSeparator.new()
	inner_vbox.add_child(info_separator)
	
	# 技能详情标签
	skill_detail_label = RichTextLabel.new()
	skill_detail_label.custom_minimum_size = Vector2(INFO_PANEL_WIDTH - 30, 200)
	skill_detail_label.bbcode_enabled = true
	skill_detail_label.scroll_active = false
	skill_detail_label.fit_content = true
	skill_detail_label.add_theme_font_size_override("normal_font_size", 12)
	skill_detail_label.add_theme_color_override("default_color", Color.WHITE)
	skill_detail_label.text = "选择一个技能查看详情..."
	inner_vbox.add_child(skill_detail_label)
	
	skill_info_panel.visible = false

# 🎯 技能按钮悬停处理
func _on_skill_button_hovered(skill: SkillData) -> void:
	_update_skill_info(skill)

# 🎯 更新技能信息显示
func _update_skill_info(skill: SkillData) -> void:
	if not skill_detail_label:
		return
	
	# 构建技能详情文本
	var info_text = ""
	
	# 技能名称（高亮显示）
	info_text += "[color=#4da6ff][b]%s[/b][/color]\n\n" % skill.name
	
	# 技能描述
	info_text += "[color=#ffffff]%s[/color]\n\n" % skill.description
	
	# 技能属性
	info_text += "[color=#ffcc66][b]技能属性[/b][/color]\n"
	info_text += "• MP消耗: [color=#66ccff]%d[/color]\n" % skill.mp_cost
	info_text += "• 冷却时间: [color=#66ccff]%.1f 秒[/color]\n" % skill.cooldown
	info_text += "• 释放时间: [color=#66ccff]%.1f 秒[/color]\n" % skill.cast_time
	info_text += "• 施法距离: [color=#66ccff]%.0f[/color]\n" % skill.targeting_range
	
	# 目标类型
	var target_type_text = ""
	match skill.target_type:
		SkillEnums.TargetType.SELF:
			target_type_text = "自身"
		SkillEnums.TargetType.ENEMY:
			target_type_text = "敌方"
		SkillEnums.TargetType.ALLY:
			target_type_text = "友方"
		SkillEnums.TargetType.ALLYONLY:
			target_type_text = "队友（不包括自己）"
		SkillEnums.TargetType.ALL:
			target_type_text = "所有目标"
		_:
			target_type_text = "未知"
	
	info_text += "• 目标类型: [color=#66ccff]%s[/color]\n" % target_type_text
	
	# 范围类型
	if skill.range_type == SkillEnums.RangeType.RANGE:
		info_text += "• 效果范围: [color=#ff9966]%.0f 范围[/color]\n" % skill.range_distance
	else:
		info_text += "• 效果范围: [color=#ff9966]单体[/color]\n"
	
	# 基础伤害（如果有）
	if skill.base_damage > 0:
		info_text += "• 基础伤害: [color=#ff6666]%d[/color]\n" % skill.base_damage
	
	# 可用性检查
	info_text += "\n[color=#ffcc66][b]可用性[/b][/color]\n"
	if skill.can_use(current_character):
		info_text += "[color=#66ff66]✓ 可以使用[/color]"
	else:
		var reason = _get_unusable_reason(skill)
		info_text += "[color=#ff6666]✗ 无法使用: %s[/color]" % reason
	
	skill_detail_label.text = info_text

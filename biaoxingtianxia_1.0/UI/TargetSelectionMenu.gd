extends Panel

signal target_selected(targets: Array)
signal menu_closed()

var current_skill: SkillData = null
var current_caster: GameCharacter = null
var available_targets: Array = []
var target_buttons: Array = []

# UI组件引用
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var skill_info_label: Label = $VBoxContainer/SkillInfoLabel
@onready var target_list_container: VBoxContainer = $VBoxContainer/ScrollContainer/TargetListContainer
@onready var target_info_panel: Panel = $VBoxContainer/TargetInfoPanel
@onready var target_name_label: Label = $VBoxContainer/TargetInfoPanel/VBoxContainer/TargetNameLabel
@onready var target_hp_label: Label = $VBoxContainer/TargetInfoPanel/VBoxContainer/TargetHPLabel
@onready var target_mp_label: Label = $VBoxContainer/TargetInfoPanel/VBoxContainer/TargetMPLabel
@onready var target_status_label: Label = $VBoxContainer/TargetInfoPanel/VBoxContainer/TargetStatusLabel
@onready var cancel_button: Button = $VBoxContainer/CancelButton

func _ready():
	# 连接取消按钮
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# 默认隐藏菜单
	visible = false
	
	# 隐藏目标信息面板
	target_info_panel.visible = false

# 打开目标选择菜单
func open_menu(skill: SkillData, caster: GameCharacter, targets: Array):
	current_skill = skill
	current_caster = caster
	available_targets = targets
	
	# 🚀 设置标题和技能信息，包含技能类型信息
	var skill_type_text = ""
	match skill.targeting_type:
		SkillEnums.TargetingType.SELF:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				skill_type_text = " [自身范围]"
			else:
				skill_type_text = " [自身]"
		SkillEnums.TargetingType.NORMAL:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				skill_type_text = " [目标范围]"
			else:
				skill_type_text = " [单体]"
		SkillEnums.TargetingType.PROJECTILE_SINGLE:
			skill_type_text = " [弹道单点]"
		SkillEnums.TargetingType.PROJECTILE_PIERCE:
			skill_type_text = " [弹道穿刺]"
		SkillEnums.TargetingType.FREE:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				skill_type_text = " [自由范围]"
			else:
				skill_type_text = " [自由位置]"
	
	title_label.text = "选择目标" + skill_type_text
	skill_info_label.text = "%s 使用: %s" % [caster.name, skill.name]
	
	# 🚀 添加范围信息
	if skill.range_type == SkillEnums.RangeType.RANGE:
		skill_info_label.text += " (范围: %d像素)" % skill.range_distance
	
	# 清除之前的目标按钮
	_clear_target_buttons()
	
	# 创建目标按钮
	_create_target_buttons()
	
	# 显示菜单
	visible = true
	
	# 定位到屏幕中央
	_center_on_screen()
	
	print("🎯 [目标UI] 为技能 %s 打开目标选择菜单，可选目标: %d 个" % [skill.name, targets.size()])

# 关闭菜单
func close_menu():
	visible = false
	current_skill = null
	current_caster = null
	available_targets.clear()
	target_info_panel.visible = false
	_clear_target_buttons()
	menu_closed.emit()

# 清除目标按钮
func _clear_target_buttons():
	for button in target_buttons:
		if is_instance_valid(button):
			button.queue_free()
	target_buttons.clear()

# 创建目标按钮
func _create_target_buttons():
	for target in available_targets:
		var button = Button.new()
		button.custom_minimum_size = Vector2(250, 50)
		
		# 设置按钮文本和样式
		_setup_target_button(button, target)
		
		# 连接按钮信号
		button.pressed.connect(_on_target_button_pressed.bind(target))
		button.mouse_entered.connect(_on_target_button_hovered.bind(target))
		button.mouse_exited.connect(_on_target_button_unhovered)
		
		# 添加到容器
		target_list_container.add_child(button)
		target_buttons.append(button)

# 设置目标按钮的文本和样式
func _setup_target_button(button: Button, target: GameCharacter):
	# 基础信息
	var button_text = "%s (HP: %d/%d)" % [target.name, target.current_hp, target.max_hp]
	
	# 根据目标类型设置颜色
	var button_color = Color.WHITE
	var bg_color = Color(0.2, 0.2, 0.2, 0.8)
	
	if current_skill.target_type == SkillEnums.TargetType.ENEMY:
		# 敌人目标 - 红色系
		if not target.is_player_controlled():
			button_color = Color.LIGHT_CORAL
			bg_color = Color(0.4, 0.1, 0.1, 0.8)
		else:
			# 这不应该发生，但以防万一
			button_color = Color.GRAY
			button.disabled = true
	elif current_skill.target_type == SkillEnums.TargetType.ALLY or current_skill.target_type == SkillEnums.TargetType.SELF:
		# 友方目标 - 绿色系
		if target.is_player_controlled():
			button_color = Color.LIGHT_GREEN
			bg_color = Color(0.1, 0.4, 0.1, 0.8)
		else:
			# 这不应该发生，但以防万一
			button_color = Color.GRAY
			button.disabled = true
	
	# 检查目标是否存活
	if not target.is_alive():
		button_text += " (已阵亡)"
		button_color = Color.GRAY
		button.disabled = true
	
	button.text = button_text
	button.add_theme_color_override("font_color", button_color)
	
	# 设置背景样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = button_color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", style_box)

# 目标按钮点击事件
func _on_target_button_pressed(target: GameCharacter):
	if target.is_alive():
		# 🚀 根据技能类型显示不同的选择说明
		var selection_info = ""
		match current_skill.targeting_type:
			SkillEnums.TargetingType.PROJECTILE_PIERCE:
				selection_info = "选择弹道方向：向 %s 方向发射" % target.name
			SkillEnums.TargetingType.FREE:
				if current_skill.range_type == SkillEnums.RangeType.RANGE:
					selection_info = "选择释放位置：以 %s 位置为中心的范围攻击" % target.name
				else:
					selection_info = "选择释放位置：在 %s 位置释放" % target.name
			SkillEnums.TargetingType.NORMAL:
				if current_skill.range_type == SkillEnums.RangeType.RANGE:
					selection_info = "选择范围中心：以 %s 为中心的范围攻击" % target.name
				else:
					selection_info = "选择目标：%s" % target.name
			_:
				selection_info = "选择目标：%s" % target.name
		
		print("🎯 [目标UI] %s" % selection_info)
		
		# 🚀 根据技能范围类型决定选择单个还是多个目标
		var selected_targets = []
		if current_skill.range_type == SkillEnums.RangeType.SINGLE:
			selected_targets = [target]
		else:
			# 范围技能：选择的目标将作为中心点或方向参考
			selected_targets = [target]
		
		target_selected.emit(selected_targets)
		close_menu()
	else:
		print("⚠️ [目标UI] 目标已阵亡: %s" % target.name)

# 目标按钮悬停事件
func _on_target_button_hovered(target: GameCharacter):
	_show_target_info(target)

# 目标按钮离开事件
func _on_target_button_unhovered():
	target_info_panel.visible = false

# 显示目标信息
func _show_target_info(target: GameCharacter):
	target_name_label.text = target.name
	target_hp_label.text = "生命值: %d/%d" % [target.current_hp, target.max_hp]
	target_mp_label.text = "魔法值: %d/%d" % [target.current_mp, target.max_mp]
	
	# 显示状态
	var status_text = "状态: "
	if target.is_alive():
		status_text += "存活"
		if target.is_player_controlled():
			status_text += " (友方)"
		else:
			status_text += " (敌方)"
	else:
		status_text += "阵亡"
	
	target_status_label.text = status_text
	
	target_info_panel.visible = true

# 取消按钮事件
func _on_cancel_pressed():
	print("❌ [目标UI] 取消目标选择")
	close_menu()

# 将菜单居中显示
func _center_on_screen():
	var viewport_size = get_viewport_rect().size
	global_position = Vector2(
		(viewport_size.x - size.x) / 2,
		(viewport_size.y - size.y) / 2
	) 
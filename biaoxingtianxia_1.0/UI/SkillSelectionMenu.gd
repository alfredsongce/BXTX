extends Panel

signal skill_selected(skill_id: String)
signal menu_closed()

var current_character: GameCharacter = null
var available_skills: Array = []
var skill_buttons: Array = []

# UI组件引用
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var skill_list_container: VBoxContainer = $VBoxContainer/ScrollContainer/SkillListContainer
@onready var skill_info_panel: Panel = $VBoxContainer/SkillInfoPanel
@onready var skill_name_label: Label = $VBoxContainer/SkillInfoPanel/VBoxContainer/SkillNameLabel
@onready var skill_desc_label: Label = $VBoxContainer/SkillInfoPanel/VBoxContainer/SkillDescLabel
@onready var skill_cost_label: Label = $VBoxContainer/SkillInfoPanel/VBoxContainer/SkillCostLabel
@onready var skill_range_label: Label = $VBoxContainer/SkillInfoPanel/VBoxContainer/SkillRangeLabel
@onready var cancel_button: Button = $VBoxContainer/CancelButton

func _ready():
	# 连接取消按钮
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# 默认隐藏菜单
	visible = false
	
	# 隐藏技能信息面板
	skill_info_panel.visible = false

# 打开技能选择菜单
func open_menu(character: GameCharacter, skills: Array):
	current_character = character
	available_skills = skills
	
	# 设置标题
	title_label.text = "选择技能 - " + character.name
	
	# 清除之前的技能按钮
	_clear_skill_buttons()
	
	# 创建技能按钮
	_create_skill_buttons()
	
	# 显示菜单
	visible = true
	
	# 定位到屏幕中央
	_center_on_screen()
	
	print("🎯 [技能UI] 为 %s 打开技能选择菜单，可用技能: %d 个" % [character.name, skills.size()])

# 关闭菜单
func close_menu():
	visible = false
	current_character = null
	available_skills.clear()
	skill_info_panel.visible = false
	_clear_skill_buttons()
	menu_closed.emit()

# 清除技能按钮
func _clear_skill_buttons():
	for button in skill_buttons:
		if is_instance_valid(button):
			button.queue_free()
	skill_buttons.clear()

# 创建技能按钮
func _create_skill_buttons():
	for skill in available_skills:
		var button = Button.new()
		button.text = skill.name
		button.custom_minimum_size = Vector2(200, 40)
		
		# 检查技能是否可用
		var can_use = skill.can_use(current_character)
		button.disabled = not can_use
		
		# 设置按钮样式
		if can_use:
			button.add_theme_color_override("font_color", Color.WHITE)
		else:
			button.add_theme_color_override("font_color", Color.GRAY)
			# 添加不可用原因到按钮文本
			var reason = _get_unusable_reason(skill)
			button.text += " (" + reason + ")"
		
		# 连接按钮信号
		button.pressed.connect(_on_skill_button_pressed.bind(skill))
		button.mouse_entered.connect(_on_skill_button_hovered.bind(skill))
		button.mouse_exited.connect(_on_skill_button_unhovered)
		
		# 添加到容器
		skill_list_container.add_child(button)
		skill_buttons.append(button)

# 获取技能不可用的原因
func _get_unusable_reason(skill: SkillData) -> String:
	if current_character.current_mp < skill.mp_cost:
		return "MP不足"
	# 这里可以添加其他检查，如冷却时间等
	return "不可用"

# 技能按钮点击事件
func _on_skill_button_pressed(skill: SkillData):
	if skill.can_use(current_character):
		print("🎯 [技能UI] 选择技能: %s" % skill.name)
		skill_selected.emit(skill.id)
		close_menu()
	else:
		print("⚠️ [技能UI] 技能不可用: %s" % skill.name)

# 技能按钮悬停事件
func _on_skill_button_hovered(skill: SkillData):
	_show_skill_info(skill)

# 技能按钮离开事件
func _on_skill_button_unhovered():
	skill_info_panel.visible = false

# 显示技能信息
func _show_skill_info(skill: SkillData):
	skill_name_label.text = skill.name
	skill_desc_label.text = skill.description
	skill_cost_label.text = "MP消耗: %d" % skill.mp_cost
	skill_range_label.text = "攻击范围: %d像素" % skill.targeting_range
	
	skill_info_panel.visible = true

# 取消按钮事件
func _on_cancel_pressed():
	print("❌ [技能UI] 取消技能选择")
	close_menu()

# 将菜单居中显示
func _center_on_screen():
	var viewport_size = get_viewport_rect().size
	global_position = Vector2(
		(viewport_size.x - size.x) / 2,
		(viewport_size.y - size.y) / 2
	) 
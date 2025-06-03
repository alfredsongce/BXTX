extends Control
class_name SkillCastingHUD

# 🎯 技能释放时的HUD显示
# 显示当前技能信息、操作提示等

var skill_info_label: Label = null
var instruction_label: Label = null
var cancel_hint_label: Label = null

# 样式配置
const BACKGROUND_COLOR = Color(0.0, 0.0, 0.0, 0.85)
const TEXT_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const HIGHLIGHT_COLOR = Color(0.3, 0.8, 1.0, 1.0)

func _ready():
	# 设置布局
	_setup_layout()
	
	# 默认隐藏
	visible = false
	
	print("🎯 [技能释放HUD] SkillCastingHUD初始化完成")

# 🎨 设置布局
func _setup_layout() -> void:
	# 设置为全屏布局，但内容在顶部中央
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 创建背景面板
	var background_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = BACKGROUND_COLOR
	background_panel.add_theme_stylebox_override("panel", panel_style)
	
	# 🚀 简化：先设置一个默认位置和大小，具体位置由_ensure_correct_position调整
	background_panel.position = Vector2(100, 15)  # 临时位置
	background_panel.size = Vector2(640, 140)
	
	add_child(background_panel)
	
	# 创建垂直布局容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)  # 🚀 稍微增加间距
	background_panel.add_child(vbox)
	
	# 添加边距
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 25)  # 🚀 增加左右边距
	margin_container.add_theme_constant_override("margin_right", 25)
	margin_container.add_theme_constant_override("margin_top", 12)   # 🚀 增加上下边距
	margin_container.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(margin_container)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	margin_container.add_child(inner_vbox)
	
	# 技能信息标签
	skill_info_label = Label.new()
	skill_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_info_label.add_theme_font_size_override("font_size", 16)
	skill_info_label.add_theme_color_override("font_color", HIGHLIGHT_COLOR)
	inner_vbox.add_child(skill_info_label)
	
	# 操作指示标签
	instruction_label = Label.new()
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 14)
	instruction_label.add_theme_color_override("font_color", TEXT_COLOR)
	inner_vbox.add_child(instruction_label)
	
	# 取消提示标签
	cancel_hint_label = Label.new()
	cancel_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_hint_label.add_theme_font_size_override("font_size", 12)
	cancel_hint_label.add_theme_color_override("font_color", Color.GRAY)
	cancel_hint_label.text = "右键或ESC键取消"
	inner_vbox.add_child(cancel_hint_label)

# 🚀 显示技能释放HUD
func show_skill_casting(skill: SkillData, caster: GameCharacter) -> void:
	if not skill or not caster:
		return
	
	# 🚀 修复：在显示时重新确保位置正确
	call_deferred("_ensure_correct_position")
	
	# 设置技能信息
	skill_info_label.text = "%s 正在释放: %s" % [caster.name, skill.name]
	
	# 根据技能类型设置操作提示
	var instruction_text = ""
	match skill.targeting_type:
		SkillEnums.TargetingType.SELF:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				instruction_text = "左键点击任意位置释放自身范围技能"
			else:
				instruction_text = "左键点击任意位置释放自身技能"
		
		SkillEnums.TargetingType.NORMAL:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				instruction_text = "将鼠标悬停在目标上查看效果范围，左键点击释放"
			else:
				instruction_text = "左键点击蓝色范围内的目标释放技能"
		
		SkillEnums.TargetingType.PROJECTILE_SINGLE:
			instruction_text = "左键点击蓝色范围内的目标发射弹道"
		
		SkillEnums.TargetingType.PROJECTILE_PIERCE:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				instruction_text = "将鼠标悬停在目标上查看穿刺范围，左键点击释放"
			else:
				instruction_text = "左键点击目标发射穿刺弹道"
		
		SkillEnums.TargetingType.FREE:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				instruction_text = "将鼠标移动到蓝色范围内查看效果范围，左键点击释放"
			else:
				instruction_text = "左键点击蓝色范围内的任意位置释放技能"
		
		_:
			instruction_text = "左键点击合法目标释放技能"
	
	instruction_label.text = instruction_text
	
	# 显示HUD
	visible = true
	
	print("🎯 [技能释放HUD] 显示技能释放界面: %s" % skill.name)

# 🚀 确保位置正确的延迟方法
func _ensure_correct_position() -> void:
	# 获取第一个子节点（背景面板）
	if get_child_count() > 0:
		var background_panel = get_child(0)
		
		# 🚀 尝试使用更直接的定位方法
		var viewport_size = get_viewport().get_visible_rect().size
		var panel_width = 640
		var panel_height = 140
		
		# 直接设置位置为屏幕中央顶部
		background_panel.position.x = (viewport_size.x - panel_width) / 2
		background_panel.position.y = 15
		background_panel.size = Vector2(panel_width, panel_height)
		
		print("🔧 [技能释放HUD] 调整位置: x=%d, y=%d, 屏幕宽度=%d" % [background_panel.position.x, background_panel.position.y, viewport_size.x])

# 🚀 隐藏技能释放HUD
func hide_skill_casting() -> void:
	visible = false
	print("❌ [技能释放HUD] 隐藏技能释放界面") 

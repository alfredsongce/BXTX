extends Node2D
class_name VisualSkillCaster

# 🎯 可视化技能释放系统
# 支持鼠标指向式的技能选择和释放

# 信号定义
signal skill_cast_requested(skill: SkillData, caster: GameCharacter, targets: Array)
signal skill_casting_cancelled()

# 状态枚举
enum CastingState {
	INACTIVE,          # 未激活
	SHOWING_RANGE,     # 显示技能范围
	SELECTING_TARGET,  # 选择目标中
	CONFIRMING_CAST    # 确认释放
}

# 当前状态
var current_state: CastingState = CastingState.INACTIVE
var active_skill: SkillData = null
var active_caster: GameCharacter = null

# 视觉组件
var casting_range_circle: Node2D = null
var effect_range_preview: Node2D = null
var target_highlights: Array = []
var cursor_indicator: Node2D = null
var casting_hud: Control = null

# 颜色配置
const CASTING_RANGE_COLOR = Color(0.2, 0.8, 1.0, 0.3)  # 蓝色半透明 - 施法范围
const EFFECT_RANGE_COLOR = Color(1.0, 0.6, 0.0, 0.4)   # 橙色半透明 - 效果范围
const VALID_TARGET_COLOR = Color(0.0, 1.0, 0.0, 0.6)   # 绿色 - 合法目标
const INVALID_TARGET_COLOR = Color(1.0, 0.0, 0.0, 0.4) # 红色 - 非法目标
const CURSOR_COLOR = Color(1.0, 1.0, 1.0, 0.8)         # 白色 - 鼠标指示器

# 配置参数
const TARGET_HIGHLIGHT_RADIUS = 40.0
const CURSOR_INDICATOR_RADIUS = 20.0
const RANGE_CIRCLE_WIDTH = 4.0
const EFFECT_PREVIEW_WIDTH = 3.0

# 🧪 调试模式开关
var debug_mode_enabled: bool = false

# 鼠标跟踪
var mouse_world_position: Vector2
var hovered_target: GameCharacter = null
var valid_targets_in_range: Array = []

func _ready():
	# 添加到技能释放组
	add_to_group("visual_skill_caster")
	print("🎯 [可视化技能] VisualSkillCaster系统初始化完成")
	print("🎯 [可视化技能] 按F4键输出调试信息")
	
	# 设置输入处理
	set_process_input(true)
	set_process(true)

func _process(_delta):
	if current_state == CastingState.INACTIVE:
		return
	
	# 更新鼠标世界坐标
	_update_mouse_world_position()
	
	# 更新鼠标指示器位置
	_update_cursor_indicator()
	
	# 检查鼠标悬停的目标
	_update_hovered_target()
	
	# 更新效果范围预览
	_update_effect_range_preview()
	
	# 🚀 实时更新目标高亮（特别是范围型技能）
	if active_skill and active_skill.range_type == SkillEnums.RangeType.RANGE:
		_update_target_highlights_based_on_mouse()

func _input(event):
	if current_state == CastingState.INACTIVE:
		# 🧪 在非激活状态也允许调试信息输出
		if event is InputEventKey and event.pressed and event.keycode == KEY_F4:
			print("ℹ️ [调试] 当前未在技能释放状态")
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()
	
	elif event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			cancel_skill_casting()
		elif event.keycode == KEY_F4 and event.pressed:
			# 🧪 F4键输出一次性调试信息
			_output_debug_info()

# 🚀 开始技能释放流程
func start_skill_casting(skill: SkillData, caster: GameCharacter) -> void:
	if current_state != CastingState.INACTIVE:
		print("⚠️ [可视化技能] 技能释放系统正忙")
		return
	
	active_skill = skill
	active_caster = caster
	current_state = CastingState.SHOWING_RANGE
	
	print("🎯 [可视化技能] 开始技能释放: %s (施法者: %s)" % [skill.name, caster.name])
	
	# 🚀 修复：通知BattleScene更新UI状态
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("_update_battle_ui"):
		battle_scene._update_battle_ui("技能释放", "正在释放: %s" % skill.name, "skill_action")
	
	# 创建并显示技能释放HUD
	_create_and_show_hud()
	
	# 获取范围内的合法目标
	_calculate_valid_targets()
	
	# 显示施法范围
	_show_casting_range()
	
	# 创建鼠标指示器
	_create_cursor_indicator()
	
	# 高亮合法目标
	_highlight_valid_targets()
	
	current_state = CastingState.SELECTING_TARGET

# 🚀 取消技能释放
func cancel_skill_casting() -> void:
	print("❌ [可视化技能] 取消技能释放")
	
	_clear_all_visuals()
	_clear_hud()
	
	# 🚀 修复：通知BattleScene恢复正常UI状态
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("_restore_current_turn_ui"):
		battle_scene._restore_current_turn_ui()
	
	current_state = CastingState.INACTIVE
	active_skill = null
	active_caster = null
	hovered_target = null
	valid_targets_in_range.clear()
	
	skill_casting_cancelled.emit()

# 🎨 显示施法范围
func _show_casting_range() -> void:
	_clear_casting_range()
	
	if not active_skill or not active_caster:
		return
	
	# 创建施法范围圆圈
	casting_range_circle = _create_range_circle(
		active_caster.position,
		active_skill.targeting_range,
		CASTING_RANGE_COLOR,
		RANGE_CIRCLE_WIDTH,
		false  # 不填充，只显示边框
	)
	
	add_child(casting_range_circle)

# 🎨 创建鼠标指示器
func _create_cursor_indicator() -> void:
	_clear_cursor_indicator()
	
	cursor_indicator = _create_range_circle(
		Vector2.ZERO,
		CURSOR_INDICATOR_RADIUS,
		CURSOR_COLOR,
		2.0,
		false
	)
	
	add_child(cursor_indicator)

# 🎨 高亮合法目标
func _highlight_valid_targets() -> void:
	_clear_target_highlights()
	
	# 🚀 修改：只在有需要时显示目标高亮
	_update_target_highlights_based_on_mouse()

# 🚀 根据鼠标位置更新目标高亮
func _update_target_highlights_based_on_mouse() -> void:
	_clear_target_highlights()
	
	if not active_skill:
		return
	
	# 🚀 对于范围型技能，检查鼠标范围内是否有有效目标
	if active_skill.range_type == SkillEnums.RangeType.RANGE:
		var targets_in_mouse_range = _get_targets_in_mouse_range()
		
		# 🚀 修复：只显示鼠标效果范围内的合法目标圈
		for target in targets_in_mouse_range:
			if _is_target_valid_for_skill(target):
				var highlight = _create_target_highlight(target)
				add_child(highlight)
				target_highlights.append(highlight)
	else:
		# 🚀 修复：对于单体技能，只显示合法目标的圆圈
		for target in valid_targets_in_range:
			if _is_target_valid_for_skill(target):
				var highlight = _create_target_highlight(target)
				add_child(highlight)
				target_highlights.append(highlight)

# 🎨 创建目标高亮
func _create_target_highlight(target: GameCharacter) -> Node2D:
	# 🚀 根据技能效果和目标关系决定颜色
	var highlight_color = _get_target_effect_color(target)
	
	var highlight = _create_range_circle(
		target.position,
		TARGET_HIGHLIGHT_RADIUS,
		highlight_color,
		3.0,
		true  # 填充
	)
	
	# 🚀 修复：将目标高亮圈圈的z_index设置为负值，使其显示在角色下方
	highlight.z_index = -15  # 比其他圈圈更靠下，确保目标高亮在最底层
	
	return highlight

# 🎨 根据技能效果和目标关系获取目标圆圈颜色
func _get_target_effect_color(target: GameCharacter) -> Color:
	if not active_skill or not active_caster:
		return VALID_TARGET_COLOR  # 默认绿色
	
	# 判断技能的主要效果类型
	var effect_type = _analyze_skill_effect_type()
	
	# 判断目标与施法者的关系
	var is_friendly = active_caster.is_player_controlled() == target.is_player_controlled()
	var is_self = target == active_caster
	
	# 根据效果类型和目标关系决定颜色
	match effect_type:
		"damage", "debuff":
			# 伤害/减益效果：目标会受到负面影响 → 红色
			return Color(1.0, 0.2, 0.2, 0.6)  # 红色
		
		"heal", "buff":
			# 治疗/增益效果：目标会受到正面影响 → 绿色
			return Color(0.2, 1.0, 0.2, 0.6)  # 绿色
		
		"mixed":
			# 复合效果：根据目标关系判断
			if is_friendly or is_self:
				# 友方：可能受到治疗/增益 → 绿色
				return Color(0.2, 1.0, 0.2, 0.6)  # 绿色
			else:
				# 敌方：可能受到伤害/减益 → 红色
				return Color(1.0, 0.2, 0.2, 0.6)  # 红色
		
		"universal_damage":
			# 无差别伤害（如陨石术）：所有目标都受伤害 → 红色
			return Color(1.0, 0.2, 0.2, 0.6)  # 红色
		
		_:
			# 未知效果类型：使用原来的绿色
			return VALID_TARGET_COLOR

# 🔍 分析技能的主要效果类型
func _analyze_skill_effect_type() -> String:
	if not active_skill:
		return "unknown"
	
	# 检查effect_ids字段
	if active_skill.effect_ids.size() > 0:
		var main_effect = active_skill.effect_ids[0].to_lower()
		
		# 伤害类效果
		if main_effect.begins_with("damage"):
			# 特殊处理：某些伤害技能对所有目标都造成伤害
			if main_effect == "damage_meteor" or active_skill.target_type == SkillEnums.TargetType.ALL:
				return "universal_damage"
			else:
				return "damage"
		
		# 治疗类效果
		elif main_effect.begins_with("heal"):
			return "heal"
		
		# 增益类效果
		elif main_effect.begins_with("buff"):
			return "buff"
		
		# 减益类效果
		elif main_effect.begins_with("debuff"):
			return "debuff"
	
	# 如果没有effect_ids，根据技能目标类型推断
	match active_skill.target_type:
		SkillEnums.TargetType.ENEMY:
			return "damage"  # 敌方技能通常造成伤害
		SkillEnums.TargetType.ALLY, SkillEnums.TargetType.ALLYONLY, SkillEnums.TargetType.SELF:
			return "heal"  # 友方技能通常治疗/增益
		SkillEnums.TargetType.ALL:
			return "mixed"  # 全体技能需要特殊处理
		_:
			return "unknown"

# 🔍 计算范围内的合法目标
func _calculate_valid_targets() -> void:
	valid_targets_in_range.clear()
	
	if not active_skill or not active_caster:
		return
	
	# 获取所有角色
	var battle_scene = get_tree().current_scene
	if not battle_scene or not battle_scene.has_method("get_all_characters"):
		print("❌ [可视化技能] 无法获取角色列表")
		return
	
	var all_characters = battle_scene.get_all_characters()
	var caster_position = active_caster.position
	
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		# 检查距离
		var distance = caster_position.distance_to(character.position)
		if distance > active_skill.targeting_range:
			continue
		
		# 添加到范围内目标列表
		valid_targets_in_range.append(character)

# 🔍 检查目标是否对技能合法
func _is_target_valid_for_skill(target: GameCharacter) -> bool:
	if not active_skill or not active_caster or not target:
		return false
	
	match active_skill.target_type:
		SkillEnums.TargetType.SELF:
			return target == active_caster
		SkillEnums.TargetType.ENEMY:
			return active_caster.is_player_controlled() != target.is_player_controlled()
		SkillEnums.TargetType.ALLY:
			return active_caster.is_player_controlled() == target.is_player_controlled()
		SkillEnums.TargetType.ALLYONLY:
			return (active_caster.is_player_controlled() == target.is_player_controlled() 
					and target != active_caster)
		SkillEnums.TargetType.ALL:
			return true
		_:
			return false

# 🔄 更新鼠标指示器
func _update_cursor_indicator() -> void:
	if cursor_indicator:
		cursor_indicator.position = mouse_world_position

# 🔄 更新鼠标世界位置
func _update_mouse_world_position() -> void:
	mouse_world_position = get_global_mouse_position()

# 🔄 更新悬停目标
func _update_hovered_target() -> void:
	var new_hovered_target = _get_target_at_position(mouse_world_position)
	
	if new_hovered_target != hovered_target:
		hovered_target = new_hovered_target
		# 当悬停目标改变时，更新效果范围预览
		_update_effect_range_preview()

# 🔄 更新效果范围预览
func _update_effect_range_preview() -> void:
	_clear_effect_range_preview()
	
	if not active_skill or active_skill.range_type != SkillEnums.RangeType.RANGE:
		return
	
	# 确定预览中心位置
	var preview_center: Vector2
	
	match active_skill.targeting_type:
		SkillEnums.TargetingType.SELF:
			preview_center = active_caster.position
		SkillEnums.TargetingType.FREE:
			# 自由型技能：以鼠标位置为中心
			if _is_position_in_casting_range(mouse_world_position):
				preview_center = mouse_world_position
			else:
				return  # 超出范围，不显示预览
		_:
			# 其他类型：以悬停目标为中心
			if hovered_target and _is_target_valid_for_skill(hovered_target):
				preview_center = hovered_target.position
			else:
				return  # 没有合法悬停目标，不显示预览
	
	# 创建效果范围预览
	effect_range_preview = _create_range_circle(
		preview_center,
		active_skill.range_distance,
		EFFECT_RANGE_COLOR,
		EFFECT_PREVIEW_WIDTH,
		true  # 填充
	)
	
	add_child(effect_range_preview)

# 🖱️ 处理左键点击
func _handle_left_click() -> void:
	if current_state != CastingState.SELECTING_TARGET:
		return
	
	var targets = _get_targets_for_click()
	
	if targets.is_empty():
		print("⚠️ [可视化技能] 点击位置没有合法目标")
		return
	
	print("✅ [可视化技能] 确认释放技能，目标数量: %d" % targets.size())
	
	# 发送技能释放请求
	skill_cast_requested.emit(active_skill, active_caster, targets)
	
	# 清理并退出
	cancel_skill_casting()

# 🖱️ 处理右键点击 (取消)
func _handle_right_click() -> void:
	cancel_skill_casting()

# 🎯 获取点击位置的目标
func _get_targets_for_click() -> Array:
	var targets = []
	
	match active_skill.targeting_type:
		SkillEnums.TargetingType.SELF:
			if active_skill.range_type == SkillEnums.RangeType.RANGE:
				# 自身范围技能
				targets = _get_targets_in_area(active_caster.position, active_skill.range_distance)
			else:
				# 单体自身技能
				targets.append(active_caster)
		
		SkillEnums.TargetingType.FREE:
			# 自由型技能：以点击位置为中心
			if _is_position_in_casting_range(mouse_world_position):
				if active_skill.range_type == SkillEnums.RangeType.RANGE:
					targets = _get_targets_in_area(mouse_world_position, active_skill.range_distance)
				else:
					# 自由单体？不太常见，暂时按范围处理
					targets = _get_targets_in_area(mouse_world_position, active_skill.range_distance)
		
		_:
			# 普通型、弹道型等：需要点击具体目标
			var clicked_target = _get_target_at_position(mouse_world_position)
			
			if not clicked_target:
				return targets  # 空数组
			
			if not _is_target_valid_for_skill(clicked_target):
				return targets  # 空数组
			
			if active_skill.range_type == SkillEnums.RangeType.RANGE:
				# 范围技能：以点击目标为中心获取范围内目标
				targets = _get_targets_in_area(clicked_target.position, active_skill.range_distance)
			else:
				# 单体技能：只针对点击的目标
				targets.append(clicked_target)
	
	# 过滤出合法目标
	var valid_targets = []
	for target in targets:
		if _is_target_valid_for_skill(target):
			valid_targets.append(target)
	
	return valid_targets

# 🔍 获取指定位置的目标
func _get_target_at_position(position: Vector2) -> GameCharacter:
	var closest_target = null
	var closest_distance = TARGET_HIGHLIGHT_RADIUS
	
	for target in valid_targets_in_range:
		var distance = position.distance_to(target.position)
		if distance < closest_distance:
			closest_target = target
			closest_distance = distance
	
	return closest_target

# 🔍 获取指定区域内的所有目标
func _get_targets_in_area(center_position: Vector2, radius: float) -> Array:
	var targets_in_area = []
	
	# 获取所有角色
	var battle_scene = get_tree().current_scene
	if not battle_scene or not battle_scene.has_method("get_all_characters"):
		return targets_in_area
	
	var all_characters = battle_scene.get_all_characters()
	
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		var distance = center_position.distance_to(character.position)
		if distance <= radius:
			targets_in_area.append(character)
	
	return targets_in_area

# 🔍 检查位置是否在施法范围内
func _is_position_in_casting_range(position: Vector2) -> bool:
	if not active_skill or not active_caster:
		return false
	
	var distance = active_caster.position.distance_to(position)
	return distance <= active_skill.targeting_range

# 🎨 创建范围圆圈的通用方法
func _create_range_circle(center: Vector2, radius: float, color: Color, line_width: float, filled: bool) -> Node2D:
	var circle_node = Node2D.new()
	circle_node.position = center
	
	# 🚀 修复：设置z_index为负值，使所有技能圈圈显示在角色下方
	circle_node.z_index = -5
	
	# 使用自定义绘制
	var circle_drawer = _CircleDrawer.new()
	circle_drawer.setup(radius, color, line_width, filled)
	circle_node.add_child(circle_drawer)
	
	return circle_node

# 🧹 清理方法
func _clear_casting_range() -> void:
	if casting_range_circle:
		casting_range_circle.queue_free()
		casting_range_circle = null

func _clear_effect_range_preview() -> void:
	if effect_range_preview:
		effect_range_preview.queue_free()
		effect_range_preview = null

func _clear_cursor_indicator() -> void:
	if cursor_indicator:
		cursor_indicator.queue_free()
		cursor_indicator = null

func _clear_target_highlights() -> void:
	for highlight in target_highlights:
		if is_instance_valid(highlight):
			highlight.queue_free()
	target_highlights.clear()

func _clear_all_visuals() -> void:
	_clear_casting_range()
	_clear_effect_range_preview()
	_clear_cursor_indicator()
	_clear_target_highlights()

# 清理资源
func _exit_tree() -> void:
	_clear_all_visuals()

# 🎨 内部圆圈绘制类
class _CircleDrawer extends Node2D:
	var radius: float
	var color: Color
	var line_width: float
	var filled: bool
	
	func setup(r: float, c: Color, lw: float, f: bool):
		radius = r
		color = c
		line_width = lw
		filled = f
	
	func _draw():
		if filled:
			draw_circle(Vector2.ZERO, radius, color)
		else:
			draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, line_width)

# 🎨 创建并显示技能释放HUD
func _create_and_show_hud() -> void:
	if not active_skill or not active_caster:
		return
	
	# 创建HUD
	if not casting_hud:
		var SkillCastingHUD = load("res://UI/SkillCastingHUD.gd")
		casting_hud = SkillCastingHUD.new()
		get_tree().current_scene.add_child(casting_hud)
	
	# 显示HUD
	casting_hud.show_skill_casting(active_skill, active_caster)

# 🎨 隐藏技能释放HUD
func _hide_hud() -> void:
	if casting_hud:
		casting_hud.hide_skill_casting()

# 🎨 清理HUD
func _clear_hud() -> void:
	if casting_hud:
		casting_hud.queue_free()
		casting_hud = null

# 🚀 获取鼠标范围内的目标
func _get_targets_in_mouse_range() -> Array:
	if not active_skill or active_skill.range_type != SkillEnums.RangeType.RANGE:
		return []
	
	var mouse_range_targets = []
	var range_radius = active_skill.range_distance
	
	# 确定鼠标范围中心位置
	var range_center: Vector2
	
	match active_skill.targeting_type:
		SkillEnums.TargetingType.SELF:
			range_center = active_caster.position
		SkillEnums.TargetingType.FREE:
			# 自由型技能：以鼠标位置为中心
			if _is_position_in_casting_range(mouse_world_position):
				range_center = mouse_world_position
			else:
				return []  # 超出施法范围
		_:
			# 其他类型：以悬停目标为中心
			if hovered_target:
				range_center = hovered_target.position
			else:
				return []  # 没有悬停目标
	
	# 获取所有角色
	var battle_scene = get_tree().current_scene
	if not battle_scene or not battle_scene.has_method("get_all_characters"):
		return []
	
	var all_characters = battle_scene.get_all_characters()
	
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		var distance = range_center.distance_to(character.position)
		if distance <= range_radius:
			mouse_range_targets.append(character)
	
	return mouse_range_targets

# 🧪 输出完整的调试信息
func _output_debug_info() -> void:
	print("\n🧪 ==================== 调试信息 ====================")
	
	if not active_skill or not active_caster:
		print("❌ 技能或施法者为空")
		return
	
	print("🎯 技能: %s" % active_skill.name)
	print("🎯 施法者: %s (位置: %s)" % [active_caster.name, active_caster.position])
	print("🎯 技能范围: %s" % active_skill.targeting_range)
	
	print("\n🖱️ 鼠标和坐标信息:")
	print("  - 鼠标世界位置: %s" % mouse_world_position)
	print("  - 鼠标屏幕位置: %s" % get_viewport().get_mouse_position())
	print("  - 视口大小: %s" % get_viewport().get_visible_rect().size)
	print("  - VisualSkillCaster变换: %s" % transform)
	print("  - VisualSkillCaster全局变换: %s" % global_transform)
	
	print("🎯 目标类型: %s" % SkillEnums.TargetType.keys()[active_skill.target_type])
	print("🎯 效果类型: %s" % _analyze_skill_effect_type())
	print("🎯 效果ID: %s" % (active_skill.effect_ids[0] if active_skill.effect_ids.size() > 0 else "无"))
	print("🎯 射程内角色数量: %d" % valid_targets_in_range.size())
	
	print("\n🎨 技能范围圆圈信息:")
	if casting_range_circle:
		print("  - 圆圈存在: 是")
		print("  - 圆圈位置: %s" % casting_range_circle.position)
		print("  - 圆圈全局位置: %s" % casting_range_circle.global_position)
		print("  - 圆圈z_index: %s" % casting_range_circle.z_index)
	else:
		print("  - 圆圈存在: 否")
	
	print("\n📋 所有角色控制类型:")
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("get_all_characters"):
		var all_characters = battle_scene.get_all_characters()
		for character in all_characters:
			if character and character.is_alive():
				var distance = active_caster.position.distance_to(character.position)
				var in_range = distance <= active_skill.targeting_range
				var is_valid = _is_target_valid_for_skill(character)
				var effect_color = _get_target_effect_color(character)
				var color_name = ""
				if effect_color.r > 0.8:
					color_name = "红色"
				elif effect_color.g > 0.8:
					color_name = "绿色"
				else:
					color_name = "其他"
				
				print("  - %s (ID:%s): 玩家控制=%s, 距离=%.1f, 射程内=%s, 合法=%s, 圆圈=%s" % [
					character.name, character.id, character.is_player_controlled(), 
					distance, in_range, is_valid, color_name
				])
	
	print("\n🎯 鼠标点击检测:")
	var clicked_target = _get_target_at_position(mouse_world_position)
	if clicked_target:
		print("  - 最近目标: %s (距离: %.1f)" % [clicked_target.name, mouse_world_position.distance_to(clicked_target.position)])
		print("  - 目标合法: %s" % _is_target_valid_for_skill(clicked_target))
		var effect_color = _get_target_effect_color(clicked_target)
		var color_name = "红色" if effect_color.r > 0.8 else ("绿色" if effect_color.g > 0.8 else "其他")
		print("  - 圆圈颜色: %s" % color_name)
	else:
		print("  - 未检测到目标 (检测半径: %.1f)" % TARGET_HIGHLIGHT_RADIUS)
	
	print("🧪 ================================================\n")

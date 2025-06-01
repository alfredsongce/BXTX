extends Node2D
class_name SkillRangeDisplay

# 范围显示组件
var range_circles: Array = []
var pierce_lines: Array = []

# 颜色配置
var ally_color: Color = Color.GREEN
var enemy_color: Color = Color.RED
var neutral_color: Color = Color.BLUE
var all_color: Color = Color.PURPLE

# 绘制技能范围
func show_skill_range(skill: SkillData, caster: GameCharacter, target_position: Vector2 = Vector2.ZERO) -> void:
	clear_range_display()
	
	match skill.targeting_type:
		SkillEnums.TargetingType.NORMAL:
			_show_normal_range(skill, caster)
		
		SkillEnums.TargetingType.PROJECTILE_SINGLE:
			_show_projectile_single_range(skill, caster)
		
		SkillEnums.TargetingType.PROJECTILE_PIERCE:
			if target_position != Vector2.ZERO:
				_show_projectile_pierce_range(skill, caster, target_position)
			else:
				_show_projectile_single_range(skill, caster)  # 显示射程
		
		SkillEnums.TargetingType.FREE:
			_show_free_range(skill, caster)
		
		SkillEnums.TargetingType.SELF:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				_show_self_range(skill, caster)

# 显示普通型技能范围
func _show_normal_range(skill: SkillData, caster: GameCharacter) -> void:
	var color = _get_skill_color(skill)
	
	# 显示施法范围
	_draw_range_circle(caster.position, skill.targeting_range, color, 0.3)
	
	# 如果是范围技能，显示效果范围示例
	if skill.range_type == SkillEnums.RangeType.RANGE:
		_draw_range_circle(caster.position, skill.range_distance, color, 0.5)

# 显示弹道单点型技能范围
func _show_projectile_single_range(skill: SkillData, caster: GameCharacter) -> void:
	var color = _get_skill_color(skill)
	
	# 显示射程范围
	_draw_range_circle(caster.position, skill.targeting_range, color, 0.3)

# 显示弹道穿刺型技能范围
func _show_projectile_pierce_range(skill: SkillData, caster: GameCharacter, target_position: Vector2) -> void:
	var color = _get_skill_color(skill)
	var direction = (target_position - caster.position).normalized()
	var end_position = caster.position + direction * skill.targeting_range
	
	# 绘制弹道路径
	_draw_pierce_line(caster.position, end_position, color, 0.6)

# 显示自由型技能范围
func _show_free_range(skill: SkillData, caster: GameCharacter) -> void:
	var color = _get_skill_color(skill)
	
	# 显示施法范围
	_draw_range_circle(caster.position, skill.targeting_range, color, 0.3)

# 显示自身范围技能
func _show_self_range(skill: SkillData, caster: GameCharacter) -> void:
	var color = _get_skill_color(skill)
	
	# 显示以施法者为中心的效果范围
	_draw_range_circle(caster.position, skill.range_distance, color, 0.5)

# 绘制范围圆圈
func _draw_range_circle(center: Vector2, radius: float, color: Color, alpha: float) -> void:
	var circle_node = Node2D.new()
	circle_node.position = center
	
	var circle = _create_circle_shape(radius, color, alpha)
	circle_node.add_child(circle)
	
	add_child(circle_node)
	range_circles.append(circle_node)

# 绘制穿刺路径
func _draw_pierce_line(start: Vector2, end: Vector2, color: Color, alpha: float) -> void:
	var line_node = Line2D.new()
	line_node.add_point(start)
	line_node.add_point(end)
	line_node.width = 20.0
	line_node.default_color = Color(color.r, color.g, color.b, alpha)
	
	add_child(line_node)
	pierce_lines.append(line_node)

# 创建圆圈形状
func _create_circle_shape(radius: float, color: Color, alpha: float) -> Node2D:
	var shape_node = Node2D.new()
	
	# 这里可以使用Godot的绘制方法或者自定义绘制
	# 简化实现：使用基本的圆圈显示
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	collision_shape.modulate = Color(color.r, color.g, color.b, alpha)
	
	shape_node.add_child(collision_shape)
	
	return shape_node

# 获取技能颜色
func _get_skill_color(skill: SkillData) -> Color:
	match skill.target_type:
		SkillEnums.TargetType.ALLY, SkillEnums.TargetType.SELF:
			return ally_color
		SkillEnums.TargetType.ENEMY:
			return enemy_color
		SkillEnums.TargetType.ALL:
			return all_color
		_:
			return neutral_color

# 清除范围显示
func clear_range_display() -> void:
	for circle in range_circles:
		if is_instance_valid(circle):
			circle.queue_free()
	range_circles.clear()
	
	for line in pierce_lines:
		if is_instance_valid(line):
			line.queue_free()
	pierce_lines.clear()

# 清理资源
func _exit_tree() -> void:
	clear_range_display() 
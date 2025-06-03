extends Node2D
class_name SkillEffects

# 技能效果管理器 - 负责所有技能的视觉效果

# 🎨 颜色配置
const DAMAGE_COLOR = Color.RED
const HEALING_COLOR = Color.GREEN
const CRITICAL_COLOR = Color.ORANGE
const SKILL_RANGE_COLOR = Color.CYAN
const EXPLOSION_COLOR = Color.YELLOW

# 🎯 动画配置
const DAMAGE_NUMBER_DURATION = 3.0
const HEALING_NUMBER_DURATION = 2.5
const SKILL_ANIMATION_DURATION = 0.8
const RANGE_EFFECT_DURATION = 1.0

# 📊 字体大小配置
const NORMAL_DAMAGE_SIZE = 24
const CRITICAL_DAMAGE_SIZE = 32
const HEALING_SIZE = 22
const SKILL_NAME_SIZE = 20

# 存储活跃的效果节点
var active_effects: Array = []

func _ready():
	# 添加到技能效果组
	add_to_group("skill_effects")
	print("✨ [技能效果] SkillEffects系统初始化完成")

# 🎬 播放完整的技能动画序列
func play_skill_animation(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("🎬 [技能效果] 播放技能动画: %s" % skill.name)
	
	# 1. 显示技能名称
	_show_skill_name(skill, caster)
	
	# 2. 播放施法动画
	await _play_cast_animation(skill, caster)
	
	# 3. 根据技能类型播放不同的效果
	match skill.targeting_type:
		SkillEnums.TargetingType.PROJECTILE_SINGLE:
			await _play_projectile_animation(skill, caster, targets)
		SkillEnums.TargetingType.PROJECTILE_PIERCE:
			await _play_pierce_animation(skill, caster, targets)
		SkillEnums.TargetingType.NORMAL:
			if skill.range_type == SkillEnums.RangeType.RANGE:
				await _play_area_effect_animation(skill, targets)
			else:
				await _play_single_target_animation(skill, targets)
		SkillEnums.TargetingType.SELF:
			await _play_self_effect_animation(skill, caster)
		SkillEnums.TargetingType.FREE:
			await _play_area_effect_animation(skill, targets)
		_:
			await _play_single_target_animation(skill, targets)
	
	print("✅ [技能效果] 技能动画播放完成: %s" % skill.name)

# 💥 创建伤害数字效果
func create_damage_numbers(target: GameCharacter, damage: int, is_critical: bool = false) -> void:
	print("💥 [SkillEffects] 创建伤害数字: %s 受到 %d 点伤害%s" % [target.name if target else "null", damage, " (暴击!)" if is_critical else ""])
	
	# 🔍 详细调试信息
	if not target:
		print("❌ [SkillEffects] 目标角色为空")
		return
	
	print("🔍 [SkillEffects] 目标角色信息: 名称=%s, ID=%s, 类型=%s" % [target.name, target.id, target.control_type])
	
	var target_node = _get_character_node(target)
	if not target_node:
		print("❌ [SkillEffects] 无法获取目标节点，伤害数字创建失败")
		print("🔍 [SkillEffects] 尝试备用查找方法...")
		# 尝试备用查找方法
		target_node = _find_character_node_fallback(target)
		if not target_node:
			print("❌ [SkillEffects] 备用查找也失败，跳过伤害数字创建")
			return
		else:
			print("✅ [SkillEffects] 备用查找成功找到目标节点")
	
	print("🔍 [伤害数字] 在 %s 位置显示伤害" % target_node.global_position)
	print("🔍 [伤害数字] 目标节点详细信息: 名称=%s, 类型=%s, 可见=%s" % [target_node.name, target_node.get_class(), target_node.visible])
	
	# 🎨 使用RichTextLabel创建伤害数字
	var damage_label = RichTextLabel.new()
	damage_label.bbcode_enabled = true
	damage_label.z_index = 100
	damage_label.fit_content = true  # 自动调整大小以适应内容
	damage_label.scroll_active = false  # 禁用滚动
	damage_label.selection_enabled = false  # 禁用选择
	
	# 🔧 确保显示属性
	damage_label.visible = true
	damage_label.modulate = Color.WHITE  # 确保不透明
	
	# 设置文本内容和样式
	var color_code: String
	var font_size: int
	var text_content: String
	
	if is_critical:
		color_code = "orange"
		font_size = CRITICAL_DAMAGE_SIZE
		text_content = "暴击! -%d" % damage
	else:
		color_code = "red"
		font_size = NORMAL_DAMAGE_SIZE
		text_content = "-%d" % damage
	
	# 设置富文本内容（带颜色、大小、粗体、阴影效果）
	damage_label.text = "[center][font_size=%d][color=%s][b]%s[/b][/color][/font_size][/center]" % [font_size, color_code, text_content]
	
	# 设置大小
	damage_label.size = Vector2(150, 60)
	
	# 设置初始位置（目标角色头顶）
	var start_pos = target_node.global_position + Vector2(-75, -80)  # 居中显示在角色头顶
	
	print("🔍 [伤害数字] 目标节点位置: %s" % target_node.global_position)
	print("🔍 [伤害数字] 伤害标签位置: %s" % start_pos)
	print("🔍 [伤害数字] 伤害文本: %s" % text_content)
	
	damage_label.global_position = start_pos
	
	# 添加到场景
	get_tree().current_scene.add_child(damage_label)
	active_effects.append(damage_label)
	
	print("✅ [伤害数字] 伤害数字已创建: %s" % text_content)
	
	# 创建飞出动画
	var tween = create_tween()
	# 不使用parallel，按顺序执行动画
	
	# 🔧 改进动画：先停留1秒让玩家看清，然后再飞出
	var stay_duration = 1.0  # 停留时间
	var fly_duration = DAMAGE_NUMBER_DURATION - stay_duration  # 飞出时间
	
	# 缩放动画：立即开始（暴击时更明显）
	if is_critical:
		tween.tween_property(damage_label, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(damage_label, "scale", Vector2(1.2, 1.2), 0.3)
	else:
		tween.tween_property(damage_label, "scale", Vector2(1.2, 1.2), 0.2)
		tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.3)
	
	# 停留时间
	tween.tween_interval(stay_duration - 0.5)  # 减去缩放动画时间
	
	# 位置动画：向上飞出并稍微偏移
	var end_pos = start_pos + Vector2(randf_range(-30, 30), -80)
	tween.tween_property(damage_label, "global_position", end_pos, fly_duration)
	
	# 同时进行透明度动画（从飞出开始的一半时间开始淡出）
	var fade_tween = create_tween()
	fade_tween.tween_interval(stay_duration + fly_duration * 0.5)
	fade_tween.tween_property(damage_label, "modulate:a", 0.0, fly_duration * 0.5)
	
	# 动画完成后清理
	tween.tween_callback(_cleanup_effect.bind(damage_label))
	
	print("💥 [伤害效果] 显示伤害数字: %d %s" % [damage, "暴击!" if is_critical else ""])

# 💚 创建治疗数字效果
func create_healing_numbers(target: GameCharacter, healing: int) -> void:
	var target_node = _get_character_node(target)
	if not target_node:
		return
	
	# 🎨 使用RichTextLabel创建治疗数字
	var heal_label = RichTextLabel.new()
	heal_label.bbcode_enabled = true
	heal_label.z_index = 100
	heal_label.fit_content = true
	
	# 设置治疗文本内容和样式（绿色）
	var text_content = "+%d" % healing
	heal_label.text = "[center][font_size=%d][color=green][b]%s[/b][/color][/font_size][/center]" % [HEALING_SIZE, text_content]
	
	# 设置大小
	heal_label.size = Vector2(120, 50)
	
	# 设置初始位置（目标角色头顶）
	var start_pos = target_node.global_position + Vector2(-60, -60)
	heal_label.global_position = start_pos
	
	# 添加到场景
	get_tree().current_scene.add_child(heal_label)
	active_effects.append(heal_label)
	
	# 创建温和的上升动画
	var tween = create_tween()
	# 不使用parallel，按顺序执行
	
	# 🔧 治疗数字也增加停留时间
	var stay_duration = 0.8  # 治疗数字停留时间稍短
	var fly_duration = HEALING_NUMBER_DURATION - stay_duration
	
	# 轻微的缩放动画（立即开始）
	tween.tween_property(heal_label, "scale", Vector2(1.3, 1.3), 0.3)
	tween.tween_property(heal_label, "scale", Vector2(1.0, 1.0), 0.2)
	
	# 停留时间
	tween.tween_interval(stay_duration - 0.5)  # 减去缩放时间
	
	# 位置动画：温和向上
	var end_pos = start_pos + Vector2(0, -60)
	tween.tween_property(heal_label, "global_position", end_pos, fly_duration)
	
	# 透明度动画（单独的tween）
	var fade_tween = create_tween()
	fade_tween.tween_interval(stay_duration + fly_duration * 0.6)
	fade_tween.tween_property(heal_label, "modulate:a", 0.0, fly_duration * 0.4)
	
	# 动画完成后清理
	tween.tween_callback(_cleanup_effect.bind(heal_label))
	
	print("💚 [治疗效果] 显示治疗数字: +%d" % healing)

# 🎯 显示技能名称
func _show_skill_name(skill: SkillData, caster: GameCharacter) -> void:
	var caster_node = _get_character_node(caster)
	if not caster_node:
		return
	
	# 创建技能名称标签
	var skill_label = Label.new()
	skill_label.text = skill.name
	skill_label.z_index = 99
	skill_label.add_theme_font_size_override("font_size", SKILL_NAME_SIZE)
	skill_label.add_theme_color_override("font_color", SKILL_RANGE_COLOR)
	skill_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	skill_label.add_theme_constant_override("shadow_offset_x", 2)
	skill_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# 设置位置（施法者头顶）
	var start_pos = caster_node.global_position + Vector2(0, -100)
	skill_label.global_position = start_pos
	
	# 添加到场景
	get_tree().current_scene.add_child(skill_label)
	active_effects.append(skill_label)
	
	# 创建完整的技能名称动画序列
	var tween = create_tween()
	
	# 1. 从小到大出现
	skill_label.scale = Vector2.ZERO
	tween.tween_property(skill_label, "scale", Vector2(1.0, 1.0), 0.3)
	
	# 2. 停留一段时间后淡出并清理
	tween.tween_interval(0.8)
	tween.tween_property(skill_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_cleanup_effect.bind(skill_label))

# ⚡ 播放施法动画
func _play_cast_animation(skill: SkillData, caster: GameCharacter) -> void:
	var caster_node = _get_character_node(caster)
	if not caster_node:
		return
	
	# 创建施法光环效果
	var cast_ring = _create_cast_ring(caster_node.global_position)
	
	# 施法者发光效果
	var original_modulate = caster_node.modulate
	var tween = create_tween()
	
	# 闪烁效果
	tween.tween_property(caster_node, "modulate", Color.CYAN, 0.2)
	tween.tween_property(caster_node, "modulate", original_modulate, 0.2)
	
	# 等待施法时间
	await get_tree().create_timer(0.4).timeout
	
	print("⚡ [施法动画] %s 施法完成" % caster.name)

# 🎭 创建施法光环
func _create_cast_ring(position: Vector2) -> Node2D:
	var ring = Node2D.new()
	ring.global_position = position
	get_tree().current_scene.add_child(ring)
	active_effects.append(ring)
	
	# 创建多个光环粒子
	for i in range(8):
		var particle = _create_cast_particle(ring, i * 45)
	
	# 光环旋转和缩放动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 旋转动画
	tween.tween_property(ring, "rotation_degrees", 360, 1.0)
	
	# 缩放动画序列
	ring.scale = Vector2.ZERO
	tween.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_interval(0.4)  # 停留时间
	tween.tween_property(ring, "scale", Vector2.ZERO, 0.3)
	
	# 清理（总时长1秒）
	tween.tween_callback(_cleanup_effect.bind(ring))
	
	return ring

# ✨ 创建光环粒子
func _create_cast_particle(parent: Node2D, angle_degrees: float) -> ColorRect:
	var particle = ColorRect.new()
	particle.size = Vector2(8, 8)
	particle.color = Color.CYAN
	
	# 计算位置
	var angle_rad = deg_to_rad(angle_degrees)
	var radius = 40
	particle.position = Vector2(cos(angle_rad) * radius, sin(angle_rad) * radius)
	
	parent.add_child(particle)
	
	# 粒子闪烁效果（有限循环）
	var tween = create_tween()
	tween.set_loops(3)  # 设置有限循环次数
	tween.tween_property(particle, "modulate:a", 0.3, 0.2)
	tween.tween_property(particle, "modulate:a", 1.0, 0.2)
	
	# 粒子会随着父节点（ring）一起被清理，无需单独清理
	
	return particle

# 🚀 播放弹道动画
func _play_projectile_animation(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	if targets.is_empty():
		return
	
	var caster_node = _get_character_node(caster)
	var target_node = _get_character_node(targets[0])
	if not caster_node or not target_node:
		return
	
	# 创建弹道效果
	var projectile = _create_projectile(caster_node.global_position, target_node.global_position)
	
	# 等待弹道到达
	await get_tree().create_timer(0.6).timeout
	
	# 播放命中效果
	_create_impact_effect(target_node.global_position)
	
	print("🚀 [弹道动画] 弹道技能命中目标")

# 💫 创建弹道效果
func _create_projectile(start_pos: Vector2, end_pos: Vector2) -> ColorRect:
	var projectile = ColorRect.new()
	projectile.size = Vector2(20, 8)
	projectile.color = SKILL_RANGE_COLOR
	projectile.global_position = start_pos
	projectile.z_index = 50
	
	get_tree().current_scene.add_child(projectile)
	active_effects.append(projectile)
	
	# 计算方向和旋转
	var direction = (end_pos - start_pos).normalized()
	projectile.rotation = direction.angle()
	
	# 弹道飞行动画
	var tween = create_tween()
	tween.tween_property(projectile, "global_position", end_pos, 0.6)
	tween.tween_callback(_cleanup_effect.bind(projectile))
	
	return projectile

# 💥 创建命中效果
func _create_impact_effect(position: Vector2) -> void:
	# 创建爆炸环
	var impact_ring = Node2D.new()
	impact_ring.global_position = position
	get_tree().current_scene.add_child(impact_ring)
	active_effects.append(impact_ring)
	
	# 创建爆炸粒子
	for i in range(12):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.color = EXPLOSION_COLOR
		
		var angle = i * 30.0
		var radius = 30
		var offset = Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle))) * radius
		particle.position = offset
		
		impact_ring.add_child(particle)
		
		# 粒子扩散动画
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", offset * 2, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
	
	# 清理爆炸环（使用Timer而不是空Tween）
	get_tree().create_timer(0.5).timeout.connect(func(): _cleanup_effect(impact_ring))

# ⚡ 播放穿刺动画
func _play_pierce_animation(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	if targets.is_empty():
		return
	
	var caster_node = _get_character_node(caster)
	if not caster_node:
		return
	
	# 计算穿刺方向（使用第一个目标）
	var first_target = _get_character_node(targets[0])
	if not first_target:
		return
	
	var direction = (first_target.global_position - caster_node.global_position).normalized()
	var end_pos = caster_node.global_position + direction * skill.targeting_range
	
	# 创建穿刺射线
	var pierce_beam = _create_pierce_beam(caster_node.global_position, end_pos)
	
	# 依次创建每个目标的命中效果
	for i in range(targets.size()):
		var target_node = _get_character_node(targets[i])
		if target_node:
			get_tree().create_timer(0.1 * i).timeout.connect(
				func(): _create_impact_effect(target_node.global_position)
			)
	
	await get_tree().create_timer(0.8).timeout
	print("⚡ [穿刺动画] 穿刺技能命中 %d 个目标" % targets.size())

# 📏 创建穿刺射线
func _create_pierce_beam(start_pos: Vector2, end_pos: Vector2) -> Line2D:
	var beam = Line2D.new()
	beam.add_point(start_pos)
	beam.add_point(end_pos)
	beam.width = 8.0
	beam.default_color = Color.YELLOW
	beam.z_index = 40
	
	get_tree().current_scene.add_child(beam)
	active_effects.append(beam)
	
	# 射线闪烁效果
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(beam, "modulate:a", 0.3, 0.1)
	tween.tween_property(beam, "modulate:a", 1.0, 0.1)
	
	# 清理（使用Timer而不是空Tween）
	get_tree().create_timer(0.6).timeout.connect(func(): _cleanup_effect(beam))
	
	return beam

# 🌊 播放范围效果动画
func _play_area_effect_animation(skill: SkillData, targets: Array) -> void:
	if targets.is_empty():
		return
	
	# 使用第一个目标作为中心点
	var center_target = _get_character_node(targets[0])
	if not center_target:
		return
	
	var center_pos = center_target.global_position
	
	# 创建范围效果圈
	var area_circle = _create_area_circle(center_pos, skill.range_distance)
	
	# 依次对每个目标播放效果
	for i in range(targets.size()):
		var target_node = _get_character_node(targets[i])
		if target_node:
			get_tree().create_timer(0.1 * i).timeout.connect(
				func(): _create_impact_effect(target_node.global_position)
			)
	
	await get_tree().create_timer(RANGE_EFFECT_DURATION).timeout
	print("🌊 [范围动画] 范围技能影响 %d 个目标" % targets.size())

# ⭕ 创建范围效果圈
func _create_area_circle(center_pos: Vector2, radius: float) -> Node2D:
	var circle = Node2D.new()
	circle.global_position = center_pos
	get_tree().current_scene.add_child(circle)
	active_effects.append(circle)
	
	# 创建圆圈边界
	var circle_line = Line2D.new()
	circle_line.width = 4.0
	circle_line.default_color = Color.CYAN
	circle_line.z_index = 30
	
	# 绘制圆圈
	var points = 32
	for i in range(points + 1):
		var angle = (i * 2.0 * PI) / points
		var point = Vector2(cos(angle), sin(angle)) * radius
		circle_line.add_point(point)
	
	circle.add_child(circle_line)
	
	# 圆圈扩散动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	circle.scale = Vector2.ZERO
	tween.tween_property(circle, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(circle, "modulate:a", 0.0, RANGE_EFFECT_DURATION)
	
	# 清理
	tween.tween_callback(_cleanup_effect.bind(circle))
	
	return circle

# 🔮 播放单体目标动画
func _play_single_target_animation(skill: SkillData, targets: Array) -> void:
	if targets.is_empty():
		return
	
	var target_node = _get_character_node(targets[0])
	if not target_node:
		return
	
	# 创建单体效果
	_create_single_target_effect(target_node.global_position)
	
	await get_tree().create_timer(0.5).timeout
	print("🔮 [单体动画] 单体技能命中目标")

# ✨ 创建单体目标效果
func _create_single_target_effect(position: Vector2) -> void:
	var effect = Node2D.new()
	effect.global_position = position
	get_tree().current_scene.add_child(effect)
	active_effects.append(effect)
	
	# 创建闪光效果
	for i in range(6):
		var spark = ColorRect.new()
		spark.size = Vector2(12, 4)
		spark.color = Color.WHITE
		
		var angle = i * 60.0
		spark.rotation_degrees = angle
		spark.position = Vector2(-6, -2)  # 居中
		
		effect.add_child(spark)
		
		# 闪光动画
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "scale", Vector2(2.0, 1.0), 0.2)
		tween.tween_property(spark, "modulate:a", 0.0, 0.4)
	
	# 清理效果
	get_tree().create_timer(0.4).timeout.connect(func(): _cleanup_effect(effect))

# 🌟 播放自身效果动画
func _play_self_effect_animation(skill: SkillData, caster: GameCharacter) -> void:
	var caster_node = _get_character_node(caster)
	if not caster_node:
		return
	
	# 创建自身增强效果
	_create_self_enhancement_effect(caster_node.global_position)
	
	await get_tree().create_timer(0.6).timeout
	print("🌟 [自身动画] 自身技能效果完成")

# 💫 创建自身增强效果
func _create_self_enhancement_effect(position: Vector2) -> void:
	var effect = Node2D.new()
	effect.global_position = position
	get_tree().current_scene.add_child(effect)
	active_effects.append(effect)
	
	# 创建上升光柱效果
	for i in range(5):
		var beam = ColorRect.new()
		beam.size = Vector2(4, 60)
		beam.color = Color.GREEN
		beam.position = Vector2(randf_range(-20, 20), -30)
		
		effect.add_child(beam)
		
		# 光柱上升动画
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(beam, "position:y", beam.position.y - 40, 0.8)
		tween.tween_property(beam, "modulate:a", 0.0, 0.8)
	
	# 清理效果
	get_tree().create_timer(0.8).timeout.connect(func(): _cleanup_effect(effect))

# 🔍 获取角色对应的节点
func _get_character_node(character: GameCharacter) -> Node2D:
	if not character:
		print("⚠️ [SkillEffects] _get_character_node: 角色数据为空")
		return null
	
	print("🔍 [SkillEffects] 查找角色节点: %s (ID: %s)" % [character.name, character.id])
	
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		print("⚠️ [SkillEffects] 当前场景为空")
		return null
	
	print("🔍 [SkillEffects] 当前场景: %s" % battle_scene.name)
	
	if battle_scene.has_method("get_character_node_by_data"):
		print("🔍 [SkillEffects] 调用BattleScene.get_character_node_by_data")
		var result = battle_scene.get_character_node_by_data(character)
		if result:
			print("✅ [SkillEffects] 找到角色节点: %s -> %s (位置: %s)" % [character.name, result.name, result.global_position])
		else:
			print("❌ [SkillEffects] 未找到角色节点: %s" % character.name)
		return result
	else:
		print("⚠️ [SkillEffects] BattleScene没有get_character_node_by_data方法")
		return null

# 🔍 备用角色节点查找方法
func _find_character_node_fallback(character: GameCharacter) -> Node2D:
	print("🔍 [SkillEffects] 使用备用方法查找角色节点: %s" % character.name)
	
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		return null
	
	# 尝试通过CharacterManager查找
	var character_manager = battle_scene.get_node_or_null("BattleSystems/BattleCharacterManager")
	if character_manager and character_manager.has_method("get_character_node_by_data"):
		print("🔍 [SkillEffects] 通过CharacterManager查找")
		var result = character_manager.get_character_node_by_data(character)
		if result:
			print("✅ [SkillEffects] CharacterManager找到角色节点: %s" % result.name)
			return result
	
	# 尝试直接在场景中搜索
	print("🔍 [SkillEffects] 在场景中直接搜索角色节点")
	var all_nodes = _get_all_character_nodes(battle_scene)
	for node in all_nodes:
		if node.has_method("get_character_data"):
			var node_character = node.get_character_data()
			if node_character and node_character.id == character.id:
				print("✅ [SkillEffects] 直接搜索找到角色节点: %s" % node.name)
				return node
	
	print("❌ [SkillEffects] 备用方法也未找到角色节点")
	return null

# 🔍 获取场景中所有可能的角色节点
func _get_all_character_nodes(scene: Node) -> Array:
	var character_nodes = []
	_collect_character_nodes_recursive(scene, character_nodes)
	return character_nodes

func _collect_character_nodes_recursive(node: Node, collection: Array) -> void:
	# 检查是否是角色节点（通常有CharacterArea或类似组件）
	if node.has_node("CharacterArea") or node.name.begins_with("Character") or node.name.begins_with("Enemy"):
		collection.append(node)
	
	# 递归检查子节点
	for child in node.get_children():
		_collect_character_nodes_recursive(child, collection)

# 🧹 清理效果
func _cleanup_effect(effect_node: Node) -> void:
	if is_instance_valid(effect_node):
		active_effects.erase(effect_node)
		effect_node.queue_free()

# 🧹 清理所有效果
func cleanup_all_effects() -> void:
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()
	print("🧹 [技能效果] 清理所有活跃效果")

func _exit_tree():
	cleanup_all_effects()

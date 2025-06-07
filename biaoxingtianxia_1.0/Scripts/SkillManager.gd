extends Node
class_name SkillManager

# 技能数据缓存
var skill_database: Dictionary = {}
var active_skill_selection: SkillData = null
var current_caster: GameCharacter = null

# 状态管理
enum SkillState {
	IDLE,
	SELECTING_SKILL,
	SELECTING_TARGET,
	EXECUTING_SKILL
}
var current_state: SkillState = SkillState.IDLE

# 调试开关
var debug_enabled: bool = false

# 🎬 技能效果系统
var skill_effects: Node2D = null

# 信号定义
signal skill_selection_started(caster: GameCharacter)
signal skill_selected(skill: SkillData)
signal skill_target_selected(skill: SkillData, targets: Array)
signal skill_execution_completed(skill: SkillData, results: Dictionary, caster: GameCharacter)
signal skill_cancelled()

func _ready():
	print("🎯 [技能系统] SkillManager初始化...")
	_load_skill_database()
	
	# 🎬 初始化技能效果系统
	_setup_skill_effects()
	
	# 添加到技能管理器组
	add_to_group("skill_manager")

# 加载技能数据库
func _load_skill_database():
	print("📚 [技能系统] 加载技能数据库...")
	
	# 确保DataManager已加载技能数据
	DataManager.load_data("skills")
	
	# 从DataManager获取技能数据
	var skills_data = DataManager.get_data("skills")
	if not skills_data or not skills_data is Array:
		print("⚠️ [技能系统] 未找到技能数据或数据格式错误")
		return
	
	# 解析技能数据
	for skill_row in skills_data:
		var skill = SkillData.new()
		skill.load_from_csv_row(skill_row)
		skill_database[skill.id] = skill
	
	print("✅ [技能系统] 技能数据库加载完成，共 %d 个技能" % skill_database.size())

# 获取角色可用技能列表
func get_available_skills(character: GameCharacter) -> Array:
	var available_skills = []
	
	# 🚀 修复：根据角色的技能学习配置获取可用技能
	print("🎯 [技能系统] 为角色 %s (等级%d) 获取可用技能" % [character.name, character.level])
	
	# 确保技能学习数据已加载
	DataManager.load_data("skill_learning")
	
	# 获取角色的技能学习配置
	var character_skill_learning = DataManager.get_character_skill_learning(character.id)
	
	print("🔍 [技能系统] 角色 %s 的技能学习配置: %d 条" % [character.name, character_skill_learning.size()])
	
	for learning_record in character_skill_learning:
		var skill_id = learning_record.get("skill_id", "")
		var learn_type = learning_record.get("learn_type", "")
		var learn_level = int(learning_record.get("learn_level", "0"))
		
		# 检查是否应该学会这个技能
		var should_learn = false
		
		match learn_type.to_upper():
			"INITIAL":
				# 初始学会的技能
				should_learn = true
				print("📚 [技能系统] %s 初始掌握技能: %s" % [character.name, skill_id])
			"LEVEL":
				# 等级学会的技能
				if character.level >= learn_level:
					should_learn = true
					print("📚 [技能系统] %s 等级%d学会技能: %s (需求等级%d)" % [character.name, character.level, skill_id, learn_level])
				else:
					print("📚 [技能系统] %s 等级不足，无法学会技能: %s (当前%d/需求%d)" % [character.name, skill_id, character.level, learn_level])
		
		# 如果应该学会，添加到可用技能列表
		if should_learn and skill_database.has(skill_id):
			var skill = skill_database[skill_id]
			available_skills.append(skill)
	
	print("✅ [技能系统] 角色 %s 最终可用技能数量: %d" % [character.name, available_skills.size()])
	return available_skills

# 开始技能选择流程
func start_skill_selection(character: GameCharacter) -> void:
	if current_state != SkillState.IDLE:
		print("⚠️ [技能系统] 无法开始技能选择，当前状态: %s" % SkillState.keys()[current_state])
		return
	
	current_caster = character
	current_state = SkillState.SELECTING_SKILL
	
	print("🎯 [技能系统] 开始为角色 %s 选择技能" % character.name)
	skill_selection_started.emit(character)

# 执行技能
func execute_skill(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("⚡ [技能系统] 开始执行技能: %s，施法者: %s，目标数量: %d" % [skill.name, caster.name, targets.size()])
	
	# 设置状态
	current_state = SkillState.EXECUTING_SKILL
	active_skill_selection = skill
	current_caster = caster
	
	# 执行技能逻辑
	await _execute_skill(targets)

# 内部技能执行方法
func _execute_skill(targets: Array) -> void:
	if not active_skill_selection or not current_caster:
		print("⚠️ [技能系统] 技能执行失败：缺少技能数据或施法者")
		return
	
	var skill = active_skill_selection
	var caster = current_caster
	
	print("🎯 [技能系统] 执行技能: %s" % skill.name)
	
	# 计算技能效果
	var results = []
	for target in targets:
		if target is GameCharacter:
			var damage = _calculate_skill_damage(skill, caster, target)
			# 应用伤害
			target.take_damage(damage)
			
			var result = {
				"target": target,
				"damage": damage,
				"type": "damage"
			}
			results.append(result)
			print("💥 [技能系统] 对 %s 造成 %d 点伤害" % [target.name, damage])

	# 播放技能效果（包括受击动画）
	await _play_skill_effects(skill, caster, targets)
	
	# 在动画播放完成后显示伤害数字
	for result in results:
		if result.type == "damage":
			_show_damage_numbers(result.target, result.damage)
	
	# 发出技能执行完成信号
	var results_dict = {"results": results}
	skill_execution_completed.emit(skill, results_dict, caster)
	
	# 重置状态
	current_state = SkillState.IDLE
	active_skill_selection = null
	current_caster = null
	
	print("✅ [技能系统] 技能执行完成: %s" % skill.name)

# 计算技能伤害
func _calculate_skill_damage(skill: SkillData, caster: GameCharacter, target: GameCharacter) -> int:
	# 基础伤害计算
	var base_damage = skill.base_damage
	var caster_attack = caster.attack
	var target_defense = target.defense
	
	# 简单的伤害计算公式
	var damage = base_damage + (caster_attack * 0.5) - (target_defense * 0.3)
	damage = max(1, int(damage))  # 确保至少造成1点伤害
	
	return damage

# 显示伤害数字
func _show_damage_numbers(target: GameCharacter, damage: int) -> void:
	# 查找技能效果系统
	var skill_effects = get_tree().get_first_node_in_group("skill_effects")
	if skill_effects and skill_effects.has_method("create_damage_numbers"):
		print("💥 [技能系统] 显示伤害数字: %s 受到 %d 点伤害" % [target.name, damage])
		skill_effects.create_damage_numbers(target, damage, false)
	else:
		print("⚠️ [技能系统] 未找到技能效果系统，无法显示伤害数字")
		# 尝试通过BattleVisualEffectsManager显示
		var visual_effects_manager = get_tree().get_first_node_in_group("battle_visual_effects")
		if visual_effects_manager and visual_effects_manager.has_method("create_damage_numbers"):
			print("💥 [技能系统] 通过视觉效果管理器显示伤害数字")
			visual_effects_manager.create_damage_numbers(target, damage, false)
		else:
			print("⚠️ [技能系统] 也未找到视觉效果管理器，跳过伤害数字显示")

# 播放技能效果
func _play_skill_effects(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	# 查找技能效果系统
	var skill_effects = get_tree().get_first_node_in_group("skill_effects")
	if skill_effects and skill_effects.has_method("play_skill_animation"):
		print("🎬 [技能系统] 播放技能动画效果")
		await skill_effects.play_skill_animation(skill, caster, targets)
	else:
		print("⚠️ [技能系统] 未找到技能效果系统，跳过动画")
		# 简单延迟模拟技能执行时间
		await get_tree().create_timer(1.0).timeout

# 🎬 技能效果系统
func _setup_skill_effects():
	# 从场景中获取SkillEffects节点
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene and battle_scene.has_node("SkillEffects"):
		print("✨ [技能系统] 找到场景中的SkillEffects节点")
	else:
		print("⚠️ [技能系统] 未找到SkillEffects节点，技能视觉效果将不可用")

# 🚀 重置技能管理器状态
func reset_state() -> void:
	print("🔄 [技能系统] 重置技能管理器状态")
	current_state = SkillState.IDLE
	active_skill_selection = null
	current_caster = null

# 🚀 取消技能选择
func cancel_skill_selection() -> void:
	print("❌ [技能系统] 取消技能选择")
	if current_state != SkillState.IDLE:
		reset_state()
		skill_cancelled.emit()
 

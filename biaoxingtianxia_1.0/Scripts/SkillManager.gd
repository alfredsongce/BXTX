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
func start_skill_selection(caster: GameCharacter) -> void:
	if current_state != SkillState.IDLE:
		print("⚠️ [技能系统] 技能系统正忙，无法开始新的技能选择")
		return
	
	current_caster = caster
	current_state = SkillState.SELECTING_SKILL
	
	print("🎯 [技能系统] 开始技能选择，施法者: %s" % caster.name)
	
	# 获取可用技能列表
	var available_skills = get_available_skills(caster)
	
	if available_skills.is_empty():
		print("⚠️ [技能系统] %s 没有可用技能" % caster.name)
		cancel_skill_selection()
		return
	
	# 🚀 第二阶段：使用技能选择UI
	_show_skill_selection_ui(available_skills)
	
	skill_selection_started.emit(caster)

# 显示技能选择UI
func _show_skill_selection_ui(available_skills: Array) -> void:
	# 🚀 使用新的可视化技能选择器
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("show_visual_skill_selection"):
		battle_scene.show_visual_skill_selection(current_caster, available_skills)
	else:
		print("⚠️ [技能系统] 无法显示可视化技能选择UI，回退到自动选择")
		# 回退到自动选择第一个技能
		if available_skills.size() > 0:
			select_skill(available_skills[0].id)

# 选择具体技能
func select_skill(skill_id: String) -> void:
	if current_state != SkillState.SELECTING_SKILL:
		print("⚠️ [技能系统] 当前状态不允许选择技能")
		return
	
	if not skill_database.has(skill_id):
		print("❌ [技能系统] 技能ID不存在: %s" % skill_id)
		cancel_skill_selection()
		return
	
	active_skill_selection = skill_database[skill_id]
	
	# 检查技能是否可用
	if not active_skill_selection.can_use(current_caster):
		print("⚠️ [技能系统] 技能无法使用: %s" % active_skill_selection.name)
		cancel_skill_selection()
		return
	
	print("✅ [技能系统] 选择技能: %s" % active_skill_selection.name)
	
	# 进入目标选择阶段
	current_state = SkillState.SELECTING_TARGET
	_start_target_selection()
	
	skill_selected.emit(active_skill_selection)

# 开始目标选择
func _start_target_selection() -> void:
	# 🚀 修复：添加空值检查避免字符串格式化错误
	if not active_skill_selection:
		print("❌ [技能系统] active_skill_selection为空，无法开始目标选择")
		cancel_skill_selection()
		return
	
	var targeting_type_name = "未知"
	if active_skill_selection.targeting_type >= 0 and active_skill_selection.targeting_type < SkillEnums.TargetingType.size():
		targeting_type_name = SkillEnums.TargetingType.keys()[active_skill_selection.targeting_type]
	
	print("🎯 [技能系统] 开始目标选择，技能类型: %s" % targeting_type_name)
	
	# 根据技能的目标选择类型处理
	match active_skill_selection.targeting_type:
		SkillEnums.TargetingType.SELF:
			# 自身技能，直接选择施法者
			if active_skill_selection.range_type == SkillEnums.RangeType.RANGE:
				# 自身范围技能，需要获取施法者周围的目标
				_execute_self_range_skill()
			else:
				# 单体自身技能
				_select_targets([current_caster])
		
		SkillEnums.TargetingType.NORMAL:
			# 普通型：显示范围内的合法目标
			_show_normal_targets()
		
		SkillEnums.TargetingType.PROJECTILE_SINGLE:
			# 弹道单点型：显示视线内的合法目标
			_show_projectile_single_targets()
		
		SkillEnums.TargetingType.PROJECTILE_PIERCE:
			# 弹道路径穿刺型：需要选择方向
			_show_projectile_pierce_targets()
		
		SkillEnums.TargetingType.FREE:
			# 自由型：选择任意位置释放（必须配合范围型）
			_show_free_position_targets()
		
		_:
			# 其他类型暂时未实现，使用普通型逻辑
			print("⚠️ [技能系统] 目标选择类型暂未实现，使用普通型逻辑")
			_show_normal_targets()

# 显示普通型目标
func _show_normal_targets() -> void:
	var valid_targets = _get_valid_targets_in_range()
	
	if valid_targets.is_empty():
		print("⚠️ [技能系统] 范围内没有合法目标")
		cancel_skill_selection()
		return
	
	print("🎯 [技能系统] 找到 %d 个合法目标" % valid_targets.size())
	
	# 🚀 第三阶段：使用目标选择UI
	_show_target_selection_ui(valid_targets)

# 显示弹道单点型目标
func _show_projectile_single_targets() -> void:
	# 暂时使用普通型逻辑
	_show_normal_targets()

# 显示目标选择UI
func _show_target_selection_ui(valid_targets: Array) -> void:
	# 通过信号通知BattleScene显示目标选择UI
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("show_target_selection_menu"):
		battle_scene.show_target_selection_menu(active_skill_selection, current_caster, valid_targets)
	else:
		print("⚠️ [技能系统] 无法显示目标选择UI，回退到自动选择")
		# 回退到自动选择第一个目标
		if valid_targets.size() > 0:
			_select_targets([valid_targets[0]])

# 获取范围内的合法目标
func _get_valid_targets_in_range() -> Array:
	var valid_targets = []
	var battle_scene = get_tree().current_scene
	
	if not battle_scene or not battle_scene.has_method("get_all_characters"):
		# 备用方案：从character_manager获取
		if battle_scene and battle_scene.get("character_manager"):
			return _get_targets_from_character_manager(battle_scene.character_manager)
		else:
			print("❌ [技能系统] 无法获取角色列表")
			return valid_targets
	
	var all_characters = battle_scene.get_all_characters()
	var caster_position = current_caster.position
	
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		# 跳过施法者自己（根据技能类型决定）
		if character == current_caster and active_skill_selection.target_type not in [SkillEnums.TargetType.SELF, SkillEnums.TargetType.ALLY, SkillEnums.TargetType.ALL]:
			continue
		
		# 检查目标类型匹配
		if not _is_valid_target_type(character):
			continue
		
		# 检查距离
		var distance = caster_position.distance_to(character.position)
		if distance > active_skill_selection.targeting_range:
			continue
		
		valid_targets.append(character)
	
	return valid_targets

# 从character_manager获取目标（备用方案）
func _get_targets_from_character_manager(character_manager: BattleCharacterManager) -> Array:
	var valid_targets = []
	var caster_position = current_caster.position
	
	if not character_manager:
		return valid_targets
	
	var all_characters = character_manager.get_all_characters()
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		# 跳过施法者自己（根据技能类型决定）
		if character == current_caster and active_skill_selection.target_type not in [SkillEnums.TargetType.SELF, SkillEnums.TargetType.ALLY, SkillEnums.TargetType.ALL]:
			continue
		
		# 检查目标类型匹配
		if not _is_valid_target_type(character):
			continue
		
		# 检查距离
		var distance = caster_position.distance_to(character.position)
		if distance > active_skill_selection.targeting_range:
			continue
		
		valid_targets.append(character)
	
	return valid_targets

# 检查目标类型是否匹配
func _is_valid_target_type(target: GameCharacter) -> bool:
	# 🚀 修复：添加空值检查，避免访问已重置的active_skill_selection
	if not active_skill_selection:
		print("⚠️ [技能系统] _is_valid_target_type: active_skill_selection为空")
		return false
	
	match active_skill_selection.target_type:
		SkillEnums.TargetType.SELF:
			return target == current_caster
		SkillEnums.TargetType.ENEMY:
			return current_caster.is_player_controlled() != target.is_player_controlled()
		SkillEnums.TargetType.ALLY:
			return current_caster.is_player_controlled() == target.is_player_controlled()
		SkillEnums.TargetType.ALLYONLY:
			# 友方专用：必须是友方但不能是自己
			return current_caster.is_player_controlled() == target.is_player_controlled() and target != current_caster
		SkillEnums.TargetType.ALL:
			return true
		_:
			return false

# 选择目标并执行技能
func _select_targets(targets: Array) -> void:
	if targets.is_empty():
		print("❌ [技能系统] 没有选择任何目标")
		cancel_skill_selection()
		return
	
	# 🚀 处理范围技能：如果是范围型技能，需要获取选中目标周围的所有角色
	var final_targets = []
	
	if active_skill_selection.range_type == SkillEnums.RangeType.RANGE:
		print("💥 [范围技能] 处理范围型技能效果")
		
		# 对于特殊的取目标方式处理
		match active_skill_selection.targeting_type:
			SkillEnums.TargetingType.PROJECTILE_PIERCE:
				# 弹道穿刺型：获取弹道路径上的所有目标
				if targets.size() > 0:
					var direction = (targets[0].position - current_caster.position).normalized()
					final_targets = _get_targets_on_projectile_path(current_caster.position, direction, active_skill_selection.targeting_range)
					# 过滤合法目标
					var valid_pierce_targets = []
					for target in final_targets:
						if _is_valid_target_type(target):
							valid_pierce_targets.append(target)
					final_targets = valid_pierce_targets
			
			SkillEnums.TargetingType.FREE:
				# 自由型：以选中位置为中心的范围效果
				if targets.size() > 0:
					var center_position = targets[0].position
					var area_targets = _get_targets_in_area(center_position, active_skill_selection.range_distance)
					# 过滤合法目标
					for target in area_targets:
						if _is_valid_target_type(target):
							final_targets.append(target)
			
			_:
				# 普通范围技能：以第一个目标为中心的范围效果
				if targets.size() > 0:
					var center_position = targets[0].position
					var area_targets = _get_targets_in_area(center_position, active_skill_selection.range_distance)
					# 过滤合法目标
					for target in area_targets:
						if _is_valid_target_type(target):
							final_targets.append(target)
	else:
		# 单体技能：直接使用选中的目标
		final_targets = targets
	
	# 确保最终目标列表不为空
	if final_targets.is_empty():
		print("⚠️ [技能系统] 技能效果范围内没有合法目标")
		cancel_skill_selection()
		return
	
	var target_names = []
	for target in final_targets:
		target_names.append(target.name)
	print("✅ [技能系统] 最终选择目标: %s" % str(target_names))
	
	current_state = SkillState.EXECUTING_SKILL
	skill_target_selected.emit(active_skill_selection, final_targets)
	
	# 执行技能
	_execute_skill(final_targets)

# 执行技能
func _execute_skill(targets: Array) -> void:
	print("⚡ [技能系统] 执行技能: %s" % active_skill_selection.name)
	
	# 🚀 消耗ActionSystem中的攻击点数
	var action_system = get_tree().current_scene.get_node_or_null("ActionSystem")
	if action_system:
		if not action_system.consume_action_points(current_caster, "skill"):
			print("⚠️ [技能系统] 无法消耗攻击点数，取消技能")
			cancel_skill_selection()
			return
	
	# 消耗MP
	current_caster.current_mp -= active_skill_selection.mp_cost
	
	var results = {
		"skill_name": active_skill_selection.name,
		"caster": current_caster.name,
		"targets": [],
		"total_damage": 0,
		"total_healing": 0
	}
	
	# 🎬 播放技能动画（等待动画完成）
	if skill_effects and skill_effects.has_method("play_skill_animation"):
		await skill_effects.play_skill_animation(active_skill_selection, current_caster, targets)
		print("🎬 [技能系统] 技能动画播放完成")
	else:
		# 如果没有动画系统，添加短暂延迟
		await get_tree().create_timer(0.3).timeout
	
	# 🚀 保存施法者引用，避免在应用技能效果时current_caster被重置
	var skill_caster = current_caster
	var skill_data = active_skill_selection
	
	# 对每个目标应用技能效果
	for target in targets:
		var target_result = _apply_skill_to_target(target, skill_caster, skill_data)
		results.targets.append(target_result)
		
		if target_result.has("damage"):
			results.total_damage += target_result.damage
		if target_result.has("healing"):
			results.total_healing += target_result.healing
	
	print("✅ [技能系统] 技能执行完成")
	
	# 重置状态
	_reset_skill_state()
	
	# 发出技能执行完成信号
	skill_execution_completed.emit(skill_data, results, skill_caster)

# 对单个目标应用技能效果
func _apply_skill_to_target(target: GameCharacter, caster: GameCharacter, skill: SkillData) -> Dictionary:
	var result = {
		"target_name": target.name,
		"effects": []
	}
	
	# 🚀 修复：添加空值检查，避免访问null的skill对象
	if not skill:
		print("⚠️ [技能系统] _apply_skill_to_target: skill参数为空")
		result.effects.append("技能数据错误")
		return result
	
	# 🚀 根据技能目标类型决定效果
	match skill.target_type:
		SkillEnums.TargetType.ENEMY:
			# 敌方型：造成伤害
			var damage_data = _calculate_damage_with_crit(caster, target, skill)
			var damage = damage_data.damage
			var is_critical = damage_data.is_critical
			
			target.take_damage(damage)
			
			# 🎬 显示伤害数字
			if skill_effects and skill_effects.has_method("create_damage_numbers"):
				print("🎬 [调试] ==== SkillManager调用伤害跳字 ====")
				print("🎬 [调试] 敌方伤害 - 目标: %s, 伤害: %d, 暴击: %s" % [target.name, damage, is_critical])
				print("🎬 [调试] 目标是否存活: %s" % target.is_alive())
				print("🎬 [调试] skill_effects节点: %s" % skill_effects.get_path())
				print("🎬 [调试] 当前时间: %s" % Time.get_datetime_string_from_system())
				skill_effects.create_damage_numbers(target, damage, is_critical)
				print("🎬 [调试] 伤害跳字调用完成")
			else:
				print("⚠️ [调试] skill_effects为空或没有create_damage_numbers方法")
			
			result.damage = damage
			result.is_critical = is_critical
			result.effects.append("造成 %d 点伤害%s" % [damage, " (暴击!)" if is_critical else ""])
			
			print("💥 [技能系统] %s 对 %s 造成 %d 点伤害%s" % [caster.name, target.name, damage, " (暴击!)" if is_critical else ""])
			
			# 检查目标是否死亡
			if not target.is_alive():
				result.effects.append("目标被击败")
				print("💀 [技能系统] %s 被击败" % target.name)
				# 🚀 新增：通知BattleScene处理角色死亡
				_notify_character_death(target)
		
		SkillEnums.TargetType.ALLY, SkillEnums.TargetType.ALLYONLY, SkillEnums.TargetType.SELF:
			# 友方型、自身型和友方专用型：治疗效果
			var healing = _calculate_healing(caster, target, skill)
			target.heal(healing)
			
			# 🎬 显示治疗数字
			if skill_effects and skill_effects.has_method("create_healing_numbers"):
				print("🎬 [调试] 治疗效果 - 目标: %s, 治疗: %d" % [target.name, healing])
				skill_effects.create_healing_numbers(target, healing)
			else:
				print("⚠️ [调试] skill_effects为空或没有create_healing_numbers方法")
			
			result.healing = healing
			result.effects.append("恢复 %d 点生命值" % healing)
			
			print("💚 [技能系统] %s 为 %s 恢复 %d 点生命值" % [caster.name, target.name, healing])
		
		SkillEnums.TargetType.ALL:
			# 无视敌我型：根据实际关系决定效果
			if caster.is_player_controlled() != target.is_player_controlled():
				# 对敌人造成伤害
				var damage_data = _calculate_damage_with_crit(caster, target, skill)
				var damage = damage_data.damage
				var is_critical = damage_data.is_critical
				
				target.take_damage(damage)
				
				# 🎬 显示伤害数字
				if skill_effects and skill_effects.has_method("create_damage_numbers"):
					print("🎬 [调试] ==== SkillManager调用伤害跳字 ====")
					print("🎬 [调试] 敌方伤害 - 目标: %s, 伤害: %d, 暴击: %s" % [target.name, damage, is_critical])
					print("🎬 [调试] 目标是否存活: %s" % target.is_alive())
					print("🎬 [调试] skill_effects节点: %s" % skill_effects.get_path())
					print("🎬 [调试] 当前时间: %s" % Time.get_datetime_string_from_system())
					skill_effects.create_damage_numbers(target, damage, is_critical)
					print("🎬 [调试] 伤害跳字调用完成")
				else:
					print("⚠️ [调试] skill_effects为空或没有create_damage_numbers方法")
				
				result.damage = damage
				result.is_critical = is_critical
				result.effects.append("造成 %d 点伤害%s" % [damage, " (暴击!)" if is_critical else ""])
				
				print("💥 [技能系统] %s 对敌人 %s 造成 %d 点伤害%s" % [caster.name, target.name, damage, " (暴击!)" if is_critical else ""])
				
				if not target.is_alive():
					result.effects.append("目标被击败")
					print("💀 [技能系统] %s 被击败" % target.name)
					# 🚀 新增：通知BattleScene处理角色死亡
					_notify_character_death(target)
			else:
				# 对友方造成伤害（无视敌我的负面效果）
				var damage_data = _calculate_damage_with_crit(caster, target, skill)
				var damage = damage_data.damage
				var is_critical = damage_data.is_critical
				
				target.take_damage(damage)
				
				# 🎬 显示伤害数字
				if skill_effects and skill_effects.has_method("create_damage_numbers"):
					print("🎬 [调试] ==== SkillManager调用伤害跳字 ====")
					print("🎬 [调试] 友方误伤 - 目标: %s, 伤害: %d, 暴击: %s" % [target.name, damage, is_critical])
					print("🎬 [调试] 目标是否存活: %s" % target.is_alive())
					print("🎬 [调试] skill_effects节点: %s" % skill_effects.get_path())
					print("🎬 [调试] 当前时间: %s" % Time.get_datetime_string_from_system())
					skill_effects.create_damage_numbers(target, damage, is_critical)
					print("🎬 [调试] 伤害跳字调用完成")
				else:
					print("⚠️ [调试] skill_effects为空或没有create_damage_numbers方法")
				
				result.damage = damage
				result.is_critical = is_critical
				result.effects.append("误伤造成 %d 点伤害%s" % [damage, " (暴击!)" if is_critical else ""])
				
				print("💥 [技能系统] %s 误伤友方 %s 造成 %d 点伤害%s" % [caster.name, target.name, damage, " (暴击!)" if is_critical else ""])
				
				if not target.is_alive():
					result.effects.append("友方被误伤击败")
					print("💀 [技能系统] 友方 %s 被误伤击败" % target.name)
					# 🚀 新增：通知BattleScene处理角色死亡
					_notify_character_death(target)
	
	return result

# 🎯 计算伤害（带暴击）
func _calculate_damage_with_crit(attacker: GameCharacter, target: GameCharacter, skill: SkillData) -> Dictionary:
	# 🚀 第一阶段：使用简单的伤害公式
	var base_damage = attacker.attack - target.defense
	base_damage = max(1, base_damage)
	
	# 技能伤害加成
	if skill.base_damage > 0:
		base_damage += skill.base_damage
	
	# 🎯 暴击判断（10%几率）
	var is_critical = randf() < 0.1
	if is_critical:
		base_damage = int(base_damage * 2.0)  # 暴击双倍伤害
	
	# 添加随机因素 (±20%)
	var random_factor = randf_range(0.8, 1.2)
	var final_damage = int(base_damage * random_factor)
	
	return {
		"damage": max(1, final_damage),
		"is_critical": is_critical
	}

# 计算治疗量
func _calculate_healing(caster: GameCharacter, target: GameCharacter, skill: SkillData) -> int:
	# 🚀 第一阶段：简单的治疗公式
	var base_healing = caster.attack / 2  # 使用攻击力的一半作为治疗基数
	
	if skill.base_damage > 0:
		base_healing = skill.base_damage
	
	# 添加随机因素 (±10%)
	var random_factor = randf_range(0.9, 1.1)
	var final_healing = int(base_healing * random_factor)
	
	return max(1, final_healing)

# 取消技能选择
func cancel_skill_selection() -> void:
	print("❌ [技能系统] 取消技能选择")
	_reset_skill_state()
	skill_cancelled.emit()

# 重置技能状态
func _reset_skill_state() -> void:
	current_state = SkillState.IDLE
	active_skill_selection = null
	current_caster = null

# 公共重置状态方法（供BattleEventManager调用）
func reset_state() -> void:
	print("🔄 [技能管理器] 重置技能状态")
	_reset_skill_state()

# 公共执行技能方法（供BattleEventManager调用）
func execute_skill(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("⚡ [技能管理器] 执行技能: %s，施法者: %s，目标数量: %d" % [skill.name, caster.name, targets.size()])
	
	# 🚀 防止重复执行：检查当前状态
	if current_state == SkillState.EXECUTING_SKILL:
		print("⚠️ [技能管理器] 技能正在执行中，忽略重复调用")
		return
	
	# 设置当前技能和施法者
	active_skill_selection = skill
	current_caster = caster
	current_state = SkillState.EXECUTING_SKILL
	
	# 执行技能
	_execute_skill(targets)

# 🚀 范围技能支持方法

# 执行自身范围技能（如冰霜新星）
func _execute_self_range_skill() -> void:
	print("❄️ [范围技能] 执行自身范围技能: %s" % active_skill_selection.name)
	
	# 获取施法者周围范围内的所有目标
	var targets_in_range = _get_targets_in_area(current_caster.position, active_skill_selection.range_distance)
	
	# 过滤合法目标
	var valid_targets = []
	for target in targets_in_range:
		if _is_valid_target_type(target):
			valid_targets.append(target)
	
	if valid_targets.is_empty():
		print("⚠️ [范围技能] 范围内没有合法目标")
		cancel_skill_selection()
		return
	
	print("✅ [范围技能] 找到 %d 个范围内的目标" % valid_targets.size())
	_select_targets(valid_targets)

# 显示弹道穿刺型目标选择
func _show_projectile_pierce_targets() -> void:
	print("⚡ [弹道穿刺] 显示方向选择UI")
	
	# 🚀 第一阶段：简化实现，获取射程内的所有合法目标让玩家选择起始方向
	var valid_targets = _get_valid_targets_in_range()
	
	if valid_targets.is_empty():
		print("⚠️ [弹道穿刺] 射程内没有合法目标")
		cancel_skill_selection()
		return
	
	print("⚡ [弹道穿刺] 找到 %d 个射程内的目标，选择方向" % valid_targets.size())
	
	# 🚀 暂时使用普通目标选择UI，后续可以扩展为方向选择
	_show_target_selection_ui(valid_targets)

# 显示自由位置目标选择
func _show_free_position_targets() -> void:
	print(" [自由目标] 显示位置选择UI")
	
	# 🚀 第一阶段：简化实现，获取射程内的所有合法目标作为位置参考
	var valid_targets = _get_valid_targets_in_range()
	
	if valid_targets.is_empty():
		print("⚠️ [自由目标] 射程内没有可参考目标")
		# 对于自由型技能，即使没有目标也可以释放到空地
		# 暂时取消，后续实现地面点击选择
		cancel_skill_selection()
		return
	
	print("🎯 [自由目标] 找到 %d 个可参考位置" % valid_targets.size())
	
	# 🚀 暂时使用普通目标选择UI，后续可以扩展为地面位置选择
	_show_target_selection_ui(valid_targets)

# 获取指定区域内的所有角色
func _get_targets_in_area(center_position: Vector2, radius: float) -> Array:
	var targets_in_area = []
	var battle_scene = get_tree().current_scene
	
	if not battle_scene or not battle_scene.has_method("get_all_characters"):
		# 备用方案：从character_manager获取
		if battle_scene and battle_scene.get("character_manager"):
			return _get_area_targets_from_character_manager(battle_scene.character_manager, center_position, radius)
		else:
			print("❌ [范围技能] 无法获取角色列表")
			return targets_in_area
	
	var all_characters = battle_scene.get_all_characters()
	
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		# 检查是否在范围内
		var distance = center_position.distance_to(character.position)
		if distance <= radius:
			targets_in_area.append(character)
	
	return targets_in_area

# 从character_manager获取区域内目标（备用方案）
func _get_area_targets_from_character_manager(character_manager: BattleCharacterManager, center_position: Vector2, radius: float) -> Array:
	var targets_in_area = []
	
	if not character_manager:
		return targets_in_area
	
	var all_characters = character_manager.get_all_characters()
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		# 检查是否在范围内
		var distance = center_position.distance_to(character.position)
		if distance <= radius:
			targets_in_area.append(character)
	
	return targets_in_area

# 获取弹道路径上的所有目标
func _get_targets_on_projectile_path(start_position: Vector2, direction: Vector2, max_distance: float) -> Array:
	var targets_on_path = []
	var battle_scene = get_tree().current_scene
	
	if not battle_scene or not battle_scene.has_method("get_all_characters"):
		print("❌ [弹道穿刺] 无法获取角色列表")
		return targets_on_path
	
	var all_characters = battle_scene.get_all_characters()
	
	for character in all_characters:
		if not character or not character.is_alive():
			continue
		
		# 检查角色是否在弹道路径上
		if _is_character_on_projectile_path(start_position, direction, max_distance, character.position):
			targets_on_path.append(character)
	
	# 按距离排序，近的在前
	targets_on_path.sort_custom(func(a, b): 
		return start_position.distance_to(a.position) < start_position.distance_to(b.position)
	)
	
	return targets_on_path

# 检查角色是否在弹道路径上
func _is_character_on_projectile_path(start_pos: Vector2, direction: Vector2, max_distance: float, char_pos: Vector2) -> bool:
	# 计算角色相对于起始位置的向量
	var to_char = char_pos - start_pos
	
	# 检查距离是否在射程内
	if to_char.length() > max_distance:
		return false
	
	# 计算投影长度（角色在射线方向上的投影）
	var projection_length = to_char.dot(direction.normalized())
	
	# 如果投影长度为负，说明角色在起始位置后方
	if projection_length < 0:
		return false
	
	# 计算角色到射线的距离
	var projection_point = start_pos + direction.normalized() * projection_length
	var distance_to_line = char_pos.distance_to(projection_point)
	
	# 如果距离射线太远（这里使用32像素作为容差），则不在路径上
	return distance_to_line <= 32.0

# 切换调试模式
func toggle_debug() -> void:
	debug_enabled = not debug_enabled
	print("🔧 [技能系统] 调试模式: %s" % ("开启" if debug_enabled else "关闭"))

# 获取技能信息（用于UI显示）
func get_skill_info(skill_id: String) -> Dictionary:
	if skill_database.has(skill_id):
		return skill_database[skill_id].get_display_info()
	else:
		return {}

# 检查技能系统状态
func is_busy() -> bool:
	return current_state != SkillState.IDLE 

# 🎬 技能效果系统
func _setup_skill_effects():
	# 从场景中获取SkillEffects节点
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_node("SkillEffects"):
		skill_effects = battle_scene.get_node("SkillEffects")
		print("✨ [技能系统] 找到场景中的SkillEffects节点")
	else:
		print("⚠️ [技能系统] 未找到SkillEffects节点，技能视觉效果将不可用")
		skill_effects = null

# 🎬 技能效果系统
func apply_skill_effects(skill: SkillData, targets: Array) -> void:
	if skill_effects and skill_effects.has_method("apply_effects"):
		skill_effects.apply_effects(skill, targets)

# 🚀 新增：通知BattleScene处理角色死亡
func _notify_character_death(target: GameCharacter) -> void:
	var battle_scene = get_tree().current_scene
	if battle_scene:
		if battle_scene.battle_visual_effects_manager:
			battle_scene.battle_visual_effects_manager.handle_character_death_visuals(target)
		elif battle_scene.has_method("_handle_character_death"):
			battle_scene._handle_character_death(target)
 

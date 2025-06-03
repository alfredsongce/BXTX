# BattleAIManager.gd
# AI决策和行动管理器
# 负责处理AI角色的决策逻辑、行动策略和目标选择

class_name BattleAIManager
extends Node

# 信号定义
signal ai_action_completed(ai_character: GameCharacter, result: Dictionary)
signal ai_turn_started(ai_character: GameCharacter)
signal ai_decision_made(ai_character: GameCharacter, decision: Dictionary)

# AI策略枚举
enum AIStrategy {
	AGGRESSIVE,    # 激进：优先攻击
	DEFENSIVE,     # 防御：优先移动到安全位置
	BALANCED,      # 平衡：移动+攻击
	OPPORTUNISTIC  # 机会主义：根据情况选择最优行动
}

# 组件引用
var character_manager: Node
var action_system: Node
var battle_combat_manager: Node
var movement_coordinator: Node
var battle_animation_manager: Node

# AI配置
var ai_config = {
	"default_strategy": AIStrategy.BALANCED,
	"move_range_factor": 0.8,  # 移动范围系数
	"attack_priority_threshold": 0.7,  # 攻击优先级阈值
	"safety_distance": 120.0,  # 安全距离
	"decision_delay": 0.5  # 决策延迟（秒）
}

# 初始化
func _ready() -> void:
	name = "BattleAIManager"
	print("✅ [AI管理器] BattleAIManager 初始化完成")

# 设置组件引用
func setup_references(refs: Dictionary) -> void:
	character_manager = refs.get("character_manager")
	action_system = refs.get("action_system")
	battle_combat_manager = refs.get("battle_combat_manager")
	movement_coordinator = refs.get("movement_coordinator")
	battle_animation_manager = refs.get("battle_animation_manager")
	
	print("🔗 [AI管理器] 组件引用设置完成")

# 🚀 执行完整的AI回合
func execute_ai_turn(ai_character: GameCharacter) -> void:
	print("🤖 [AI管理器] 开始执行 %s 的回合" % ai_character.name)
	
	# 发出AI回合开始信号
	ai_turn_started.emit(ai_character)
	
	# 添加决策延迟，让玩家看到AI在"思考"
	await get_tree().create_timer(ai_config.decision_delay).timeout
	
	# 分析当前情况并制定策略
	var decision = _make_ai_decision(ai_character)
	print("🧠 [AI管理器] %s 的决策: %s" % [ai_character.name, decision.description])
	
	# 发出AI决策信号
	ai_decision_made.emit(ai_character, decision)
	
	# 执行决策
	var result = await _execute_ai_decision(ai_character, decision)
	
	# 发出AI行动完成信号
	ai_action_completed.emit(ai_character, result)

# 🚀 AI决策制定
func _make_ai_decision(ai_character: GameCharacter) -> Dictionary:
	print("🧠 [AI管理器] %s 开始制定决策..." % ai_character.name)
	
	# 分析行动能力
	var can_move = false
	var can_attack = false
	
	if action_system:
		can_move = action_system.can_character_perform_action(ai_character, "move")
		can_attack = action_system.can_character_perform_action(ai_character, "skill")
	
	print("🔍 [AI管理器] %s 行动能力 - 移动: %s, 攻击: %s" % [ai_character.name, can_move, can_attack])
	
	# 分析战场情况
	var battlefield_analysis = _analyze_battlefield(ai_character)
	
	# 根据策略和情况制定决策
	var strategy = _determine_strategy(ai_character, battlefield_analysis)
	var decision = _create_decision_plan(ai_character, strategy, battlefield_analysis, can_move, can_attack)
	
	return decision

# 🚀 分析战场情况
func _analyze_battlefield(ai_character: GameCharacter) -> Dictionary:
	var analysis = {
		"enemies": [],
		"closest_enemy": null,
		"closest_distance": 999999.0,
		"weakest_enemy": null,
		"ai_health_ratio": 1.0,
		"threat_level": 0.0
	}
	
	# 获取敌方目标
	var enemy_targets = _get_enemy_targets(ai_character)
	analysis.enemies = enemy_targets
	
	# 分析最近和最弱的敌人
	var current_pos = ai_character.position
	for enemy in enemy_targets:
		if not enemy or not enemy.is_alive():
			continue
		
		# 计算距离
		var distance = current_pos.distance_to(enemy.position)
		if distance < analysis.closest_distance:
			analysis.closest_distance = distance
			analysis.closest_enemy = enemy
		
		# 找最弱的敌人（血量最少）
		if not analysis.weakest_enemy or enemy.current_hp < analysis.weakest_enemy.current_hp:
			analysis.weakest_enemy = enemy
	
	# 计算AI自身状态
	analysis.ai_health_ratio = float(ai_character.current_hp) / float(ai_character.max_hp)
	
	# 计算威胁等级（基于敌人数量和距离）
	analysis.threat_level = min(1.0, enemy_targets.size() * 0.3 + (1.0 - analysis.closest_distance / 500.0))
	
	return analysis

# 🚀 确定AI策略
func _determine_strategy(ai_character: GameCharacter, analysis: Dictionary) -> AIStrategy:
	# 根据血量和威胁等级动态调整策略
	var health_ratio = analysis.ai_health_ratio
	var threat_level = analysis.threat_level
	
	if health_ratio < 0.3:  # 血量很低
		return AIStrategy.DEFENSIVE
	elif health_ratio > 0.8 and threat_level < 0.5:  # 血量充足且威胁较低
		return AIStrategy.AGGRESSIVE
	elif analysis.enemies.size() == 1 and analysis.weakest_enemy and analysis.weakest_enemy.current_hp < ai_character.attack:
		return AIStrategy.OPPORTUNISTIC  # 可以一击击败敌人
	else:
		return AIStrategy.BALANCED

# 🚀 创建决策计划
func _create_decision_plan(ai_character: GameCharacter, strategy: AIStrategy, analysis: Dictionary, can_move: bool, can_attack: bool) -> Dictionary:
	var plan = {
		"strategy": strategy,
		"actions": [],
		"description": "",
		"priority_target": null,
		"move_target": null
	}
	
	match strategy:
		AIStrategy.AGGRESSIVE:
			plan.description = "激进攻击策略"
			plan.priority_target = analysis.closest_enemy
			if can_attack and analysis.closest_enemy:
				plan.actions.append("attack")
			if can_move:
				plan.actions.append("move_closer")
				plan.move_target = _calculate_aggressive_position(ai_character, analysis.closest_enemy)
		
		AIStrategy.DEFENSIVE:
			plan.description = "防御策略"
			if can_move:
				plan.actions.append("move_safe")
				plan.move_target = _calculate_safe_position(ai_character, analysis.enemies)
			if can_attack and analysis.closest_enemy and analysis.closest_distance < 200:
				plan.actions.append("attack")
				plan.priority_target = analysis.closest_enemy
		
		AIStrategy.OPPORTUNISTIC:
			plan.description = "机会主义策略"
			plan.priority_target = analysis.weakest_enemy
			if can_attack and analysis.weakest_enemy:
				plan.actions.append("attack")
			if can_move:
				plan.actions.append("move_optimal")
				plan.move_target = _calculate_optimal_position(ai_character, analysis.weakest_enemy)
		
		AIStrategy.BALANCED:
			plan.description = "平衡策略"
			plan.priority_target = analysis.closest_enemy if analysis.closest_enemy else analysis.weakest_enemy
			if can_move:
				plan.actions.append("move")
				plan.move_target = _calculate_balanced_position(ai_character, analysis)
			if can_attack and plan.priority_target:
				plan.actions.append("attack")
	
	# 如果没有可执行的行动，选择休息
	if plan.actions.is_empty():
		plan.actions.append("rest")
		plan.description = "休息恢复"
	
	return plan

# 🚀 执行AI决策
func _execute_ai_decision(ai_character: GameCharacter, decision: Dictionary) -> Dictionary:
	var actions_performed = []
	var total_damage_dealt = 0
	var targets_defeated = []
	var has_moved = false
	
	print("🎯 [AI管理器] 执行决策: %s" % decision.description)
	print("📋 [AI管理器] 计划行动顺序: %s" % str(decision.actions))
	
	# 按顺序执行行动
	for i in range(decision.actions.size()):
		var action = decision.actions[i]
		print("🎬 [AI管理器] 执行第%d个行动: %s" % [i + 1, action])
		
		match action:
			"move", "move_closer", "move_safe", "move_optimal":
				print("🚶 [AI管理器] 开始执行移动行动")
				if decision.move_target:
					has_moved = await _execute_ai_move(ai_character, decision.move_target)
					if has_moved:
						actions_performed.append("移动")
						print("✅ [AI管理器] 移动行动完成")
					else:
						print("❌ [AI管理器] 移动行动失败")
				else:
					print("⚠️ [AI管理器] 没有移动目标，跳过移动")
			
			"attack":
				print("⚔️ [AI管理器] 开始执行攻击行动")
				if decision.priority_target:
					var attack_result = await _execute_ai_attack(ai_character, decision.priority_target)
					if attack_result.success:
						actions_performed.append("攻击")
						total_damage_dealt += attack_result.damage
						if attack_result.target_defeated:
							targets_defeated.append(decision.priority_target)
						print("✅ [AI管理器] 攻击行动完成")
					else:
						print("❌ [AI管理器] 攻击行动失败")
				else:
					print("⚠️ [AI管理器] 没有攻击目标，跳过攻击")
			
			"rest":
				print("😴 [AI管理器] 执行休息行动")
				actions_performed.append("休息")
				# 可以在这里添加休息效果，比如恢复少量HP或MP
	
	# 创建综合结果
	var final_result = {
		"type": "ai_turn_complete",
		"success": true,
		"message": _generate_action_description(actions_performed, total_damage_dealt, targets_defeated),
		"actions": actions_performed,
		"damage_dealt": total_damage_dealt,
		"targets_defeated": targets_defeated,
		"strategy_used": decision.strategy
	}
	
	print("✅ [AI管理器] %s 回合完成: %s" % [ai_character.name, final_result.message])
	return final_result

# 🚀 执行AI移动
func _execute_ai_move(ai_character: GameCharacter, target_position: Vector2) -> bool:
	# 如果目标位置为零向量，则由AI管理器计算最佳位置
	if target_position == Vector2.ZERO:
		var analysis = _analyze_battlefield(ai_character)
		var strategy = _determine_strategy(ai_character, analysis)
		target_position = _calculate_move_position_by_strategy(ai_character, strategy, analysis)
	
	print("🚶 [AI管理器] %s 移动到: %s" % [ai_character.name, target_position])
	
	# 消耗移动点数
	if action_system and not action_system.consume_action_points(ai_character, "move"):
		print("⚠️ [AI管理器] 移动点数不足")
		return false
	
	# 执行移动
	if movement_coordinator:
		print("🎬 [AI管理器] 开始移动动画...")
		var success = await movement_coordinator.move_character_direct(ai_character, target_position)
		if success:
			print("✅ [AI管理器] %s 移动完成" % ai_character.name)
			return true
		else:
			print("❌ [AI管理器] %s 移动失败" % ai_character.name)
	
	return false

# 🚀 根据策略计算移动位置
func _calculate_move_position_by_strategy(ai_character: GameCharacter, strategy: AIStrategy, analysis: Dictionary) -> Vector2:
	match strategy:
		AIStrategy.AGGRESSIVE:
			return _calculate_aggressive_position(ai_character, analysis.closest_enemy)
		AIStrategy.DEFENSIVE:
			return _calculate_safe_position(ai_character, analysis.enemies)
		AIStrategy.OPPORTUNISTIC:
			return _calculate_optimal_position(ai_character, analysis.weakest_enemy)
		AIStrategy.BALANCED:
			return _calculate_balanced_position(ai_character, analysis)
		_:
			return ai_character.position  # 默认不移动

# 🚀 执行AI攻击
func _execute_ai_attack(ai_character: GameCharacter, target: GameCharacter) -> Dictionary:
	var result = {"success": false, "damage": 0, "target": target.name, "target_defeated": false}
	
	if not ai_character or not target:
		print("⚠️ [AI管理器] 攻击参数无效")
		return result
	
	print("⚔️ [AI管理器] %s 攻击 %s" % [ai_character.name, target.name])
	
	# 检查行动点数
	if action_system and not action_system.consume_action_points(ai_character, "skill"):
		print("⚠️ [AI管理器] 攻击点数不足")
		return result
	
	# 调用战斗管理器执行攻击
	if battle_combat_manager:
		var attack_result = await battle_combat_manager.execute_attack(ai_character, target)
		if attack_result and attack_result.has("success"):
			return attack_result
		else:
			print("⚠️ [AI管理器] 战斗管理器攻击返回无效结果")
	else:
		print("⚠️ [AI管理器] 战斗管理器不可用，使用简化攻击逻辑")
		# 简化的攻击逻辑
		var damage = _calculate_simple_damage(ai_character, target)
		target.take_damage(damage)
		
		result.success = true
		result.damage = damage
		result.target_defeated = not target.is_alive()
		
		print("💥 [AI管理器] 造成 %d 点伤害，%s 剩余HP: %d/%d" % [damage, target.name, target.current_hp, target.max_hp])
		
		if result.target_defeated:
			print("💀 [AI管理器] %s 被击败！" % target.name)
	
	return result

# 🚀 简化的伤害计算
func _calculate_simple_damage(attacker: GameCharacter, target: GameCharacter) -> int:
	if not attacker or not target:
		return 0
	
	# 基础伤害 = 攻击者攻击力 - 目标防御力
	var base_damage = max(1, attacker.attack - target.defense)
	# 添加随机性 (80%-120%)
	var random_factor = randf_range(0.8, 1.2)
	return int(base_damage * random_factor)

# 🚀 获取敌方目标
func _get_enemy_targets(ai_character: GameCharacter) -> Array:
	var targets = []
	
	if character_manager:
		var all_characters = character_manager.get_all_characters()
		for character in all_characters:
			if character.is_alive() and character.is_player_controlled() != ai_character.is_player_controlled():
				targets.append(character)
	
	return targets

# 🚀 计算激进位置（接近敌人）
func _calculate_aggressive_position(ai_character: GameCharacter, target: GameCharacter) -> Vector2:
	var current_pos = ai_character.position
	var target_pos = target.position
	
	# 朝目标方向移动，但保持攻击距离
	var direction = (target_pos - current_pos).normalized()
	var move_distance = min(ai_character.qinggong_skill * ai_config.move_range_factor, 
							current_pos.distance_to(target_pos) - 100)
	
	return current_pos + direction * max(50, move_distance)

# 🚀 计算安全位置（远离敌人）
func _calculate_safe_position(ai_character: GameCharacter, enemies: Array) -> Vector2:
	var current_pos = ai_character.position
	var safe_direction = Vector2.ZERO
	
	# 计算远离所有敌人的方向
	for enemy in enemies:
		if enemy and enemy.is_alive():
			var away_direction = (current_pos - enemy.position).normalized()
			safe_direction += away_direction
	
	if safe_direction.length() > 0:
		safe_direction = safe_direction.normalized()
		var move_distance = ai_character.qinggong_skill * ai_config.move_range_factor
		return current_pos + safe_direction * move_distance
	
	return current_pos

# 🚀 计算最优位置（针对特定目标）
func _calculate_optimal_position(ai_character: GameCharacter, target: GameCharacter) -> Vector2:
	var current_pos = ai_character.position
	var target_pos = target.position
	
	# 移动到最佳攻击位置
	var direction = (target_pos - current_pos).normalized()
	var optimal_distance = 150.0  # 最佳攻击距离
	var current_distance = current_pos.distance_to(target_pos)
	
	if current_distance > optimal_distance:
		# 太远，需要接近
		var move_distance = min(ai_character.qinggong_skill * ai_config.move_range_factor,
								current_distance - optimal_distance)
		return current_pos + direction * move_distance
	else:
		# 已经在合适距离，稍微调整位置
		var perpendicular = Vector2(-direction.y, direction.x)
		return current_pos + perpendicular * 50

# 🚀 计算平衡位置
func _calculate_balanced_position(ai_character: GameCharacter, analysis: Dictionary) -> Vector2:
	var current_pos = ai_character.position
	
	if analysis.closest_enemy:
		var target_pos = analysis.closest_enemy.position
		var distance = analysis.closest_distance
		
		if distance > 200:  # 太远，接近一些
			return _calculate_aggressive_position(ai_character, analysis.closest_enemy)
		elif distance < 100:  # 太近，拉开距离
			return _calculate_safe_position(ai_character, [analysis.closest_enemy])
		else:  # 距离合适，保持位置或稍作调整
			return current_pos
	
	return current_pos

# 🚀 生成行动描述
func _generate_action_description(actions: Array, damage: int, defeated: Array) -> String:
	if actions.is_empty():
		return "选择了休息恢复"
	
	var action_desc = _join_string_array(actions)
	
	if damage > 0:
		action_desc += "，造成了%d点伤害" % damage
	
	if defeated.size() > 0:
		var defeated_desc = _join_string_array(defeated)
		action_desc += "，击败了%s" % defeated_desc
	
	return "完成了%s" % action_desc

# 🚀 辅助方法：拼接字符串数组
func _join_string_array(arr: Array, delimiter: String = "、", final_delimiter: String = "和") -> String:
	if arr.is_empty():
		return ""
	elif arr.size() == 1:
		return str(arr[0])
	elif arr.size() == 2:
		return str(arr[0]) + final_delimiter + str(arr[1])
	else:
		var result = str(arr[0])
		for i in range(1, arr.size() - 1):
			result += delimiter + str(arr[i])
		result += final_delimiter + str(arr[-1])
		return result

# 🚀 设置AI配置
func set_ai_config(config: Dictionary) -> void:
	for key in config:
		if ai_config.has(key):
			ai_config[key] = config[key]
	
	print("🔧 [AI管理器] AI配置已更新")

# 🚀 获取AI配置
func get_ai_config() -> Dictionary:
	return ai_config.duplicate()

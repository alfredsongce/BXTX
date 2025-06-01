# 核心战斗逻辑管理器
# 负责处理攻击计算、伤害计算、胜负判定等核心战斗功能

class_name BattleCombatManager
extends Node

# 信号定义
signal combat_action_completed(character: GameCharacter, result: Dictionary)
signal victory_condition_met(victory_type: String, details: Dictionary)
signal character_defeated(character: GameCharacter)
signal damage_calculated(attacker: GameCharacter, target: GameCharacter, damage: int)

# 组件引用
var character_manager: Node
var action_system: Node
var battle_manager: Node
var battle_animation_manager: Node
var battle_visual_effects_manager: Node
var battle_input_handler: Node
var battle_ui_manager: Node

# 战斗统计
var combat_stats = {
	"total_damage_dealt": 0,
	"total_attacks": 0,
	"defeated_characters": [],
	"battle_duration": 0.0
}

# 初始化
func _ready() -> void:
	name = "BattleCombatManager"
	print("✅ [战斗管理器] BattleCombatManager 初始化完成")

# 设置组件引用
func setup_references(refs: Dictionary) -> void:
	character_manager = refs.get("character_manager")
	action_system = refs.get("action_system")
	battle_manager = refs.get("battle_manager")
	battle_animation_manager = refs.get("battle_animation_manager")
	battle_visual_effects_manager = refs.get("battle_visual_effects_manager")
	battle_input_handler = refs.get("battle_input_handler")
	battle_ui_manager = refs.get("battle_ui_manager")
	
	print("🔗 [战斗管理器] 组件引用设置完成")

# 🚀 执行攻击（主要接口）
func execute_attack(attacker: GameCharacter, target: GameCharacter) -> Dictionary:
	print("⚔️ [战斗管理器] %s 攻击 %s" % [attacker.name, target.name])
	
	# 验证攻击
	var validation_result = _validate_attack(attacker, target)
	if not validation_result.valid:
		return validation_result
	
	# 🎬 播放攻击动画（如果是AI攻击）
	if battle_animation_manager and not attacker.is_player_controlled():
		print("🎬 [战斗管理器] 播放AI攻击动画")
		await battle_animation_manager.play_ai_attack_animation(attacker, target)
	
	# 计算伤害
	var damage = calculate_damage(attacker, target)
	
	# 应用伤害
	target.take_damage(damage)
	
	# 🎬 显示伤害跳字
	if battle_visual_effects_manager:
		print("🎬 [战斗管理器] 显示伤害跳字")
		battle_visual_effects_manager.create_ai_attack_damage_numbers(target, damage)
	
	# 更新统计
	combat_stats.total_damage_dealt += damage
	combat_stats.total_attacks += 1
	
	# 发出信号
	damage_calculated.emit(attacker, target, damage)
	
	# 检查目标是否被击败
	if not target.is_alive():
		_handle_character_defeat(target)
	
	# 创建结果
	var result = {
		"type": "attack",
		"success": true,
		"damage": damage,
		"target": target.name,
		"target_defeated": not target.is_alive(),
		"message": "%s 对 %s 造成了 %d 点伤害" % [attacker.name, target.name, damage]
	}
	
	# 发出行动完成信号
	combat_action_completed.emit(attacker, result)
	
	return result

# 🚀 从场景执行攻击（兼容接口）
func execute_attack_from_scene(attacker_node: Node2D, target_node: Node2D) -> Dictionary:
	print("⚔️ [战斗管理器] 从场景执行攻击: %s -> %s" % [attacker_node.name, target_node.name])
	
	# 获取角色数据
	var attacker_data = attacker_node.get_character_data() if attacker_node.has_method("get_character_data") else null
	var target_data = target_node.get_character_data() if target_node.has_method("get_character_data") else null
	
	if not attacker_data or not target_data:
		print("❌ [战斗管理器] 无法获取角色数据")
		return {"type": "attack", "success": false, "message": "无法获取角色数据"}
	
	# 执行攻击
	return await execute_attack(attacker_data, target_data)

# 🚀 计算伤害
func calculate_damage(attacker: GameCharacter, target: GameCharacter) -> int:
	var base_damage = attacker.attack
	var defense = target.defense
	
	# 基础伤害计算：攻击力 - 防御力，最小为1
	var damage = max(1, base_damage - defense)
	
	# 添加随机因子（±20%）
	var random_factor = randf_range(0.8, 1.2)
	damage = int(damage * random_factor)
	
	print("💥 [战斗管理器] 伤害计算: %s(%d攻击) -> %s(%d防御) = %d伤害" % [attacker.name, base_damage, target.name, defense, damage])
	
	return damage

# 🚀 验证攻击
func _validate_attack(attacker: GameCharacter, target: GameCharacter) -> Dictionary:
	if not attacker or not target:
		return {"valid": false, "message": "攻击者或目标无效"}
	
	if not attacker.is_alive():
		return {"valid": false, "message": "攻击者已死亡"}
	
	if not target.is_alive():
		return {"valid": false, "message": "目标已死亡"}
	
	return {"valid": true}

# 🚀 处理角色被击败
func _handle_character_defeat(character: GameCharacter) -> void:
	print("💀 [战斗管理器] 角色被击败: %s" % character.name)
	
	# 添加到击败列表
	combat_stats.defeated_characters.append(character.name)
	
	# 发出信号
	character_defeated.emit(character)
	
	# 处理死亡视觉效果
	_handle_character_death_visuals(character)
	
	# 检查胜负条件
	check_victory_condition()

# 🚀 处理角色死亡视觉效果
func _handle_character_death_visuals(character: GameCharacter) -> void:
	print("🎭 [战斗管理器] 处理死亡视觉效果: %s" % character.name)
	
	# 查找角色节点
	var character_node = _find_character_node(character)
	if character_node:
		# 添加死亡标记
		_add_death_marker(character_node)
		
		# 播放死亡动画（如果有动画管理器）
		if battle_animation_manager and battle_animation_manager.has_method("play_death_animation"):
			battle_animation_manager.play_death_animation(character_node)
		
		# 播放死亡特效（如果有特效管理器）
		if battle_visual_effects_manager and battle_visual_effects_manager.has_method("play_death_effect"):
			battle_visual_effects_manager.play_death_effect(character_node)

# 🚀 查找角色节点
func _find_character_node(character: GameCharacter) -> Node2D:
	if not character_manager:
		return null
	
	# 尝试通过角色管理器查找
	if character_manager.has_method("find_character_node"):
		return character_manager.find_character_node(character)
	
	# 备用方案：在场景中搜索
	var scene_tree = get_tree()
	if scene_tree:
		var nodes = scene_tree.get_nodes_in_group("characters")
		for node in nodes:
			if node.has_method("get_character_data"):
				var node_data = node.get_character_data()
				if node_data == character:
					return node
	
	return null

# 🚀 为死亡角色添加死亡标记
func _add_death_marker(character_node: Node2D) -> void:
	# 检查是否已经有死亡标记
	var existing_marker = character_node.get_node_or_null("DeathMarker")
	if existing_marker:
		return
	
	# 创建死亡标记（红色X）
	var death_marker = Node2D.new()
	death_marker.name = "DeathMarker"
	death_marker.z_index = 10  # 确保在角色上方显示
	
	# 创建X形状的线条
	var x_drawer = _DeathMarkerDrawer.new()
	x_drawer.name = "XDrawer"
	death_marker.add_child(x_drawer)
	
	character_node.add_child(death_marker)
	print("💀 [战斗管理器] 为 %s 添加死亡标记" % character_node.name)

# 🚀 检查胜负条件
func check_victory_condition() -> void:
	print("🔍 [战斗管理器] 检查胜负条件...")
	
	# 只有在战斗进行中才检查胜负
	if not battle_manager or not battle_manager.is_battle_in_progress():
		print("⚠️ [战斗管理器] 战斗未进行中，跳过胜负检查")
		return
	
	# 统计存活的玩家和敌人
	var survival_stats = _get_survival_stats()
	var alive_players = survival_stats.alive_players
	var alive_enemies = survival_stats.alive_enemies
	
	print("🔍 [战斗管理器] 存活统计 - 玩家: %d, 敌人: %d" % [alive_players, alive_enemies])
	
	# 判定胜负
	if alive_players == 0:
		print("💀 [战斗管理器] 玩家全灭，我方失败！")
		_trigger_victory_condition("player_defeat", survival_stats)
	elif alive_enemies == 0:
		print("🎉 [战斗管理器] 敌人全灭，我方胜利！")
		_trigger_victory_condition("enemy_defeat", survival_stats)
	else:
		print("⚖️ [战斗管理器] 双方都有存活者，战斗继续")

# 🚀 获取存活统计
func _get_survival_stats() -> Dictionary:
	var stats = {
		"alive_players": 0,
		"alive_enemies": 0,
		"dead_players": [],
		"dead_enemies": []
	}
	
	if character_manager and character_manager.has_method("get_survival_stats"):
		return character_manager.get_survival_stats()
	
	# 备用方案：手动统计
	if character_manager:
		var all_characters = character_manager.get_all_characters() if character_manager.has_method("get_all_characters") else []
		for character in all_characters:
			if character.is_alive():
				if character.is_player_controlled():
					stats.alive_players += 1
				else:
					stats.alive_enemies += 1
			else:
				if character.is_player_controlled():
					stats.dead_players.append(character.name)
				else:
					stats.dead_enemies.append(character.name)
	
	return stats

# 🚀 触发胜负条件
func _trigger_victory_condition(victory_type: String, details: Dictionary) -> void:
	print("🏆 [战斗管理器] 触发胜负条件: %s" % victory_type)
	
	# 发出胜负信号
	victory_condition_met.emit(victory_type, details)
	
	# 通知战斗管理器
	if battle_manager and battle_manager.has_method("handle_victory_condition"):
		battle_manager.handle_victory_condition(victory_type, details)

# 🚀 重置战斗统计
func reset_combat_stats() -> void:
	combat_stats = {
		"total_damage_dealt": 0,
		"total_attacks": 0,
		"defeated_characters": [],
		"battle_duration": 0.0
	}
	print("🔄 [战斗管理器] 战斗统计已重置")

# 🚀 获取战斗统计
func get_combat_stats() -> Dictionary:
	return combat_stats.duplicate()

# 🚀 处理回合结束
func handle_turn_end() -> void:
	print("🔄 [战斗管理器] 处理回合结束")
	
	# 重置行动系统
	if action_system and action_system.has_method("reset_action_system"):
		action_system.reset_action_system()
		print("🔄 [战斗管理器] 行动系统已重置")
	
	# 更新UI
	if battle_manager and battle_manager.turn_manager:
		var current_character = battle_manager.turn_manager.get_current_character()
		if current_character and battle_ui_manager:
			var character_type = "玩家" if current_character.is_player_controlled() else "AI"
			var turn_number = battle_manager.turn_manager.get_current_turn()
			battle_ui_manager.update_battle_ui("回合 %d" % turn_number, "当前行动: %s (%s)" % [current_character.name, character_type], "turn_info")
			print("🎮 [战斗管理器] UI已更新")


# 🚀 检查胜负条件 - 从BattleScene迁移
func check_victory_condition_extended() -> void:
	print("🔍 [战斗管理器] 开始检查胜负条件...")
	
	# 只有在战斗进行中才检查胜负
	if not battle_manager:
		print("❌ [战斗管理器] BattleManager不存在，跳过胜负检查")
		return
	
	if not battle_manager.is_battle_in_progress():
		print("⚠️ [战斗管理器] 战斗未进行中，跳过胜负检查")
		return
	
	print("✅ [战斗管理器] 战斗进行中，继续检查...")
	
	# 统计存活的玩家和敌人
	var alive_players = 0
	var alive_enemies = 0
	var dead_players = []
	var dead_enemies = []
	
	# 检查玩家角色
	var player_characters = get_tree().get_nodes_in_group("player_characters")
	for player_node in player_characters:
		if player_node and player_node.has_method("get_character_data"):
			var player_data = player_node.get_character_data()
			if player_data:
				if player_data.is_alive():
					alive_players += 1
					print("✅ [战斗管理器] 存活玩家: %s (HP: %d/%d)" % [player_data.name, player_data.current_hp, player_data.max_hp])
				else:
					dead_players.append(player_data.name)
					print("💀 [战斗管理器] 死亡玩家: %s" % player_data.name)
	
	# 检查敌人角色
	var enemy_characters = get_tree().get_nodes_in_group("enemy_characters")
	var defeated_enemies = []
	for enemy_node in enemy_characters:
		if enemy_node:
			var enemy_data = enemy_node.get_character_data()
			if enemy_data and enemy_data.is_alive():
				print("💀 [战斗管理器] 击败敌人: %s" % enemy_data.name)
				enemy_data.current_hp = 0
				defeated_enemies.append(enemy_data.name)
				if battle_visual_effects_manager:
					battle_visual_effects_manager.handle_character_death(enemy_data)
				else:
					_handle_character_death_visuals(enemy_data)
	
	if defeated_enemies.size() > 0:
		print("✅ [战斗管理器] 已击败 %d 个敌人: %s" % [defeated_enemies.size(), str(defeated_enemies)])
		print("🔍 [战斗管理器] 等待胜利判定...")
	else:
		print("⚠️ [战斗管理器] 没有找到存活的敌人")



# 🚀 SkillManager信号回调
func on_skill_executed(caster: GameCharacter, skill: SkillData, targets: Array, results: Array):
	print("⚡ [技能系统] 技能执行完成: %s，施法者: %s" % [skill.name, caster.name])
	
	# 创建行动结果
	var action_result = {
		"type": "skill",
		"success": true,
		"message": "使用了技能: %s" % skill.name,
		"skill_results": results
	}
	
	# 🚀 修复：直接使用传递的caster参数
	if battle_manager:
		print("🎯 [技能系统] 通知BattleManager技能行动完成")
		battle_manager.character_action_completed.emit(caster, action_result)

func on_skill_cancelled():
	print("❌ [技能系统] 技能使用被取消")
	
	# 重置行动系统
	if action_system:
		action_system.reset_action_system()

# 🧪 测试胜利判定 - 保持向后兼容
func test_victory_condition() -> void:
	check_victory_condition_extended()

# 🧪 测试胜利判定扩展版本 - 保持向后兼容
func test_victory_condition_extended() -> void:
	check_victory_condition_extended()

# 🚀 显示攻击目标
func display_attack_targets(attacker_character: GameCharacter) -> void:
	print("🎯 [战斗管理器] 显示攻击目标: %s" % attacker_character.name)
	
	# 获取敌方目标
	var enemy_targets = get_enemy_targets(attacker_character)
	
	# 高亮所有敌方目标
	for target in enemy_targets:
		highlight_target(target, true)
	
	print("✅ [战斗管理器] 已高亮 %d 个攻击目标" % enemy_targets.size())

# 🚀 获取敌方目标
func get_enemy_targets(attacker: GameCharacter) -> Array:
	var targets = []
	
	if not character_manager:
		print("⚠️ [战斗管理器] CharacterManager不可用，无法获取敌方目标")
		return targets
	
	# 获取所有角色
	var all_characters = character_manager.get_all_characters() if character_manager.has_method("get_all_characters") else []
	
	for character in all_characters:
		# 跳过攻击者自己
		if character == attacker:
			continue
		
		# 跳过死亡角色
		if not character.is_alive():
			continue
		
		# 根据攻击者类型选择目标
		if attacker.is_player_controlled():
			# 玩家攻击敌人
			if not character.is_player_controlled():
				targets.append(character)
		else:
			# AI攻击玩家
			if character.is_player_controlled():
				targets.append(character)
	
	print("🎯 [战斗管理器] 为 %s 找到 %d 个敌方目标" % [attacker.name, targets.size()])
	return targets

# 🚀 高亮目标
func highlight_target(target: GameCharacter, highlight: bool) -> void:
	# 查找目标角色对应的节点
	var target_node = _find_character_node(target)
	if not target_node:
		print("⚠️ [战斗管理器] 无法找到目标角色节点: %s" % target.name)
		return
	
	highlight_target_node(target_node, highlight)

# 🚀 高亮目标节点
func highlight_target_node(target_node: Node2D, highlight: bool) -> void:
	if not target_node:
		return
	
	# 查找或创建高亮效果节点
	var highlight_node = target_node.get_node_or_null("TargetHighlight")
	
	if highlight:
		# 创建高亮效果
		if not highlight_node:
			highlight_node = Node2D.new()
			highlight_node.name = "TargetHighlight"
			highlight_node.z_index = 5  # 确保在角色上方显示
			
			# 创建高亮绘制器
			var highlight_drawer = _TargetHighlightDrawer.new()
			highlight_drawer.name = "HighlightDrawer"
			highlight_node.add_child(highlight_drawer)
			
			target_node.add_child(highlight_node)
			print("✨ [战斗管理器] 为 %s 添加高亮效果" % target_node.name)
	else:
		# 移除高亮效果
		if highlight_node:
			highlight_node.queue_free()
			print("🔄 [战斗管理器] 移除 %s 的高亮效果" % target_node.name)

# 🚀 清除攻击目标高亮
func clear_attack_targets() -> void:
	print("🔄 [战斗管理器] 清除所有攻击目标高亮")
	
	if not character_manager:
		print("⚠️ [战斗管理器] CharacterManager不可用，无法清除目标高亮")
		return
	
	# 获取所有角色节点并清除高亮
	var all_characters = character_manager.get_all_characters() if character_manager.has_method("get_all_characters") else []
	
	for character in all_characters:
		var character_node = _find_character_node(character)
		if character_node:
			highlight_target_node(character_node, false)
	
	print("✅ [战斗管理器] 已清除所有目标高亮")

# 🚀 取消攻击
func cancel_attack() -> void:
	print("❌ [战斗管理器] 取消攻击")
	
	# 清除目标高亮
	clear_attack_targets()
	
	# 重置行动系统
	if action_system and action_system.has_method("reset_action_system"):
		action_system.reset_action_system()
		print("🔄 [战斗管理器] 行动系统已重置")
	
	print("✅ [战斗管理器] 攻击已取消")

# 🚀 目标高亮绘制类
class _TargetHighlightDrawer extends Node2D:
	func _draw():
		var radius = 40.0
		var thickness = 3.0
		var color = Color.RED
		color.a = 0.8  # 半透明效果
		
		# 绘制圆形高亮
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, thickness)
		
		# 添加脉冲效果
		var time = Time.get_time_dict_from_system()
		var pulse = sin(time.second * 3.0 + time.msec * 0.003) * 0.3 + 0.7
		color.a *= pulse
		draw_arc(Vector2.ZERO, radius * 1.2, 0, TAU, 32, color, thickness * 0.5)

# 🚀 死亡标记绘制类
class _DeathMarkerDrawer extends Node2D:
	func _draw():
		var size = 30.0
		var thickness = 4.0
		var color = Color.RED
		
		# 绘制X形状
		draw_line(Vector2(-size/2, -size/2), Vector2(size/2, size/2), color, thickness)
		draw_line(Vector2(size/2, -size/2), Vector2(-size/2, size/2), color, thickness)

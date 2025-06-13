extends Node
class_name GameplaySettings

## 游戏玩法设置配置管理器
## 专门负责管理关卡的游戏玩法规则、胜利条件、特殊机制等

@export_group("胜利条件")
@export var victory_condition: String = "defeat_all_enemies"  # "defeat_all_enemies", "survive_time", "reach_target", "collect_items"
@export var victory_target_count: int = 0  # 目标数量（如需要收集的物品数量）
@export var victory_time_limit: float = 0.0  # 时间限制（秒，0表示无限制）
@export var defeat_condition: String = "all_players_defeated"  # "all_players_defeated", "time_expired", "key_character_dead"

@export_group("回合规则")
@export var turn_time_limit: float = 30.0  # 单回合时间限制
@export var action_points_per_turn: int = 2  # 每回合行动点数
@export var movement_points_per_turn: int = 3  # 每回合移动点数
@export var enable_counter_attacks: bool = true  # 是否启用反击

@export_group("特殊规则")
@export var friendly_fire_enabled: bool = false  # 是否允许友军伤害
@export var revive_allowed: bool = true  # 是否允许复活
@export var item_usage_limit: int = 3  # 物品使用次数限制
@export var skill_cooldown_modifier: float = 1.0  # 技能冷却修正值

@export_group("难度设置")
@export var difficulty_level: String = "normal"  # "easy", "normal", "hard", "nightmare"
@export var enemy_stat_multiplier: float = 1.0  # 敌人属性倍率
@export var player_stat_multiplier: float = 1.0  # 玩家属性倍率
@export var experience_multiplier: float = 1.0  # 经验值倍率

@export_group("特殊机制")
@export var weather_affects_combat: bool = false  # 天气是否影响战斗
@export var terrain_bonuses_enabled: bool = true  # 是否启用地形加成
@export var height_advantage_bonus: float = 0.1  # 高度优势伤害加成
@export var flanking_bonus: float = 0.15  # 侧翼攻击伤害加成

@export_group("奖励设置")
@export var base_experience_reward: int = 100  # 基础经验奖励
@export var gold_reward_range: Vector2i = Vector2i(50, 150)  # 金币奖励范围
@export var bonus_items: Array[String] = []  # 额外奖励物品
@export var rare_drop_chance: float = 0.1  # 稀有物品掉落概率

## 获取当前游戏玩法设置摘要
func get_gameplay_summary() -> String:
	var summary = "游戏玩法设置:\n"
	summary += "- 胜利条件: %s\n" % _get_victory_condition_name()
	summary += "- 难度等级: %s\n" % difficulty_level
	summary += "- 回合时间: %d秒\n" % int(turn_time_limit)
	summary += "- 行动点数: %d\n" % action_points_per_turn
	summary += "- 特殊规则: %s\n" % _get_special_rules_summary()
	
	return summary

## 获取胜利条件名称
func _get_victory_condition_name() -> String:
	match victory_condition:
		"defeat_all_enemies":
			return "击败所有敌人"
		"survive_time":
			return "生存%d秒" % int(victory_time_limit)
		"reach_target":
			return "到达指定位置"
		"collect_items":
			return "收集%d个物品" % victory_target_count
		_:
			return "未知条件"

## 获取特殊规则摘要
func _get_special_rules_summary() -> String:
	var rules = []
	
	if friendly_fire_enabled:
		rules.append("友军伤害")
	if not revive_allowed:
		rules.append("禁止复活")
	if weather_affects_combat:
		rules.append("天气影响")
	if enable_counter_attacks:
		rules.append("反击机制")
	
	return ", ".join(rules) if not rules.is_empty() else "标准规则"

## 检查胜利条件
func check_victory_condition(battle_state: Dictionary) -> bool:
	match victory_condition:
		"defeat_all_enemies":
			return battle_state.get("alive_enemies", 1) == 0
		
		"survive_time":
			return battle_state.get("elapsed_time", 0.0) >= victory_time_limit
		
		"reach_target":
			return battle_state.get("target_reached", false)
		
		"collect_items":
			return battle_state.get("collected_items", 0) >= victory_target_count
		
		_:
			return false

## 检查失败条件
func check_defeat_condition(battle_state: Dictionary) -> bool:
	match defeat_condition:
		"all_players_defeated":
			return battle_state.get("alive_players", 1) == 0
		
		"time_expired":
			return victory_time_limit > 0 and battle_state.get("elapsed_time", 0.0) >= victory_time_limit
		
		"key_character_dead":
			return battle_state.get("key_character_alive", true) == false
		
		_:
			return false

## 应用难度设置
func apply_difficulty_modifiers(character_stats: Dictionary, is_player: bool) -> Dictionary:
	var modified_stats = character_stats.duplicate()
	
	var multiplier = player_stat_multiplier if is_player else enemy_stat_multiplier
	
	# 应用属性倍率
	for stat in ["hp", "attack", "defense", "speed"]:
		if modified_stats.has(stat):
			modified_stats[stat] = int(modified_stats[stat] * multiplier)
	
	print("⚖️ [游戏玩法] 应用难度修正 (%s): 倍率=%.2f" % ["玩家" if is_player else "敌人", multiplier])
	
	return modified_stats

## 计算地形加成
func calculate_terrain_bonus(attacker_pos: Vector2, target_pos: Vector2, terrain_type: String) -> float:
	if not terrain_bonuses_enabled:
		return 0.0
	
	var bonus = 0.0
	
	# 高度优势加成
	if attacker_pos.y < target_pos.y:  # 攻击者位置更高
		bonus += height_advantage_bonus
		print("⛰️ [游戏玩法] 高度优势加成: +%.1f%%" % (height_advantage_bonus * 100))
	
	# 地形类型加成
	match terrain_type:
		"forest":
			bonus += 0.05  # 森林地形防御加成
		"mountain":
			bonus += 0.1   # 山地地形攻击加成
		"water":
			bonus -= 0.05  # 水域地形移动减成
	
	return bonus

## 计算侧翼攻击加成
func calculate_flanking_bonus(attacker_pos: Vector2, target_pos: Vector2, target_facing: Vector2) -> float:
	if not terrain_bonuses_enabled:
		return 0.0
	
	# 计算攻击方向与目标朝向的夹角
	var attack_direction = (attacker_pos - target_pos).normalized()
	var dot_product = attack_direction.dot(target_facing.normalized())
	
	# 如果攻击来自背后或侧面（夹角大于90度），给予侧翼加成
	if dot_product < 0:
		print("🗡️ [游戏玩法] 侧翼攻击加成: +%.1f%%" % (flanking_bonus * 100))
		return flanking_bonus
	
	return 0.0

## 计算经验奖励
func calculate_experience_reward(base_exp: int) -> int:
	var final_exp = int(base_exp * experience_multiplier)
	print("⭐ [游戏玩法] 经验奖励: %d (基础: %d, 倍率: %.2f)" % [final_exp, base_exp, experience_multiplier])
	return final_exp

## 计算金币奖励
func calculate_gold_reward() -> int:
	var gold = randi_range(gold_reward_range.x, gold_reward_range.y)
	print("💰 [游戏玩法] 金币奖励: %d (范围: %d-%d)" % [gold, gold_reward_range.x, gold_reward_range.y])
	return gold

## 检查稀有物品掉落
func check_rare_drop() -> bool:
	var roll = randf()
	var success = roll < rare_drop_chance
	
	if success:
		print("✨ [游戏玩法] 稀有物品掉落! (概率: %.1f%%, 掷骰: %.3f)" % [rare_drop_chance * 100, roll])
	
	return success

## 获取可用的特殊动作
func get_available_special_actions(character_state: Dictionary) -> Array[String]:
	var actions: Array[String] = []
	
	# 根据当前设置和角色状态确定可用动作
	if enable_counter_attacks and character_state.get("can_counter", true):
		actions.append("counter_attack")
	
	if revive_allowed and character_state.get("has_revive_items", false):
		actions.append("revive")
	
	if item_usage_limit > character_state.get("items_used", 0):
		actions.append("use_item")
	
	return actions

## 应用技能冷却修正
func apply_cooldown_modifier(base_cooldown: float) -> float:
	var modified_cooldown = base_cooldown * skill_cooldown_modifier
	
	if skill_cooldown_modifier != 1.0:
		print("⏰ [游戏玩法] 技能冷却修正: %.1f秒 → %.1f秒 (倍率: %.2f)" % [base_cooldown, modified_cooldown, skill_cooldown_modifier])
	
	return modified_cooldown

## 验证游戏玩法设置
func validate_gameplay_settings() -> Array[String]:
	var errors: Array[String] = []
	
	if turn_time_limit <= 0:
		errors.append("回合时间限制必须大于0")
	
	if action_points_per_turn <= 0:
		errors.append("每回合行动点数必须大于0")
	
	if victory_time_limit < 0:
		errors.append("时间限制不能为负数")
	
	if enemy_stat_multiplier <= 0 or player_stat_multiplier <= 0:
		errors.append("属性倍率必须大于0")
	
	if rare_drop_chance < 0 or rare_drop_chance > 1:
		errors.append("稀有物品掉落概率必须在0-1之间")
	
	return errors

## 重置设置为默认值
func reset_to_defaults():
	victory_condition = "defeat_all_enemies"
	difficulty_level = "normal"
	turn_time_limit = 30.0
	action_points_per_turn = 2
	enemy_stat_multiplier = 1.0
	player_stat_multiplier = 1.0
	experience_multiplier = 1.0
	
	print("�� [游戏玩法] 设置已重置为默认值") 
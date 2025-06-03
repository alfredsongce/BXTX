# BattleContext 战斗上下文类
# 用于管理战斗上下文，里面记载了单次战斗时所需的一切数据
class_name BattleContext
extends Resource

# ----------------------
# 基础战斗信息（必选）
# ----------------------
var attacker = null         # 攻击方角色（Node2D/CharacterBody2D等）
var defender = null         # 防守方角色/角色组（单个角色或数组）
var current_skill = null    # 当前使用的技能数据（自定义结构体或字典）
var battle_id = ""          # 战斗ID（用于日志记录）
var battle_type = "single"  # 战斗类型（single/group/boss等）

# ----------------------
# 临时计算数据（动态更新）
# ----------------------
var temp_data = {
		"base_damage": 0.0,        # 基础伤害（未计算加成）
		"final_damage": 0.0,       # 最终伤害（含所有修正）
		"heal_amount": 0.0,        # 治疗量（如果是治疗技能）
		"is_critical": false,      # 是否暴击
		"is_blocked": false,       # 是否被格挡
		"status_effects": []       # 施加的状态效果列表（如中毒/灼烧）
}

# ----------------------
# 阶段状态标记（子队列管理）
# ----------------------
var phase_states = {
		"preparation": false,  # 准备阶段完成状态
		"damage_calculated": false,  # 伤害计算完成
		"damage_applied": false,  # 伤害已应用
		"post_battle_processed": false,  # 战斗后处理完成
		"animation_played": false  # 动画播放完成
}

# ----------------------
# 扩展数据（动态添加）
# ----------------------
var extra_data = {}  # 用于存储临时扩展属性（如自定义逻辑数据）

# ----------------------
# 上下文初始化
# ----------------------
func _init():
	# 初始化默认值
	reset_context()

func reset_context():
	attacker = null
	defender = null
	current_skill = null
	battle_id = ""
	battle_type = "single"
	temp_data = {
		"base_damage": 0.0,
		"final_damage": 0.0,
		"heal_amount": 0.0,
		"is_critical": false,
		"is_blocked": false,
		"status_effects": []
	}
	phase_states = {
	"preparation": false,
	"damage_calculated": false,
	"damage_applied": false,
	"post_battle_processed": false,
	"animation_played": false
	}
	extra_data.clear()

# ----------------------
# 阶段状态管理方法
# ----------------------
func mark_phase_complete(phase_name: String):
		if phase_name in phase_states:
			phase_states[phase_name] = true
		else:
			print("无效的阶段名称:", phase_name)

func is_phase_complete(phase_name: String) -> bool:
		return phase_states.get(phase_name, false)

# ----------------------
# 临时数据操作方法
# ----------------------
func set_temp_data(key: String, value):
		if key in temp_data:
			temp_data[key] = value
		else:
			print("无效的临时数据键:", key)

func get_temp_data(key: String, default_value=null):
		return temp_data.get(key, default_value)

# ----------------------
# 扩展数据操作方法
# ----------------------
func set_extra_data(key: String, value):
		extra_data[key] = value

func get_extra_data(key: String, default_value=null):
		return extra_data.get(key, default_value)

# ----------------------
# 辅助调试方法
# ----------------------
func print_context_info():
	print("===== Battle Context Info =====")
	print("Attacker:", attacker.name if attacker != null else "None")
		
	print("Defender:", defender.name if defender != null else "None")
	print("Current Skill:", current_skill.name if current_skill != null else "None")
	print("Temp Data:", temp_data)
	print("Phase States:", phase_states)
	print("===============================")

# Edit file: res://Scripts/Character/GameCharacter.gd
class_name GameCharacter
extends Resource

# 信号定义（修改信号名称避免冲突）
signal stats_changed
signal leveled_up(new_level: int)  # 修改为leveled_up
signal health_changed(new_value: int, max_value: int)
signal exp_changed(new_value: int, to_next_level: int)
signal height_changed(new_height: int)  # 新增高度变化信号

# 核心属性
@export var id: String = "0":
	set(value):
		if value.is_valid_int():
			id = value
		else:
			push_error("角色ID必须是数字字符串: %s" % value)
			id = "0"

@export var name: String = "Unnamed"

# 控制类型（用于区分玩家角色和敌人）
enum ControlType { PLAYER, AI_ENEMY }
@export var control_type: ControlType = ControlType.PLAYER
@export var level: int = 1:
	set(value):
		level = max(1, value)
		exp_to_next_level = _calculate_exp_to_next_level()

# 战斗属性
@export var max_hp: int = 100
@export var current_hp: int = 100:
	set(value):
		var clamped = clamp(value, 0, max_hp)
		if current_hp != clamped:
			current_hp = clamped
			health_changed.emit(current_hp, max_hp)
			stats_changed.emit()

@export var max_mp: int = 50
@export var current_mp: int = 50:
	set(value):
		var clamped = clamp(value, 0, max_mp)
		if current_mp != clamped:
			current_mp = clamped
			stats_changed.emit()

@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 5

# 轻功相关属性
@export var qinggong_skill: int = 300:  # 轻功值，表示最大Y坐标向上偏移量(像素)
	set(value):
		qinggong_skill = max(0, value)
		stats_changed.emit()

# 被动技能相关属性
@export var passive_skills: Array[String] = []  # 角色拥有的被动技能ID列表

# 角色当前位置
var position: Vector2 = Vector2.ZERO  # 角色当前位置
var ground_position: Vector2 = Vector2.ZERO  # 角色地面位置(基准位置)

# 成长属性
@export var exp: int = 0:
	set(value):
		exp = max(0, value)
		exp_changed.emit(exp, exp_to_next_level)
		stats_changed.emit()

@export var exp_to_next_level: int = 100
@export var growth_rates: Dictionary = {
	"hp": 10,
	"attack": 2,
	"defense": 2,
	"speed": 1,
	"qinggong": 1  # 添加轻功成长率
}

# 状态效果
enum STATUS { NORMAL, POISONED, PARALYZED, CONFUSED }
@export var status: STATUS = STATUS.NORMAL

func _init() -> void:
	current_hp = max_hp
	current_mp = max_mp
	exp_to_next_level = _calculate_exp_to_next_level()
	
	# 初始化位置
	position = Vector2.ZERO
	ground_position = Vector2.ZERO
	
	# 确保初始化时没有高度差异
	# 这对后续的set_base_position调用很重要
	position.y = ground_position.y

func load_from_id(char_id: String) -> void:
	print("🎯 [GameCharacter] 开始加载角色数据，角色ID: %s" % char_id)
	
	if char_id.is_empty():
		printerr("❌ [GameCharacter] 角色ID不能为空")
		return
	
	if not DataManager:
		printerr("❌ [GameCharacter] DataManager 未找到")
		return
	
	var data = DataManager.get_data("character", char_id)
	if data == null or data.is_empty():
		printerr("❌ [GameCharacter] 未找到角色ID %s 的数据" % char_id)
		return
	
	id = char_id
	name = data.get("name", "Unnamed")
	level = int(data.get("level", 1))
	max_hp = int(data.get("max_hp", 100))
	current_hp = max_hp
	max_mp = int(data.get("max_mp", 50))
	current_mp = max_mp
	attack = int(data.get("attack", 10))
	defense = int(data.get("defense", 5))
	speed = int(data.get("speed", 5))
	qinggong_skill = int(data.get("qinggong_skill", 120))  # 从CSV数据中读取轻功值
	
	# 加载角色被动技能
	_load_passive_skills(char_id)
	
	# 重要：不要重置position和ground_position
	# 这些应该由调用者通过set_base_position设置
	# position和ground_position保持当前值
	
	growth_rates = data.get("growth_rates", growth_rates)
	exp = 0
	exp_to_next_level = _calculate_exp_to_next_level()
	status = STATUS.NORMAL
	
	stats_changed.emit()

# 修改函数名称为perform_level_up以避免冲突
func perform_level_up() -> void:
	exp -= exp_to_next_level
	level += 1
	
	# 根据成长率提升属性
	max_hp += growth_rates.get("hp", 10)
	max_mp += growth_rates.get("mp", 5)
	attack += growth_rates.get("attack", 2)
	defense += growth_rates.get("defense", 2)
	speed += growth_rates.get("speed", 1)
	qinggong_skill += growth_rates.get("qinggong", 1)  # 轻功也会随等级提升
	
	current_hp = max_hp
	current_mp = max_mp
	exp_to_next_level = _calculate_exp_to_next_level()
	
	leveled_up.emit(level)  # 使用修改后的信号名
	stats_changed.emit()

func add_exp(amount: int) -> void:
	if not is_alive():
		return
	
	exp += amount
	while exp >= exp_to_next_level and is_alive():
		perform_level_up()  # 调用修改后的函数

# 其余保持不变...
func take_damage(amount: int) -> void:
	# 🚀 修复：直接应用伤害，不再进行额外的防御力减免
	# 伤害计算应该在调用方（如SkillManager）中完成
	var damage = max(1, amount)
	current_hp -= damage
	stats_changed.emit()

func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	stats_changed.emit()

func full_heal() -> void:
	current_hp = max_hp
	current_mp = max_mp
	status = STATUS.NORMAL
	stats_changed.emit()

func is_alive() -> bool:
	return current_hp > 0

# 控制类型判断方法
func is_player_controlled() -> bool:
	return control_type == ControlType.PLAYER

func is_ai_controlled() -> bool:
	return control_type == ControlType.AI_ENEMY

func set_as_enemy() -> void:
	control_type = ControlType.AI_ENEMY

func set_as_player() -> void:
	control_type = ControlType.PLAYER

func _calculate_exp_to_next_level() -> int:
	return int(100 * pow(1.2, level - 1))

func get_stats() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"level": level,
		"hp": "%d/%d" % [current_hp, max_hp],
		"mp": "%d/%d" % [current_mp, max_mp],
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"qinggong": qinggong_skill,
		"exp": "%d/%d" % [exp, exp_to_next_level],
		"status": STATUS.keys()[status]
	}

func apply_status_effect(new_status: STATUS, turns: int = 3) -> void:
	status = new_status
	stats_changed.emit()

func save_to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"level": level,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"qinggong_skill": qinggong_skill,
		"passive_skills": passive_skills,  # 🚀 新增：保存被动技能
		"exp": exp,
		"exp_to_next_level": exp_to_next_level,
		"growth_rates": growth_rates,
		"status": status
	}

func load_from_dict(data: Dictionary) -> void:
	id = data.get("id", "0")
	name = data.get("name", "Unnamed")
	level = data.get("level", 1)
	max_hp = data.get("max_hp", 100)
	current_hp = data.get("current_hp", max_hp)
	attack = data.get("attack", 10)
	defense = data.get("defense", 5)
	speed = data.get("speed", 5)
	qinggong_skill = data.get("qinggong_skill", 3)
	passive_skills = data.get("passive_skills", [])  # 🚀 新增：加载被动技能
	
	# 只有在数据中包含位置信息时才设置位置
	# 否则保持当前位置不变
	if data.has("position"):
		position = data.get("position", Vector2.ZERO)
	if data.has("ground_position"):
		ground_position = data.get("ground_position", Vector2.ZERO)
	
	exp = data.get("exp", 0)
	exp_to_next_level = data.get("exp_to_next_level", _calculate_exp_to_next_level())
	growth_rates = data.get("growth_rates", growth_rates)
	status = data.get("status", STATUS.NORMAL)
	
	stats_changed.emit()

# 设置角色位置
func set_position(pos: Vector2) -> void:
	position = pos
	
	# 如果Y坐标低于地面，则更新地面位置
	if pos.y > ground_position.y:
		ground_position.y = pos.y
	
	# 保持X坐标一致
	ground_position.x = pos.x

# 计算角色当前高度(以像素为单位)
func get_height() -> float:
	return ground_position.y - position.y

# 获取当前高度等级(每40像素为1级)
func get_height_level() -> float:
	return get_height() / 40

# 设置角色高度(以等级为单位，每级40像素)
func set_height(height_level: float) -> void:
	var height_pixels = height_level * 40
	position.y = ground_position.y - height_pixels
	height_changed.emit(height_pixels)
	stats_changed.emit()
	print("🔧 [GameCharacter] 角色 %s 高度设置为: %.1f级 (%.1f像素)" % [name, height_level, height_pixels])

# 检查是否在地面
func is_on_ground() -> bool:
	return abs(position.y - ground_position.y) < 1.0  # 允许1像素的误差

# 设置到地面位置
func set_to_ground() -> void:
	position.y = ground_position.y
	height_changed.emit(0)
	stats_changed.emit()

# ========== 被动技能管理功能 ==========

# 🚀 新增：从数据库加载角色被动技能
func _load_passive_skills(character_id: String) -> void:
	"""加载角色的被动技能"""
	if not DataManager:
		return
	
	# 从DataManager获取角色的被动技能配置
	var passive_skill_records = DataManager.get_character_passive_skills(character_id)
	
	# 清空现有的被动技能列表
	passive_skills.clear()
	
	if passive_skill_records.is_empty():
		return
	
	# 处理每个被动技能记录
	for record in passive_skill_records:
		var passive_skill_id = record.get("passive_skill_id", "")
		var required_level = int(record.get("learn_level", "1"))
		
		# 检查角色等级是否满足学习条件
		if level >= required_level:
			# 从被动技能数据库获取技能详细信息
			var skill_data = DataManager.get_data("passive_skills", passive_skill_id)
			if skill_data and not skill_data.is_empty():
				passive_skills.append(passive_skill_id)

# 🚀 新增：检查是否拥有指定被动技能
func has_passive_skill(skill_id: String) -> bool:
	var has_skill = skill_id in passive_skills
	# 移除过度日志输出 - 技能检查时不输出
	return has_skill

# 🚀 新增：检查是否能够飞行（拥有御剑飞行技能）
func can_fly() -> bool:
	var flying_ability = has_passive_skill("御剑飞行")
	# 移除过度日志输出 - 飞行能力检查时不输出
	return flying_ability

# 🚀 新增：添加被动技能
func add_passive_skill(skill_id: String) -> void:
	if not has_passive_skill(skill_id):
		passive_skills.append(skill_id)
		print("✅ [GameCharacter] 角色 %s 获得被动技能: %s" % [name, skill_id])
		stats_changed.emit()
	else:
		print("⚠️ [GameCharacter] 角色 %s 已拥有被动技能: %s" % [name, skill_id])

# 🚀 新增：移除被动技能
func remove_passive_skill(skill_id: String) -> void:
	if has_passive_skill(skill_id):
		passive_skills.erase(skill_id)
		print("❌ [GameCharacter] 角色 %s 失去被动技能: %s" % [name, skill_id])
		stats_changed.emit()
	else:
		print("⚠️ [GameCharacter] 角色 %s 没有被动技能: %s" % [name, skill_id])

# 🚀 新增：获取所有被动技能列表
func get_passive_skills() -> Array[String]:
	return passive_skills.duplicate()

# 🚀 新增：获取被动技能详细信息
func get_passive_skill_details() -> Array[Dictionary]:
	var details: Array[Dictionary] = []
	
	for skill_id in passive_skills:
		if DataManager:
			var skill_data = DataManager.get_passive_skill_data(skill_id)
			if skill_data != null and not skill_data.is_empty():
				details.append(skill_data)
	
	return details

# 🚀 新增：获取被动技能描述
func get_passive_skill_description(skill_id: String) -> String:
	if not DataManager:
		return "DataManager 未找到"
	
	var skill_data = DataManager.get_passive_skill_data(skill_id)
	return skill_data.get("description", "未知技能")

# 🚀 新增：调试输出被动技能信息
func debug_print_passive_skills() -> void:
	print("=== 角色 %s 的被动技能 ===" % name)
	if passive_skills == null or passive_skills.is_empty():
		print("无被动技能")
	else:
		for skill_id in passive_skills:
			if DataManager:
				var skill_data = DataManager.get_passive_skill_data(skill_id)
				if skill_data != null and not skill_data.is_empty():
					print("- %s (%s): %s" % [skill_data.get("name", skill_id), skill_data.get("effect_type", "unknown"), skill_data.get("description", "无描述")])
				else:
					print("- %s: 数据未找到" % skill_id)
			else:
				print("- %s: DataManager 未找到" % skill_id)
	print("飞行能力: %s" % ("是" if can_fly() else "否"))
	print("========================")

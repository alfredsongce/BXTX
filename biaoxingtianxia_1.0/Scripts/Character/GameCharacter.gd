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
	if not char_id.is_valid_int():
		push_error("无效的角色ID格式: %s" % char_id)
		return
	
	var data = DataManager.get_data("character", char_id)
	if data.is_empty():
		return
	
	id = char_id
	name = data.get("name", "Unnamed")
	level = data.get("level", 1)
	max_hp = data.get("max_hp", 100)
	current_hp = max_hp
	max_mp = data.get("max_mp", 50)
	current_mp = max_mp
	attack = data.get("attack", 10)
	defense = data.get("defense", 5)
	speed = data.get("speed", 5)
	qinggong_skill = data.get("qinggong_skill", 120)  # 默认设为120像素(3级)
	
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

# 设置角色高度 - 返回是否设置成功
func set_height(height_in_levels: float) -> bool:
	# 转换高度等级为像素高度
	var height_pixels = height_in_levels * 40
	
	# 检查高度是否在合法范围内
	if height_pixels < 0 or height_pixels > qinggong_skill:
		return false
	
	# 设置新位置
	position.y = ground_position.y - height_pixels
	
	# 发出高度变化信号 - 向下取整以保持接口兼容
	var int_height = int(height_in_levels)
	height_changed.emit(int_height)
	stats_changed.emit()
	
	return true

# 尝试移动到目标位置
func try_move_to(target_pos: Vector2) -> bool:
	# 🚀 统一距离计算：使用直线距离，与Input组件保持一致
	var direct_distance = position.distance_to(target_pos)
	
	# 计算高度相关信息（用于显示）
	var new_height = ground_position.y - target_pos.y
	var current_height = get_height()
	var height_change = abs(new_height - current_height)
	
	# 检查高度是否在合法范围
	if new_height < 0 or new_height > qinggong_skill:
		return false
	
	# 🚀 使用直线距离进行轻功检查，与Input组件保持一致
	if direct_distance > qinggong_skill:
		return false
	
	return true

# 根据角色位置获取高度
func get_height_display() -> String:
	# 将像素高度转换为游戏中的高度等级(每40像素1级)
	var height_level = int(get_height() / 40)
	return str(height_level)

# 获取当前高度等级(每40像素为1级)
func get_height_level() -> float:
	return get_height() / 40

# 检查是否在地面
func is_on_ground() -> bool:
	return abs(position.y - ground_position.y) < 1.0  # 允许1像素的误差

# 设置到地面位置
func set_to_ground() -> void:
	position.y = ground_position.y
	height_changed.emit(0)
	stats_changed.emit()

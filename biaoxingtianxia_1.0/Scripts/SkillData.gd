class_name SkillData
extends Resource

# 基础信息
var id: String
var name: String
var description: String
var mp_cost: int = 0
var cooldown: float = 0.0
var cast_time: float = 0.0

# 目标选择参数
var targeting_type: SkillEnums.TargetingType
var targeting_range: float = 0.0

# 范围参数
var range_type: SkillEnums.RangeType
var range_distance: float = 0.0

# 目标类型
var target_type: SkillEnums.TargetType

# 效果相关
var effect_ids: Array = []
var damage_formula: String = ""
var base_damage: int = 0

# 视觉效果
var animation_id: String = ""
var sound_id: String = ""

# 从CSV行数据加载
func load_from_csv_row(row_data: Dictionary) -> void:
	id = row_data.get("id", "")
	name = row_data.get("name", "")
	description = row_data.get("description", "")
	mp_cost = int(row_data.get("mp_cost", "0"))
	cooldown = float(row_data.get("cooldown", "0"))
	cast_time = float(row_data.get("cast_time", "0"))
	
	# 解析枚举值
	targeting_type = _parse_targeting_type(row_data.get("targeting_type", "NORMAL"))
	targeting_range = float(row_data.get("targeting_range", "0"))
	
	range_type = _parse_range_type(row_data.get("range_type", "SINGLE"))
	range_distance = float(row_data.get("range_distance", "0"))
	
	target_type = _parse_target_type(row_data.get("target_type", "ENEMY"))
	
	# 解析效果ID列表
	var effects_str = row_data.get("effect_ids", "")
	if effects_str != "":
		effect_ids = effects_str.split(",")
	
	damage_formula = row_data.get("damage_formula", "")
	base_damage = int(row_data.get("base_damage", "0"))
	
	animation_id = row_data.get("animation_id", "")
	sound_id = row_data.get("sound_id", "")

# 解析目标选择类型
func _parse_targeting_type(type_str: String) -> SkillEnums.TargetingType:
	match type_str.to_upper():
		"PROJECTILE_SINGLE":
			return SkillEnums.TargetingType.PROJECTILE_SINGLE
		"PROJECTILE_PATH":
			return SkillEnums.TargetingType.PROJECTILE_PATH
		"PROJECTILE_PIERCE":
			return SkillEnums.TargetingType.PROJECTILE_PIERCE
		"NORMAL":
			return SkillEnums.TargetingType.NORMAL
		"FREE":
			return SkillEnums.TargetingType.FREE
		"SELF":
			return SkillEnums.TargetingType.SELF
		_:
			return SkillEnums.TargetingType.NORMAL

# 解析范围类型
func _parse_range_type(type_str: String) -> SkillEnums.RangeType:
	match type_str.to_upper():
		"SINGLE":
			return SkillEnums.RangeType.SINGLE
		"RANGE":
			return SkillEnums.RangeType.RANGE
		_:
			return SkillEnums.RangeType.SINGLE

# 解析目标类型
func _parse_target_type(type_str: String) -> SkillEnums.TargetType:
	match type_str.to_upper():
		"SELF":
			return SkillEnums.TargetType.SELF
		"ENEMY":
			return SkillEnums.TargetType.ENEMY
		"ALLY":
			return SkillEnums.TargetType.ALLY
		"ALLYONLY":
			return SkillEnums.TargetType.ALLYONLY
		"ALL":
			return SkillEnums.TargetType.ALL
		_:
			return SkillEnums.TargetType.ENEMY

# 检查技能是否可以使用
func can_use(caster: GameCharacter) -> bool:
	# 检查MP消耗
	if caster.current_mp < mp_cost:
		return false
	
	# 检查冷却时间（暂时跳过，后续实现）
	# TODO: 实现冷却时间检查
	
	return true

# 获取技能的显示信息
func get_display_info() -> Dictionary:
	return {
		"name": name,
		"description": description,
		"mp_cost": mp_cost,
		"cooldown": cooldown,
		"cast_time": cast_time,
		"range": targeting_range
	} 
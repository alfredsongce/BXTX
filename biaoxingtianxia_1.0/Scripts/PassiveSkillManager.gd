class_name PassiveSkillManager
extends Node

## 被动技能管理器
## 负责加载、管理和查询被动技能数据

signal passive_skills_loaded

## 存储所有被动技能数据
var passive_skills: Dictionary = {}

## 按类型分组的技能
var skills_by_type: Dictionary = {}

## 数据文件路径
const PASSIVE_SKILLS_FILE = "res://data/passive_skills.csv"

func _ready():
	load_passive_skills()

## 从CSV文件加载被动技能数据
func load_passive_skills() -> void:
	if not FileAccess.file_exists(PASSIVE_SKILLS_FILE):
		printerr("被动技能数据文件不存在: " + PASSIVE_SKILLS_FILE)
		return
	
	var file = FileAccess.open(PASSIVE_SKILLS_FILE, FileAccess.READ)
	if file == null:
		printerr("无法打开被动技能数据文件: " + PASSIVE_SKILLS_FILE)
		return
	
	# 读取英文表头（第一行）
	var header = file.get_csv_line()
	print("被动技能数据文件英文表头: ", header)
	
	# 跳过中文注释行（第二行）
	var comment_line = file.get_csv_line()
	print("被动技能数据文件中文注释: ", comment_line)
	
	passive_skills.clear()
	skills_by_type.clear()
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() >= 4 and line[0] != "":
			var skill = PassiveSkill.new()
			skill.id = line[0]
			skill.name = line[1]
			skill.description = line[2]
			skill.effect_type = line[3]
			
			# 存储技能
			passive_skills[skill.id] = skill
			
			# 按类型分组
			if not skills_by_type.has(skill.effect_type):
				skills_by_type[skill.effect_type] = []
			skills_by_type[skill.effect_type].append(skill)
	
	file.close()
	print("成功加载被动技能数据，共 ", passive_skills.size(), " 个技能")
	passive_skills_loaded.emit()

## 根据ID获取被动技能
func get_passive_skill(skill_id: String) -> PassiveSkill:
	if passive_skills.has(skill_id):
		return passive_skills[skill_id]
	else:
		printerr("未找到被动技能: " + skill_id)
		return null

## 按类型获取技能列表
func get_skills_by_type(effect_type: String) -> Array[PassiveSkill]:
	if skills_by_type.has(effect_type):
		return skills_by_type[effect_type]
	else:
		return []

## 获取所有技能ID列表
func get_all_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in passive_skills.keys():
		ids.append(id)
	return ids

## 获取所有技能类型
func get_all_effect_types() -> Array[String]:
	var types: Array[String] = []
	for type in skills_by_type.keys():
		types.append(type)
	return types

## 检查技能是否存在
func has_skill(skill_id: String) -> bool:
	return passive_skills.has(skill_id)

## 调试输出所有技能信息
func debug_print_all_skills() -> void:
	print("=== 被动技能列表 ===")
	for skill_id in passive_skills.keys():
		var skill = passive_skills[skill_id]
		print("ID: ", skill.id, ", 名称: ", skill.name, ", 类型: ", skill.effect_type)
	print("=== 技能类型分组 ===")
	for type in skills_by_type.keys():
		print("类型 ", type, ": ", skills_by_type[type].size(), " 个技能")
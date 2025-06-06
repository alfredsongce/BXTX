class_name PassiveSkill
extends Resource

## 被动技能资源类
## 用于定义游戏中的被动技能数据结构

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var effect_type: String = ""
@export var is_active: bool = true

## 构造函数
func _init(skill_id: String = "", skill_name: String = "", skill_desc: String = "", skill_effect_type: String = "", active: bool = true):
	id = skill_id
	name = skill_name
	description = skill_desc
	effect_type = skill_effect_type
	is_active = active

## 检查技能是否为飞行类型
func is_flight_skill() -> bool:
	return effect_type == "flight"

## 检查技能是否为移动类型
func is_movement_skill() -> bool:
	return effect_type == "movement"

## 获取技能信息字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"effect_type": effect_type,
		"is_active": is_active
	}

## 从字典加载技能信息
func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	effect_type = data.get("effect_type", "")
	is_active = data.get("is_active", true)
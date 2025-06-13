extends Resource
class_name EnemyConfig

@export var enemy_id: String = ""
@export var spawn_index: int = 0  # 对应EnemySpawn节点的索引
@export var level_override: int = -1  # -1表示使用默认等级
@export var custom_ai_behavior: String = ""
@export var special_abilities: Array[String] = []

func _init(id: String = "", spawn_idx: int = 0, level_ovr: int = -1):
    enemy_id = id
    spawn_index = spawn_idx
    level_override = level_ovr

func get_display_name() -> String:
    """获取显示名称，用于编辑器"""
    if enemy_id.is_empty():
        return "未配置敌人"
    else:
        return "敌人ID: %s (生成点%d)" % [enemy_id, spawn_index]

func validate() -> bool:
    """验证配置是否有效"""
    if enemy_id.is_empty():
        return false
    if spawn_index < 0:
        return false
    return true 
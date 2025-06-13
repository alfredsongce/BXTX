# 角色生成点节点
# 用于可视化配置角色的生成位置

class_name SpawnPoint extends Marker2D

# 生成点类型
enum SpawnType {
	PLAYER,    # 玩家角色
	ENEMY      # 敌人角色
}

# 导出属性，可在编辑器中配置
@export var spawn_type: SpawnType = SpawnType.PLAYER
@export var character_id: String = ""  # 可选：指定特定角色ID
@export var spawn_index: int = 0       # 生成点索引
@export var description: String = ""   # 描述信息

# 视觉配置
@export var show_gizmo: bool = true
@export var gizmo_color: Color = Color.CYAN
@export var gizmo_size: float = 40.0

func _ready():
	# 设置gizmo大小
	gizmo_extents = gizmo_size
	
	# 根据类型设置颜色
	match spawn_type:
		SpawnType.PLAYER:
			gizmo_color = Color.CYAN
		SpawnType.ENEMY:
			gizmo_color = Color.RED

func _draw():
	if not show_gizmo:
		return
	
	# 绘制生成点标识
	var radius = gizmo_size / 2
	
	# 绘制圆形
	draw_circle(Vector2.ZERO, radius, gizmo_color * Color(1, 1, 1, 0.3))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, gizmo_color, 2.0)
	
	# 绘制类型标识
	var icon_size = radius * 0.6
	var font = ThemeDB.fallback_font
	match spawn_type:
		SpawnType.PLAYER:
			# 绘制P字母
			draw_string(font, Vector2(-8, 4), "P", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, gizmo_color)
		SpawnType.ENEMY:
			# 绘制E字母
			draw_string(font, Vector2(-8, 4), "E", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, gizmo_color)
	
	# 绘制索引
	if spawn_index >= 0:
		var index_text = str(spawn_index + 1)
		draw_string(font, Vector2(-4, -12), index_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, gizmo_color)

# 获取生成点信息
func get_spawn_info() -> Dictionary:
	return {
		"type": "player" if spawn_type == SpawnType.PLAYER else "enemy",
		"character_id": character_id,
		"spawn_index": spawn_index,
		"position": global_position,
		"description": description
	}

# 是否为玩家生成点
func is_player_spawn() -> bool:
	return spawn_type == SpawnType.PLAYER

# 是否为敌人生成点
func is_enemy_spawn() -> bool:
	return spawn_type == SpawnType.ENEMY

# 设置生成点类型
func set_spawn_type(type: SpawnType) -> void:
	spawn_type = type
	queue_redraw()

# 设置角色ID
func set_character_id(id: String) -> void:
	character_id = id

# 设置生成索引
func set_spawn_index(index: int) -> void:
	spawn_index = index
	queue_redraw()

# 验证配置
func is_valid() -> bool:
	return spawn_index >= 0

# 获取调试信息
func get_debug_info() -> String:
	var type_text = "玩家" if is_player_spawn() else "敌人"
	var char_info = character_id if not character_id.is_empty() else "未指定"
	return "%s生成点%d (角色ID: %s) 位置: %s" % [type_text, spawn_index + 1, char_info, global_position] 
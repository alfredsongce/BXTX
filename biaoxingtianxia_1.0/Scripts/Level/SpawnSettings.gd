extends Node
class_name SpawnSettings

## 角色生成点配置管理器
## 专门负责管理关卡中玩家和敌人的生成点配置

@export_group("生成点配置")
@export var level_id: String = "level_1"  # 关卡ID，用于从CSV配置中读取生成点

@export_group("回退配置（当CSV配置不可用时）")
@export var player_spawn_pattern: String = "line"  # "line", "triangle", "circle", "custom"
@export var player_spawn_spacing: float = 100.0
@export var player_spawn_base_position: Vector2 = Vector2(600, 1000)
@export var enemy_spawn_pattern: String = "line"  # "line", "triangle", "circle", "custom"
@export var enemy_spawn_spacing: float = 100.0
@export var enemy_spawn_base_position: Vector2 = Vector2(1000, 1000)

@export_group("高级配置")
@export var auto_adjust_height: bool = true  # 是否自动调整生成点高度以避开障碍物
@export var height_check_distance: float = 50.0  # 高度检查距离
@export var max_spawn_retries: int = 5  # 生成失败时的最大重试次数

## 获取玩家生成点列表
func get_player_spawn_points() -> Array[Vector2]:
	var spawns: Array[Vector2] = []
	
	# 优先从CSV配置获取生成点
	var csv_spawns = _get_spawn_points_from_csv("player")
	if not csv_spawns.is_empty():
		print("🎯 [生成点配置] 从CSV配置获取玩家生成点")
		return csv_spawns
	
	# 其次从场景节点获取
	var spawn_nodes = get_node_or_null("../../GameplayLayers/CharacterSpawns/PlayerSpawns")
	if spawn_nodes:
		print("🎯 [生成点配置] 从场景节点获取玩家生成点")
		for child in spawn_nodes.get_children():
			if child is Marker2D:
				spawns.append(child.global_position)
				print("📍 [生成点配置] 玩家生成点: %s" % child.global_position)
	else:
		print("🎯 [生成点配置] 场景中无玩家生成点，使用回退配置生成")
		spawns = _generate_spawn_points_by_pattern(player_spawn_pattern, player_spawn_base_position, player_spawn_spacing, 3)
	
	return spawns

## 获取敌人生成点列表
func get_enemy_spawn_points() -> Array[Vector2]:
	var spawns: Array[Vector2] = []
	
	# 优先从CSV配置获取生成点
	var csv_spawns = _get_spawn_points_from_csv("enemy")
	if not csv_spawns.is_empty():
		print("🎯 [生成点配置] 从CSV配置获取敌人生成点")
		return csv_spawns
	
	# 其次从场景节点获取
	var spawn_nodes = get_node_or_null("../../GameplayLayers/CharacterSpawns/EnemySpawns")
	if spawn_nodes:
		print("🎯 [生成点配置] 从场景节点获取敌人生成点")
		for child in spawn_nodes.get_children():
			if child is Marker2D:
				spawns.append(child.global_position)
				print("📍 [生成点配置] 敌人生成点: %s" % child.global_position)
	else:
		print("🎯 [生成点配置] 场景中无敌人生成点，使用回退配置生成")
		spawns = _generate_spawn_points_by_pattern(enemy_spawn_pattern, enemy_spawn_base_position, enemy_spawn_spacing, 3)
	
	return spawns

## 根据模式生成生成点
func _generate_spawn_points_by_pattern(pattern: String, base_pos: Vector2, spacing: float, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	match pattern:
		"line":
			for i in range(count):
				points.append(Vector2(base_pos.x + i * spacing, base_pos.y))
		
		"triangle":
			if count >= 1:
				points.append(base_pos)
			if count >= 2:
				points.append(Vector2(base_pos.x - spacing/2, base_pos.y + spacing))
			if count >= 3:
				points.append(Vector2(base_pos.x + spacing/2, base_pos.y + spacing))
			for i in range(3, count):
				points.append(Vector2(base_pos.x + (i-2) * spacing, base_pos.y + spacing * 2))
		
		"circle":
			var angle_step = 2 * PI / count
			for i in range(count):
				var angle = i * angle_step
				var x = base_pos.x + cos(angle) * spacing
				var y = base_pos.y + sin(angle) * spacing
				points.append(Vector2(x, y))
		
		_:  # "custom" 或其他情况
			for i in range(count):
				points.append(Vector2(base_pos.x + i * spacing, base_pos.y))
	
	# 如果启用了自动高度调整，进行高度检查
	if auto_adjust_height:
		points = _adjust_spawn_heights(points)
	
	return points

## 调整生成点高度以避开障碍物
func _adjust_spawn_heights(points: Array[Vector2]) -> Array[Vector2]:
	var adjusted_points: Array[Vector2] = []
	
	for point in points:
		var adjusted_point = _find_safe_spawn_position(point)
		adjusted_points.append(adjusted_point)
	
	return adjusted_points

## 查找安全的生成位置
func _find_safe_spawn_position(original_pos: Vector2) -> Vector2:
	# 这里可以添加物理检测逻辑，避开障碍物
	# 暂时返回原始位置
	return original_pos

## 从CSV配置获取生成点
func _get_spawn_points_from_csv(spawn_type: String) -> Array[Vector2]:
	"""从DataManager的生成点配置CSV中获取生成点列表"""
	print("🎯 [生成点配置] 开始从CSV获取%s生成点，关卡ID: %s" % [spawn_type, level_id])
	
	# 获取生成点配置数据
	var spawn_config_data = DataManager.get_spawn_configuration(level_id)
	
	if spawn_config_data.is_empty():
		printerr("⚠️ [生成点配置] 未找到关卡ID '%s' 的生成点配置" % level_id)
		return []
	
	var spawn_points: Array[Vector2] = []
	var spawn_list = []
	
	if spawn_type == "player":
		spawn_list = spawn_config_data.get("player_spawns", [])
	elif spawn_type == "enemy":
		spawn_list = spawn_config_data.get("enemy_spawns", [])
	
	# 按spawn_index排序
	spawn_list.sort_custom(func(a, b): return a.spawn_index < b.spawn_index)
	
	for spawn_data in spawn_list:
		var position = spawn_data.get("position", Vector2.ZERO)
		spawn_points.append(position)
		print("📍 [生成点配置] %s生成点%d: %s (%s)" % [spawn_type, spawn_data.spawn_index, position, spawn_data.description])
	
	print("✅ [生成点配置] 从CSV获取%s生成点完成，共%d个点" % [spawn_type, spawn_points.size()])
	return spawn_points

## 验证生成点配置
func validate_spawn_configuration() -> Array[String]:
	var errors: Array[String] = []
	
	var player_spawns = get_player_spawn_points()
	var enemy_spawns = get_enemy_spawn_points()
	
	if player_spawns.is_empty():
		errors.append("没有配置玩家生成点")
	
	if enemy_spawns.is_empty():
		errors.append("没有配置敌人生成点")
	
	# 检查生成点之间的距离
	for i in range(player_spawns.size()):
		for j in range(i + 1, player_spawns.size()):
			if player_spawns[i].distance_to(player_spawns[j]) < 30.0:
				errors.append("玩家生成点 %d 和 %d 距离过近" % [i, j])
	
	return errors

## 获取最佳生成点数量推荐
func get_recommended_spawn_count(character_count: int) -> Dictionary:
	return {
		"min_spawns": character_count,
		"recommended_spawns": character_count + 2,
		"max_spawns": character_count * 2
	} 

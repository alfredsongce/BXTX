# 生成点管理器
# 自动扫描场景中的SpawnPoint节点，提供统一的生成点管理

class_name SpawnPointManager extends Node

# 生成点存储
var player_spawn_points: Array[SpawnPoint] = []
var enemy_spawn_points: Array[SpawnPoint] = []

# 信号
signal spawn_points_updated()
signal spawn_point_added(spawn_point: SpawnPoint)
signal spawn_point_removed(spawn_point: SpawnPoint)

func _ready():
	print("📍 [SpawnPointManager] 生成点管理器初始化")
	call_deferred("scan_spawn_points")

# 扫描场景中的所有生成点
func scan_spawn_points() -> void:
	player_spawn_points.clear()
	enemy_spawn_points.clear()
	
	print("🔍 [SpawnPointManager] 开始扫描生成点...")
	_scan_node_recursive(get_tree().current_scene)
	
	# 按索引排序
	player_spawn_points.sort_custom(_sort_by_index)
	enemy_spawn_points.sort_custom(_sort_by_index)
	
	print("✅ [SpawnPointManager] 生成点扫描完成:")
	print("   - 玩家生成点: %d 个" % player_spawn_points.size())
	print("   - 敌人生成点: %d 个" % enemy_spawn_points.size())
	
	_validate_spawn_points()
	spawn_points_updated.emit()

# 递归扫描节点
func _scan_node_recursive(node: Node) -> void:
	if node is SpawnPoint:
		_add_spawn_point(node as SpawnPoint)
	
	for child in node.get_children():
		_scan_node_recursive(child)

# 添加生成点
func _add_spawn_point(spawn_point: SpawnPoint) -> void:
	if spawn_point.is_player_spawn():
		if spawn_point not in player_spawn_points:
			player_spawn_points.append(spawn_point)
			print("📍 [SpawnPointManager] 发现玩家生成点: 索引%d, 位置%s" % [spawn_point.spawn_index, spawn_point.global_position])
	elif spawn_point.is_enemy_spawn():
		if spawn_point not in enemy_spawn_points:
			enemy_spawn_points.append(spawn_point)
			print("📍 [SpawnPointManager] 发现敌人生成点: 索引%d, 位置%s" % [spawn_point.spawn_index, spawn_point.global_position])
	
	spawn_point_added.emit(spawn_point)

# 按索引排序
func _sort_by_index(a: SpawnPoint, b: SpawnPoint) -> bool:
	return a.spawn_index < b.spawn_index

# 验证生成点配置
func _validate_spawn_points() -> void:
	print("🔍 [SpawnPointManager] 验证生成点配置...")
	
	# 检查玩家生成点索引连续性
	for i in range(player_spawn_points.size()):
		var spawn_point = player_spawn_points[i]
		if spawn_point.spawn_index != i:
			print("⚠️ [SpawnPointManager] 玩家生成点索引不连续: 期望%d, 实际%d" % [i, spawn_point.spawn_index])
	
	# 检查敌人生成点索引连续性
	for i in range(enemy_spawn_points.size()):
		var spawn_point = enemy_spawn_points[i]
		if spawn_point.spawn_index != i:
			print("⚠️ [SpawnPointManager] 敌人生成点索引不连续: 期望%d, 实际%d" % [i, spawn_point.spawn_index])

# 获取玩家生成点位置列表
func get_player_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for spawn_point in player_spawn_points:
		positions.append(spawn_point.global_position)
	return positions

# 获取敌人生成点位置列表
func get_enemy_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for spawn_point in enemy_spawn_points:
		positions.append(spawn_point.global_position)
	return positions

# 根据索引获取玩家生成点位置
func get_player_spawn_position(index: int) -> Vector2:
	if index >= 0 and index < player_spawn_points.size():
		return player_spawn_points[index].global_position
	
	printerr("❌ [SpawnPointManager] 无效的玩家生成点索引: %d (总数: %d)" % [index, player_spawn_points.size()])
	return Vector2.ZERO

# 根据索引获取敌人生成点位置
func get_enemy_spawn_position(index: int) -> Vector2:
	if index >= 0 and index < enemy_spawn_points.size():
		return enemy_spawn_points[index].global_position
	
	printerr("❌ [SpawnPointManager] 无效的敌人生成点索引: %d (总数: %d)" % [index, enemy_spawn_points.size()])
	return Vector2.ZERO

# 根据角色ID获取生成点（如果有指定）
func get_spawn_point_for_character(character_id: String) -> SpawnPoint:
	# 先在玩家生成点中查找
	for spawn_point in player_spawn_points:
		if spawn_point.character_id == character_id:
			return spawn_point
	
	# 再在敌人生成点中查找
	for spawn_point in enemy_spawn_points:
		if spawn_point.character_id == character_id:
			return spawn_point
	
	return null

# 获取可用的玩家生成点数量
func get_player_spawn_count() -> int:
	return player_spawn_points.size()

# 获取可用的敌人生成点数量
func get_enemy_spawn_count() -> int:
	return enemy_spawn_points.size()

# 是否有足够的玩家生成点
func has_enough_player_spawns(required_count: int) -> bool:
	return player_spawn_points.size() >= required_count

# 是否有足够的敌人生成点
func has_enough_enemy_spawns(required_count: int) -> bool:
	return enemy_spawn_points.size() >= required_count

# 获取所有生成点的调试信息
func get_debug_info() -> String:
	var info = "=== 生成点配置信息 ===\n"
	
	info += "玩家生成点 (%d个):\n" % player_spawn_points.size()
	for spawn_point in player_spawn_points:
		info += "  - " + spawn_point.get_debug_info() + "\n"
	
	info += "敌人生成点 (%d个):\n" % enemy_spawn_points.size()
	for spawn_point in enemy_spawn_points:
		info += "  - " + spawn_point.get_debug_info() + "\n"
	
	return info

# 打印调试信息
func print_debug_info() -> void:
	print(get_debug_info())

# 手动添加生成点（运行时）
func add_spawn_point_runtime(spawn_point: SpawnPoint) -> void:
	_add_spawn_point(spawn_point)
	
	# 重新排序
	if spawn_point.is_player_spawn():
		player_spawn_points.sort_custom(_sort_by_index)
	else:
		enemy_spawn_points.sort_custom(_sort_by_index)
	
	spawn_points_updated.emit()

# 移除生成点（运行时）
func remove_spawn_point_runtime(spawn_point: SpawnPoint) -> void:
	if spawn_point in player_spawn_points:
		player_spawn_points.erase(spawn_point)
	elif spawn_point in enemy_spawn_points:
		enemy_spawn_points.erase(spawn_point)
	
	spawn_point_removed.emit(spawn_point)
	spawn_points_updated.emit() 
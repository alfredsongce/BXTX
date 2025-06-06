# 障碍物管理器
class_name ObstacleManager
extends Node2D

# 信号
signal obstacle_added(obstacle)
signal obstacle_removed(obstacle)
signal obstacles_cleared()

# 障碍物管理配置（不再动态生成）
# 所有障碍物都应该在场景中预先配置

# 内部变量
var obstacles: Array = []
var battle_scene: Node

func _ready():
	# 添加到obstacle_manager组，供其他系统查找
	add_to_group("obstacle_manager")
	
	# 获取战斗场景引用
	var parent = get_parent()
	if parent:
		battle_scene = parent.get_parent() if parent.get_parent() else parent
	else:
		battle_scene = null
	
	# 注释掉自动扫描，由BattleScene统一控制
	# call_deferred("_register_existing_obstacles")

# 移除动态生成障碍物的功能，改为只扫描现有障碍物
# func _generate_initial_obstacles(): # 已删除

# 移除角色位置更新功能，不再需要动态生成时的位置检查
# func _update_character_positions(): # 已删除

# 移除位置验证功能，不再需要动态生成时的位置检查
# func _is_position_valid(pos: Vector2) -> bool: # 已删除

func get_obstacles_in_area(center: Vector2, radius: float) -> Array:
	"""获取指定区域内的障碍物"""
	var result: Array = []
	for obstacle in obstacles:
		if center.distance_to(obstacle.global_position) <= radius:
			result.append(obstacle)
	return result

func is_position_blocked(pos: Vector2) -> bool:
	"""检查位置是否被障碍物阻挡 - 使用物理空间查询（与快速预检测统一）"""
	# print("🔍 [ObstacleManager] 开始物理空间查询检测 - 位置: %s" % str(pos))
	
	# 获取物理空间
	var space = get_world_2d().direct_space_state
	if not space:
		# print("⚠️ [ObstacleManager] 无法获取物理空间")
		return false
	
	# 创建查询参数
	var query = PhysicsShapeQueryParameters2D.new()
	
	# 创建一个小的圆形查询区域用于点检测
	var shape = CircleShape2D.new()
	shape.radius = 5.0  # 小半径用于精确的点检测
	
	query.shape = shape
	query.transform = Transform2D(0, pos)
	query.collision_mask = 14  # 检测静态障碍物(2)、角色(4)和障碍物(8) = 2+4+8=14（与快速预检测保持一致）
	query.collide_with_areas = true
	query.collide_with_bodies = true  # 与快速预检测保持一致，检测Areas和Bodies
	
	# 执行物理查询
	var results = space.intersect_shape(query, 10)
	
	# print("📋 [ObstacleManager] 物理查询参数 - 碰撞掩码: %d, 检测Areas: %s" % [query.collision_mask, query.collide_with_areas])
	
	if results.size() > 0:
		# print("🚫 [ObstacleManager] 检测到 %d 个障碍物碰撞" % results.size())
		for i in range(results.size()):
			var result = results[i]
			var collider = result.get("collider")
			if collider:
				var collision_layer = collider.collision_layer if "collision_layer" in collider else "未知"
				var node_name = collider.name if "name" in collider else "未知节点"
				var node_type = collider.get_class() if collider.has_method("get_class") else "未知类型"
				# print("  - 障碍物 %d: %s (%s), 碰撞层: %s" % [i+1, node_name, node_type, str(collision_layer)])
		return true
	else:
		# print("✅ [ObstacleManager] 位置无障碍物阻挡")
		return false

func _register_existing_obstacles():
	"""扫描并注册场景中已存在的障碍物"""
	print("🔍 开始扫描现有障碍物...")
	if not get_parent():
		print("❌ 没有父节点，无法扫描")
		return
		
	print("📂 父节点: %s, 子节点数量: %d" % [get_parent().name, get_parent().get_child_count()])
	
	# 递归扫描所有子节点，包括DynamicsLevel下的障碍物
	_scan_node_for_obstacles(get_parent())
	
	print("🏁 扫描完成，总障碍物数量: %d" % obstacles.size())
	print("📋 已注册的障碍物列表:")
	for i in range(obstacles.size()):
		var obstacle = obstacles[i]
		print("  %d. %s - 位置: %s, 碰撞层: %d" % [i+1, obstacle.name, obstacle.global_position, obstacle.collision_layer])

func _scan_node_for_obstacles(node: Node):
	"""递归扫描节点及其子节点寻找障碍物"""
	for child in node.get_children():
		# 排除ObstacleManager自身
		if child == self:
			continue
			
		# 检查各种条件
		var is_in_obstacle_group = child.is_in_group("obstacle")
		var is_obstacle_class = child.get_class() == "Obstacle"
		var has_obstacle_in_name = "Obstacle" in child.name
		
		# 检查是否是障碍物类型（必须是StaticBody2D类型）
		if (is_in_obstacle_group or is_obstacle_class or has_obstacle_in_name) and child is StaticBody2D:
			# 避免重复添加
			if not child in obstacles:
				obstacles.append(child)
				print("✅ 注册障碍物: %s" % child.name)
				obstacle_added.emit(child)
		
		# 递归检查子节点
		_scan_node_for_obstacles(child)

func get_obstacles() -> Array:
	"""获取所有障碍物"""
	return obstacles

func get_obstacle_count() -> int:
	"""获取障碍物数量"""
	return obstacles.size()

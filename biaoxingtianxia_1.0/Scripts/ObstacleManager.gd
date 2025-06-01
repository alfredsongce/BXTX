# 障碍物管理器
class_name ObstacleManager
extends Node2D

# 信号
signal obstacle_added(obstacle)
signal obstacle_removed(obstacle)
signal obstacles_cleared()

# 障碍物配置
@export var rock_count: int = 5
@export var rock_radius_min: float = 15.0
@export var rock_radius_max: float = 30.0
@export var spawn_area_size: Vector2 = Vector2(800, 600)
@export var min_distance_between_obstacles: float = 50.0
@export var min_distance_from_characters: float = 80.0

# 内部变量
var obstacles: Array = []
var battle_scene: Node2D
var character_positions: Array[Vector2] = []

func _ready():
	# 获取战斗场景引用
	battle_scene = get_parent().get_parent() if get_parent() else null
	
	# 延迟生成障碍物，等待角色加载完成
	call_deferred("_generate_initial_obstacles")

func _generate_initial_obstacles():
	# 获取当前角色位置
	_update_character_positions()
	
	# 生成乱石障碍物
	generate_rocks(rock_count)

func _update_character_positions():
	character_positions.clear()
	
	if not battle_scene:
		return
	
	# 获取玩家位置
	var players_node = battle_scene.get_node_or_null("Players")
	if players_node:
		for child in players_node.get_children():
			if child.has_method("get_global_position"):
				character_positions.append(child.global_position)
	
	# 获取敌人位置
	var enemies_node = battle_scene.get_node_or_null("Enemies")
	if enemies_node:
		for child in enemies_node.get_children():
			if child.has_method("get_global_position"):
				character_positions.append(child.global_position)

func generate_rocks(count: int):
	"""生成指定数量的乱石障碍物"""
	for i in range(count):
		var rock = _create_rock_obstacle()
		var position = _find_valid_position()
		
		if position != Vector2.ZERO:
			rock.global_position = position
			add_child(rock)
			obstacles.append(rock)
			obstacle_added.emit(rock)
			print("生成乱石障碍物于位置: ", position)
		else:
			print("无法找到合适位置生成障碍物")
			rock.queue_free()

func _create_rock_obstacle():
	"""创建乱石障碍物"""
	var ObstacleClass = preload("res://Scripts/Obstacle.gd")
	var rock = ObstacleClass.new()
	rock.obstacle_type = 0  # ObstacleType.ROCK
	rock.obstacle_radius = randf_range(rock_radius_min, rock_radius_max)
	rock.obstacle_color = Color.RED
	rock.is_passable = false
	rock.blocks_vision = false
	return rock

func _find_valid_position() -> Vector2:
	"""寻找有效的障碍物生成位置"""
	var max_attempts = 50
	
	# 获取地面高度（从BattleScene获取）
	var ground_level = 1000.0  # GROUND_LEVEL常量值
	
	for attempt in range(max_attempts):
		# 在角色头顶区域生成障碍物
		# X坐标：在所有角色位置的范围内随机
		var min_x = INF
		var max_x = -INF
		for char_pos in character_positions:
			min_x = min(min_x, char_pos.x)
			max_x = max(max_x, char_pos.x)
		
		# 扩展X范围，在角色区域周围生成
		var x_range = max_x - min_x
		if x_range < 200:  # 最小范围
			x_range = 200
		var center_x = (min_x + max_x) / 2
		var x = center_x + randf_range(-x_range, x_range)
		
		# Y坐标：在地面上方一定范围内（角色头顶区域）
		# 障碍物应该在地面上，不要太高
		var y = ground_level + randf_range(-50, -10)  # 地面上方10-50像素
		
		var test_position = Vector2(x, y)
		
		# 检查是否与现有障碍物冲突
		if _is_position_valid(test_position):
			return test_position
	
	return Vector2.ZERO  # 找不到合适位置

func _is_position_valid(pos: Vector2) -> bool:
	"""检查位置是否有效"""
	# 检查与角色的距离
	for char_pos in character_positions:
		if pos.distance_to(char_pos) < min_distance_from_characters:
			return false
	
	# 检查与现有障碍物的距离
	for obstacle in obstacles:
		if pos.distance_to(obstacle.global_position) < min_distance_between_obstacles:
			return false
	
	return true

func add_obstacle_at_position(pos: Vector2, obstacle_type: int = 0):
	"""在指定位置添加障碍物"""
	var obstacle
	
	match obstacle_type:
		0:  # ROCK
			obstacle = _create_rock_obstacle()
		_:
			obstacle = _create_rock_obstacle()
	
	obstacle.global_position = pos
	add_child(obstacle)
	obstacles.append(obstacle)
	obstacle_added.emit(obstacle)
	return obstacle

func remove_obstacle(obstacle):
	"""移除指定障碍物"""
	if obstacle in obstacles:
		obstacles.erase(obstacle)
		obstacle_removed.emit(obstacle)
		obstacle.queue_free()

func clear_all_obstacles():
	"""清除所有障碍物"""
	for obstacle in obstacles:
		obstacle.queue_free()
	obstacles.clear()
	obstacles_cleared.emit()

func get_obstacles_in_area(center: Vector2, radius: float) -> Array:
	"""获取指定区域内的障碍物"""
	var result: Array = []
	for obstacle in obstacles:
		if center.distance_to(obstacle.global_position) <= radius:
			result.append(obstacle)
	return result

func is_position_blocked(pos: Vector2) -> bool:
	"""检查位置是否被障碍物阻挡 - 使用物理空间查询（与快速预检测统一）"""
	print("🔍 [ObstacleManager] 开始物理空间查询检测 - 位置: %s" % str(pos))
	
	# 获取物理空间
	var space = get_world_2d().direct_space_state
	if not space:
		print("⚠️ [ObstacleManager] 无法获取物理空间")
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
	
	print("📋 [ObstacleManager] 物理查询参数 - 碰撞掩码: %d, 检测Areas: %s" % [query.collision_mask, query.collide_with_areas])
	
	if results.size() > 0:
		print("🚫 [ObstacleManager] 检测到 %d 个障碍物碰撞" % results.size())
		for i in range(results.size()):
			var result = results[i]
			var collider = result.get("collider")
			if collider:
				var collision_layer = collider.collision_layer if "collision_layer" in collider else "未知"
				var node_name = collider.name if "name" in collider else "未知节点"
				var node_type = collider.get_class() if collider.has_method("get_class") else "未知类型"
				print("  - 障碍物 %d: %s (%s), 碰撞层: %s" % [i+1, node_name, node_type, str(collision_layer)])
		return true
	else:
		print("✅ [ObstacleManager] 位置无障碍物阻挡")
		return false

func get_obstacle_count() -> int:
	"""获取障碍物数量"""
	return obstacles.size()

# 调试功能
func regenerate_obstacles():
	"""重新生成障碍物（调试用）"""
	clear_all_obstacles()
	_update_character_positions()
	generate_rocks(rock_count)

func add_debug_obstacles_around_characters():
	"""在角色周围添加调试障碍物"""
	_update_character_positions()
	
	for char_pos in character_positions:
		# 在角色周围生成几个障碍物
		for i in range(3):
			var angle = i * TAU / 3.0
			var distance = randf_range(100, 150)
			var offset = Vector2(cos(angle), sin(angle)) * distance
			var obstacle_pos = char_pos + offset
			
			# 确保不与现有障碍物重叠
			if _is_position_valid(obstacle_pos):
				add_obstacle_at_position(obstacle_pos, 0)

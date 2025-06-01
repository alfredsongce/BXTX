# 🔍 移动范围显示系统 - 验证器节点
extends Node2D
class_name MoveRangeValidator

# 🎯 节点架构设计 - 符合Godot理念

# 🚀 缓存优化
var _cached_obstacles: Array = []
var _cache_character_id: String = ""
var _cache_update_time: int = 0  # 🚀 修复：改为int类型以匹配Time.get_ticks_msec()
var _cache_lifetime: float = 0.1  # 缓存100ms

# 📡 信号
signal validation_completed(is_valid: bool, reason: String)
signal obstacle_cache_updated(count: int)

func _ready():
	print("🔍 [Validator] 验证器节点初始化完成")

# 🚀 主要验证接口（实例方法 - 优化版）
func validate_position_comprehensive(
	character: GameCharacter, 
	target_position: Vector2, 
	character_actual_position: Vector2 = Vector2.ZERO
) -> Dictionary:
	
	print("\n🔍 [Validator] ========== 开始综合验证 ==========")
	
	if not character:
		var result = {"is_valid": false, "reason": "角色数据为空"}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	
	# 使用实际位置，如果未提供则使用角色数据位置
	var actual_char_pos = character_actual_position
	if actual_char_pos == Vector2.ZERO:
		actual_char_pos = character.position
	
	var max_range = character.qinggong_skill
	var char_ground_y = character.ground_position.y
	
	print("📋 [Validator] 验证参数 - 角色: %s, 实际位置: %s, 目标位置: %s, 轻功: %d" % [
		character.name, actual_char_pos, target_position, max_range
	])
	
	# 🎯 五重验证逻辑（优化版）
	
	# 检查1：圆形范围检查
	print("🔍 [Validator] 步骤1: 圆形范围检查...")
	if not _check_circular_range(actual_char_pos, target_position, max_range):
		var distance = actual_char_pos.distance_to(target_position)
		var result = {"is_valid": false, "reason": "超出圆形移动范围(%.1f > %d)" % [distance, max_range]}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	print("✅ [Validator] 圆形范围检查通过")
	
	# 检查2：高度限制检查
	print("🔍 [Validator] 步骤2: 高度限制检查...")
	if not _check_height_limit(target_position, char_ground_y, max_range):
		var target_height = char_ground_y - target_position.y
		var result = {"is_valid": false, "reason": "超出高度限制(%.1f > %d)" % [target_height, max_range]}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	print("✅ [Validator] 高度限制检查通过")
	
	# 检查3：地面检查
	print("🔍 [Validator] 步骤3: 地面检查...")
	if not _check_ground_limit(target_position, char_ground_y):
		var result = {"is_valid": false, "reason": "不能移动到地面以下"}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	print("✅ [Validator] 地面检查通过")
	
	# 检查4：角色障碍物碰撞检查（优化版 - 支持空间查询）
	print("🔍 [Validator] 步骤4: 角色障碍物碰撞检查...")
	var obstacles = _get_obstacle_characters_cached(character.id)
	print("📊 [Validator] 发现角色障碍物数量: %d" % obstacles.size())
	if not _check_capsule_obstacles(target_position, obstacles, character):
		var result = {"is_valid": false, "reason": "目标位置有角色碰撞"}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	print("✅ [Validator] 角色障碍物检查通过")
	
	# 检查5：静态障碍物碰撞检查（优化版 - 使用空间查询）
	print("🔍 [Validator] 步骤5: 静态障碍物碰撞检查...")
	var static_check_result = _check_static_obstacles(target_position, character)
	print("📊 [Validator] 静态障碍物检查结果: %s" % ("通过" if static_check_result else "失败"))
	if not static_check_result:
		var result = {"is_valid": false, "reason": "目标位置有静态障碍物"}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	print("✅ [Validator] 静态障碍物检查通过")
	
	var result = {"is_valid": true, "reason": ""}
	print("✅ [Validator] 所有验证步骤通过")
	print("🔍 [Validator] ========== 综合验证结束 ==========\n")
	validation_completed.emit(true, result.reason)
	return result

# 🔍 检查1：圆形范围检查
func _check_circular_range(char_pos: Vector2, target_pos: Vector2, max_range: int) -> bool:
	var distance = char_pos.distance_to(target_pos)
	return distance <= max_range

# 🔍 检查2：高度限制检查
func _check_height_limit(world_pos: Vector2, ground_y: float, max_range: int) -> bool:
	var target_height = ground_y - world_pos.y  # 高度 = 地面Y - 目标Y
	return target_height >= 0 and target_height <= max_range

# 🔍 检查3：地面检查
func _check_ground_limit(world_pos: Vector2, ground_y: float) -> bool:
	return world_pos.y <= ground_y  # 目标位置不能在地面以下

# 🔍 检查4：胶囊型障碍物检查（优化版 - 支持空间查询）
func _check_capsule_obstacles(world_pos: Vector2, obstacles: Array, character = null) -> bool:
	# 如果有角色信息，尝试使用空间查询优化
	if character and obstacles.size() > 5:  # 只在障碍物较多时使用空间查询
		return _check_capsule_obstacles_with_physics_query(world_pos, character)
	else:
		# 使用传统遍历方法
		return _check_capsule_obstacles_legacy(world_pos, obstacles)

# 🚀 新增：基于空间查询的角色障碍物检测
func _check_capsule_obstacles_with_physics_query(world_pos: Vector2, character) -> bool:
	# 获取角色的碰撞形状参数
	var capsule_params = _get_character_capsule_params(character)
	if not capsule_params:
		# 回退到传统方法
		var obstacles = _get_obstacle_characters_cached(character.id if character is Dictionary else character.id)
		return _check_capsule_obstacles_legacy(world_pos, obstacles)
	
	# 获取物理空间
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		print("⚠️ [Validator] 无法获取物理空间状态")
		return true
	
	# 创建查询参数
	var query = PhysicsShapeQueryParameters2D.new()
	
	# 设置碰撞形状
	if capsule_params.half_height > 0.0:
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = capsule_params.radius
		capsule_shape.height = capsule_params.height
		query.shape = capsule_shape
	else:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = capsule_params.radius
		query.shape = circle_shape
	
	# 设置变换
	var transform = Transform2D()
	transform.origin = world_pos
	var character_node = _get_character_node(character)
	if character_node:
		transform.rotation = character_node.rotation
		transform = transform.scaled(character_node.scale)
	query.transform = transform
	
	# 设置碰撞层和掩码（只检测角色）
	query.collision_mask = 4  # 假设角色在第4层
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	# 排除自身
	var exclude_rids = []
	if character_node:
		var char_area = character_node.get_node_or_null("CharacterArea")
		if char_area:
			exclude_rids.append(char_area.get_rid())
	query.exclude = exclude_rids
	
	# 执行查询
	var results = space_state.intersect_shape(query, 1)
	
	# 如果有碰撞结果，说明与其他角色碰撞
	if results.size() > 0:
		print("🔍 [Validator] 空间查询检测到角色碰撞 - 位置: %s" % str(world_pos))
		return false
	
	return true

# 🔧 传统角色障碍物检测方法
func _check_capsule_obstacles_legacy(world_pos: Vector2, obstacles: Array) -> bool:
	for obstacle_data in obstacles:
		if _point_intersects_capsule(world_pos, obstacle_data):
			return false  # 与障碍物碰撞
	return true  # 无碰撞

# 🔧 获取障碍物角色数据（带缓存）
func _get_obstacle_characters_cached(exclude_character_id: String) -> Array:
	# 🚀 修复：使用简单可靠的毫秒时间戳
	var current_time_ms = Time.get_ticks_msec()
	
	# 检查缓存是否有效
	if (_cache_character_id == exclude_character_id and 
		current_time_ms - _cache_update_time < _cache_lifetime * 1000):
		return _cached_obstacles
	
	# 更新缓存
	_cached_obstacles = _get_obstacle_characters(exclude_character_id)
	_cache_character_id = exclude_character_id
	_cache_update_time = current_time_ms
	
	obstacle_cache_updated.emit(_cached_obstacles.size())
	return _cached_obstacles

# 🔍 检查5：静态障碍物检查（统一使用物理查询）
func _check_static_obstacles(world_pos: Vector2, character = null) -> bool:
	print("🔍 [Validator] 静态障碍物检测开始 - 位置: %s" % world_pos)
	
	# 🚀 统一使用物理空间查询（与快速预检测保持一致）
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		print("⚠️ [Validator] 无法获取物理空间状态")
		return true
	
	# 创建查询参数
	var query = PhysicsShapeQueryParameters2D.new()
	
	# 🚀 修复：使用与快速预检测相同的角色碰撞形状
	var shape = _get_character_collision_shape(character)
	if not shape:
		# 如果无法获取角色形状，使用默认圆形
		shape = CircleShape2D.new()
		shape.radius = 20.0  # 使用更大的半径，接近角色实际大小
		print("⚠️ [Validator] 使用默认圆形形状，半径: %s" % shape.radius)
	else:
		print("✅ [Validator] 使用角色实际碰撞形状: %s" % shape.get_class())
	
	query.shape = shape
	query.transform = Transform2D(0, world_pos)
	query.collision_mask = 14  # 检测静态障碍物(2)、角色(4)和障碍物(8) = 2+4+8=14（与快速预检测完全一致）
	query.collide_with_areas = true
	query.collide_with_bodies = true  # 与快速预检测保持一致
	
	# 排除当前角色
	var exclude_rids = []
	var character_node = _get_character_node(character)
	if character_node:
		var char_area = character_node.get_node_or_null("CharacterArea")
		if char_area:
			exclude_rids.append(char_area.get_rid())
	query.exclude = exclude_rids
	
	# 执行物理查询
	var results = space_state.intersect_shape(query, 10)
	
	print("📋 [Validator] 物理查询参数详情:")
	print("  - 位置: %s" % str(world_pos))
	if shape is CircleShape2D:
		print("  - 查询形状: %s, 半径: %.1f" % [shape.get_class(), shape.radius])
	elif shape is CapsuleShape2D:
		print("  - 查询形状: %s, 半径: %.1f, 高度: %.1f" % [shape.get_class(), shape.radius, shape.height])
	else:
		print("  - 查询形状: %s" % shape.get_class())
	print("  - 碰撞掩码: %d (二进制: %s)" % [query.collision_mask, String.num(query.collision_mask, 2)])
	print("  - 检测Areas: %s, Bodies: %s" % [query.collide_with_areas, query.collide_with_bodies])
	print("  - 变换矩阵: %s" % str(query.transform))
	print("📊 [Validator] 查询结果数量: %d" % results.size())
	
	if results.size() > 0:
		print("🚫 [Validator] 检测到 %d 个障碍物碰撞" % results.size())
		for i in range(results.size()):
			var result = results[i]
			var collider = result.get("collider")
			if collider:
				var collision_layer = collider.collision_layer if "collision_layer" in collider else "未知"
				var node_name = collider.name if "name" in collider else "未知节点"
				var node_type = collider.get_class() if collider.has_method("get_class") else "未知类型"
				var node_position = collider.global_position if "global_position" in collider else "未知位置"
				print("  - 障碍物 %d: %s (%s)" % [i+1, node_name, node_type])
				print("    碰撞层: %s, 位置: %s" % [str(collision_layer), str(node_position)])
				if "collision_mask" in collider:
					print("    碰撞掩码: %s" % str(collider.collision_mask))
		return false  # 有障碍物，位置被阻挡
	else:
		print("✅ [Validator] 位置无障碍物阻挡 - 查询返回空结果")
		print("🔍 [Validator] 可能原因分析:")
		print("  1. 查询位置确实无障碍物")
		print("  2. 碰撞掩码不匹配")
		print("  3. 查询形状与快速预检测不同")
		print("  4. 物理空间状态不同步")
		return true  # 无障碍物，位置可用

# 🚀 新增：基于PhysicsShapeQueryParameters2D的静态障碍物检测
func _check_static_obstacles_with_physics_query(world_pos: Vector2, character) -> bool:
	# 获取角色的碰撞形状参数
	var capsule_params = _get_character_capsule_params(character)
	if not capsule_params:
		# 如果无法获取胶囊参数，回退到传统方法
		return _check_static_obstacles_legacy(world_pos)
	
	# 获取物理空间
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		print("⚠️ [Validator] 无法获取物理空间状态")
		return true
	
	# 创建查询参数
	var query = PhysicsShapeQueryParameters2D.new()
	
	# 设置碰撞形状
	if capsule_params.half_height > 0.0:
		# 使用胶囊形状
		var capsule_shape = CapsuleShape2D.new()
		capsule_shape.radius = capsule_params.radius
		capsule_shape.height = capsule_params.height
		query.shape = capsule_shape
	else:
		# 使用圆形形状
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = capsule_params.radius
		query.shape = circle_shape
	
	# 设置变换（位置和旋转）
	var transform = Transform2D()
	transform.origin = world_pos
	# 处理角色旋转（如果有的话）
	var character_node = _get_character_node(character)
	if character_node:
		transform.rotation = character_node.rotation
		# 处理缩放
		transform = transform.scaled(character_node.scale)
	query.transform = transform
	
	# 设置碰撞层和掩码（只检测静态障碍物）
	query.collision_mask = 2  # 假设静态障碍物在第2层
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	# 执行查询（只需要知道是否有碰撞）
	var results = space_state.intersect_shape(query, 1)
	
	# 如果有碰撞结果，说明位置被阻挡
	if results.size() > 0:
		print("🔍 [Validator] 空间查询检测到静态障碍物碰撞 - 位置: %s" % str(world_pos))
		return false
	
	return true

# 🔧 传统静态障碍物检测方法（向后兼容）
func _check_static_obstacles_legacy(world_pos: Vector2) -> bool:
	print("🔍 [Validator] 传统静态障碍物检测开始")
	# 获取BattleScene来查找ObstacleManager
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if not battle_scene:
		print("⚠️ [Validator] 无法找到battle_scene组")
		return true  # 如果找不到场景，假设没有障碍物
	
	# 获取ObstacleManager
	var obstacle_manager = battle_scene.get_node_or_null("TheLevel/ObstacleManager")
	if not obstacle_manager:
		print("⚠️ [Validator] 无法找到ObstacleManager")
		return true  # 如果找不到障碍物管理器，假设没有障碍物
	
	print("✅ [Validator] 找到ObstacleManager: %s" % obstacle_manager.name)
	
	# 使用点检测
	if obstacle_manager.has_method("is_position_blocked"):
		var is_blocked = obstacle_manager.is_position_blocked(world_pos)
		print("📊 [Validator] ObstacleManager检测结果 - 位置: %s, 被阻挡: %s" % [str(world_pos), str(is_blocked)])
		return not is_blocked
	else:
		print("⚠️ [Validator] ObstacleManager没有is_position_blocked方法")
		return true

# 🔍 胶囊体积静态障碍物检测
func _check_capsule_static_obstacles(world_pos: Vector2, character, obstacle_manager) -> bool:
	# 获取角色的胶囊形状参数
	var capsule_params = _get_character_capsule_params(character)
	if not capsule_params:
		# 如果无法获取胶囊参数，回退到点检测
		if obstacle_manager.has_method("is_position_blocked"):
			return not obstacle_manager.is_position_blocked(world_pos)
		return true
	
	# 获取障碍物列表
	var obstacles = []
	if obstacle_manager.has_method("get_obstacles_in_area"):
		# 扩大搜索范围以包含胶囊半径
		var search_radius = capsule_params.radius + 100  # 额外缓冲
		obstacles = obstacle_manager.get_obstacles_in_area(world_pos, search_radius)
	else:
		print("⚠️ [Validator] ObstacleManager没有get_obstacles_in_area方法")
		return true
	
	# 检查胶囊与每个障碍物的碰撞
	for obstacle in obstacles:
		if _capsule_intersects_circle(world_pos, capsule_params, obstacle.position, obstacle.radius):
			print("🔍 [Validator] 胶囊体与静态障碍物碰撞 - 位置: %s, 障碍物: %s" % [str(world_pos), str(obstacle.position)])
			return false
	
	return true

# 🔧 获取角色节点
func _get_character_node(character):
	# 如果character已经是节点，直接返回
	if character is Node:
		return character
	
	# 如果character是字典，尝试通过ID查找节点
	if character is Dictionary and character.has("id"):
		var battle_scene = get_tree().get_first_node_in_group("battle_scene")
		if battle_scene and battle_scene.has_method("_find_character_node_by_id"):
			return battle_scene._find_character_node_by_id(character.id)
	
	return null

# 🚀 新增：获取角色碰撞形状（用于与快速预检测保持一致）
func _get_character_collision_shape(character):
	var character_node = _get_character_node(character)
	if not character_node:
		return null
	
	var character_area = character_node.get_node_or_null("CharacterArea")
	if not character_area:
		return null
	
	var collision_shape = character_area.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return null
	
	return collision_shape.shape

# 🔧 获取角色胶囊形状参数
func _get_character_capsule_params(character) -> Dictionary:
	# 尝试从角色节点获取碰撞形状
	var character_node = null
	
	# 如果character是字典，尝试通过ID查找节点
	if character is Dictionary and character.has("id"):
		var battle_scene = get_tree().get_first_node_in_group("battle_scene")
		if battle_scene:
			# 在Players和Enemies容器中查找
			var players_container = battle_scene.get_node_or_null("TheLevel/Players")
			var enemies_container = battle_scene.get_node_or_null("TheLevel/Enemies")
			
			for container in [players_container, enemies_container]:
				if container:
					for child in container.get_children():
						var char_data = child.get("character_data")
						if char_data and char_data.id == character.id:
							character_node = child
							break
				if character_node:
					break
	elif character is Node:
		character_node = character
	
	if not character_node:
		print("⚠️ [Validator] 无法找到角色节点")
		return {}
	
	# 获取碰撞形状
	var character_area = character_node.get_node_or_null("CharacterArea")
	if not character_area:
		print("⚠️ [Validator] 角色没有CharacterArea")
		return {}
	
	var collision_shape = character_area.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		print("⚠️ [Validator] 角色没有有效的碰撞形状")
		return {}
	
	# 检查是否为胶囊形状
	if collision_shape.shape is CapsuleShape2D:
		var capsule = collision_shape.shape as CapsuleShape2D
		return {
			"radius": capsule.radius,
			"height": capsule.height,
			"half_height": capsule.height / 2.0
		}
	elif collision_shape.shape is CircleShape2D:
		# 将圆形视为高度为0的胶囊
		var circle = collision_shape.shape as CircleShape2D
		return {
			"radius": circle.radius,
			"height": 0.0,
			"half_height": 0.0
		}
	else:
		print("⚠️ [Validator] 不支持的碰撞形状类型: %s" % collision_shape.shape.get_class())
		return {}

# 🔍 胶囊与圆形碰撞检测
func _capsule_intersects_circle(capsule_center: Vector2, capsule_params: Dictionary, circle_center: Vector2, circle_radius: float) -> bool:
	# 如果胶囊高度为0，按圆形处理
	if capsule_params.half_height <= 0.0:
		var distance = capsule_center.distance_to(circle_center)
		return distance <= (capsule_params.radius + circle_radius)
	
	# 计算胶囊的顶部和底部圆心
	var capsule_top = capsule_center + Vector2(0, -capsule_params.half_height)
	var capsule_bottom = capsule_center + Vector2(0, capsule_params.half_height)
	
	# 计算圆心到胶囊中心线的最短距离
	var distance_to_line = _point_to_line_segment_distance(circle_center, capsule_top, capsule_bottom)
	
	# 判断是否碰撞
	return distance_to_line <= (capsule_params.radius + circle_radius)

# 🔍 计算点到线段的最短距离
func _point_to_line_segment_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	
	# 如果线段长度为0，返回点到起点的距离
	var line_length_sq = line_vec.length_squared()
	if line_length_sq == 0.0:
		return point_vec.length()
	
	# 计算投影参数t
	var t = point_vec.dot(line_vec) / line_length_sq
	t = clamp(t, 0.0, 1.0)  # 限制在线段范围内
	
	# 计算最近点
	var closest_point = line_start + t * line_vec
	
	# 返回距离
	return point.distance_to(closest_point)

# 🔧 获取所有障碍物角色数据
func _get_obstacle_characters(exclude_character_id: String) -> Array:
	var obstacles = []
	
	# 🚀 简化：直接使用get_tree()而不是Engine.get_singleton
	if not get_tree():
		print("⚠️ [Validator] 无法获取场景树")
		return obstacles
	
	# 获取BattleScene来查找所有角色
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if not battle_scene:
		print("⚠️ [Validator] 无法找到battle_scene组")
		return obstacles
	
	# 🚀 减少详细输出
	# print("🔍 [Validator] 开始扫描角色障碍物，排除角色ID: %s" % exclude_character_id)
	
	# 遍历所有角色节点（包括容器中的角色）
	var checked_nodes = 0
	var found_characters = 0
	
	# 查找Players和Enemies容器中的角色
	var players_container = battle_scene.get_node_or_null("Players")
	var enemies_container = battle_scene.get_node_or_null("Enemies")
	
	var all_character_nodes = []
	if players_container:
		all_character_nodes.append_array(players_container.get_children())
	if enemies_container:
		all_character_nodes.append_array(enemies_container.get_children())
	
	# 如果没有找到容器，回退到直接子节点搜索
	if all_character_nodes.is_empty():
		for node in battle_scene.get_children():
			if node.is_in_group("party_members") or node.is_in_group("enemies"):
				all_character_nodes.append(node)
	
	for node in all_character_nodes:
		checked_nodes += 1
		# 检查是否是角色节点（有角色数据或在相应组中）
		if not (node.is_in_group("party_members") or node.is_in_group("enemies") or node.has_method("get_character_data")):
			continue
		
		found_characters += 1
		var character_data = node.get_character_data() if node.has_method("get_character_data") else null
		if not character_data:
			# 只在调试模式下显示详细信息
			if OS.is_debug_build():
				print("⚠️ [Validator] 节点 %s 没有角色数据" % node.name)
			continue
			
		if character_data.id == exclude_character_id:
			# print("🔍 [Validator] 跳过自身角色: %s" % character_data.id)
			continue
		
		# 获取碰撞形状信息
		var character_area = node.get_node_or_null("CharacterArea")
		if not character_area:
			if OS.is_debug_build():
				print("⚠️ [Validator] 角色 %s 没有CharacterArea" % character_data.id)
			continue
		
		var collision_shape = character_area.get_node_or_null("CollisionShape2D")
		if not collision_shape or not collision_shape.shape:
			if OS.is_debug_build():
				print("⚠️ [Validator] 角色 %s 没有有效的碰撞形状" % character_data.id)
			continue
		
		# 构建障碍物数据
		var obstacle_data = {
			"position": node.position,
			"shape": collision_shape.shape,
			"character_id": character_data.id
		}
		obstacles.append(obstacle_data)
		# print("✅ [Validator] 添加障碍物: %s 位置: %s" % [character_data.id, str(node.position)])
	
	# 🚀 只在有障碍物或出现问题时打印
	if obstacles.size() > 0 or found_characters == 0:
		print("🔍 [Validator] 扫描完成 - 检查节点: %d, 发现角色: %d, 障碍物: %d" % [checked_nodes, found_characters, obstacles.size()])
	return obstacles

# 🔍 检查点是否与胶囊体相交
func _point_intersects_capsule(point: Vector2, obstacle_data: Dictionary) -> bool:
	var shape = obstacle_data.shape
	var obstacle_pos = obstacle_data.position
	
	if shape is CapsuleShape2D:
		return _point_in_capsule(point, obstacle_pos, shape as CapsuleShape2D)
	elif shape is CircleShape2D:
		return _point_in_circle(point, obstacle_pos, shape as CircleShape2D)
	elif shape is RectangleShape2D:
		return _point_in_rectangle(point, obstacle_pos, shape as RectangleShape2D)
	
	return false

# 🔍 点与胶囊体碰撞检测
func _point_in_capsule(point: Vector2, capsule_pos: Vector2, capsule: CapsuleShape2D) -> bool:
	var radius = capsule.radius
	var height = capsule.height
	
	# 胶囊体 = 矩形 + 两个半圆
	var local_point = point - capsule_pos
	
	# 胶囊体的矩形部分高度
	var rect_height = height - 2 * radius
	
	if rect_height > 0:
		# 标准胶囊体：检查矩形部分和圆形端盖
		if abs(local_point.x) <= radius and abs(local_point.y) <= rect_height / 2:
			return true  # 在矩形部分内
		
		# 检查上下两个半圆端盖
		var top_center = Vector2(0, -rect_height / 2)
		var bottom_center = Vector2(0, rect_height / 2)
		
		return (local_point.distance_to(top_center) <= radius or 
				local_point.distance_to(bottom_center) <= radius)
	else:
		# 退化为圆形
		return local_point.length() <= radius

# 🔍 点与圆形碰撞检测
func _point_in_circle(point: Vector2, circle_pos: Vector2, circle: CircleShape2D) -> bool:
	var distance = point.distance_to(circle_pos)
	return distance <= circle.radius

# 🔍 点与矩形碰撞检测
func _point_in_rectangle(point: Vector2, rect_pos: Vector2, rect: RectangleShape2D) -> bool:
	var local_point = point - rect_pos
	var half_size = rect.size / 2
	
	return (abs(local_point.x) <= half_size.x and 
			abs(local_point.y) <= half_size.y)

# 🎯 批量验证（优化版）
func validate_positions_batch(
	character: GameCharacter,
	positions: Array,
	character_actual_position: Vector2 = Vector2.ZERO
) -> Array:
	
	if not character or positions.is_empty():
		return []
	
	# 预计算常用数据
	var actual_char_pos = character_actual_position
	if actual_char_pos == Vector2.ZERO:
		actual_char_pos = character.position
	
	var max_range = character.qinggong_skill
	var char_ground_y = character.ground_position.y
	var obstacles = _get_obstacle_characters_cached(character.id)
	
	var results = []
	
	# 批量验证
	for position in positions:
		var is_valid = (
			_check_circular_range(actual_char_pos, position, max_range) and
			_check_height_limit(position, char_ground_y, max_range) and
			_check_ground_limit(position, char_ground_y) and
			_check_capsule_obstacles(position, obstacles)
		)
		results.append(is_valid)
	
	return results

# 🔧 工具方法：获取角色实际位置
func get_character_actual_position(character: GameCharacter) -> Vector2:
	if not character:
		print("⚠️ [Validator] 角色参数为空")
		return Vector2.ZERO
	
	# 🚀 简化：直接使用get_tree()
	if not get_tree():
		print("⚠️ [Validator] 无法获取场景树")
		return character.position
	
	# 尝试通过BattleScene查找角色节点
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if not battle_scene:
		print("⚠️ [Validator] 无法找到battle_scene组，使用角色数据位置")
		return character.position
	
	# 查找对应的角色节点
	if battle_scene.has_method("_find_character_node_by_id"):
		var character_node = battle_scene._find_character_node_by_id(character.id)
		if character_node:
			# print("✅ [Validator] 获取到角色 %s 节点位置: %s" % [character.id, str(character_node.position)])
			return character_node.position
		else:
			print("⚠️ [Validator] 找不到角色节点 %s，使用数据位置" % character.id)
	else:
		print("⚠️ [Validator] BattleScene没有_find_character_node_by_id方法")
	
	# 如果找不到，返回角色数据位置作为fallback
	return character.position

# 🚀 缓存管理
func clear_cache():
	"""手动清理缓存"""
	_cached_obstacles.clear()
	_cache_character_id = ""
	_cache_update_time = 0
	print("🔍 [Validator] 缓存已清理")

func set_cache_lifetime(lifetime_seconds: float):
	"""设置缓存生存时间"""
	_cache_lifetime = clamp(lifetime_seconds, 0.01, 1.0)
	print("🔍 [Validator] 缓存生存时间设置为: %.2f秒" % _cache_lifetime)

# 🚀 性能统计
func get_validation_stats() -> Dictionary:
	return {
		"validator_version": "2.0.0",
		"architecture": "godot_node",
		"cache_enabled": true,
		"cache_size": _cached_obstacles.size(),
		"cache_character": _cache_character_id,
		"supported_shapes": ["CapsuleShape2D", "CircleShape2D", "RectangleShape2D"],
		"validation_checks": ["circular_range", "height_limit", "ground_limit", "capsule_obstacles"],
		"features": ["batch_validation", "obstacle_caching", "signal_emission"]
	}

# 🔍 移动范围显示系统 - 验证器节点
extends Node
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

# 🚀 主要验证接口（实例方法）
func validate_position_comprehensive(
	character: GameCharacter, 
	target_position: Vector2, 
	character_actual_position: Vector2 = Vector2.ZERO
) -> Dictionary:
	
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
	
	# 🚀 减少频繁的调试输出
	# print("🔍 [Validator] 验证位置 - 角色: %s, 目标: %s, 实际位置: %s, 轻功: %d" % [
	#	character.id, str(target_position), str(actual_char_pos), max_range
	# ])
	
	# 🎯 四重验证逻辑
	
	# 检查1：圆形范围检查
	if not _check_circular_range(actual_char_pos, target_position, max_range):
		var distance = actual_char_pos.distance_to(target_position)
		var result = {"is_valid": false, "reason": "超出圆形移动范围(%.1f > %d)" % [distance, max_range]}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	
	# 检查2：高度限制检查
	if not _check_height_limit(target_position, char_ground_y, max_range):
		var target_height = char_ground_y - target_position.y
		var result = {"is_valid": false, "reason": "高度超限(%.1f > %d)" % [target_height, max_range]}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	
	# 检查3：地面限制检查
	if not _check_ground_limit(target_position, char_ground_y):
		var result = {"is_valid": false, "reason": "不能移动到地面以下"}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	
	# 检查4：障碍物碰撞检查（使用缓存）
	var obstacles = _get_obstacle_characters_cached(character.id)
	if not _check_capsule_obstacles(target_position, obstacles):
		var result = {"is_valid": false, "reason": "目标位置有角色碰撞"}
		print("❌ [Validator] %s" % result.reason)
		validation_completed.emit(false, result.reason)
		return result
	
	var result = {"is_valid": true, "reason": ""}
	# 🚀 减少成功验证的输出频率
	# print("✅ [Validator] 位置验证通过")
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

# 🔍 检查4：胶囊型障碍物检查
func _check_capsule_obstacles(world_pos: Vector2, obstacles: Array) -> bool:
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

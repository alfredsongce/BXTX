# 位置计算与碰撞检测统一管理器
# 按照Godot设计理念，作为节点挂载在BattleScene中
# 统一处理所有位置计算和碰撞检测逻辑

class_name PositionCollisionManager
extends Node2D

# 信号定义
signal position_validated(position: Vector2, is_valid: bool)
signal collision_detected(position: Vector2, collider: Node2D)
signal validation_completed(is_valid: bool, reason: String)
signal obstacle_cache_updated(count: int)

# 配置参数
@export var collision_mask: int = 31  # 检测地面(1)、静态障碍物(2)、角色(4)、障碍物(8)、水面(16) = 1+2+4+8+16=31

# 内部变量
var space_state: PhysicsDirectSpaceState2D
var query: PhysicsShapeQueryParameters2D

# 缓存
var position_cache: Dictionary = {}
var cache_timeout: float = 0.1  # 缓存超时时间
var cache_lifetime_ms: int = 100  # 缓存生命周期（毫秒）

# 统计数据
var validation_count: int = 0
var cache_hit_count: int = 0
var physics_check_count: int = 0

func _ready():
	print("🔧 [PositionCollisionManager] 初始化基于物理空间查询的统一碰撞检测管理器")
	
	# 初始化物理查询组件
	space_state = get_world_2d().direct_space_state
	print("✅ [PositionCollisionManager] 物理空间状态获取成功: ", space_state != null)
	
	# 创建物理查询参数
	query = PhysicsShapeQueryParameters2D.new()
	query.collision_mask = collision_mask
	query.collide_with_areas = true  # 🔧 关键修复：启用Area2D碰撞检测
	query.collide_with_bodies = false  # 只检测Area2D，不检测RigidBody2D
	print("✅ [PositionCollisionManager] 物理查询参数配置完成:")
	print("  - 碰撞掩码: %d" % collision_mask)
	print("  - 检测Area2D: %s" % query.collide_with_areas)
	print("  - 检测Bodies: %s" % query.collide_with_bodies)
	
	print("🎯 [PositionCollisionManager] 基于物理查询的统一管理器初始化完成")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			# 按T键输出调试信息
			var mouse_pos = get_global_mouse_position()
			var character = get_tree().get_first_node_in_group("player")
			if character:
				output_debug_info_for_position(mouse_pos, character)
			else:
				print("❌ 未找到玩家角色节点")
		elif event.keycode == KEY_W:
			# 按W键输出物理验证详细信息
			var mouse_pos = get_global_mouse_position()
			var character = get_tree().get_first_node_in_group("player")
			if character:
				output_physical_validation_debug(mouse_pos, character)
			else:
				print("❌ 未找到玩家角色节点")

# 统一的碰撞检测接口 - 供所有调用方使用
func check_position_collision(position: Vector2, character: Node2D) -> bool:
	return validate_position(position, character)

# 主要验证接口 - 唯一的验证方法（包含物理碰撞和轻功技能检查）
func validate_position(target_position: Vector2, exclude_character: Node2D = null) -> bool:
	validation_count += 1
	
	# 检查缓存
	var cache_key = _generate_cache_key(target_position, exclude_character)
	if position_cache.has(cache_key):
		var cache_data = position_cache[cache_key]
		if Time.get_time_dict_from_system()["second"] - cache_data.timestamp < cache_timeout:
			cache_hit_count += 1
			return cache_data.result
	
	# 执行统一验证（物理碰撞 + 轻功技能）
	var result = _perform_unified_validation(target_position, exclude_character)
	
	# 更新缓存
	position_cache[cache_key] = {
		"result": result,
		"timestamp": Time.get_time_dict_from_system()["second"]
	}
	
	return result

# 🚀 获取详细的验证结果（包含原因）- 新增方法
func get_validation_details(target_position: Vector2, exclude_character: Node2D = null) -> Dictionary:
	validation_count += 1
	
	# 检查缓存
	var cache_key = _generate_cache_key(target_position, exclude_character)
	if position_cache.has(cache_key):
		var cache_data = position_cache[cache_key]
		if Time.get_time_dict_from_system()["second"] - cache_data.timestamp < cache_timeout:
			cache_hit_count += 1
			return {
				"is_valid": cache_data.result,
				"reason": cache_data.reason if cache_data.has("reason") else ("位置有效" if cache_data.result else "位置无效")
			}
	
	# 执行详细验证
	var validation_result = _perform_detailed_validation(target_position, exclude_character)
	
	# 更新缓存（包含原因）
	position_cache[cache_key] = {
		"result": validation_result.is_valid,
		"reason": validation_result.reason,
		"timestamp": Time.get_time_dict_from_system()["second"]
	}
	
	return validation_result

# 🚀 获取移动成本 - 新增方法
func get_movement_cost(from_position: Vector2, to_position: Vector2) -> float:
	return from_position.distance_to(to_position)

# 🚀 五重验证逻辑 - 从MoveRangeValidator迁移
func validate_position_comprehensive(
	character: GameCharacter, 
	target_position: Vector2, 
	character_actual_position: Vector2 = Vector2.ZERO
) -> Dictionary:
	
	if not character:
		var result = {"is_valid": false, "reason": "角色数据为空"}
		validation_completed.emit(false, result.reason)
		return result
	
	# 使用实际位置，如果未提供则使用角色数据位置
	var actual_char_pos = character_actual_position
	if actual_char_pos == Vector2.ZERO:
		actual_char_pos = character.position
	
	var max_range = character.qinggong_skill
	var char_ground_y = character.ground_position.y
	
	# 🎯 四重验证逻辑（移除高度限制检查）
	
	# 检查1：圆形范围检查
	if not _check_circular_range(actual_char_pos, target_position, max_range):
		var distance = actual_char_pos.distance_to(target_position)
		var result = {"is_valid": false, "reason": "超出圆形移动范围(%.1f > %d)" % [distance, max_range]}
		validation_completed.emit(false, result.reason)
		return result
	
	# 检查2：地面检查
	if not _check_ground_limit_comprehensive(target_position, char_ground_y):
		var result = {"is_valid": false, "reason": "不能移动到地面以下"}
		validation_completed.emit(false, result.reason)
		return result
	
	# 检查3：角色障碍物碰撞检查
	var obstacles = _get_obstacle_characters_cached(character.id)
	if not _check_capsule_obstacles_comprehensive(target_position, obstacles, character):
		var result = {"is_valid": false, "reason": "目标位置有角色碰撞"}
		validation_completed.emit(false, result.reason)
		return result
	
	# 检查4：静态障碍物碰撞检查
	var static_check_result = _check_static_obstacles_comprehensive(target_position, character)
	if not static_check_result:
		var result = {"is_valid": false, "reason": "目标位置有静态障碍物"}
		validation_completed.emit(false, result.reason)
		return result
	
	var result = {"is_valid": true, "reason": ""}
	validation_completed.emit(true, result.reason)
	return result

# 🚀 批量验证功能 - 从MoveRangeValidator迁移
func validate_positions_batch(positions: Array, character: GameCharacter) -> Array:
	var results = []
	var obstacles = _get_obstacle_characters_cached(character.id)
	var char_ground_y = character.ground_position.y
	var max_range = character.qinggong_skill
	
	for position in positions:
		var is_valid = (
			_check_circular_range(character.position, position, max_range) and
			_check_ground_limit_comprehensive(position, char_ground_y) and
			_check_capsule_obstacles_comprehensive(position, obstacles, character)
		)
		results.append(is_valid)
	
	return results

# 🚀 生成缓存键 - 优化方法
func _generate_cache_key(target_position: Vector2, exclude_character: Node2D = null) -> String:
	var character_id = exclude_character.get_instance_id() if exclude_character else "null"
	return "%s_%s" % [target_position, character_id]

# 🚀 执行详细验证并返回原因 - 新增方法
func _perform_detailed_validation(target_position: Vector2, exclude_character: Node2D = null) -> Dictionary:
	if not exclude_character:
		return {"is_valid": false, "reason": "角色节点为空"}
	
	# 获取角色数据
	var character_data = null
	if exclude_character.has_method("get_character_data"):
		character_data = exclude_character.get_character_data()
	
	if not character_data:
		return {"is_valid": false, "reason": "无法获取角色数据"}
	
	# 1. 轻功技能范围检查
	if not _validate_qinggong_range(target_position, exclude_character):
		return {"is_valid": false, "reason": "超出轻功技能范围"}
	
	# 2. 地面约束检查（移除高度限制）
	if not _validate_ground_constraint(target_position, exclude_character):
		return {"is_valid": false, "reason": "违反地面约束"}
	
	# 3. 物理碰撞检查
	if not _perform_physical_validation(target_position, exclude_character):
		return {"is_valid": false, "reason": "位置存在物理碰撞"}
	
	return {"is_valid": true, "reason": "位置有效"}

# 执行统一验证逻辑（轻功技能 + 地面约束 + 物理碰撞检查）
func _perform_unified_validation(target_position: Vector2, exclude_character: Node2D = null) -> bool:
	if not exclude_character:
		print("⚠️ [PositionCollisionManager] 角色节点为空")
		return false
	
	# 1. 轻功技能范围检查
	if not _validate_qinggong_range(target_position, exclude_character):
		return false
	
	# 2. 🔧 修复：添加地面约束检查
	if not _validate_ground_constraint(target_position, exclude_character):
		return false
	
	# 3. 物理碰撞检查
	return _perform_physical_validation(target_position, exclude_character)

# 🚀 新增：轻功技能范围验证（支持被动技能系统）
func _validate_qinggong_range(target_position: Vector2, character: Node2D) -> bool:
	# 通过get_character_data()方法获取GameCharacter对象
	var character_data = null
	if character.has_method("get_character_data"):
		character_data = character.get_character_data()
	
	if not character_data:
		printerr("❌ [PositionCollisionManager] 无法获取角色数据，跳过轻功检查")
		return true  # 如果无法获取角色数据，不限制范围
	
	# 检查GameCharacter对象是否有qinggong_skill属性
	if not "qinggong_skill" in character_data:
		printerr("❌ [PositionCollisionManager] GameCharacter没有qinggong_skill属性")
		return true
	
	# 计算距离限制：轻功值直接作为移动范围（像素）
	var max_range = character_data.qinggong_skill
	var character_position = character.position
	var distance = character_position.distance_to(target_position)
	
	print("🏃 [PositionCollisionManager] 轻功范围检查 - 距离: %.1f, 限制: %d" % [distance, max_range])
	
	if distance > max_range:
		print("❌ [PositionCollisionManager] 轻功范围检查失败：距离超出限制 (%.1f > %d)" % [distance, max_range])
		return false
	
	print("✅ [PositionCollisionManager] 轻功范围检查通过")
	return true



# 🚀 新增：地面约束验证
func _validate_ground_constraint(target_position: Vector2, character: Node2D) -> bool:
	print("🔍 [PositionCollisionManager] 开始地面约束验证 - 目标位置: %s" % target_position)
	
	# 获取角色数据
	var character_data = null
	if character.has_method("get_character_data"):
		character_data = character.get_character_data()
		print("📋 [PositionCollisionManager] 获取到角色数据: %s" % ("成功" if character_data else "失败"))
	else:
		printerr("❌ [PositionCollisionManager] 角色节点没有get_character_data方法")
	
	# 如果角色拥有御剑飞行技能，跳过地面约束检查
	if character_data and character_data.has_method("can_fly"):
		var can_fly = character_data.can_fly()
		print("🔍 [PositionCollisionManager] 角色飞行能力检查: %s" % ("可以飞行" if can_fly else "不能飞行"))
		if can_fly:
			print("✈️ [PositionCollisionManager] 角色拥有飞行能力，跳过地面约束检查")
			return true
	else:
		printerr("❌ [PositionCollisionManager] 角色数据无效或没有can_fly方法")
	
	# 对于没有飞行能力的角色，跳过高度限制检查（已移除）
	
	# 🔧 修复：使用GroundAnchor位置进行地面检测
	var ground_anchor_position = _get_ground_anchor_position(target_position, character)
	
	# 检查GroundAnchor位置是否在地面上或水面上
	var is_on_ground = _is_position_on_ground(ground_anchor_position)
	var is_on_water = _is_position_on_water(ground_anchor_position)
	
	# 地面或水面都允许移动
	return is_on_ground or is_on_water

# 🚀 新增：获取GroundAnchor在目标位置的实际位置
func _get_ground_anchor_position(target_position: Vector2, character: Node2D) -> Vector2:
	# 获取角色的GroundAnchor偏移量
	var ground_anchor_offset = Vector2(0, 22)  # 默认偏移量
	if character:
		var ground_anchor = character.get_node_or_null("GroundAnchor")
		if ground_anchor:
			ground_anchor_offset = ground_anchor.position
	
	# 返回GroundAnchor在目标位置的实际位置
	return target_position + ground_anchor_offset

# 🚀 新增：检查位置是否在地面上
func _is_position_on_ground(position: Vector2) -> bool:
	# 使用射线检测向下检查地面
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	
	# 创建向下的射线查询
	var ray_query = PhysicsRayQueryParameters2D.create(
		position,
		position + Vector2(0, 50),  # 向下检测50像素
		1  # 地面层（collision_layer = 1）
	)
	
	var result = space_state.intersect_ray(ray_query)
	return not result.is_empty()

# 🚀 新增：检查位置是否在水面上
func _is_position_on_water(position: Vector2) -> bool:
	# 使用射线检测向下检查水面
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	
	# 创建向下的射线查询（检测水面层）
	var ray_query = PhysicsRayQueryParameters2D.create(
		position,
		position + Vector2(0, 50),  # 向下检测50像素
		16  # 水面层（collision_layer = 16，即第5位）
	)
	
	var result = space_state.intersect_ray(ray_query)
	return not result.is_empty()

# 🚀 MoveRangeValidator辅助函数 - 迁移的验证逻辑

# 圆形范围检查
func _check_circular_range(char_position: Vector2, target_position: Vector2, max_range: float) -> bool:
	return char_position.distance_to(target_position) <= max_range



# 地面检查（综合版本）
func _check_ground_limit_comprehensive(target_position: Vector2, char_ground_y: float) -> bool:
	return target_position.y <= char_ground_y

# 角色障碍物检查（综合版本）
func _check_capsule_obstacles_comprehensive(target_position: Vector2, obstacles: Array, character: GameCharacter) -> bool:
	var capsule_radius = 20.0  # 角色胶囊体半径
	
	for obstacle in obstacles:
		if not obstacle or obstacle == character:
			continue
			
		var obstacle_pos = obstacle.position
		var distance = target_position.distance_to(obstacle_pos)
		
		if distance < capsule_radius * 2:
			return false
	
	return true

# 静态障碍物检查（综合版本）
func _check_static_obstacles_comprehensive(target_position: Vector2, character: GameCharacter) -> bool:
	if not space_state:
		return true
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = target_position
	query.collision_mask = 2  # 静态障碍物层
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	return results.is_empty()

# 获取缓存的障碍物角色
func _get_obstacle_characters_cached(exclude_character_id: String) -> Array:
	var cache_key = "obstacles_" + exclude_character_id
	
	if position_cache.has(cache_key):
		var cache_data = position_cache[cache_key]
		if Time.get_ticks_msec() - cache_data.timestamp < 1000:  # 1秒缓存
			return cache_data.data
	
	# 重新获取障碍物数据
	var obstacles = []
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene:
		var characters = battle_scene.get_all_characters()
		for character in characters:
			if character.id != exclude_character_id:
				obstacles.append(character)
	
	# 更新缓存
	position_cache[cache_key] = {
		"data": obstacles,
		"timestamp": Time.get_ticks_msec()
	}
	
	obstacle_cache_updated.emit(obstacles.size())
	return obstacles

# 获取角色实际位置
func get_character_actual_position(character_id: String) -> Vector2:
	var character_node = _get_character_node_by_id(character_id)
	if character_node:
		return character_node.global_position
	return Vector2.ZERO

# 通过ID获取角色节点
func _get_character_node_by_id(character_id: String) -> Node:
	var battle_scene = AutoLoad.get_battle_scene()
	if not battle_scene:
		return null
	
	var characters = battle_scene.get_all_characters()
	for character in characters:
		if character.id == character_id:
			return character
	
	return null

# 清理缓存
func clear_cache():
	position_cache.clear()
	print("PositionCollisionManager: 缓存已清理")

# 设置缓存生命周期
func set_cache_lifetime(lifetime_ms: int):
	cache_lifetime_ms = lifetime_ms
	print("PositionCollisionManager: 缓存生命周期设置为 ", lifetime_ms, "ms")

# 获取验证统计信息
func get_validation_stats() -> Dictionary:
	return {
		"version": "2.0.0",
		"architecture": "统一验证管理器",
		"cache_size": position_cache.size(),
		"cache_lifetime_ms": cache_lifetime_ms,
		"supported_shapes": ["圆形", "胶囊体", "点"],
		"validation_checks": [
			"圆形范围检查",
			"地面约束检查",
			"角色碰撞检查",
			"静态障碍物检查"
		],
		"features": [
			"四重验证逻辑",
			"批量验证",
			"智能缓存",
			"信号通知",
			"性能统计"
		]
	}

# 🐛 按T键触发的调试信息输出函数
func output_debug_info_for_position(target_position: Vector2, character: Node2D) -> void:
	print("\n=== 🐛 PositionCollisionManager 调试信息 ===")
	print("📍 目标位置: %s" % target_position)
	
	if not character:
		print("❌ 角色节点为空")
		return
	
	print("👤 角色信息:")
	print("  - 角色名称: %s" % character.name)
	print("  - 角色位置: %s" % character.global_position)
	print("  - 角色类型: %s" % character.get_class())
	
	# 🚀 新增：GroundAnchor位置计算详细信息
	print("\n🎯 GroundAnchor位置计算:")
	var ground_anchor_offset = Vector2(0, 22)  # 默认偏移量
	var ground_anchor = character.get_node_or_null("GroundAnchor")
	if ground_anchor:
		ground_anchor_offset = ground_anchor.position
		print("  - GroundAnchor节点: ✅ 找到")
		print("  - GroundAnchor偏移: %s" % ground_anchor_offset)
	else:
		print("  - GroundAnchor节点: ❌ 未找到，使用默认偏移")
		print("  - 默认偏移: %s" % ground_anchor_offset)
	
	var ground_anchor_position = target_position + ground_anchor_offset
	print("  - 鼠标位置（角色中心）: %s" % target_position)
	print("  - GroundAnchor实际位置: %s" % ground_anchor_position)
	print("  - Y轴偏移量: %.1f像素" % ground_anchor_offset.y)
	
	# 🚀 新增：地面约束检测详细信息
	print("\n🌍 地面约束检测:")
	var is_on_ground = _is_position_on_ground(ground_anchor_position)
	var is_on_water = _is_position_on_water(ground_anchor_position)
	var ground_constraint_valid = is_on_ground or is_on_water
	
	print("  - 地面检测位置: %s" % ground_anchor_position)
	print("  - 地面检测范围: 向下50像素")
	print("  - 地面层检测（层1）: %s" % ("✅ 检测到地面" if is_on_ground else "❌ 无地面"))
	print("  - 水面层检测（层16）: %s" % ("✅ 检测到水面" if is_on_water else "❌ 无水面"))
	print("  - 地面约束结果: %s" % ("✅ 通过" if ground_constraint_valid else "❌ 失败"))
	
	# 🚀 新增：射线检测详细信息
	print("\n🔍 射线检测详细信息:")
	var space_state_2d = get_world_2d().direct_space_state
	if space_state_2d:
		print("  - 物理空间状态: ✅ 可用")
		
		# 地面射线检测
		var ground_ray_start = ground_anchor_position
		var ground_ray_end = ground_anchor_position + Vector2(0, 50)
		var ground_ray_query = PhysicsRayQueryParameters2D.create(ground_ray_start, ground_ray_end, 1)
		var ground_result = space_state_2d.intersect_ray(ground_ray_query)
		
		print("  📏 地面射线检测:")
		print("    - 起点: %s" % ground_ray_start)
		print("    - 终点: %s" % ground_ray_end)
		print("    - 检测层: 1 (地面层)")
		if not ground_result.is_empty():
			var hit_point = ground_result.get("position", Vector2.ZERO)
			var hit_normal = ground_result.get("normal", Vector2.ZERO)
			var hit_collider = ground_result.get("collider")
			var distance_to_ground = ground_ray_start.distance_to(hit_point)
			print("    - 结果: ✅ 击中地面")
			print("    - 击中点: %s" % hit_point)
			print("    - 击中法线: %s" % hit_normal)
			print("    - 距离地面: %.1f像素" % distance_to_ground)
			if hit_collider:
				print("    - 击中对象: %s" % hit_collider.name)
		else:
			print("    - 结果: ❌ 未击中地面")
		
		# 水面射线检测
		var water_ray_query = PhysicsRayQueryParameters2D.create(ground_ray_start, ground_ray_end, 16)
		var water_result = space_state_2d.intersect_ray(water_ray_query)
		
		print("  🌊 水面射线检测:")
		print("    - 起点: %s" % ground_ray_start)
		print("    - 终点: %s" % ground_ray_end)
		print("    - 检测层: 16 (水面层)")
		if not water_result.is_empty():
			var hit_point = water_result.get("position", Vector2.ZERO)
			var hit_collider = water_result.get("collider")
			var distance_to_water = ground_ray_start.distance_to(hit_point)
			print("    - 结果: ✅ 击中水面")
			print("    - 击中点: %s" % hit_point)
			print("    - 距离水面: %.1f像素" % distance_to_water)
			if hit_collider:
				print("    - 击中对象: %s" % hit_collider.name)
		else:
			print("    - 结果: ❌ 未击中水面")
	else:
		print("  - 物理空间状态: ❌ 不可用")
	
	# 🚀 新增：场景中地面对象检查
	print("\n🏗️ 场景地面对象检查:")
	_check_scene_ground_objects()
	
	# 🚀 新增：碰撞层设置检查
	print("\n⚙️ 碰撞层设置检查:")
	_check_collision_layer_settings()
	
	# 轻功技能检查
	print("\n🏃 轻功技能检查:")
	var character_data = null
	if character.has_method("get_character_data"):
		character_data = character.get_character_data()
	
	if character_data and "qinggong_skill" in character_data:
		var qinggong_skill = character_data.qinggong_skill
		var distance = character.global_position.distance_to(target_position)
		var max_distance = qinggong_skill
		var qinggong_valid = distance <= max_distance
		print("  - 角色当前位置: %s" % character.global_position)
		print("  - 目标位置: %s" % target_position)
		print("  - 当前距离: %.1f" % distance)
		print("  - 最大距离: %.1f" % max_distance)
		print("  - 轻功检查: %s" % ("✅ 通过" if qinggong_valid else "❌ 失败"))
		
		# 检查飞行能力
		var can_fly = false
		if character_data and character_data.has_method("can_fly"):
			can_fly = character_data.can_fly()
		print("  - 飞行能力: %s" % ("✅ 可以飞行" if can_fly else "❌ 不能飞行"))
		if can_fly:
			print("  - 地面约束: 🚀 跳过（角色可以飞行）")
	else:
		print("  - 轻功技能: ❌ 无角色数据或无轻功技能")
	
	# 物理碰撞检查（简化版本）
	print("\n🔍 物理碰撞检查:")
	if space_state:
		var collision_shape = _get_character_collision_shape(character)
		if collision_shape:
			print("  - 角色碰撞形状: ✅ %s" % collision_shape.get_class())
			var is_valid = _perform_physical_validation(target_position, character)
			print("  - 物理碰撞检测: %s" % ("✅ 无碰撞" if is_valid else "❌ 有碰撞"))
		else:
			print("  - 角色碰撞形状: ❌ 无法获取")
	else:
		print("  - 物理空间状态: ❌ 未初始化")
	
	# 障碍物系统状态
	print("\n🚧 障碍物系统状态:")
	var obstacle_manager = get_tree().get_first_node_in_group("obstacle_manager")
	if obstacle_manager:
		print("  - 障碍物管理器: ✅ 已找到")
		if obstacle_manager.has_method("get_obstacles"):
			var obstacles = obstacle_manager.get_obstacles()
			print("  - 当前障碍物数量: %d" % obstacles.size())
			if obstacles.size() > 0:
				print("  - 当前存在的障碍物:")
				for obstacle in obstacles:
					if obstacle and is_instance_valid(obstacle):
						var distance_to_obstacle = target_position.distance_to(obstacle.global_position)
						print("    * %s (位置: %s, 碰撞层: %d, 距离: %.1f)" % [obstacle.name, obstacle.global_position, obstacle.collision_layer, distance_to_obstacle])
			else:
				print("  - 当前无障碍物")
		else:
			print("  - 障碍物管理器: ❌ 没有get_obstacles方法")
	else:
		print("  - 障碍物管理器: ❌ 未找到")
	
	# 🚀 新增：完整验证流程详细信息
	print("\n🎯 完整验证流程:")
	print("  - 验证位置: %s" % target_position)
	print("  - 验证角色: %s" % character.name)
	
	# 分步验证
	var qinggong_result = _validate_qinggong_range(target_position, character)
	var ground_constraint_result = _validate_ground_constraint(target_position, character)
	var physical_result = _perform_physical_validation(target_position, character)
	
	print("  📋 分步验证结果:")
	print("    1. 轻功范围检查: %s" % ("✅ 通过" if qinggong_result else "❌ 失败"))
	print("    2. 地面约束检查: %s" % ("✅ 通过" if ground_constraint_result else "❌ 失败"))
	print("    3. 物理碰撞检查: %s" % ("✅ 通过" if physical_result else "❌ 失败"))
	
	# 最终结果
	var final_result = validate_position(target_position, character)
	print("\n🏆 最终验证结果: %s" % ("✅ 位置有效，可以移动" if final_result else "❌ 位置无效，显示X标记"))
	
	# 问题诊断
	if not final_result:
		print("\n🔧 问题诊断:")
		if not qinggong_result:
			print("  ⚠️ 轻功范围不足 - 距离超出轻功技能范围")
		if not ground_constraint_result:
			print("  ⚠️ 地面约束失败 - GroundAnchor位置不在地面或水面上")
			print("    💡 建议检查: GroundAnchor位置(%s)下方是否有地面层(1)或水面层(16)" % ground_anchor_position)
		if not physical_result:
			print("  ⚠️ 物理碰撞冲突 - 目标位置存在障碍物")
	
	print("\n📊 统计信息:")
	print("  - 验证次数: %d" % validation_count)
	print("  - 缓存命中: %d" % cache_hit_count)
	print("  - 物理检查: %d" % physics_check_count)
	if validation_count > 0:
		print("  - 缓存命中率: %.1f%%" % (float(cache_hit_count) / validation_count * 100.0))
	print("=== PositionCollisionManager 调试信息结束 ===\n")

# 执行物理碰撞验证（移除调试日志，提高性能）
func _perform_physical_validation(target_position: Vector2, exclude_character: Node2D) -> bool:
	if not space_state:
		return false
	
	# 获取角色的碰撞形状
	var collision_shape = _get_character_collision_shape(exclude_character)
	if not collision_shape:
		return false
	
	# 设置查询参数
	query.shape = collision_shape
	query.transform.origin = target_position
	var exclude_rids = []
	if exclude_character:
		var char_area = exclude_character.get_node_or_null("CharacterArea")
		if char_area:
			exclude_rids.append(char_area.get_rid())
	query.exclude = exclude_rids
	
	# 执行碰撞检测
	var result = space_state.intersect_shape(query)
	physics_check_count += 1
	
	# 返回结果（true表示无碰撞，false表示有碰撞）
	return result.size() == 0

# 🐛 按W键触发的物理验证详细调试信息
func output_physical_validation_debug(target_position: Vector2, exclude_character: Node2D) -> void:
	print("\n=== 🐛 物理验证详细调试信息 ===\n")
	
	if not space_state:
		print("❌ 物理空间状态未初始化")
		return
	
	# 获取角色的碰撞形状
	var collision_shape = _get_character_collision_shape(exclude_character)
	if not collision_shape:
		print("❌ 无法获取角色碰撞形状")
		return
	
	# 设置查询参数
	query.shape = collision_shape
	query.transform.origin = target_position
	var exclude_rids = []
	if exclude_character:
		var char_area = exclude_character.get_node_or_null("CharacterArea")
		if char_area:
			exclude_rids.append(char_area.get_rid())
	query.exclude = exclude_rids
	
	# 🐛 详细调试输出
	print("🔍 [物理查询详情]")
	print("  📍 查询位置: %s" % target_position)
	print("  🎭 碰撞掩码: %d (二进制: %s)" % [collision_mask, String.num_int64(collision_mask, 2)])
	print("  🔧 查询形状: %s" % collision_shape.get_class())
	
	# 🐛 碰撞形状详细信息
	if collision_shape is CapsuleShape2D:
		var capsule = collision_shape as CapsuleShape2D
		print("  📏 胶囊形状 - 半径: %.2f, 高度: %.2f" % [capsule.radius, capsule.height])
	
	# 🐛 变换矩阵信息
	var transform_2d = query.transform
	print("  🔄 变换矩阵:")
	print("    - 位置: %s" % transform_2d.origin)
	print("    - 旋转: %.2f度" % rad_to_deg(transform_2d.get_rotation()))
	print("    - 缩放: %s" % transform_2d.get_scale())
	
	# 🐛 查询参数完整信息
	print("  ⚙️ 查询参数:")
	print("    - 碰撞掩码: %d" % query.collision_mask)
	print("    - 排除对象: %s" % query.exclude)
	print("    - 碰撞类型(Areas): %s" % query.collide_with_areas)
	print("    - 碰撞体类型(Bodies): %s" % query.collide_with_bodies)
	
	# 🐛 关键问题检查
	if not query.collide_with_areas:
		printerr("❌ 严重问题: collide_with_areas为false，无法检测Area2D类型的障碍物！")
	else:
		print("  ✅ collide_with_areas已启用，可以检测Area2D障碍物")
	
	# 🐛 附近障碍物检查
	print("  🔍 检查附近是否有障碍物:")
	var obstacle_manager = get_tree().get_first_node_in_group("obstacle_manager")
	if obstacle_manager and obstacle_manager.has_method("get_obstacles"):
		var obstacles = obstacle_manager.get_obstacles()
		var nearby_obstacles = []
		for obstacle in obstacles:
			if obstacle and is_instance_valid(obstacle):
				var distance = target_position.distance_to(obstacle.global_position)
				if distance < 100.0:  # 扩大检查范围到100像素
					nearby_obstacles.append(obstacle)
					var layer_mask_match = (obstacle.collision_layer & query.collision_mask) != 0
					print("    - %s: 距离%.1f, 位置%s" % [obstacle.name, distance, obstacle.global_position])
					print("      碰撞层: %d (二进制: %s)" % [obstacle.collision_layer, String.num_int64(obstacle.collision_layer, 2)])
					print("      查询掩码: %d (二进制: %s)" % [query.collision_mask, String.num_int64(query.collision_mask, 2)])
					print("      层掩码匹配: %s (按位与结果: %d)" % ["是" if layer_mask_match else "否", obstacle.collision_layer & query.collision_mask])
					print("      节点类型: %s" % obstacle.get_class())
					if obstacle.has_method("get_rid"):
						print("      RID: %s" % str(obstacle.get_rid()))
		if nearby_obstacles.is_empty():
			print("    - 100像素范围内无障碍物")
	else:
		print("    - 无法获取障碍物管理器或障碍物列表")
	print("  🚫 排除RID数量: %d" % exclude_rids.size())
	
	# 执行碰撞检测
	var result = space_state.intersect_shape(query)
	
	# 🐛 详细结果输出
	print("  📊 碰撞结果数量: %d" % result.size())
	if result.size() > 0:
		print("  🎯 检测到的碰撞对象:")
		for i in range(result.size()):
			var collision = result[i]
			var collider = collision.get("collider")
			if collider:
				print("    [%d] %s (类型: %s, 位置: %s)" % [i, collider.name, collider.get_class(), collider.global_position])
				if collider.has_method("get_rid"):
					print("        RID: %s" % collider.get_rid())
				if "collision_layer" in collider:
					print("        碰撞层: %d" % collider.collision_layer)
		print("  ❌ 位置无效: 检测到碰撞")
	else:
		print("  ✅ 位置有效: 无碰撞检测")
	
	print("\n=== 物理验证调试信息结束 ===\n")





# 缓存管理 - 已移除重复函数定义

# 获取统计信息
func get_statistics() -> Dictionary:
	return {
		"validation_count": validation_count,
		"cache_hit_count": cache_hit_count,
		"physics_check_count": physics_check_count,
		"cache_hit_rate": float(cache_hit_count) / max(validation_count, 1),
		"cache_size": position_cache.size()
	}

# 打印详细状态
func print_status():
	print("\n=== PositionCollisionManager 状态报告 ===")
	print("🔧 初始化状态: ", "完成" if space_state != null else "失败")
	print("⚙️ 配置参数:")
	print("   - 碰撞掩码: ", collision_mask)
	print("📊 运行统计:")
	print("   - 验证请求总数: ", validation_count)
	print("   - 缓存命中次数: ", cache_hit_count)
	print("   - 物理检测次数: ", physics_check_count)
	if validation_count > 0:
		print("   - 缓存命中率: ", "%.1f%%" % (float(cache_hit_count) / validation_count * 100.0))
	print("💾 缓存状态: ", position_cache.size(), " 个条目")
	print("=== 基于物理查询的碰撞检测状态报告结束 ===\n")

# 更新配置
func update_config(new_collision_mask: int):
	collision_mask = new_collision_mask
	
	# 更新查询参数
	if query:
		query.collision_mask = collision_mask
	
	# 清理缓存，因为配置已改变
	clear_cache()
	
	print("[PositionCollisionManager] 配置已更新 - 碰撞掩码: ", new_collision_mask)

# 获取角色的真实碰撞形状
func _get_character_collision_shape(character_node: Node2D) -> Shape2D:
	if not character_node:
		return null
	
	var character_area = character_node.get_node_or_null("CharacterArea")
	if not character_area:
		return null
	
	var collision_shape = character_area.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return null
	
	return collision_shape.shape



# 获取指定位置的碰撞信息
func get_collision_info(target_position: Vector2, exclude_character: Node2D = null) -> Dictionary:
	var info = {
		"position": target_position,
		"is_valid": false,
		"physics_colliders": []
	}
	
	# 获取角色的真实碰撞形状
	var character_shape = null
	if exclude_character:
		character_shape = _get_character_collision_shape(exclude_character)
	
	# 必须获取到角色的真实碰撞形状
	if not character_shape:
		push_error("[PositionCollisionManager] 无法获取角色碰撞形状，获取碰撞信息失败")
		return info
	
	# 使用角色真实形状进行查询
	query.shape = character_shape
	query.transform.origin = target_position
	var exclude_rids = []
	if exclude_character:
		var char_area = exclude_character.get_node_or_null("CharacterArea")
		if char_area:
			exclude_rids.append(char_area.get_rid())
	query.exclude = exclude_rids
	
	# 执行物理查询
	var physics_results = space_state.intersect_shape(query)
	for result in physics_results:
		info.physics_colliders.append({
			"collider": result.collider,
			"shape": result.shape,
			"rid": result.rid
		})
	
	# 判断位置是否有效（无碰撞即有效）
	info.is_valid = info.physics_colliders.is_empty()
	
	return info

# 🚀 新增：检查场景中的地面对象
func _check_scene_ground_objects() -> void:
	var scene_tree = get_tree()
	if not scene_tree:
		print("  - 场景树: ❌ 不可用")
		return
	
	var current_scene = scene_tree.current_scene
	if not current_scene:
		print("  - 当前场景: ❌ 不可用")
		return
	
	print("  - 当前场景: ✅ %s" % current_scene.name)
	
	# 查找所有StaticBody2D节点（通常用作地面）
	var static_bodies = _find_nodes_by_type(current_scene, "StaticBody2D")
	print("  - StaticBody2D节点数量: %d" % static_bodies.size())
	
	for i in range(min(static_bodies.size(), 5)):  # 最多显示5个
		var body = static_bodies[i]
		var collision_layer = body.collision_layer
		var collision_mask = body.collision_mask
		print("    [%d] %s - 层:%d 掩码:%d" % [i+1, body.name, collision_layer, collision_mask])
		
		# 检查是否在地面层或水面层
		var is_ground_layer = (collision_layer & 1) != 0  # 第1位
		var is_water_layer = (collision_layer & 16) != 0  # 第5位
		if is_ground_layer:
			print("      🌍 地面层: ✅")
		if is_water_layer:
			print("      🌊 水面层: ✅")
		if not is_ground_layer and not is_water_layer:
			print("      ⚠️ 不在地面或水面层")
	
	# 查找所有TileMap节点（通常用作地形）
	var tilemaps = _find_nodes_by_type(current_scene, "TileMap")
	print("  - TileMap节点数量: %d" % tilemaps.size())
	
	for i in range(min(tilemaps.size(), 3)):  # 最多显示3个
		var tilemap = tilemaps[i]
		var collision_layer = tilemap.collision_layer
		print("    [%d] %s - 层:%d" % [i+1, tilemap.name, collision_layer])
		
		# 检查是否在地面层或水面层
		var is_ground_layer = (collision_layer & 1) != 0
		var is_water_layer = (collision_layer & 16) != 0
		if is_ground_layer:
			print("      🌍 地面层: ✅")
		if is_water_layer:
			print("      🌊 水面层: ✅")
		if not is_ground_layer and not is_water_layer:
			print("      ⚠️ 不在地面或水面层")

# 🚀 新增：检查碰撞层设置
func _check_collision_layer_settings() -> void:
	print("  - 地面层(1): 二进制位1 = %s" % ("✅ 启用" if (1 & 1) != 0 else "❌ 禁用"))
	print("  - 水面层(16): 二进制位5 = %s" % ("✅ 启用" if (16 & 16) != 0 else "❌ 禁用"))
	print("  - 层1二进制: %s" % String.num_int64(1, 2).pad_zeros(8))
	print("  - 层16二进制: %s" % String.num_int64(16, 2).pad_zeros(8))
	
	# 检查项目设置中的层名称
	print("  - 项目碰撞层设置:")
	for i in range(1, 6):  # 检查前5层
		var layer_name = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % i, "")
		if layer_name != "":
			print("    层%d: %s" % [i, layer_name])
		else:
			print("    层%d: (未命名)" % i)

# 🚀 新增：递归查找指定类型的节点
func _find_nodes_by_type(node: Node, type_name: String) -> Array:
	var result = []
	if node.get_class() == type_name:
		result.append(node)
	
	for child in node.get_children():
		result.append_array(_find_nodes_by_type(child, type_name))
	
	return result

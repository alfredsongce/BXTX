# 位置计算与碰撞检测统一管理器
# 按照Godot设计理念，作为节点挂载在BattleScene中
# 统一处理所有位置计算和碰撞检测逻辑

class_name PositionCollisionManager
extends Node2D

# 信号定义
signal position_validated(position: Vector2, is_valid: bool)
signal collision_detected(position: Vector2, collider: Node2D)

# 配置参数
@export var collision_mask: int = 0b1000  # 检测障碍物层 (layer 4, mask 8)

# 内部变量
var space_state: PhysicsDirectSpaceState2D
var query: PhysicsShapeQueryParameters2D

# 缓存
var position_cache: Dictionary = {}
var cache_timeout: float = 0.1  # 缓存超时时间

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

# 统一的碰撞检测接口 - 供所有调用方使用
func check_position_collision(position: Vector2, character: Node2D) -> bool:
	return validate_position(position, character)

# 主要验证接口 - 唯一的验证方法（包含物理碰撞和轻功技能检查）
func validate_position(target_position: Vector2, exclude_character: Node2D = null) -> bool:
	validation_count += 1
	
	# 检查缓存
	var cache_key = str(target_position) + "_" + str(exclude_character.get_instance_id() if exclude_character else "null")
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

# 执行统一验证逻辑（物理碰撞 + 轻功技能检查）
func _perform_unified_validation(target_position: Vector2, exclude_character: Node2D = null) -> bool:
	if not exclude_character:
		print("⚠️ [PositionCollisionManager] 角色节点为空")
		return false
	
	# 1. 轻功技能范围检查
	if not _validate_qinggong_range(target_position, exclude_character):
		return false
	
	# 2. 物理碰撞检查
	return _perform_physical_validation(target_position, exclude_character)

# 轻功技能范围验证
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
	
	var qinggong_skill = character_data.qinggong_skill
	var distance = character.global_position.distance_to(target_position)
	
	# 轻功技能值直接作为最大移动距离（像素）
	var max_distance = qinggong_skill
	
	# 移除鼠标移动时的频繁日志输出
	# 改为按T键时输出调试信息
	
	return distance <= max_distance

# 🐛 调试信息输出函数（供外部调用）
func output_debug_info_for_position(target_position: Vector2, character: Node2D) -> void:
	print("\n=== 🐛 PositionCollisionManager 调试信息 ===")
	print("📍 目标位置: %s" % target_position)
	
	if not character:
		print("❌ 角色节点为空")
		return
	
	print("🎭 角色节点: %s" % character.name)
	print("📍 角色当前位置: %s" % character.global_position)
	
	# 轻功范围检查详细信息
	var character_data = null
	if character.has_method("get_character_data"):
		character_data = character.get_character_data()
		if character_data:
			print("✅ 成功获取角色数据: %s" % character_data.name)
			if "qinggong_skill" in character_data:
				var qinggong_skill = character_data.qinggong_skill
				var distance = character.global_position.distance_to(target_position)
				print("🏃 轻功技能值: %d" % qinggong_skill)
				print("📏 移动距离: %.1f" % distance)
				print("✅ 轻功检查: %s" % ("通过" if distance <= qinggong_skill else "失败"))
			else:
				print("❌ 角色数据中没有qinggong_skill属性")
		else:
			print("❌ 无法获取角色数据")
	else:
		print("❌ 角色节点没有get_character_data方法")
	
	# 物理碰撞检查详细信息
	if space_state:
		print("✅ 物理空间状态: 已初始化")
		var collision_shape = _get_character_collision_shape(character)
		if collision_shape:
			print("✅ 角色碰撞形状: 已获取 (%s)" % collision_shape.get_class())
		else:
			print("❌ 无法获取角色碰撞形状")
	else:
		print("❌ 物理空间状态: 未初始化")
	
	# 完整验证结果
	var final_result = validate_position(target_position, character)
	print("🔍 最终验证结果: %s" % ("通过" if final_result else "失败"))
	print("=== PositionCollisionManager 调试信息结束 ===\n")

# 执行物理碰撞验证
func _perform_physical_validation(target_position: Vector2, exclude_character: Node2D) -> bool:
	if not space_state:
		print("⚠️ [PositionCollisionManager] 物理空间状态未初始化")
		return false
	
	# 获取角色的碰撞形状
	var collision_shape = _get_character_collision_shape(exclude_character)
	if not collision_shape:
		print("⚠️ [PositionCollisionManager] 无法获取角色碰撞形状")
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
		for obstacle in obstacles:
			if obstacle and is_instance_valid(obstacle):
				var distance = target_position.distance_to(obstacle.global_position)
				if distance < 50.0:  # 50像素范围内
					print("    - %s: 距离%.1f, 位置%s, 碰撞层%d" % [obstacle.name, distance, obstacle.global_position, obstacle.collision_layer])
	else:
		print("    - 无法获取障碍物管理器或障碍物列表")
	print("  🚫 排除RID数量: %d" % exclude_rids.size())
	
	# 执行碰撞检测
	var result = space_state.intersect_shape(query)
	physics_check_count += 1
	
	# 🐛 详细结果输出
	print("  📊 碰撞结果数量: %d" % result.size())
	if result.size() > 0:
		print("  🎯 检测到的碰撞对象:")
		for i in range(result.size()):
			var collision = result[i]
			var collider = collision.get("collider")
			if collider:
				print("    [%d] %s (类型: %s, 碰撞层: %d)" % [i, collider.name, collider.get_class(), collider.collision_layer])
			else:
				print("    [%d] 未知碰撞对象" % i)
	else:
		print("  ✅ 无碰撞检测到")
	
	# 如果没有碰撞，位置有效
	var is_valid = result.is_empty()
	print("🔍 [PositionCollisionManager] 形状查询结果: %s" % ("通过" if is_valid else "失败"))
	return is_valid





# 缓存管理
func clear_cache():
	position_cache.clear()
	# print("[PositionCollisionManager] 缓存已清空")

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

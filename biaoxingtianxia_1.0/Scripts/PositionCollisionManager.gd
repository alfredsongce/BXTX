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
var move_range_config: MoveRangeConfig  # 🚀 新增：移动范围配置引用

# 缓存
var position_cache: Dictionary = {}
var cache_timeout: float = 0.05  # 缓存超时时间（缩短以提高吸附响应性）
var cache_lifetime_ms: int = 100  # 缓存生命周期（毫秒）

# 统计数据
var validation_count: int = 0
var cache_hit_count: int = 0
var physics_check_count: int = 0

# 🚀 缓存清理计时器
var cache_cleanup_timer: Timer

func _ready():
	print("🔧 [PositionCollisionManager] 初始化基于物理空间查询的统一碰撞检测管理器")
	
	# 初始化物理查询组件
	space_state = get_world_2d().direct_space_state
	print("✅ [PositionCollisionManager] 物理空间状态获取成功: ", space_state != null)
	
	# 🚀 获取MoveRangeConfig引用
	_setup_config_reference()
	
	# 创建物理查询参数
	query = PhysicsShapeQueryParameters2D.new()
	query.collision_mask = collision_mask
	query.collide_with_areas = true  # 🔧 关键修复：启用Area2D碰撞检测
	query.collide_with_bodies = true  # 🔧 关键修复：启用StaticBody2D碰撞检测（障碍物）
	print("✅ [PositionCollisionManager] 物理查询参数配置完成:")
	print("  - 碰撞掩码: %d" % collision_mask)
	print("  - 检测Area2D: %s" % query.collide_with_areas)
	print("  - 检测Bodies: %s" % query.collide_with_bodies)
	
	# 🚀 设置缓存清理计时器
	cache_cleanup_timer = Timer.new()
	cache_cleanup_timer.wait_time = 2.0  # 每2秒清理一次过期缓存
	cache_cleanup_timer.timeout.connect(_on_cache_cleanup_timeout)
	cache_cleanup_timer.autostart = true
	add_child(cache_cleanup_timer)
	
	print("🎯 [PositionCollisionManager] 基于物理查询的统一管理器初始化完成")
	print("🧹 [缓存管理] 自动清理计时器已启动（每2秒清理过期缓存）")

# 🚀 设置配置引用
func _setup_config_reference():
	# 尝试通过多种路径获取MoveRangeConfig
	var battle_scene = AutoLoad.get_battle_scene()
	if battle_scene:
		# 尝试路径1: MoveRange/Config
		move_range_config = battle_scene.get_node_or_null("MoveRange/Config")
		if move_range_config:
			print("✅ [PositionCollisionManager] 成功获取MoveRangeConfig引用: MoveRange/Config")
			return
		
		# 尝试路径2: MoveRangeDisplay/Config
		move_range_config = battle_scene.get_node_or_null("MoveRangeDisplay/Config")
		if move_range_config:
			print("✅ [PositionCollisionManager] 成功获取MoveRangeConfig引用: MoveRangeDisplay/Config")
			return
		
		# 尝试路径3: 查找所有MoveRangeConfig类型的节点
		var config_nodes = battle_scene.find_children("*", "MoveRangeConfig", true, false)
		if config_nodes.size() > 0:
			move_range_config = config_nodes[0]
			print("✅ [PositionCollisionManager] 通过类型查找获取MoveRangeConfig引用")
			return
	
	print("❌ [PositionCollisionManager] 警告: 未找到MoveRangeConfig，将使用默认值")

# 🚀 获取地面高度偏移配置
# 🚀 新增：获取障碍物顶端吸附距离配置值
func _get_obstacle_top_snap_distance() -> int:
	if move_range_config and move_range_config.has_method("get") and "obstacle_top_snap_distance" in move_range_config:
		var distance = move_range_config.obstacle_top_snap_distance
		# print("🔧 [配置获取] obstacle_top_snap_distance配置值: %d像素" % distance)
		return distance
	else:
		print("⚠️ [配置获取] 无法获取obstacle_top_snap_distance配置，使用默认值: 8像素")
		return 8  # 默认值

# 🚀 保留：获取ground_height_offset配置值（用于地面检测）
func _get_ground_height_offset() -> int:
	if move_range_config and move_range_config.has_method("get") and "ground_height_offset" in move_range_config:
		var offset = move_range_config.ground_height_offset
		# print("🔧 [配置获取] ground_height_offset配置值: %d像素" % offset)
		return offset
	else:
		print("⚠️ [配置获取] 无法获取ground_height_offset配置，使用默认值: 1像素")
		return 1  # 默认值

# 🚀 新增：获取地面平台吸附距离配置值
func _get_ground_platform_snap_distance() -> int:
	if move_range_config and move_range_config.has_method("get") and "ground_platform_snap_distance" in move_range_config:
		var distance = move_range_config.ground_platform_snap_distance
		return distance
	else:
		print("⚠️ [配置获取] 无法获取ground_platform_snap_distance配置，使用默认值: 8像素")
		return 8  # 默认值

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
		elif event.keycode == KEY_F1:
			# 切换调试模式
			debug_obstacle_detection = !debug_obstacle_detection
			print("🔧 [调试模式] 障碍物检测调试: %s" % ["开启" if debug_obstacle_detection else "关闭"])
		elif event.keycode == KEY_F2:
			# 输出当前鼠标位置的详细检测信息
			_debug_current_mouse_position()

# 🚀 统一的GroundAnchor获取方法
func get_character_ground_anchor_offset(character: Node2D) -> Vector2:
	if not character:
		push_error("角色节点为空，无法获取GroundAnchor")
		return Vector2.ZERO
	
	var ground_anchor = character.get_node_or_null("GroundAnchor")
	if ground_anchor:
		# 移除过度日志输出 - 只在按F2调试时输出
		return ground_anchor.position
	else:
		push_error("角色 %s 缺少GroundAnchor节点" % character.name)
		return Vector2.ZERO  # 🚀 没有GroundAnchor就报错，不使用默认值

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
	
	# 🔧 修复：直接使用详细验证，保持一致性
	var detailed_result = _perform_detailed_validation(target_position, exclude_character)
	
	# 更新缓存时保存完整信息
	position_cache[cache_key] = {
		"result": detailed_result.is_valid,
		"reason": detailed_result.reason,
		"adjusted_position": detailed_result.get("adjusted_position", target_position),
		"timestamp": Time.get_time_dict_from_system()["second"]
	}
	
	return detailed_result.is_valid

# 🚀 获取详细的验证结果（包含原因）- 新增方法
func get_validation_details(target_position: Vector2, exclude_character: Node2D = null) -> Dictionary:
	validation_count += 1
	# 移除过度日志输出 - 鼠标移动时不输出验证详情
	
	# 🔧 F3调试：显示缓存检查过程
	if debug_obstacle_detection:
		print("🔧 [PCM] get_validation_details被调用:")
		print("  - 位置: %s" % target_position)
		print("  - debug_obstacle_detection: %s" % debug_obstacle_detection)
	
	# 检查缓存
	var cache_key = _generate_cache_key(target_position, exclude_character)
	if position_cache.has(cache_key):
		var cache_data = position_cache[cache_key]
		if Time.get_time_dict_from_system()["second"] - cache_data.timestamp < cache_timeout:
			cache_hit_count += 1
			if debug_obstacle_detection:
				print("🔧 [PCM] 使用缓存结果，跳过详细验证")
			# 🔧 修复：从缓存返回完整的验证结果，包含adjusted_position字段
			var cached_result = {
				"is_valid": cache_data.result,
				"reason": cache_data.reason if cache_data.has("reason") else ("位置有效" if cache_data.result else "位置无效")
			}
			# 如果缓存中有adjusted_position，则包含它
			if cache_data.has("adjusted_position"):
				cached_result["adjusted_position"] = cache_data.adjusted_position
			return cached_result
	
	if debug_obstacle_detection:
		print("🔧 [PCM] 缓存未命中，执行详细验证")
	
	# 执行详细验证
	var validation_result = _perform_detailed_validation(target_position, exclude_character)
	
	# 🔧 修复：更新缓存时保存完整的验证结果，包含adjusted_position字段
	position_cache[cache_key] = {
		"result": validation_result.is_valid,
		"reason": validation_result.reason,
		"adjusted_position": validation_result.get("adjusted_position", target_position),
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
func _generate_cache_key(target_position: Vector2, exclude_character: Node2D = null, is_snap_context: bool = false) -> String:
	var character_id = exclude_character.get_instance_id() if exclude_character else "null"
	var prefix = "snap_" if is_snap_context else "normal_"
	return "%s%s_%s" % [prefix, target_position, character_id]

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
	
	# 2. 地面约束检查（获取详细结果以支持位置调整）
	# 🔧 F3调试：追踪自动吸附调用
	if debug_obstacle_detection:
		print("🔧 [PCM] 调用_validate_ground_constraint_with_adjustment:")
		print("  - 目标位置: %s" % target_position)
	
	var ground_validation_result = _validate_ground_constraint_with_adjustment(target_position, exclude_character)
	
	if debug_obstacle_detection:
		print("🔧 [PCM] 地面约束验证结果:")
		print("  - is_valid: %s" % ground_validation_result.is_valid)
		print("  - adjusted_position: %s" % ground_validation_result.get("adjusted_position", "无"))
		print("  - snapped_to_obstacle: %s" % ground_validation_result.get("snapped_to_obstacle", false))
		if ground_validation_result.has("adjusted_position"):
			var adjustment_distance = target_position.distance_to(ground_validation_result.adjusted_position)
			print("  - 调整距离: %.1f像素" % adjustment_distance)
	
	if not ground_validation_result.is_valid:
		return {"is_valid": false, "reason": "违反地面约束"}
	
	# 3. 物理碰撞检查（使用调整后的位置）
	var adjusted_position = ground_validation_result.get("adjusted_position", target_position)
	var snapped_to_obstacle = ground_validation_result.get("snapped_to_obstacle", false)
	var obstacle_result = ground_validation_result.get("obstacle_result", null)
	
	# 🚀 关键修复：如果吸附到障碍物顶部，跳过对该障碍物的碰撞检查
	var physical_validation_result = false
	if snapped_to_obstacle and obstacle_result:
		# 移除过度日志输出 - 只在按键调试时输出吸附信息
		physical_validation_result = _perform_physical_validation_with_exclusion(adjusted_position, exclude_character, obstacle_result)
	else:
		physical_validation_result = _perform_physical_validation(adjusted_position, exclude_character)
	
	if not physical_validation_result:
		return {"is_valid": false, "reason": "位置存在物理碰撞"}
	
	# 🚀 修复：总是返回adjusted_position字段
	var result = {
		"is_valid": true, 
		"reason": "位置有效",
		"adjusted_position": adjusted_position
	}
	
	if adjusted_position != target_position:
		result["reason"] = "位置有效（已调整到障碍物顶部）"
		# 移除过度日志输出 - 只在按键调试时输出验证结果
	else:
		# 移除过度日志输出 - 只在按键调试时输出验证结果
		pass
	
	return result

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
	
	# 移除过度日志输出 - 轻功范围检查时不输出
	
	if distance > max_range:
		# 移除过度日志输出 - 只在按键调试时输出失败信息
		return false
	
	# 移除过度日志输出 - 轻功检查通过时不输出
	return true



# 🚀 新增：验证地面约束
func _validate_ground_constraint(target_position: Vector2, character: Node2D) -> bool:
	var result = _validate_ground_constraint_with_adjustment(target_position, character)
	return result.is_valid

# 🚀 新增：地面约束验证（使用统一射线检测）
func _validate_ground_constraint_with_adjustment(target_position: Vector2, character: Node2D) -> Dictionary:
	# 移除过度日志输出 - 地面约束验证时不输出开始信息
	
	# 获取角色数据
	var character_data = null
	if character.has_method("get_character_data"):
		character_data = character.get_character_data()
		# 移除过度日志输出 - 获取角色数据时不输出
	else:
		printerr("❌ [地面约束验证] 角色节点没有get_character_data方法")
	
	# 如果角色拥有御剑飞行技能，跳过地面约束检查
	if character_data and character_data.has_method("can_fly"):
		var can_fly = character_data.can_fly()
		# 移除过度日志输出 - 飞行能力检查时不输出
		if can_fly:
			# 移除过度日志输出 - 跳过地面约束时不输出
			return {"is_valid": true, "adjusted_position": target_position, "snapped_to_obstacle": false, "obstacle_result": null}
	else:
		printerr("❌ [地面约束验证] 角色数据无效或没有can_fly方法")
	
	# 获取角色的GroundAnchor位置
	var ground_anchor_position = _get_ground_anchor_position(target_position, character)
	# 移除过度日志输出 - GroundAnchor位置计算时不输出
	
	# 🚀 使用统一射线检测，符合物理规律
	var surface_result = _check_unified_surface(ground_anchor_position)
	# 移除过度日志输出 - 表面检测结果时不输出
	
	# 🚀 根据检测到的表面类型进行位置调整
	var adjusted_position = target_position
	var snapped_to_obstacle = false
	var is_valid = surface_result.is_valid
	
	if is_valid:
		# 获取GroundAnchor偏移量
		var ground_anchor_offset = get_character_ground_anchor_offset(character)
		
		# 根据表面类型调整位置
		if surface_result.surface_type == "obstacle_top":
			# 障碍物顶部吸附
			adjusted_position.y = surface_result.surface_y - ground_anchor_offset.y
			snapped_to_obstacle = true
			# 移除过度日志输出 - 只在按键调试时输出位置调整信息
		elif surface_result.surface_type == "ground":
			# 地面吸附
			adjusted_position.y = surface_result.surface_y - ground_anchor_offset.y
			# 移除过度日志输出 - 只在按键调试时输出位置调整信息
		elif surface_result.surface_type == "water":
			# 水面吸附
			adjusted_position.y = surface_result.surface_y - ground_anchor_offset.y
			# 移除过度日志输出 - 只在按键调试时输出位置调整信息
	
	# 移除过度日志输出 - 最终结果时不输出
	
	# 🚀 返回统一的结果格式
	return {
		"is_valid": is_valid, 
		"adjusted_position": adjusted_position,
		"snapped_to_obstacle": snapped_to_obstacle,
		"obstacle_result": surface_result if (is_valid and surface_result.surface_type == "obstacle_top") else null
	}

# 🚀 新增：获取GroundAnchor在目标位置的实际位置
func _get_ground_anchor_position(target_position: Vector2, character: Node2D) -> Vector2:
	# 获取角色的GroundAnchor偏移量
	var ground_anchor_offset = get_character_ground_anchor_offset(character)
	
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

# 🚀 新增：检查位置是否在有效表面上（使用统一检测）
# 🚀 重要：此函数的position参数必须是GroundAnchor位置
func _is_position_on_valid_surface(ground_anchor_position: Vector2) -> Dictionary:
	# 🚀 直接使用统一射线检测，符合物理规律
	return _check_unified_surface(ground_anchor_position)

# 🚀 统一射线检测：一次检测所有表面类型
# 🚀 重要：此函数的position参数必须是GroundAnchor位置，不是鼠标位置
func _check_unified_surface(ground_anchor_position: Vector2) -> Dictionary:
	# 🚀 参数验证：确保传入的是GroundAnchor位置
	if debug_obstacle_detection:
		print("🔧 [统一表面检测] 使用GroundAnchor位置进行检测: %s" % ground_anchor_position)
	
	var result = {"is_valid": false, "surface_type": "", "surface_y": 0.0}
	
	if not space_state:
		if debug_obstacle_detection:
			print("❌ [统一表面检测] space_state为空，无法进行物理查询")
		return result
	
	# 🚀 修复：射线从GroundAnchor上方开始检测，避免起点在碰撞体内部
	var ray_start = ground_anchor_position + Vector2(0, -50)  # 从上方50像素开始
	var ray_end = ground_anchor_position + Vector2(0, 100)    # 向下100像素
	var ray_query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	ray_query.collision_mask = 1 + 8 + 16  # 地面层(1) + 障碍物层(8) + 水面层(16)
	ray_query.collide_with_areas = true   # 检测水面Area2D
	ray_query.collide_with_bodies = true  # 检测地面和障碍物StaticBody2D
	
	var ray_result = space_state.intersect_ray(ray_query)
	if not ray_result:
		if debug_obstacle_detection:
			print("❌ [统一表面检测] 射线检测未命中任何表面")
		return result
	
	# 🚀 根据碰撞体类型和碰撞层判断表面类型
	var collider = ray_result.collider
	var collision_point_y = ray_result.position.y
	var height_tolerance = _get_ground_height_offset()
	# 🔧 修正：使用GroundAnchor位置计算高度差，确保计算基准统一
	var height_diff = abs(ground_anchor_position.y - collision_point_y)
	
	if debug_obstacle_detection:
		print("🔧 [统一表面检测] 射线参数 - 起点: (%.1f, %.1f), 终点: (%.1f, %.1f)" % [ray_start.x, ray_start.y, ray_end.x, ray_end.y])
		print("🔧 [统一表面检测] 射线命中 - 碰撞点Y: %.1f, 碰撞体: %s, 类型: %s" % [collision_point_y, collider.name if collider else "unknown", collider.get_class()])
		print("🔧 [统一表面检测] 高度差: %.1f, 配置容差: %d像素" % [height_diff, height_tolerance])
	
	# 🚀 判断表面类型并验证
	if collider is Area2D:
		# 水面检测
		if height_diff <= height_tolerance:
			result.is_valid = true
			result.surface_type = "water"
			result.surface_y = collision_point_y
			if debug_obstacle_detection:
				print("✅ [统一表面检测] 水面检测成功")
		else:
			if debug_obstacle_detection:
				print("❌ [统一表面检测] 水面高度差检查失败")
				
	elif collider is StaticBody2D:
		# 检查是否为障碍物（碰撞层8）
		var is_obstacle = (collider.collision_layer & 8) != 0
		var is_ground = (collider.collision_layer & 1) != 0
		
		if is_obstacle:
			# 障碍物顶部检测
			var can_stand = _can_stand_on_obstacle_top(collider)
			if can_stand:
				# 🔧 关键修复：分离吸附检测和站立验证
				var snap_distance = float(_get_obstacle_top_snap_distance())  # 8像素吸附距离
				var stand_tolerance = _get_ground_height_offset()              # 1像素站立容差
				
				if debug_obstacle_detection:
					print("🔧 [WALL调试] 吸附距离: %.1f像素, 站立容差: %d像素" % [snap_distance, stand_tolerance])
					print("🔧 [WALL调试] 高度差: %.1f, 检查吸附范围: %.1f <= %.1f?" % [height_diff, height_diff, snap_distance])
				
				if height_diff <= snap_distance:
					# ✅ 在吸附距离内，自动调整到障碍物顶部1像素位置
					var ground_height_offset = _get_ground_height_offset()
					var corrected_surface_y = collision_point_y - ground_height_offset
					
					result.is_valid = true
					result.surface_type = "obstacle_top"
					result.surface_y = corrected_surface_y
					result.collider = collider  # 🚀 确保返回碰撞体信息用于排除逻辑
					
					if debug_obstacle_detection:
						print("✅ [WALL调试] 障碍物自动吸附成功!")
						print("  - 障碍物: %s" % collider.name)
						print("  - 碰撞点Y: %.1f" % collision_point_y)
						print("  - 自动调整到: %.1f (障碍物顶部-%d像素)" % [corrected_surface_y, ground_height_offset])
				else:
					if debug_obstacle_detection:
						print("❌ [WALL调试] 超出吸附距离，高度差%.1f > 吸附距离%.1f" % [height_diff, snap_distance])
			else:
				if debug_obstacle_detection:
					print("❌ [统一表面检测] 障碍物类型不可站立: %s" % collider.name)
					
		elif is_ground:
			# 地面检测
			if height_diff <= height_tolerance:
				result.is_valid = true
				result.surface_type = "ground"
				result.surface_y = collision_point_y
				if debug_obstacle_detection:
					print("✅ [统一表面检测] 地面检测成功")
			else:
				if debug_obstacle_detection:
					print("❌ [统一表面检测] 地面高度差检查失败")
		else:
			if debug_obstacle_detection:
				print("❌ [统一表面检测] 未知碰撞体类型或层")
	
	return result

# 🚀 保留原有接口的兼容性包装函数
# 🚀 重要：这些函数的position参数必须是GroundAnchor位置
func _check_ground_surface(ground_anchor_position: Vector2) -> Dictionary:
	var unified_result = _check_unified_surface(ground_anchor_position)
	if unified_result.surface_type == "ground":
		return unified_result
	else:
		return {"is_valid": false, "surface_type": "ground", "surface_y": 0.0}

func _check_water_surface(ground_anchor_position: Vector2) -> Dictionary:
	var unified_result = _check_unified_surface(ground_anchor_position)
	if unified_result.surface_type == "water":
		return unified_result
	else:
		return {"is_valid": false, "surface_type": "water", "surface_y": 0.0}

func _check_obstacle_top_surface(ground_anchor_position: Vector2) -> Dictionary:
	var unified_result = _check_unified_surface(ground_anchor_position)
	if unified_result.surface_type == "obstacle_top":
		return unified_result
	else:
		return {"is_valid": false, "surface_type": "obstacle_top", "surface_y": 0.0}

# 🚀 已废弃的原始水面检测函数（保留用于参考）
func _check_water_surface_legacy(position: Vector2) -> Dictionary:
	var result = {"is_valid": false, "surface_type": "water", "surface_y": 0.0}
	
	if not space_state:
		if debug_obstacle_detection:
			print("❌ [水面检测] 物理空间状态未初始化")
		return result
	
	# 🚀 改为射线查询：从角色位置向下发射射线检测水面
	var ray_query = PhysicsRayQueryParameters2D.new()
	ray_query.from = position
	ray_query.to = position + Vector2(0, 100)  # 向下100像素
	ray_query.collision_mask = 16  # 水面层
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = false
	
	var ray_result = space_state.intersect_ray(ray_query)
	if ray_result:
		var water_area = ray_result.collider as Area2D
		if water_area:
			var water_y = ray_result.position.y
			var height_tolerance = _get_ground_height_offset()
			var height_diff = abs(position.y - water_y)
			
			if height_diff <= height_tolerance:
				result.is_valid = true
				result.surface_y = water_y
				if debug_obstacle_detection:
					print("✅ [水面检测] 成功 - 在允许高度范围内")
			else:
				if debug_obstacle_detection:
					print("❌ [水面检测] 失败 - 超出允许高度范围 (%.1f > %d)" % [height_diff, height_tolerance])
		else:
			if debug_obstacle_detection:
				print("❌ [水面检测] 水面区域无效")
	else:
		if debug_obstacle_detection:
			print("❌ [水面检测] 未检测到水面")
	
	return result

# 🚀 调试模式控制变量
var debug_obstacle_detection = false

func _debug_current_mouse_position():
	var mouse_pos = get_global_mouse_position()
	print("\n🔍 [F2调试] 当前鼠标位置详细检测: %s" % mouse_pos)
	
	# 🎯 第一步修复验证：统一GroundAnchor读取方法
	print("\n🎯 [第一步验证] 统一GroundAnchor读取方法:")
	var character = get_tree().get_first_node_in_group("player")
	if character:
		print("  ✅ 找到玩家角色: %s" % character.name)
		
		# 测试GroundAnchor读取（此时会输出详细信息）
		var ground_anchor = character.get_node_or_null("GroundAnchor")
		if ground_anchor:
			print("  ✅ [GroundAnchor] 从角色 %s 读取偏移: %s" % [character.name, ground_anchor.position])
			print("  ✅ 第一步修复生效：从角色节点读取GroundAnchor偏移")
		else:
			print("  ❌ 角色缺少GroundAnchor节点")
	
	# 🎯 第二步修复验证：统一高度差计算基准
	print("\n🎯 [第二步验证] 统一高度差计算基准:")
	print("  ✅ 所有高度差计算函数已统一使用GroundAnchor位置作为基准")
	print("  ✅ 第二步修复生效：参数命名为ground_anchor_position")
	
	# 🎯 第三步修复验证：统一吸附距离配置
	print("\n🎯 [第三步验证] 统一吸附距离配置:")
	var ground_snap_distance = _get_ground_platform_snap_distance()
	print("  - 地面平台吸附距离: %d像素" % ground_snap_distance)
	print("  ✅ 第三步修复生效：从配置文件读取吸附距离")
	print("  - 配置路径: ../Config.ground_platform_snap_distance")
	
	# 🎯 第五步修复验证：优化缓存机制
	print("\n🎯 [第五步验证] 优化缓存机制:")
	print("  - 缓存超时时间: %.2f秒（已优化）" % cache_timeout)
	print("  - 自动清理间隔: %.1f秒" % (cache_cleanup_timer.wait_time if cache_cleanup_timer else 0))
	print("  - 当前缓存条目数: %d" % position_cache.size())
	print("  ✅ 第五步修复生效：缩短缓存时间，提高吸附响应性")
	
	if character:
		# 测试get_validation_details的详细输出
		print("\n  🔍 测试位置验证详情（缓存系统）:")
		var test_pos = mouse_pos
		var validation_details = get_validation_details(test_pos, character)
		print("    📋 验证结果: %s" % ("有效" if validation_details.is_valid else "无效"))
		print("    📋 验证原因: %s" % validation_details.reason)
		if validation_details.has("adjusted_position"):
			print("    📋 调整位置: %s" % validation_details.adjusted_position)
			if validation_details.adjusted_position != test_pos:
				print("    🎯 [F2调试] 位置已调整: %s -> %s" % [test_pos, validation_details.adjusted_position])
	else:
		print("  ❌ 未找到玩家角色")
	
	# 临时开启调试模式
	var old_debug = debug_obstacle_detection
	debug_obstacle_detection = true
	
	# 🔧 修正：计算对应的GroundAnchor位置进行检测
	var ground_anchor_offset = get_character_ground_anchor_offset(character) if character else Vector2(0, 22)
	var ground_anchor_pos = mouse_pos + ground_anchor_offset
	print("🔧 [F2调试] GroundAnchor位置: %s (鼠标位置 + 偏移%s)" % [ground_anchor_pos, ground_anchor_offset])
	
	# 🚀 使用统一射线检测（传入GroundAnchor位置）
	var unified_result = _check_unified_surface(ground_anchor_pos)
	
	print("📊 [F2调试] 统一检测结果:")
	if unified_result.is_valid:
		print("  ✅ 检测成功 - 表面类型: %s, 表面Y: %.1f" % [unified_result.surface_type, unified_result.surface_y])
	else:
		print("  ❌ 检测失败 - 未找到有效表面")
	
	# 🚀 为了对比，也显示分离检测的结果（同样使用GroundAnchor位置）
	print("📊 [F2调试] 分离检测对比:")
	var ground_result = _check_ground_surface(ground_anchor_pos)
	var water_result = _check_water_surface(ground_anchor_pos)
	var obstacle_result = _check_obstacle_top_surface(ground_anchor_pos)
	print("  - 地面检测: %s" % ["✅有效" if ground_result.is_valid else "❌无效"])
	print("  - 水面检测: %s" % ["✅有效" if water_result.is_valid else "❌无效"])
	print("  - 障碍物检测: %s" % ["✅有效" if obstacle_result.is_valid else "❌无效"])
	
	# 测试位置吸附调整功能
	if character:
		print("\n  🎯 测试位置吸附调整功能:")
		var ground_validation = _validate_ground_constraint_with_adjustment(ground_anchor_pos, character)
		if ground_validation.is_valid:
			var adjusted = ground_validation.adjusted_position
			var snapped = ground_validation.snapped_to_obstacle
			if adjusted != ground_anchor_pos:
				print("    🎯 [F2调试] 障碍物顶部吸附: %s -> %s" % [ground_anchor_pos, adjusted])
			else:
				print("    🎯 [F2调试] 位置无需调整: %s" % ground_anchor_pos)
			if snapped:
				print("    🎯 [F2调试] 检测到障碍物吸附，会跳过对吸附障碍物的碰撞检查")
				
				# 🎯 第四步修复验证：物理碰撞排除逻辑
				print("\n🎯 [第四步验证] 增强物理碰撞排除逻辑:")
				if ground_validation.has("obstacle_result") and ground_validation.obstacle_result:
					var obstacle_data = ground_validation.obstacle_result
					print("  ✅ 障碍物数据验证: surface_type=%s, collider=%s" % [
						obstacle_data.get("surface_type", "未知"),
						obstacle_data.get("collider").name if obstacle_data.has("collider") and obstacle_data.collider else "无"
					])
					print("  ✅ 第四步修复生效：严格数据验证和碰撞体排除")
				else:
					print("  ❌ 未获取到障碍物排除数据")
		else:
			print("    ❌ 地面约束验证失败")
	
	# 恢复调试模式
	debug_obstacle_detection = old_debug
	print("🔍 [F2调试] 详细检测完成\n")



# 🚀 新增：检查是否可以站立在障碍物顶部
func _can_stand_on_obstacle_top(obstacle: StaticBody2D) -> bool:
	# 检查是否有obstacle_type属性
	if not obstacle.has_method("get") or not obstacle.has_meta("obstacle_type"):
		# 尝试直接访问属性
		if "obstacle_type" in obstacle:
			var obstacle_type = obstacle.obstacle_type
			# 🚀 扩展支持：平台、墙壁、岩石都可以站立在顶部
			var can_stand = obstacle_type == Obstacle.ObstacleType.PLATFORM or obstacle_type == Obstacle.ObstacleType.WALL or obstacle_type == Obstacle.ObstacleType.ROCK
			if debug_obstacle_detection:
				print("🔧 [障碍物类型检查] %s 类型: %s, 可站立: %s" % [obstacle.name, obstacle_type, can_stand])
			return can_stand
		else:
			if debug_obstacle_detection:
				print("❌ [障碍物类型检查] 障碍物没有obstacle_type属性: %s" % obstacle.name)
			return false
	else:
		# 通过meta访问
		var obstacle_type = obstacle.get_meta("obstacle_type")
		# 🚀 扩展支持：平台、墙壁、岩石都可以站立在顶部
		var can_stand = obstacle_type == Obstacle.ObstacleType.PLATFORM or obstacle_type == Obstacle.ObstacleType.WALL or obstacle_type == Obstacle.ObstacleType.ROCK
		if debug_obstacle_detection:
			print("🔧 [障碍物类型检查] %s meta类型: %s, 可站立: %s" % [obstacle.name, obstacle_type, can_stand])
		return can_stand

# 🚀 新增：获取障碍物顶部Y坐标
func _get_obstacle_top_y(obstacle: StaticBody2D) -> float:
	print("🔍 [障碍物Y坐标计算] 开始计算障碍物顶部Y坐标: %s" % obstacle.name)
	
	var collision_shape = obstacle.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		print("❌ [障碍物Y坐标计算] 未找到CollisionShape2D或shape为空，使用障碍物位置: %.1f" % obstacle.global_position.y)
		return obstacle.global_position.y
	
	var shape = collision_shape.shape
	var obstacle_pos = obstacle.global_position
	print("🔧 [障碍物Y坐标计算] 障碍物位置: %s, 形状类型: %s" % [obstacle_pos, shape.get_class()])
	
	if shape is CircleShape2D:
		# 圆形障碍物：顶部Y = 中心Y - 半径
		var radius = (shape as CircleShape2D).radius
		var top_y = obstacle_pos.y - radius
		print("🔧 [障碍物Y坐标计算] 圆形障碍物 - 中心Y: %.1f, 半径: %.1f, 顶部Y: %.1f" % [obstacle_pos.y, radius, top_y])
		return top_y
	elif shape is RectangleShape2D:
		# 矩形障碍物：顶部Y = 中心Y - 高度/2
		var size = (shape as RectangleShape2D).size
		var top_y = obstacle_pos.y - size.y / 2
		print("🔧 [障碍物Y坐标计算] 矩形障碍物 - 中心Y: %.1f, 尺寸: %s, 顶部Y: %.1f" % [obstacle_pos.y, size, top_y])
		return top_y
	else:
		# 其他形状：使用障碍物位置
		print("⚠️ [障碍物Y坐标计算] 未知形状类型，使用障碍物位置: %.1f" % obstacle_pos.y)
		return obstacle_pos.y

# 🚀 新增：检查位置是否在障碍物X范围内
func _is_position_in_obstacle_x_range(position: Vector2, obstacle: StaticBody2D) -> bool:
	print("🔍 [障碍物X范围检查] 开始检查位置 %s 是否在障碍物 %s 的X范围内" % [position, obstacle.name])
	
	var collision_shape = obstacle.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		print("❌ [障碍物X范围检查] 未找到CollisionShape2D或shape为空")
		return false
	
	var shape = collision_shape.shape
	var obstacle_pos = obstacle.global_position
	print("🔧 [障碍物X范围检查] 障碍物位置: %s, 形状类型: %s" % [obstacle_pos, shape.get_class()])
	
	if shape is CircleShape2D:
		# 圆形障碍物：检查X距离是否在半径内
		var radius = (shape as CircleShape2D).radius
		var x_distance = abs(position.x - obstacle_pos.x)
		var in_range = x_distance <= radius
		print("🔧 [障碍物X范围检查] 圆形障碍物 - 位置X: %.1f, 障碍物X: %.1f, X距离: %.1f, 半径: %.1f, 结果: %s" % [position.x, obstacle_pos.x, x_distance, radius, "在范围内" if in_range else "超出范围"])
		return in_range
	elif shape is RectangleShape2D:
		# 矩形障碍物：检查X坐标是否在宽度范围内
		var size = (shape as RectangleShape2D).size
		var half_width = size.x / 2
		var left_bound = obstacle_pos.x - half_width
		var right_bound = obstacle_pos.x + half_width
		var in_range = position.x >= left_bound and position.x <= right_bound
		print("🔧 [障碍物X范围检查] 矩形障碍物 - 位置X: %.1f, 左边界: %.1f, 右边界: %.1f, 宽度: %.1f, 结果: %s" % [position.x, left_bound, right_bound, size.x, "在范围内" if in_range else "超出范围"])
		return in_range
	else:
		# 其他形状：默认不在范围内
		print("⚠️ [障碍物X范围检查] 未知形状类型，默认不在范围内")
		return false

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

# 🚀 新增：清理过期缓存（提高吸附响应性）
func clear_expired_cache():
	var current_time = Time.get_time_dict_from_system()["second"]
	var keys_to_remove = []
	
	for key in position_cache.keys():
		var cache_data = position_cache[key]
		if current_time - cache_data.timestamp >= cache_timeout:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		position_cache.erase(key)
	
	if keys_to_remove.size() > 0:
		print("🧹 [缓存清理] 清理了 %d 个过期缓存条目" % keys_to_remove.size())

# 🚀 缓存清理计时器回调
func _on_cache_cleanup_timeout():
	clear_expired_cache()

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
	var ground_anchor_offset = get_character_ground_anchor_offset(character)
	
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
func _perform_physical_validation_with_exclusion(target_position: Vector2, exclude_character: Node2D, exclude_obstacle_result: Dictionary) -> bool:
	# 🚀 严格数据验证 - demo期间崩溃是好事，充分暴露问题
	if not exclude_obstacle_result.has("surface_type"):
		printerr("❌ [物理验证] 排除障碍物数据必须包含surface_type字段")
		return false
	
	if exclude_obstacle_result.surface_type != "obstacle_top":
		printerr("❌ [物理验证] 只有障碍物顶部类型才能执行排除逻辑，当前类型: %s" % exclude_obstacle_result.surface_type)
		return _perform_physical_validation(target_position, exclude_character)
	
	if not exclude_obstacle_result.has("collider"):
		printerr("❌ [物理验证] 排除障碍物数据必须包含collider字段")
		return false
	
	var obstacle_collider = exclude_obstacle_result.collider
	if obstacle_collider == null:
		printerr("❌ [物理验证] 障碍物碰撞体不能为空")
		return false
	
	if not obstacle_collider.has_method("get_rid"):
		printerr("❌ [物理验证] 障碍物碰撞体必须有get_rid方法，当前类型: %s" % obstacle_collider.get_class())
		return false

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
	
	# 🚀 关键：排除吸附的障碍物（使用已验证的obstacle_collider）
	exclude_rids.append(obstacle_collider.get_rid())
	# print("🚫 [物理验证] 排除吸附障碍物: %s (RID: %s)" % [obstacle_collider.name, obstacle_collider.get_rid()])
	
	query.exclude = exclude_rids
	
	# 执行碰撞检测
	var result = space_state.intersect_shape(query)
	physics_check_count += 1
	
	# print("🔍 [物理验证] 位置: %s, 排除RID数量: %d, 碰撞结果: %d" % [target_position, exclude_rids.size(), result.size()])
	
	# 返回结果（true表示无碰撞，false表示有碰撞）
	return result.size() == 0

# 🚀 原有的物理验证函数
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

# 🚀 移动协调器 - 统一管理角色移动逻辑
# Movement Coordinator - Unified character movement logic management

class_name MovementCoordinator
extends Node

# 移动相关信号
signal movement_started(character: GameCharacter, target_position: Vector2)
signal movement_completed(character: GameCharacter, final_position: Vector2)
signal movement_cancelled(character: GameCharacter, reason: String)

# 移动配置
@export var base_move_speed: float = 400.0  # 基础移动速度(像素/秒)
@export var min_move_duration: float = 0.5  # 最短移动时间(秒)
@export var max_move_duration: float = 1.5  # 最长移动时间(秒)

# 内部状态
var characters_moving = {}  # 用于存储正在移动的角色信息
var character_manager: Node  # BattleCharacterManager或ParticipantManager
var move_range_controller: Node
var action_system: Node

func _ready():
	_setup_node_references()
	_connect_signals()

func _setup_node_references():
	# 获取必要的节点引用
	move_range_controller = get_node_or_null("../../MoveRange/Controller")
	action_system = get_node_or_null("../../ActionSystem")
	
	# 等待 BattleCharacterManager 被创建
	await get_tree().process_frame
	character_manager = get_node_or_null("/root/战斗场景/BattleCharacterManager")
	
	# 如果还是找不到，尝试通过 BattleScene 获取
	if not character_manager:
		var battle_scene = get_node_or_null("/root/战斗场景")
		if battle_scene and battle_scene.has_method("get_character_manager"):
			character_manager = battle_scene.get_character_manager()
	
	# 尝试其他可能的路径
	if not move_range_controller:
		move_range_controller = get_node_or_null("/root/战斗场景/MoveRange/Controller")
	if not action_system:
		action_system = get_node_or_null("/root/战斗场景/ActionSystem")

func _connect_signals():
	# 连接移动范围控制器的信号
	if move_range_controller:
		if move_range_controller.has_signal("move_confirmed"):
			move_range_controller.move_confirmed.connect(_on_move_confirmed)
		if move_range_controller.has_signal("move_cancelled"):
			move_range_controller.move_cancelled.connect(_on_move_cancelled)

# 🎯 主要移动确认处理函数
func _on_move_confirmed(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float):
	print("🚶 [MovementCoordinator] 收到移动确认: %s -> %s" % [character.name, str(target_position)])
	
	# 验证移动的合法性
	if not _validate_movement(character, target_position, target_height, movement_cost):
		return
	
	# 获取角色节点
	var character_node = _get_character_node(character)
	if not character_node:
		push_error("[MovementCoordinator] 无法找到角色节点: %s" % character.name)
		return
	
	# 执行移动
	_execute_movement(character, character_node, target_position, target_height, movement_cost)

# 🔍 验证移动的合法性
func _validate_movement(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float) -> bool:
	# 检查角色是否已在移动中
	if characters_moving.has(character.id):
		print("⚠️ [MovementCoordinator] 角色 %s 已在移动中" % character.name)
		return false
	
	# 检查高度限制
	var height_pixels = target_height * 40
	if target_height < 0 or height_pixels > character.qinggong_skill:
		print("❌ [MovementCoordinator] 高度超出轻功限制: %.1f > %d" % [height_pixels, character.qinggong_skill])
		return false
	
	# 检查移动距离
	if movement_cost > character.qinggong_skill:
		print("❌ [MovementCoordinator] 移动距离超出轻功限制: %.1f > %d" % [movement_cost, character.qinggong_skill])
		return false
	
	# 检查目标位置是否被占用
	if _has_character_collision_at(target_position, character.id):
		print("❌ [MovementCoordinator] 目标位置被其他角色占用")
		return false
	
	return true

# 🚀 执行角色移动
func _execute_movement(character: GameCharacter, character_node: Node2D, target_position: Vector2, target_height: float, movement_cost: float):
	var start_position = character_node.position
	var distance = start_position.distance_to(target_position)
	var move_duration = _calculate_move_duration(distance)
	
	# 记录移动状态
	var move_data = {
		"character": character,
		"node": character_node,
		"start_position": start_position,
		"target_position": target_position,
		"target_height": target_height,
		"movement_cost": movement_cost,
		"duration": move_duration,
		"start_time": Time.get_time_dict_from_system()
	}
	characters_moving[character.id] = move_data
	
	# 发出移动开始信号
	movement_started.emit(character, target_position)
	
	# 更新角色数据中的位置
	character.position = start_position
	
	# 创建移动动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_node, "position", target_position, move_duration)
	tween.tween_callback(_on_movement_animation_completed.bind(character, target_position))
	
	print("✅ [MovementCoordinator] 开始移动动画: %s, 持续时间: %.2fs" % [character.name, move_duration])

# 🎯 移动动画完成回调
func _on_movement_animation_completed(character: GameCharacter, final_position: Vector2):
	print("🏁 [MovementCoordinator] 移动动画完成: %s -> %s" % [character.name, str(final_position)])
	
	# 🔍 调试：记录修正前的状态
	print("🔍 [调试] 修正前 - 角色当前位置: %s" % str(character.position))
	print("🔍 [调试] 修正前 - 角色地面位置: %s" % str(character.ground_position))
	print("🔍 [调试] 修正前 - 动画最终位置: %s" % str(final_position))
	
	# 获取移动数据中的目标高度
	var move_data = characters_moving.get(character.id, {})
	var target_height = move_data.get("target_height", 0.0)
	print("🔍 [调试] 移动数据: %s" % str(move_data))
	print("🔍 [调试] 目标高度: %.1f" % target_height)
	
	# 计算新的地面位置
	var old_ground_position = character.ground_position
	var new_ground_position = Vector2(final_position.x, character.ground_position.y)
	print("🔍 [调试] 地面位置变化: %s -> %s" % [str(old_ground_position), str(new_ground_position)])
	character.ground_position = new_ground_position
	
	# 根据目标高度正确设置角色位置
	var correct_y_position = new_ground_position.y - target_height
	var correct_position = Vector2(final_position.x, correct_y_position)
	print("🔍 [调试] 位置计算: 地面Y(%.1f) - 目标高度(%.1f) = 最终Y(%.1f)" % [new_ground_position.y, target_height, correct_y_position])
	character.position = correct_position
	
	print("🔧 [MovementCoordinator] 位置修正: 目标高度=%.1f, 地面Y=%.1f, 最终Y=%.1f" % [target_height, new_ground_position.y, correct_y_position])
	print("🔍 [调试] 修正后 - 角色最终位置: %s" % str(character.position))
	
	# 清理移动状态
	characters_moving.erase(character.id)
	
	# 通知移动组件（如果存在）
	var character_node = _get_character_node(character)
	if character_node:
		var movement_component = character_node.get_node_or_null("ComponentContainer/MovementComponent")
		if movement_component and movement_component.has_method("on_move_animation_completed"):
			movement_component.on_move_animation_completed(correct_position, new_ground_position)
	
	# 发出移动完成信号
	movement_completed.emit(character, correct_position)
	
	# 🚀 通知BattleScene的移动完成处理（保持现有游戏逻辑）
	var battle_scene = get_node_or_null("/root/战斗场景")
	if battle_scene and battle_scene.has_method("_on_move_completed"):
		print("📞 [MovementCoordinator] 通知BattleScene移动完成: %s" % character.name)
		battle_scene._on_move_completed(character, correct_position)
	else:
		print("⚠️ [MovementCoordinator] 未找到BattleScene，直接重置行动系统")
		# 如果找不到BattleScene，直接重置行动系统
		if action_system and action_system.has_method("reset_action_system"):
			action_system.reset_action_system()

# 🚫 移动取消处理
func _on_move_cancelled():
	print("❌ [MovementCoordinator] 移动被取消")
	# 这里可以添加取消移动的逻辑

# 🔧 辅助函数：获取角色节点
func _get_character_node(character: GameCharacter) -> Node2D:
	if not character_manager:
		push_error("[MovementCoordinator] character_manager为空")
		return null
	
	if not character_manager.has_method("get_character_node_by_data"):
		push_error("[MovementCoordinator] character_manager没有get_character_node_by_data方法")
		return null
	
	var character_node = character_manager.get_character_node_by_data(character)
	if not character_node:
		push_error("[MovementCoordinator] 无法找到角色节点: %s (ID: %s)" % [character.name, character.id])
	
	return character_node

# 🔧 辅助函数：计算移动持续时间
func _calculate_move_duration(distance: float) -> float:
	var base_duration = distance / base_move_speed
	return clamp(base_duration, min_move_duration, max_move_duration)

# 🔧 辅助函数：检查位置是否有角色碰撞
func _has_character_collision_at(position: Vector2, exclude_character_id: String) -> bool:
	if not character_manager:
		return false
	
	# 检查所有角色的位置
	var all_characters = []
	var character_info = []  # 用于调试输出
	
	# 获取队友
	if character_manager.has_method("get_party_member_nodes"):
		var party_nodes = character_manager.get_party_member_nodes()
		for character_id in party_nodes:
			if character_id != exclude_character_id:
				var node = party_nodes[character_id]
				if node:
					all_characters.append(node)
					character_info.append({"id": character_id, "type": "队友", "node": node})
	
	# 获取敌人
	if character_manager.has_method("get_enemy_nodes"):
		var enemy_nodes = character_manager.get_enemy_nodes()
		for enemy_id in enemy_nodes:
			if enemy_id != exclude_character_id:
				var node = enemy_nodes[enemy_id]
				if node:
					all_characters.append(node)
					character_info.append({"id": enemy_id, "type": "敌人", "node": node})
	
	print("🔍 [MovementCoordinator] 检查目标位置 %s 的碰撞，排除角色: %s" % [position, exclude_character_id])
	
	# 检查碰撞
	var has_collision = false
	for i in range(all_characters.size()):
		var character_node = all_characters[i]
		var info = character_info[i]
		var distance = character_node.position.distance_to(position)
		
		# 获取角色的实际碰撞体
		var character_area = character_node.get_node_or_null("CharacterArea")
		var collision_radius = 25.0  # 默认半径
		if character_area:
			var collision_shape = character_area.get_node_or_null("CollisionShape2D")
			if collision_shape and collision_shape.shape:
				if collision_shape.shape is CapsuleShape2D:
					var capsule = collision_shape.shape as CapsuleShape2D
					collision_radius = capsule.radius
					print("🔍 [MovementCoordinator] %s %s 位置: %s, 距离目标: %.1f, 胶囊半径: %.1f" % [info.type, info.id, character_node.position, distance, collision_radius])
				else:
					print("🔍 [MovementCoordinator] %s %s 位置: %s, 距离目标: %.1f, 使用默认半径: %.1f" % [info.type, info.id, character_node.position, distance, collision_radius])
			else:
				print("🔍 [MovementCoordinator] %s %s 位置: %s, 距离目标: %.1f, 无碰撞体，使用默认半径: %.1f" % [info.type, info.id, character_node.position, distance, collision_radius])
		else:
			print("🔍 [MovementCoordinator] %s %s 位置: %s, 距离目标: %.1f, 无CharacterArea，使用默认半径: %.1f" % [info.type, info.id, character_node.position, distance, collision_radius])
		
		# 使用实际的碰撞半径进行检测，并添加一些安全边距
		var safe_distance = collision_radius * 2.2  # 两个角色的半径 + 安全边距
		if distance < safe_distance:
			print("⚠️ [MovementCoordinator] 发现碰撞: %s %s 距离 %.1f < 安全距离 %.1f" % [info.type, info.id, distance, safe_distance])
			has_collision = true
	
	if not has_collision:
		print("✅ [MovementCoordinator] 目标位置无碰撞")
	
	return has_collision

# 🔧 公共接口：直接移动角色（用于AI等）
func move_character_direct(character: GameCharacter, target_position: Vector2) -> bool:
	print("🤖 [MovementCoordinator] 直接移动角色: %s -> %s" % [character.name, str(target_position)])
	
	var character_node = _get_character_node(character)
	if not character_node:
		print("❌ [MovementCoordinator] 无法找到角色节点")
		return false
	
	# 🚀 修复：添加完整的移动验证，包括地面高度检查
	var distance = character_node.position.distance_to(target_position)
	if distance > character.qinggong_skill:
		print("❌ [MovementCoordinator] 移动距离超出轻功限制")
		return false
	
	# 🚀 修复：检查地面高度限制，防止移动到地面以下
	const GROUND_LEVEL: float = 1000.0
	if target_position.y > GROUND_LEVEL:
		print("❌ [MovementCoordinator] 目标位置在地面以下: %.1f > %.1f" % [target_position.y, GROUND_LEVEL])
		return false
	
	# 执行移动并等待完成
	_execute_movement(character, character_node, target_position, 0.0, distance)
	
	# 等待移动完成
	await movement_completed
	print("📞 [MovementCoordinator] 通知BattleScene移动完成: %s" % character.name)
	return true

# 🔧 公共接口：检查角色是否在移动中
func is_character_moving(character: GameCharacter) -> bool:
	return characters_moving.has(character.id)

# 🔧 公共接口：获取移动状态信息
func get_movement_info(character: GameCharacter) -> Dictionary:
	if characters_moving.has(character.id):
		return characters_moving[character.id]
	return {}

# 🔧 公共接口：强制停止角色移动
func stop_character_movement(character: GameCharacter) -> void:
	if characters_moving.has(character.id):
		print("🛑 [MovementCoordinator] 强制停止角色移动: %s" % character.name)
		characters_moving.erase(character.id)
		movement_cancelled.emit(character, "强制停止")

# 🔧 公共接口：添加移动中的角色
func add_moving_character(character_id: String, move_data: Dictionary) -> void:
	characters_moving[character_id] = move_data

# 🔧 公共接口：清除所有移动中的角色
func clear_all_moving_characters() -> void:
	characters_moving.clear()

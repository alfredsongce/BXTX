# 玩家移动组件
extends Node
class_name PlayerMovementComponent

# 移动相关信号
signal move_requested(target_position: Vector2, target_height: float)
signal move_completed()

# 引用
var player_node: Node2D
var character_data: GameCharacter

# 移动相关变量
var is_moving: bool = false

func _init(player: Node2D = null):
	if player:
		setup(player)

func setup(player: Node2D) -> void:
	player_node = player
	if player.has_method("get_character_data"):
		character_data = player.get_character_data()

# 处理移动到指定位置
func move_to(new_position: Vector2, target_height: float = 0.0) -> void:
	if not character_data or is_moving:
		return
		
	print("********** 移动确认 **********")
	print("目标坐标: (%s, %s), 当前坐标: (%s, %s)" % [new_position.x, new_position.y, player_node.position.x, player_node.position.y])
	print("目标高度: %.1f, 当前高度: %.1f" % [target_height, character_data.get_height_level()])
	print("发起移动的角色: %s (ID: %s)" % [character_data.name, character_data.id])
	
	# 🚀 直接使用传入的目标位置，不再调整Y坐标
	var target_real_position = new_position
	
	# 🚀 根据目标位置计算新的地面位置（用于更新ground_position）
	var original_ground_y = character_data.ground_position.y
	var target_height_pixels = original_ground_y - new_position.y
	var new_ground_position = Vector2(new_position.x, original_ground_y)
	
	print("目标位置: (%s, %s), 目标高度: %.1f像素, 地面位置: (%s, %s)" % [
		target_real_position.x, target_real_position.y,
		target_height_pixels, 
		new_ground_position.x, new_ground_position.y
	])
	
	# 检查移动是否合法
	if not character_data.try_move_to(target_real_position):
		print("移动超出轻功范围，无法执行！")
		return
		
	# 🚀 根据实际高度设置角色高度（以像素为单位转换为等级）
	var calculated_height_level = target_height_pixels / 40.0
	if not character_data.set_height(calculated_height_level):
		print("设置高度失败，无法执行移动！")
		return
	
	# 🚀 不再直接执行移动，而是发出移动请求信号让BattleScene处理动画
	is_moving = true
	print("发出移动请求信号：目标位置=%s" % str(target_real_position))
	move_requested.emit(target_real_position, calculated_height_level)
	
	print("移动命令已发送到角色")

# 🚀 移动完成回调（由BattleScene调用）
func on_move_animation_completed(final_position: Vector2, new_ground_position: Vector2) -> void:
	# 现在才真正设置角色的最终位置
	character_data.position = final_position
	character_data.ground_position = new_ground_position
	
	is_moving = false
	move_completed.emit()
	print("移动成功完成！高度: %.1f" % character_data.get_height_level())

# 设置角色的基准位置（地面位置）
func set_base_position(base_pos: Vector2) -> void:
	if not character_data:
		return
	
	# 保存当前高度等级（浮点数值）
	var current_height_level = character_data.get_height_level()
	
	# 更新角色的地面位置
	character_data.ground_position = base_pos
	
	# 根据当前高度设置实际位置 - 使用精确的浮点数高度值
	var height_pixels = current_height_level * 40.0  # 确保浮点数乘法
	
	# 计算最终位置 - 位置Y坐标 = 基准Y坐标 - 高度(越高Y值越小)
	player_node.position = Vector2(base_pos.x, base_pos.y - height_pixels)
	character_data.position = player_node.position  # 同步GameCharacter的position
	
	# 确保碰撞区域也正确更新位置
	var character_area = player_node.get_node_or_null("CharacterArea")
	if character_area:
		character_area.position = Vector2.ZERO  # 保持相对于角色的位置为0
	
	print("设置基准位置: (%s, %s), 当前高度级别: %.2f, 高度像素: %.1f, 实际位置: (%s, %s)" % [
		base_pos.x, base_pos.y, 
		current_height_level, height_pixels, 
		player_node.position.x, player_node.position.y
	])

# 获取角色的基准位置（地面位置）
func get_base_position() -> Vector2:
	if character_data:
		return character_data.ground_position
	return player_node.position

# 显示移动范围
func show_move_range() -> void:
	if not character_data:
		print("错误：无法获取角色数据")
		return
	
	print("显示移动范围 - 角色: %s, 轻功值: %s像素, 轻功等级: %s, 当前高度: %s" % [
		character_data.name, 
		character_data.qinggong_skill, 
		int(character_data.qinggong_skill / 40),
		character_data.get_height_level()
	])
	
	# 获取行动系统，确保状态正确
	var action_system_script = preload("res://Scripts/ActionSystemNew.gd")
	var action_system = player_node.get_tree().current_scene.get_node_or_null("ActionSystem")
	if action_system:
		if action_system.current_state != action_system_script.SystemState.SELECTING_MOVE_TARGET:
			print("警告：行动系统状态不是SELECTING_MOVE_TARGET，将其设置为正确状态")
			action_system.current_state = action_system_script.SystemState.SELECTING_MOVE_TARGET
			action_system.selected_character = player_node
	
	# 🚀 新架构：使用MoveRange组件系统
	var battle_scene = player_node.get_tree().current_scene
	var move_range_controller = battle_scene.get_node_or_null("MoveRange/Controller")
	
	if move_range_controller:
		print("🚀 找到新的移动范围控制器，显示移动范围")
		move_range_controller.show_move_range(character_data)
	else:
		# 🔧 fallback：尝试旧的移动范围显示器（向后兼容）
		var range_display = battle_scene.get_node_or_null("MoveRangeDisplay")
		if range_display:
			print("⚠️ 使用旧的移动范围显示器（兼容模式）")
			range_display.display_for_character(character_data, player_node.position)
		else:
			push_error("❌ 严重错误：未找到移动范围显示系统！请确保场景中有MoveRange或MoveRangeDisplay节点") 

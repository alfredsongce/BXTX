# Edit file: res://Scripts/BattleScene.gd
extends Node2D

# 预加载行动系统脚本以访问其枚举和常量
const ActionSystemScript = preload("res://Scripts/ActionSystemNew.gd")

# 🚀 预加载碰撞形状绘制器
const CollisionShapeDrawer = preload("res://Scripts/CollisionShapeDrawer.gd")

# 🚀 预加载技能范围显示组件
const SkillRangeDisplayScript = preload("res://Scripts/SkillRangeDisplay.gd")

# 🚀 障碍物管理器引用
@onready var obstacle_manager: Node2D = $TheLevel/ObstacleManager

# 🌍 统一的地面高度定义
const GROUND_LEVEL: float = 1000.0  # 地面的Y坐标值

# 角色初始位置配置 - 都在统一地面高度
const SPAWN_POSITIONS := {
	"1": Vector2(600, GROUND_LEVEL),   # 觉远 - 地面位置
	"2": Vector2(700, GROUND_LEVEL),   # 柳生 - 地面位置
	"3": Vector2(800, GROUND_LEVEL)    # 兰斯洛特 - 地面位置
}

# 敌人初始位置配置 - 也在统一地面高度，在右侧不同X坐标
const ENEMY_SPAWN_POSITIONS := {
	"101": Vector2(1000, GROUND_LEVEL),   # 山贼头目 - 地面位置
	"102": Vector2(1100, GROUND_LEVEL),   # 野狼 - 地面位置  
	"103": Vector2(1200, GROUND_LEVEL)    # 骷髅战士 - 地面位置
}

# 🚀 新架构：使用场景中预创建的节点引用
@onready var move_range_controller: Node = $MoveRange/Controller
@onready var players_container: Node = $Players
@onready var collision_test_area: Area2D = $CollisionTest
@onready var action_system: Node = $ActionSystem
@onready var battle_manager: Node = $BattleManager
@onready var skill_manager: SkillManager = $SkillManager

# 🚀 角色管理组件
@onready var character_manager: BattleCharacterManager = null

# 获取角色管理器的公共方法
func get_character_manager() -> BattleCharacterManager:
	return character_manager

# 🚀 战斗UI管理器
var battle_ui_manager: BattleUIManager = null

# 🚀 技能选择协调器（通过节点引用）
@onready var skill_selection_coordinator: SkillSelectionCoordinator = $BattleSystems/SkillSelectionCoordinator

# 🚀 移动协调器（通过节点引用）
@onready var movement_coordinator: MovementCoordinator = $BattleSystems/MovementCoordinator

# 🚀 战斗流程管理器（通过节点引用）
@onready var battle_flow_manager: BattleFlowManager = $BattleSystems/BattleFlowManager

# 🚀 战斗输入处理器（通过节点引用）
@onready var battle_input_handler: BattleInputHandler = $BattleSystems/BattleInputHandler

# 🚀 战斗动画管理器（通过节点引用）
@onready var battle_animation_manager: BattleAnimationManager = $BattleSystems/BattleAnimationManager

# 🚀 战斗视觉效果管理器（通过节点引用）
@onready var battle_visual_effects_manager: BattleVisualEffectsManager = $BattleSystems/BattleVisualEffectsManager

# 🚀 战斗逻辑管理器（通过节点引用）
@onready var battle_combat_manager: BattleCombatManager = $BattleSystems/BattleCombatManager

# 🚀 AI管理器（通过节点引用）
@onready var battle_ai_manager: BattleAIManager = $BattleSystems/BattleAIManager

# 🚀 战斗事件管理器（通过节点引用）
@onready var battle_event_manager: BattleEventManager = $BattleSystems/BattleEventManager

# 🚀 优化的碰撞检测缓存
var _collision_test_shape: CollisionShape2D = null

# 碰撞体积显示控制
var show_collision_shapes: bool = true  # 默认开启碰撞体积显示

func _ready() -> void:
	# 🚀 添加到battle_scene组，方便其他组件找到
	add_to_group("battle_scene")
	# 🚀 初始化角色管理组件
	await _setup_character_manager()
	# 初始化移动范围显示系统
	_setup_move_range_system()
	# 🚀 显示所有角色的碰撞体积
	_setup_collision_visualization()
	# 🚀 连接BattleManager信号
	_connect_battle_manager_signals()
	# 🚀 初始化战斗UI
	_setup_battle_ui()
	# 🚀 初始化SkillEffects系统
	_setup_skill_effects()
	# 🚀 初始化MovementCoordinator
	_setup_movement_coordinator()
	# 🚀 初始化BattleFlowManager
	_setup_battle_flow_manager()
	# 🚀 初始化BattleInputHandler
	_setup_battle_input_handler()
	# 🚀 初始化BattleAnimationManager
	_setup_battle_animation_manager()
	# 🚀 初始化BattleVisualEffectsManager
	_setup_battle_visual_effects_manager()
	# 🚀 初始化BattleCombatManager
	_setup_battle_combat_manager()
	# 🚀 初始化BattleAIManager
	_setup_battle_ai_manager()
	# 🚀 初始化障碍物管理器
	_setup_obstacle_manager()
	# 显示游戏操作提示
	_show_gameplay_tips()

func _setup_character_manager() -> void:
	character_manager = BattleCharacterManager.new()
	character_manager.name = "BattleCharacterManager"
	add_child(character_manager)
	
	character_manager.character_spawned.connect(_on_character_spawned)
	character_manager.character_death.connect(_on_character_death_from_manager)
	character_manager.character_updated.connect(_on_character_updated_from_manager)
	
	await character_manager.spawn_party_members()
	await character_manager.spawn_enemies()
	
	character_manager.check_and_fix_character_heights()

func _setup_skill_effects() -> void:
	var skill_effects = get_node("SkillEffects")
	skill_manager.skill_effects = skill_effects

func _setup_movement_coordinator() -> void:
	print("🚀 [BattleScene] 初始化MovementCoordinator")
	# MovementCoordinator会在其_ready函数中自动初始化
	# 这里我们确保它能正确找到所需的节点引用

func _setup_battle_flow_manager() -> void:
	print("🚀 [BattleScene] 初始化BattleFlowManager")
	# BattleFlowManager会在其_ready函数中自动初始化
	# 连接相关信号
	battle_flow_manager.battle_flow_started.connect(_on_battle_flow_started)
	battle_flow_manager.battle_flow_ended.connect(_on_battle_flow_ended)
	battle_flow_manager.input_mode_changed.connect(_on_input_mode_changed)

func _setup_battle_input_handler() -> void:
	print("🚀 [BattleScene] 初始化BattleInputHandler")
	# 连接输入处理器信号
	battle_input_handler.attack_target_selected.connect(_on_attack_target_selected)
	battle_input_handler.attack_cancelled.connect(_on_attack_cancelled)
	battle_input_handler.action_menu_requested.connect(_on_action_menu_requested)
	print("✅ [BattleScene] BattleInputHandler信号连接完成")

func _setup_battle_animation_manager() -> void:
	print("🚀 [BattleScene] 初始化BattleAnimationManager")
	# 设置必要的引用
	battle_animation_manager.battle_scene = self
	battle_animation_manager.skill_manager = skill_manager
	print("✅ [BattleScene] BattleAnimationManager初始化完成")

func _setup_battle_visual_effects_manager() -> void:
	print("🚀 [BattleScene] 初始化BattleVisualEffectsManager")
	# 设置必要的引用
	battle_visual_effects_manager.battle_scene = self
	battle_visual_effects_manager.skill_manager = skill_manager
	# 设置SkillEffects引用
	var skill_effects = get_node("SkillEffects")
	battle_visual_effects_manager.skill_effects = skill_effects
	print("✅ [BattleScene] BattleVisualEffectsManager初始化完成")

func _setup_battle_combat_manager() -> void:
	print("🚀 [BattleScene] 初始化BattleCombatManager")
	# 设置组件引用
	var refs = {
		"character_manager": character_manager,
		"action_system": action_system,
		"battle_manager": battle_manager,
		"skill_manager": skill_manager,
		"battle_animation_manager": battle_animation_manager,
		"battle_visual_effects_manager": battle_visual_effects_manager,
		"battle_input_handler": battle_input_handler,
		"battle_ui_manager": battle_ui_manager
	}
	battle_combat_manager.setup_references(refs)
	
	# 连接信号
	battle_combat_manager.combat_action_completed.connect(_on_combat_action_completed)
	battle_combat_manager.character_defeated.connect(_on_combat_character_defeated)
	battle_combat_manager.victory_condition_met.connect(_on_combat_victory_condition_met)
	
	print("✅ [BattleScene] BattleCombatManager初始化完成")

func _setup_battle_ai_manager() -> void:
	print("🚀 [BattleScene] 初始化BattleAIManager")
	# 设置组件引用
	var refs = {
		"character_manager": character_manager,
		"action_system": action_system,
		"battle_combat_manager": battle_combat_manager,
		"movement_coordinator": movement_coordinator,
		"battle_animation_manager": battle_animation_manager
	}
	battle_ai_manager.setup_references(refs)
	
	# 连接信号
	battle_ai_manager.ai_action_completed.connect(_on_ai_action_completed)
	battle_ai_manager.ai_decision_made.connect(_on_ai_decision_made)
	
	print("✅ [BattleScene] BattleAIManager初始化完成")

# 🚀 BattleFlowManager信号处理函数
func _on_battle_flow_started() -> void:
	print("🎮 [BattleScene] 战斗流程已开始")


func _on_battle_flow_ended(reason: String) -> void:
	print("🎮 [BattleScene] 战斗流程已结束，原因: %s" % reason)


func _on_input_mode_changed(new_mode: String) -> void:
	print("🎮 [BattleScene] 输入模式已切换: %s" % new_mode)

# 🚀 BattleInputHandler信号处理函数
func _on_attack_target_selected(attacker: GameCharacter, target: GameCharacter) -> void:
	print("⚔️ [BattleScene] 攻击目标已选择: %s -> %s" % [attacker.name, target.name])
	await battle_combat_manager.execute_attack(attacker, target)

func _on_attack_cancelled() -> void:
	print("❌ [BattleScene] 攻击已取消")
	battle_combat_manager.clear_attack_targets()

func _on_action_menu_requested() -> void:
	print("📋 [BattleScene] 请求打开行动菜单")
	action_system.start_action_selection()

func _on_character_spawned(character_id: String, character_node: Node2D) -> void:
	var movement_component = character_node.get_node_or_null("ComponentContainer/MovementComponent")
	if movement_component:
		movement_component.move_requested.connect(
			func(target_pos: Vector2, target_height: float):
				_on_move_requested(character_node, character_id, target_pos, target_height)
		)

func _on_character_death_from_manager(dead_character: GameCharacter) -> void:
	pass

func _on_character_updated_from_manager(character_id: String) -> void:
	pass

# 🚀 BattleCombatManager信号处理函数
func _on_combat_action_completed(character: GameCharacter, result: Dictionary) -> void:
	var target_name = result.get("target", "未知目标")
	print("⚔️ [BattleScene] 战斗攻击执行: %s -> %s, 伤害: %d" % [character.name, target_name, result.get("damage", 0)])
	# 可以在这里添加额外的攻击后处理逻辑

func _on_combat_character_defeated(character: GameCharacter) -> void:
	print("💀 [BattleScene] 角色被击败: %s" % character.name)
	# 可以在这里添加角色死亡的额外处理逻辑

func _on_combat_victory_condition_met(victory_type: String, details: Dictionary) -> void:
	print("🏁 [BattleScene] 胜负条件达成: %s, 详情: %s" % [victory_type, details.get("message", "未知结果")])
	# 可以在这里添加战斗结束的处理逻辑

# 🚀 BattleAIManager信号处理函数
func _on_ai_action_completed(ai_character: GameCharacter, result: Dictionary) -> void:
	print("🤖 [BattleScene] AI行动完成: %s - %s" % [ai_character.name, result.get("message", "行动完成")])
	
	# 🚀 通知BattleManager AI回合完成
	print("🔄 [BattleScene] 通知BattleManager：%s AI回合完成" % ai_character.name)
	battle_manager.character_action_completed.emit(ai_character, result)
	
	# 可以在这里添加其他AI行动完成后的处理逻辑

# 🚀 已迁移：AI回合开始逻辑已迁移到新的_on_ai_turn_started函数（第649行）

func _on_ai_decision_made(ai_character: GameCharacter, decision: Dictionary) -> void:
	print("🧠 [BattleScene] AI决策制定: %s - %s" % [ai_character.name, decision.get("description", "未知决策")])
	# 可以在这里添加AI决策的可视化提示

func _setup_obstacle_manager() -> void:
	print("🚀 [BattleScene] 初始化障碍物管理器")
	
	if obstacle_manager:
		# 连接障碍物管理器信号
		obstacle_manager.obstacle_added.connect(_on_obstacle_added)
		obstacle_manager.obstacle_removed.connect(_on_obstacle_removed)
		obstacle_manager.obstacles_cleared.connect(_on_obstacles_cleared)
		
		print("✅ [BattleScene] 障碍物管理器初始化完成")
	else:
		print("❌ [BattleScene] 未找到障碍物管理器节点")

func _on_obstacle_added(obstacle) -> void:
	print("🪨 [BattleScene] 障碍物已添加: %s" % obstacle.global_position)

func _on_obstacle_removed(obstacle) -> void:
	print("🗑️ [BattleScene] 障碍物已移除: %s" % obstacle.global_position)

func _on_obstacles_cleared() -> void:
	print("🧹 [BattleScene] 所有障碍物已清除")

func _show_gameplay_tips() -> void:
	print("游戏已启动 - 按F11开始战斗，F10切换碰撞体积显示")
	print("按F12可以重新生成障碍物（调试功能）")

func _get_character_at_position(pos: Vector2, height_tolerance: float = 30.0) -> Node2D:
	for node in get_children():
		if node.is_in_group("party_members"):
			var node_base_pos = node.get_base_position() if node.has_method("get_base_position") else node.position
			if node_base_pos.distance_to(Vector2(pos.x, node_base_pos.y)) < height_tolerance:
				return node
	return null

func _has_character_collision_at(pos: Vector2, source_character_id: String = "") -> bool:
	_init_collision_test_area()
	
	collision_test_area.global_position = Vector2(pos.x, pos.y)
	
	if source_character_id != "":
		_update_collision_shape_for_character(source_character_id)
	
	var overlapping_areas = collision_test_area.get_overlapping_areas()
	
	for area in overlapping_areas:
		var parent = area.get_parent()
		if parent is Node and parent.is_in_group("party_members"):
			if source_character_id != "":
				var data_node = parent.get_node_or_null("Data")
				if data_node and data_node.has_method("get_character"):
					var char = data_node.get_character()
					if char and char.id == source_character_id:
						continue
			return true
	
	return false

func _init_collision_test_area():
	collision_test_area = Area2D.new()
	collision_test_area.name = "CollisionTestArea"
	collision_test_area.collision_layer = 0
	collision_test_area.collision_mask = 4
	
	_collision_test_shape = CollisionShape2D.new()
	var default_shape = CircleShape2D.new()
	default_shape.radius = 10.0
	_collision_test_shape.shape = default_shape
	
	add_child(collision_test_area)
	collision_test_area.add_child(_collision_test_shape)

# 🚀 为特定角色更新碰撞形状
func _update_collision_shape_for_character(character_id: String):
	var source_node = _find_character_node_by_id(character_id)
	if source_node:
		var char_area = source_node.get_node_or_null("CharacterArea")
		if char_area:
			for child in char_area.get_children():
				if child is CollisionShape2D and child.shape:
					_collision_test_shape.shape = child.shape.duplicate()
					return

func _on_move_confirmed(target_position: Vector2, target_height: float, movement_cost: float) -> void:
	var source_character = move_range_controller.get_current_character()
	
	var original_ground_y = source_character.ground_position.y
	var height_pixels = target_height * 40
	var target_real_position = Vector2(target_position.x, original_ground_y - height_pixels)
	
	if movement_coordinator and movement_coordinator.is_character_moving(source_character):
		return
	
	if target_height < 0 or height_pixels > source_character.qinggong_skill:
		return
	
	if movement_cost > source_character.qinggong_skill:
		return
		
	call_deferred("_process_move_async", source_character, target_real_position, target_height, movement_cost)

func _process_move_async(source_character: GameCharacter, target_real_position: Vector2, target_height: float, movement_cost: float):
	if _has_character_collision_at(target_real_position, source_character.id):
		return
	
	var source_node = _find_character_node_by_id(source_character.id)
	
	var original_height = source_character.get_height_level()
	var original_ground_y = source_character.ground_position.y
	var target_ground_pos = Vector2(target_real_position.x, original_ground_y)
	var total_distance = source_node.position.distance_to(target_real_position)
	var move_duration = movement_coordinator.calculate_move_duration(total_distance) if movement_coordinator else 1.0
	var is_horizontal_move = abs(target_height - original_height) < 0.01
	
	var move_data = {
		"node": source_node,
		"character": source_character,
		"start_position": source_node.position,
		"target_position": target_real_position,
		"target_height": target_height,
		"target_ground_position": target_ground_pos,
		"progress": 0.0,
		"total_distance": total_distance,
		"duration": move_duration,
		"speed": total_distance / move_duration,
		"is_horizontal_move": is_horizontal_move
	}
	
	if movement_coordinator:
		movement_coordinator.add_moving_character(source_character.id, move_data)

func _find_character_node_by_id(character_id: String) -> Node2D:
	return character_manager.find_character_node_by_id(character_id)

func _print_party_stats() -> void:
	character_manager.print_party_stats()

func _on_character_updated(character_id: String) -> void:
	pass

func _find_character_node(character_id: String) -> Node2D:
	return _find_character_node_by_id(character_id)

func _input(event):
	# 🚀 优先委托给BattleFlowManager处理全局输入
	if battle_flow_manager.handle_input(event):
		return
	
	# 🚀 委托给BattleInputHandler处理输入
	if battle_input_handler.handle_input(event):
		return
	
	# 🚀 障碍物调试功能
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			if obstacle_manager:
				print("🔄 [调试] 重新生成障碍物")
				obstacle_manager.regenerate_obstacles()
			else:
				print("❌ [调试] 障碍物管理器未找到")
	
func _check_and_fix_character_heights() -> void:
	character_manager.check_and_fix_character_heights()

func _process(delta):
	pass

# 🚀 移动完成处理（保留用于向后兼容和特殊逻辑）
func _on_move_completed(character: GameCharacter, final_position: Vector2):
	print("🏁 [BattleScene] 移动完成回调: %s -> %s" % [character.name, str(final_position)])
	
	# 🔍 调试：记录移动完成前的状态
	print("🔍 [BattleScene调试] 移动完成前 - 角色位置: %s" % str(character.position))
	print("🔍 [BattleScene调试] 移动完成前 - 地面位置: %s" % str(character.ground_position))
	print("🔍 [BattleScene调试] 最终位置参数: %s" % str(final_position))
	
	# ⚠️ 注意：不要直接设置character.position，因为这会触发GameCharacter的set_position方法
	# 该方法会错误地更新ground_position.y，导致位置修正问题
	# 位置应该已经在MovementCoordinator中正确设置了
	print("🔍 [BattleScene调试] 跳过位置设置，使用MovementCoordinator已设置的位置")
	
	# 检查是否还有行动点数
	var still_has_actions = not action_system.is_character_turn_finished(character)
	
	# 如果是玩家角色且还有行动点数，打开行动菜单
	if character.is_player_controlled() and still_has_actions:
		var character_node = _find_character_node_by_character_data(character)
		if character_node:
			call_deferred("_open_character_action_menu", character_node)
		return
	
	# 🚀 只有玩家角色的移动才发出行动完成信号，AI角色的移动由AI回合统一管理
	if character.is_player_controlled():
		var action_result = {
			"type": "move",
			"success": true,
			"message": "移动到了新位置",
			"final_position": final_position
		}
		
		battle_manager.character_action_completed.emit(character, action_result)
	
	# 重置行动系统
	action_system.reset_action_system()

func _exit_tree():
	if collision_test_area:
		collision_test_area.queue_free()
		collision_test_area = null
		_collision_test_shape = null

func _setup_move_range_system():
	if move_range_controller:
		move_range_controller.move_confirmed.connect(_on_move_confirmed_new)
		move_range_controller.move_cancelled.connect(_on_move_cancelled)
	else:
		push_error("[BattleScene] 未找到MoveRange/Controller节点")

func _connect_battle_manager_signals():
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.turn_ended.connect(_on_turn_ended)
	# 🚀 新增：连接表现层信号
	battle_manager.battle_visual_update_requested.connect(_on_battle_visual_update_requested)
	battle_manager.player_turn_started.connect(_on_player_turn_started)
	battle_manager.ai_turn_started.connect(_on_ai_turn_started)

func _on_battle_started():
	_update_battle_button_state()

func _on_battle_ended(result: Dictionary):
	# 🚀 修改：简化为只处理基本的战斗结束逻辑
	# 胜负判定和视觉效果现在通过battle_visual_update_requested信号处理
	_update_battle_button_state()
	print("🏁 [BattleScene] 战斗结束，结果: %s" % result.get("winner", "未知"))

# 🚀 新增：处理战斗视觉更新请求
func _on_battle_visual_update_requested(visual_type: String, data: Dictionary) -> void:
	print("🎨 [BattleScene] 收到视觉更新请求: %s" % visual_type)
	
	match visual_type:
		"battle_end":
			_handle_battle_end_visual(data)
		_:
			print("⚠️ [BattleScene] 未知的视觉更新类型: %s" % visual_type)

func _handle_battle_end_visual(data: Dictionary) -> void:
	var winner = data.get("winner", "unknown")
	var battle_result_text = data.get("battle_result_text", "胜负未定")
	
	print("🎨 [BattleScene] 处理战斗结束视觉效果: %s" % winner)
	
	# 更新UI
	_update_battle_ui("战斗结束", battle_result_text, "battle_end")
	
	# 显示视觉效果
	_end_battle_with_visual_effects(winner)

func _end_battle_with_visual_effects(winner: String) -> void:
	_force_close_all_player_menus()
	_stop_all_character_actions()
	
	match winner:
		"player":
			_add_victory_markers_to_all()
		"enemy":
			_add_defeat_markers_to_all()
		"draw":
			_add_draw_markers_to_all()

func _stop_all_character_actions() -> void:
	var tween_nodes = get_tree().get_nodes_in_group("character_tweens")
	for tween in tween_nodes:
		if is_instance_valid(tween) and tween is Tween:
			tween.kill()
	
	movement_coordinator.clear_all_moving_characters()
	action_system.reset_action_system()

# 🚀 为所有角色添加结果标记
func _add_victory_markers_to_all() -> void:
	var party_nodes = character_manager.get_party_member_nodes()
	for character_id in party_nodes:
		var character_node = party_nodes[character_id]
		if character_node:
			_add_result_marker(character_node, Color.GOLD, "胜利!")
	
	var enemy_nodes = character_manager.get_enemy_nodes()
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node:
			_add_result_marker(enemy_node, Color.GRAY, "败北")

func _add_defeat_markers_to_all() -> void:
	var party_nodes = character_manager.get_party_member_nodes()
	for character_id in party_nodes:
		var character_node = party_nodes[character_id]
		if character_node:
			_add_result_marker(character_node, Color.BLACK, "败北")
	
	var enemy_nodes = character_manager.get_enemy_nodes()
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node:
			_add_result_marker(enemy_node, Color.GOLD, "胜利!")

func _add_draw_markers_to_all() -> void:
	var party_nodes = character_manager.get_party_member_nodes()
	for character_id in party_nodes:
		var character_node = party_nodes[character_id]
		if character_node:
			_add_result_marker(character_node, Color.SILVER, "平局")
	
	var enemy_nodes = character_manager.get_enemy_nodes()
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node:
			_add_result_marker(enemy_node, Color.SILVER, "平局")

func _add_result_marker(character_node: Node2D, color: Color, text: String) -> void:
	var existing_marker = character_node.get_node_or_null("ResultMarker")
	if existing_marker:
		existing_marker.queue_free()
	
	var result_marker = Node2D.new()
	result_marker.name = "ResultMarker"
	result_marker.z_index = 20
	
	var circle_drawer = _ResultMarkerDrawer.new()
	circle_drawer.setup(color, text)
	result_marker.add_child(circle_drawer)
	
	character_node.add_child(result_marker)
	
	_animate_result_marker(result_marker)

class _ResultMarkerDrawer extends Node2D:
	var circle_color: Color = Color.GOLD
	var result_text: String = "胜利!"
	var circle_radius: float = 50.0
	var text_size: int = 16
	
	func setup(color: Color, text: String):
		circle_color = color
		result_text = text
	
	func _draw():
		draw_circle(Vector2.ZERO, circle_radius, circle_color)
		draw_arc(Vector2.ZERO, circle_radius, 0, TAU, 64, Color.WHITE, 3.0)
		var font = ThemeDB.fallback_font
		var text_position = Vector2(-result_text.length() * 6, 5)
		draw_string(font, text_position, result_text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size, Color.WHITE)

func _animate_result_marker(marker: Node2D) -> void:
	marker.scale = Vector2.ZERO
	marker.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(marker, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(marker, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.3)
	tween.tween_property(marker, "modulate:a", 1.0, 0.4)
	
	var float_tween = create_tween()
	float_tween.set_loops()
	float_tween.tween_property(marker, "position:y", -10, 1.0)
	float_tween.tween_property(marker, "position:y", 10, 1.0)

func _on_turn_started(turn_number: int):
	# 🚀 修改：简化为只处理基本的回合开始逻辑
	# 玩家和AI回合的具体处理现在通过专门的信号处理
	print("🎯 [BattleScene] _on_turn_started 被调用，回合: %d" % turn_number)
	
	var current_character = battle_manager.turn_manager.get_current_character()
	if current_character:
		var character_type = "玩家" if current_character.is_player_controlled() else "AI"
		print("🎯 [BattleScene] 当前回合角色: %s (类型: %s)" % [current_character.name, character_type])
		
		# 启动新回合
		action_system.start_new_turn_for_character(current_character)
		
		# 更新UI
		_update_battle_ui("回合 %d" % turn_number, "当前行动: %s (%s)" % [current_character.name, character_type], "turn_info")
	else:
		_update_battle_ui("回合 %d" % turn_number, "等待角色...", "turn_info")
		print("⚠️ [BattleScene] 当前角色为空")

# 🚀 新增：处理玩家回合开始
func _on_player_turn_started(character: GameCharacter) -> void:
	print("👤 [BattleScene] 玩家回合开始: %s" % character.name)
	
	var character_node = _find_character_node_by_character_data(character)
	if character_node:
		print("✅ [BattleScene] 找到角色节点，准备打开行动菜单: %s" % character_node.get_character_data().name)
		call_deferred("_open_character_action_menu", character_node)
	else:
		print("❌ [BattleScene] 未找到角色节点: %s" % character.name)

# 🚀 新增：处理AI回合开始
func _on_ai_turn_started(character: GameCharacter) -> void:
	print("🤖 [BattleScene] AI回合开始: %s" % character.name)
	print("🔍 [BattleScene] 当前战斗状态检查 - battle_manager.is_battle_active: %s" % battle_manager.is_battle_active)
	call_deferred("_execute_ai_action", character)

func _on_turn_ended(turn_number: int):
	pass

func _on_character_action_completed(character: GameCharacter, action_result: Dictionary):
	# 已委托给BattleEventManager处理，这里不再重复处理
	# 只更新UI显示
	var character_type = "玩家" if character.is_player_controlled() else "AI"
	_update_battle_ui("行动完成", "%s (%s): %s" % [character.name, character_type, action_result.get("message", "完成行动")], "action_temp")
	
	# 注意：不再调用_proceed_to_next_character，避免重复触发

func _on_move_confirmed_new(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float):
	# 🚀 委托给MovementCoordinator处理
	movement_coordinator._on_move_confirmed(character, target_position, target_height, movement_cost)

func _setup_collision_visualization():
	var party_nodes = character_manager.get_party_member_nodes()
	for character_id in party_nodes:
		var character_node = party_nodes[character_id]
		if character_node:
			_add_collision_visualization(character_node, character_id)
	
	var enemy_nodes = character_manager.get_enemy_nodes()
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node:
			_add_collision_visualization(enemy_node, enemy_id)

func _add_collision_visualization(character_node: Node2D, character_id: String):
	var character_area = character_node.get_node("CharacterArea")
	var collision_shape = character_area.get_node("CollisionShape2D")
	
	var existing_visual = character_area.get_node_or_null("CollisionVisual")
	if existing_visual:
		existing_visual.queue_free()
	
	var visual_node = Node2D.new()
	visual_node.name = "CollisionVisual"
	visual_node.position = collision_shape.position
	visual_node.visible = show_collision_shapes
	character_area.add_child(visual_node)
	
	# 获取碰撞形状
	var shape = collision_shape.shape
	if shape is CapsuleShape2D:
		_create_capsule_visual(visual_node, shape as CapsuleShape2D, character_id)
	elif shape is CircleShape2D:
		_create_circle_visual(visual_node, shape as CircleShape2D, character_id)
	elif shape is RectangleShape2D:
		_create_rectangle_visual(visual_node, shape as RectangleShape2D, character_id)
	else:
		return  # 静默失败

# 🚀 创建胶囊形状可视化
func _create_capsule_visual(parent: Node2D, shape: CapsuleShape2D, character_id: String):
	var radius = shape.radius
	var height = shape.height
	
	# 创建一个自定义绘制节点来显示胶囊形状
	var drawer = CollisionShapeDrawer.new()
	drawer.setup_capsule(radius, height, character_id)
	parent.add_child(drawer)

# 🚀 创建圆形形状可视化
func _create_circle_visual(parent: Node2D, shape: CircleShape2D, character_id: String):
	var radius = shape.radius
	
	var drawer = CollisionShapeDrawer.new()
	drawer.setup_circle(radius, character_id)
	parent.add_child(drawer)

# 🚀 创建矩形形状可视化
func _create_rectangle_visual(parent: Node2D, shape: RectangleShape2D, character_id: String):
	var size = shape.size
	
	var drawer = CollisionShapeDrawer.new()
	drawer.setup_rectangle(size, character_id)
	parent.add_child(drawer)

# 🚀 切换碰撞体积显示
func toggle_collision_visualization():
	show_collision_shapes = not show_collision_shapes
	
	# 切换队友的碰撞体积显示
	var party_nodes = character_manager.get_party_member_nodes()
	for character_id in party_nodes:
		var character_node = party_nodes[character_id]
		var character_area = character_node.get_node("CharacterArea")
		var visual_node = character_area.get_node("CollisionVisual")
		visual_node.visible = show_collision_shapes
	
	# 切换敌人的碰撞体积显示
	var enemy_nodes = character_manager.get_enemy_nodes()
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		var character_area = enemy_node.get_node("CharacterArea")
		var visual_node = character_area.get_node("CollisionVisual")
		visual_node.visible = show_collision_shapes
	
	print("🔍 碰撞体积显示: %s" % ("开启" if show_collision_shapes else "关闭"))

# 🚀 处理移动组件的移动请求信号
func _on_move_requested(character_node: Node2D, character_id: String, target_position: Vector2, target_height: float):
	# 获取角色数据
	var character = character_node.get_character_data()
	
	# 计算移动参数
	var start_position = character_node.position
	var distance = start_position.distance_to(target_position)
	var move_duration = movement_coordinator.calculate_move_duration(distance)
	
	# 🚀 创建平滑移动动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_node, "position", target_position, move_duration)
	tween.tween_callback(_on_move_animation_completed.bind(character_node, character_id, target_position))

# 🚀 移动动画完成回调
func _on_move_animation_completed(character_node: Node2D, character_id: String, final_position: Vector2):
	# 委托给BattleEventManager处理
	battle_event_manager._on_move_animation_completed(character_node, character_id, final_position)

# 通过角色数据查找对应的角色节点
func _find_character_node_by_character_data(character_data: GameCharacter) -> Node2D:
	return character_manager.get_character_node_by_data(character_data)

# 🚀 根据角色数据获取对应的角色节点（用于技能系统高亮显示等）
func get_character_node_by_data(character_data: GameCharacter) -> Node2D:
	return character_manager.get_character_node_by_data(character_data)

# 为指定角色节点打开行动菜单
func _open_character_action_menu(character_node: Node2D) -> void:
	print("🎯 [BattleScene] _open_character_action_menu被调用")
	print("🔍 [BattleScene] 传入的character_node: %s" % character_node.name)
	
	# 🚀 添加当前回合角色检查
	var character_data = character_node.get_character_data()
	# 获取当前场景、战斗管理器和回合管理器
	var current_scene = get_tree().current_scene
	var battle_manager_node = null
	if current_scene.name == "战斗场景" or current_scene.name == "BattleScene":
		battle_manager_node = current_scene.get_node("BattleManager")
	else:
		battle_manager_node = get_node("/root/BattleScene/BattleManager")
	
	var current_character = battle_manager_node.turn_manager.get_current_character()
	if current_character == null:
		print("🚫 [BattleScene] 无法获取当前回合角色，可能回合队列为空或索引越界")
		return
	
	if current_character.id != character_data.id:
		print("🚫 [BattleScene] 非当前回合角色请求打开行动菜单被拒绝：%s (当前回合：%s)" % [character_data.name, current_character.name])
		return
	print("✅ [BattleScene] 当前回合角色请求打开行动菜单：%s" % character_data.name)
	
	# 🚀 重要：在打开菜单前，先设置ActionSystem的selected_character
	action_system.selected_character = character_node
	action_system.current_state = ActionSystemScript.SystemState.SELECTING_ACTION
	print("🔧 [回合] 设置ActionSystem选中角色: %s" % character_node.get_character_data().name)
	
	# 尝试通过UI组件打开菜单
	print("🔍 [BattleScene] 查找UI组件: ComponentContainer/UIComponent")
	var ui_component = character_node.get_node_or_null("ComponentContainer/UIComponent")
	print("🔍 [BattleScene] UI组件查找结果: %s" % (ui_component.name if ui_component else "未找到"))
	
	if ui_component and ui_component.has_method("open_action_menu"):
		print("📞 [BattleScene] 调用ui_component.open_action_menu()")
		ui_component.open_action_menu()
		print("✅ [BattleScene] UI组件的open_action_menu()调用完成")
	else:
		print("⚠️ [BattleScene] UI组件不存在或没有open_action_menu方法")
		# 备用方案：直接触发action_menu_requested信号
		if character_node.has_signal("action_menu_requested"):
			print("📞 [BattleScene] 发送action_menu_requested信号")
			character_node.emit_signal("action_menu_requested")
			print("✅ [BattleScene] action_menu_requested信号已发送")
		else:
			print("❌ [BattleScene] 角色节点没有action_menu_requested信号")

# 🚀 切换到下一个角色
func _proceed_to_next_character() -> void:
	# 委托给BattleEventManager处理
	if battle_event_manager and battle_event_manager.has_method("_proceed_to_next_character"):
		battle_event_manager._proceed_to_next_character()
	else:
		# 回退到原有逻辑
		# 调用TurnManager的next_turn方法
		battle_manager.turn_manager.next_turn()
		print("✅ [回合] 已切换到下一个角色")

# 🚀 执行AI角色的自动行动
func _execute_ai_action(ai_character: GameCharacter) -> void:
	print("🚀 [AI行动] _execute_ai_action被调用，角色: %s" % ai_character.name)
	print("🔍 [AI行动] battle_manager.is_battle_active: %s" % battle_manager.is_battle_active)
	print("🔍 [AI行动] battle_manager.is_battle_in_progress(): %s" % battle_manager.is_battle_in_progress())
	
	# 🚀 AI回合开始时，强制关闭所有玩家行动菜单
	_force_close_all_player_menus()
	
	# 🚀 重要：确保AI角色的位置数据与节点同步
	var ai_node = _find_character_node_by_character_data(ai_character)
	# 同步位置数据
	ai_character.position = ai_node.position
	print("🔧 [AI行动] 同步AI角色位置: %s -> %s" % [ai_character.name, ai_character.position])
	
	# 🚀 委托给BattleAIManager处理AI行动
	print("🤖 [BattleScene] 委托给BattleAIManager处理AI行动")
	battle_ai_manager.execute_ai_turn(ai_character)


# 🚀 设置战斗UI（通过BattleUIManager）
func _setup_battle_ui() -> void:
	# 获取BattleUIManager引用
	battle_ui_manager = get_node("BattleSystems/BattleUIManager")
	
	# 连接BattleUIManager的信号
	battle_ui_manager.ui_update_requested.connect(_on_ui_update_requested)
	battle_ui_manager.battle_button_pressed.connect(_on_battle_button_pressed)
	
	# 🚀 初始化技能选择协调器
	await _setup_skill_selection_coordinator()

	print("✅ [战斗UI] 战斗UI初始化完成（通过BattleUIManager和SkillSelectionCoordinator）")

# 🚀 初始化技能选择协调器
func _setup_skill_selection_coordinator() -> void:
	print("🔍 [BattleScene] 开始设置技能选择协调器")
	
	# 等待SkillSelectionCoordinator初始化完成
	if not skill_selection_coordinator.is_initialized:
		print("🔍 [BattleScene] 等待SkillSelectionCoordinator初始化完成")
		await skill_selection_coordinator.tree_entered
		# 给一点时间让_initialize函数执行
		await get_tree().process_frame
		await get_tree().process_frame
	
	# 连接信号（节点已通过场景文件创建）
	skill_selection_coordinator.skill_selected.connect(_on_skill_selected_from_coordinator)
	skill_selection_coordinator.skill_selection_cancelled.connect(_on_skill_selection_cancelled_from_coordinator)
	skill_selection_coordinator.target_selected.connect(_on_target_selected_from_coordinator)
	skill_selection_coordinator.target_selection_cancelled.connect(_on_target_selection_cancelled_from_coordinator)
	
	print("✅ [技能选择协调器] 技能选择协调器初始化完成（使用场景节点）")

# 🚀 SkillSelectionCoordinator信号回调函数
func _on_skill_selected_from_coordinator(skill_id: String) -> void:
	print("🎯 [技能协调器] 技能选择: %s" % skill_id)
	# 委托给原有的处理函数
	_on_skill_selected(skill_id)

func _on_skill_selection_cancelled_from_coordinator() -> void:
	print("❌ [技能协调器] 技能选择取消")
	# 委托给原有的处理函数
	_on_skill_menu_closed()

func _on_target_selected_from_coordinator(targets: Array) -> void:
	print("🎯 [技能协调器] 目标选择: %d 个" % targets.size())
	# 委托给原有的处理函数
	_on_target_selected(targets)

func _on_target_selection_cancelled_from_coordinator() -> void:
	print("❌ [技能协调器] 目标选择取消")
	# 委托给原有的处理函数
	_on_target_menu_closed()

func _on_visual_skill_cast_completed_from_coordinator(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("✅ [技能协调器] 可视化技能释放完成")
	# 委托给原有的处理函数
	_on_visual_skill_cast_completed(skill, caster, targets)

func _on_visual_skill_selection_cancelled_from_coordinator() -> void:
	print("❌ [技能协调器] 可视化技能选择取消")
	# 委托给原有的处理函数
	_on_visual_skill_selection_cancelled()

# 🚀 更新UI显示（通过BattleUIManager）
func _update_battle_ui(title: String, message: String, update_type: String = "general") -> void:
	if battle_ui_manager:
		battle_ui_manager.update_battle_ui(title, message, update_type)
	else:
		print("⚠️ [战斗UI] BattleUIManager未初始化，无法更新UI")

# 🚀 恢复当前回合UI信息
func _restore_current_turn_ui() -> void:
	if battle_manager and battle_manager.turn_manager:
		var current_character = battle_manager.turn_manager.get_current_character()
		var turn_number = battle_manager.turn_manager.get_current_turn()
		
		if current_character:
			var character_type = "玩家" if current_character.is_player_controlled() else "AI"
			_update_battle_ui("回合 %d" % turn_number, "当前行动: %s (%s)" % [current_character.name, character_type], "turn_info")
		else:
			_update_battle_ui("回合 %d" % turn_number, "等待角色...", "turn_info")

# 🚀 切换战斗UI显示（通过BattleUIManager）
func toggle_battle_ui():
	if battle_ui_manager:
		battle_ui_manager.toggle_battle_ui()
	else:
		print("⚠️ [战斗UI] BattleUIManager未初始化，无法切换UI显示")

# 🚀 显示可攻击目标
func _display_attack_targets(attacker_character: GameCharacter) -> void:
		battle_combat_manager.display_attack_targets(attacker_character)

# 🚀 SkillManager信号回调 - 委托给BattleEventManager
func _on_skill_execution_completed(skill: SkillData, results: Dictionary, caster: GameCharacter):
	# 委托给BattleEventManager处理
	if battle_event_manager and battle_event_manager.has_method("_on_skill_execution_completed"):
		battle_event_manager._on_skill_execution_completed(skill, results, caster)
	else:
		# 回退到原有逻辑
		battle_combat_manager.on_skill_executed(caster, skill, [], [results])

# 🚀 技能取消回调 - 委托给BattleEventManager
func _on_skill_cancelled():
	# 委托给BattleEventManager处理
	if battle_event_manager and battle_event_manager.has_method("_on_skill_cancelled"):
		battle_event_manager._on_skill_cancelled()
	else:
		# 回退到原有逻辑
		battle_combat_manager.on_skill_cancelled()

# 🚀 技能选择UI相关方法

# 显示技能选择菜单（通过SkillSelectionCoordinator）
func show_skill_selection_menu(character: GameCharacter, available_skills: Array) -> void:
	skill_selection_coordinator.show_skill_selection_menu(character, available_skills)

# 技能选择回调
func _on_skill_selected(skill_id: String) -> void:
	print("🎯 [技能UI] 玩家选择技能: %s" % skill_id)
	
	# 通知SkillManager选择了技能
	if skill_manager:
		skill_manager.select_skill(skill_id)

# 技能菜单关闭回调
func _on_skill_menu_closed() -> void:
	print("❌ [技能UI] 技能选择菜单关闭")
	
	# 如果技能系统还在选择状态，则取消技能选择
	if skill_manager.current_state == SkillManager.SkillState.SELECTING_SKILL:
		skill_manager.cancel_skill_selection()

# 🚀 目标选择UI相关方法
# 显示目标选择菜单（通过SkillSelectionCoordinator）
func show_target_selection_menu(skill: SkillData, caster: GameCharacter, available_targets: Array) -> void:
	skill_selection_coordinator.show_target_selection_menu(skill, caster, available_targets)


# 目标选择回调
func _on_target_selected(targets: Array) -> void:
	print("🎯 [目标UI] 玩家选择目标: %d 个" % targets.size())
	
	# 通知SkillManager选择了目标
	skill_manager._select_targets(targets)

# 目标菜单关闭回调
func _on_target_menu_closed() -> void:
	print("❌ [目标UI] 目标选择菜单关闭")
	
	# 如果技能系统还在目标选择状态，则取消技能选择
	if skill_manager.current_state == SkillManager.SkillState.SELECTING_TARGET:
		skill_manager.cancel_skill_selection()

# 🚀 可视化技能选择器信号处理
func _on_visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	# 委托给BattleEventManager处理
	if battle_event_manager and battle_event_manager.has_method("_on_visual_skill_cast_completed"):
		battle_event_manager._on_visual_skill_cast_completed(skill, caster, targets)
	else:
		# 回退到原有逻辑
		print("✅ [可视化技能选择器] 技能释放完成: %s，施法者: %s，目标数量: %d" % [skill.name, caster.name, targets.size()])
		
		# 直接通过技能管理器执行技能（跳过原有的目标选择流程）
		# 设置技能管理器的状态
		skill_manager.active_skill_selection = skill
		skill_manager.current_caster = caster
		skill_manager.current_state = SkillManager.SkillState.EXECUTING_SKILL
		
		# 直接执行技能
		await skill_manager._execute_skill(targets)

func _on_visual_skill_selection_cancelled() -> void:
	# 委托给BattleEventManager处理
	if battle_event_manager and battle_event_manager.has_method("_on_visual_skill_selection_cancelled"):
		battle_event_manager._on_visual_skill_selection_cancelled()
	else:
		# 回退到原有逻辑
		print("❌ [可视化技能选择器] 技能选择被取消")
		
		# 🚀 修复：检查技能是否正在执行，避免在技能执行期间重置状态
		if skill_manager and skill_manager.current_state == SkillManager.SkillState.EXECUTING_SKILL:
			print("⚠️ [技能系统] 技能正在执行中，忽略取消请求")
			return
		
		# 🚀 修复：显式重置SkillManager状态，避免第二次技能选择时出现"正忙"问题
		if skill_manager:
			print("🔧 [技能系统] 显式重置SkillManager状态")
			skill_manager.cancel_skill_selection()
		
		# 🚀 修复：技能选择取消时，恢复到行动菜单状态，而不是重置整个行动系统
		_restore_current_turn_ui()
		
		# 🚀 重新显示当前角色的行动菜单
		var character_node = null
		
		# 首先尝试从ActionSystem获取选中的角色
		if action_system and action_system.selected_character:
			character_node = action_system.selected_character
			print("🔙 [行动系统] 从ActionSystem获取角色节点")
		else:
			# 如果ActionSystem的选中角色为空，从BattleManager获取当前回合角色
			if battle_manager and battle_manager.turn_manager:
				var current_character = battle_manager.turn_manager.get_current_character()
				if current_character:
					character_node = _find_character_node_by_character_data(current_character)
					print("🔙 [行动系统] 从BattleManager获取当前回合角色: %s" % current_character.name)
					
					# 重新设置ActionSystem的状态
					if action_system:
						action_system.selected_character = character_node
						action_system.current_state = ActionSystemScript.SystemState.SELECTING_ACTION
						print("🔧 [行动系统] 重新设置ActionSystem状态")
		
		if character_node:
			print("🔙 [行动系统] 技能选择取消，重新显示行动菜单")
			
			# 🚀 修复：直接通过角色节点的UI组件重新打开行动菜单
			var ui_component = character_node.get_node_or_null("ComponentContainer/UIComponent")
			if ui_component and ui_component.has_method("open_action_menu"):
				print("✅ [行动系统] 重新打开行动菜单")
				ui_component.open_action_menu()
			else:
				print("⚠️ [行动系统] 无法恢复行动菜单，重置行动系统")
				# 最后的备选方案
				if action_system:
					action_system.reset_action_system()

# 🚀 显示可视化技能选择界面（通过SkillSelectionCoordinator）
func show_visual_skill_selection(character: GameCharacter, available_skills: Array) -> void:
	_update_battle_ui("技能选择", "为 %s 选择技能..." % character.name, "skill_action")
	skill_selection_coordinator.show_visual_skill_selection(character, available_skills)

# 🚀 为技能系统提供的关键方法
func get_all_characters() -> Array:
	return character_manager.get_all_characters()

# 🚀 显示技能选择对话
func show_skill_menu(character: GameCharacter) -> void:
	print("🎯 [技能系统] 为角色 %s 显示技能菜单" % character.name)
	
	# 检查SkillManager是否可用
	
	# 检查SkillManager是否空闲
	if skill_manager.is_busy():
		print("⚠️ [技能系统] SkillManager正忙，无法开始新的技能选择")
		return
	
	# 🎯 启动技能选择流程
	skill_manager.start_skill_selection(character)
	
	print("✅ [技能系统] 技能选择流程已启动")

# 🧪 测试伤害跳字
func _test_damage_numbers() -> void:
	battle_visual_effects_manager.test_damage_numbers()
	var enemy_nodes = character_manager.get_enemy_nodes()
	if enemy_nodes.size() > 0:
		var first_enemy_id = enemy_nodes.keys()[0]
		var test_node = enemy_nodes[first_enemy_id]
		var test_character = test_node.get_character_data()
	
		print("✅ [测试] 找到测试角色: %s (节点: %s)" % [test_character.name, test_node.name])
		print("🔍 [测试] 角色节点位置: %s" % test_node.global_position)
		print("🔍 [测试] 角色节点可见性: %s" % test_node.visible)
		print("🔍 [测试] 角色节点z_index: %s" % test_node.z_index)
		
		# 获取Camera信息
		var camera = get_viewport().get_camera_2d()
		if camera:
			print("🔍 [测试] Camera位置: %s" % camera.global_position)
			print("🔍 [测试] Camera缩放: %s" % camera.zoom)
		else:
			print("⚠️ [测试] 没有找到Camera2D")
		
		# 测试伤害数字
		print("💥 [测试] 创建普通伤害数字: 50")
		var skill_effects = get_node("SkillEffects")
		skill_effects.create_damage_numbers(test_character, 50, false)
		
		# 等待0.5秒后创建暴击伤害
		await get_tree().create_timer(0.5).timeout
		print("💥 [测试] 创建暴击伤害数字: 100")
		skill_effects.create_damage_numbers(test_character, 100, true)
		
		# 等待0.5秒后创建治疗数字
		await get_tree().create_timer(0.5).timeout
		print("💚 [测试] 创建治疗数字: 30")
		skill_effects.create_healing_numbers(test_character, 30)

# 🚀 处理BattleUIManager的战斗按钮信号
func _on_battle_button_pressed() -> void:
	
	if battle_manager.is_battle_in_progress():
		print("⚠️ [战斗UI] 战斗已在进行中")
		return
	
	print("🎮 [战斗UI] 通过BattleUIManager按钮开始战斗")
	battle_manager.start_battle()
	
	# 更新按钮状态
	battle_ui_manager.update_battle_button_state(true)

# 🚀 处理BattleUIManager的UI更新请求信号
func _on_ui_update_requested(title: String, message: String, update_type: String) -> void:
	if update_type == "restore":
		# 恢复当前回合UI信息
		_restore_current_turn_ui()
	else:
		print("🔍 [UI更新请求] 类型: %s, 标题: %s, 消息: %s" % [update_type, title, message])

# 🚀 更新开始战斗按钮状态（通过BattleUIManager）
func _update_battle_button_state() -> void:
	var is_battle_in_progress = battle_manager.is_battle_in_progress()
	battle_ui_manager.update_battle_button_state(is_battle_in_progress)

func _on_move_cancelled():
	print("❌ [移动] 移动被取消")
	# 重置行动系统状态
	action_system.reset_action_system()

# 🚀 强制关闭所有玩家行动菜单
func _force_close_all_player_menus() -> void:
	print("🔧 [菜单管理] 强制关闭所有玩家行动菜单")
	
	# 遍历所有玩家角色节点
	var party_nodes = character_manager.get_party_member_nodes()
	for character_id in party_nodes:
		var character_node = party_nodes[character_id]
		# 检查是否有打开的UI组件菜单
		var ui_component = character_node.get_node("ComponentContainer/UIComponent")
		# 强制关闭当前打开的菜单
		if ui_component.current_open_menu and is_instance_valid(ui_component.current_open_menu):
			print("🔧 [菜单管理] 关闭角色 %s 的行动菜单" % character_id)
			ui_component.current_open_menu.close_menu()
			ui_component.current_open_menu = null
	
	# 🚀 也检查全局的ActionMenu实例
	var global_menus = get_tree().get_nodes_in_group("action_menus")
	for menu in global_menus:
		if is_instance_valid(menu) and menu.visible:
			print("🔧 [菜单管理] 关闭全局行动菜单")
			menu.close_menu()
	
	print("✅ [菜单管理] 所有玩家行动菜单已关闭")

# 🚀 辅助方法：拼接字符串数组（替代Array.join()）
func _join_string_array(arr: Array, delimiter: String = "、", final_delimiter: String = "和") -> String:
	if arr.is_empty():
		return ""
	elif arr.size() == 1:
		return str(arr[0])
	elif arr.size() == 2:
		return str(arr[0]) + final_delimiter + str(arr[1])
	else:
		var result = str(arr[0])
		for i in range(1, arr.size() - 1):
			result += delimiter + str(arr[i])
		result += final_delimiter + str(arr[-1])
		return result

# Edit file: res://Scripts/BattleScene.gd
extends Node2D

# 预加载行动系统脚本以访问其枚举和常量
const ActionSystemScript = preload("res://Scripts/ActionSystemNew.gd")

# 🚀 预加载碰撞形状绘制器
const CollisionShapeDrawer = preload("res://Scripts/CollisionShapeDrawer.gd")

# 🚀 预加载技能范围显示组件
const SkillRangeDisplayScript = preload("res://Scripts/SkillRangeDisplay.gd")

# 🆕 预加载辅助类
const BattleSystemInitializer = preload("res://Scripts/Battle/BattleSystemInitializer.gd")
const BattleSignalRouter = preload("res://Scripts/Battle/BattleSignalRouter.gd")
const BattleUICoordinator = preload("res://Scripts/Battle/BattleUICoordinator.gd")
const BattleActionCoordinator = preload("res://Scripts/Battle/BattleActionCoordinator.gd")
const BattleVisualizationManager = preload("res://Scripts/Battle/BattleVisualizationManager.gd")
const BattleLevelManager = preload("res://Scripts/Battle/BattleLevelManager.gd")

# 🚀 障碍物管理器引用
@onready var obstacle_manager: Node2D = $TheLevel/ObstacleManager
# 🚀 关卡容器引用
@onready var the_level: Node = $TheLevel

# 🌍 统一的地面高度定义
const GROUND_LEVEL: float = 1000.0  # 地面的Y坐标值

# 角色初始位置配置 - Y坐标将根据GroundAnchor动态调整
const SPAWN_POSITIONS := {
	"1": Vector2(600, GROUND_LEVEL),   # 觉远
	"2": Vector2(700, GROUND_LEVEL),   # 柳生
	"3": Vector2(800, GROUND_LEVEL)    # 兰斯洛特
}

# 敌人初始位置配置 - Y坐标将根据GroundAnchor动态调整
const ENEMY_SPAWN_POSITIONS := {
	"101": Vector2(1000, GROUND_LEVEL),   # 山贼头目
	"102": Vector2(1100, GROUND_LEVEL),   # 野狼
	"103": Vector2(1200, GROUND_LEVEL)    # 骷髅战士
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

# 🆕 辅助类
var system_initializer: BattleSystemInitializer
var signal_router: BattleSignalRouter

# 🆕 新协调器（第一阶段）
var ui_coordinator: BattleUICoordinator
var action_coordinator: BattleActionCoordinator

# 🆕 新管理器（第二阶段）
var visualization_manager: BattleVisualizationManager
var level_manager: BattleLevelManager

func _ready() -> void:
	print("🚀 [BattleScene] 开始初始化")
	add_to_group("battle_scene")
	
	# 创建辅助类
	system_initializer = BattleSystemInitializer.new()
	signal_router = BattleSignalRouter.new()
	
	# 初始化所有系统
	await system_initializer.initialize_all_systems(self)
	
	# 建立所有信号连接
	signal_router.setup_all_connections(self)
	
	print("✅ [BattleScene] 初始化完成")

func _setup_character_manager() -> void:
	print("🚀 [BattleScene] 开始初始化角色管理器")
	character_manager = BattleCharacterManager.new()
	character_manager.name = "BattleCharacterManager"
	add_child(character_manager)
	print("✅ [BattleScene] 角色管理器已创建并添加到场景树")
	
	character_manager.character_spawned.connect(_on_character_spawned)
	character_manager.character_death.connect(_on_character_death_from_manager)
	character_manager.character_updated.connect(_on_character_updated_from_manager)
	
	# 🆕 不再在这里直接生成角色，等待关卡配置加载
	# 关卡配置会通过 _on_level_data_ready 回调来生成角色
	print("⏳ [BattleScene] 角色管理器等待关卡配置加载角色")
	
	# 如果没有关卡配置（向后兼容），仍然可以使用默认方式
	# await character_manager.spawn_party_members()
	# await character_manager.spawn_enemies()
	# character_manager.check_and_fix_character_heights()

func _setup_skill_effects() -> void:
	var skill_effects = get_node("SkillEffects")
	skill_manager.skill_effects = skill_effects

func _setup_movement_coordinator() -> void:
	print("🚀 [BattleScene] 初始化MovementCoordinator")
	# MovementCoordinator会在其_ready函数中自动初始化
	# 这里我们确保它能正确找到所需的节点引用

# 🚀 各专业管理器的初始化已迁移到BattleSystemInitializer

# 🚀 专业管理器信号处理已迁移到BattleSignalRouter

func _on_character_spawned(character_id: String, character_node: Node2D) -> void:
	var movement_component = character_node.get_node_or_null("ComponentContainer/MovementComponent")
	if movement_component and movement_coordinator:
		movement_component.move_requested.connect(
			func(target_pos: Vector2, target_height: float):
				movement_coordinator.handle_move_request(character_node, character_id, target_pos, target_height)
		)

func _on_character_death_from_manager(dead_character: GameCharacter) -> void:
	pass

func _on_character_updated_from_manager(character_id: String) -> void:
	pass

# 🚀 专业管理器信号处理已迁移到各自的管理器和BattleSignalRouter

# 🚀 关卡管理功能已迁移到BattleLevelManager

func _setup_obstacle_manager() -> void:
	print("🚀 [BattleScene] 初始化障碍物管理器")
	
	if obstacle_manager:
		# 连接障碍物管理器信号
		obstacle_manager.obstacle_added.connect(_on_obstacle_added)
		obstacle_manager.obstacle_removed.connect(_on_obstacle_removed)
		obstacle_manager.obstacles_cleared.connect(_on_obstacles_cleared)
		
		# 注释掉原有的动态障碍物生成，现在使用关卡场景中的静态障碍物
		# _generate_initial_obstacles()
		
		# 延迟重新扫描障碍物，确保关卡中的障碍物已经完全初始化
		print("⏰ [BattleScene] 延迟重新扫描障碍物...")
		await get_tree().process_frame  # 等待一帧
		await get_tree().process_frame  # 再等待一帧确保完全初始化
		obstacle_manager._register_existing_obstacles()
		
		print("✅ [BattleScene] 障碍物管理器初始化完成")
	else:
		print("❌ [BattleScene] 未找到障碍物管理器节点")

func _on_obstacle_added(obstacle) -> void:
	# 障碍物添加事件处理（已简化输出）
	pass

func _on_obstacle_removed(obstacle) -> void:
	print("🗑️ [BattleScene] 障碍物已移除: %s" % obstacle.global_position)

func _on_obstacles_cleared() -> void:
	print("🧹 [BattleScene] 所有障碍物已清除")

# 🚀 原有的动态障碍物生成方法已移除，现在使用关卡场景中的静态障碍物
# func _generate_initial_obstacles() -> void:
#	"""生成战斗场景的初始障碍物"""
#	print("🪨 [BattleScene] 开始生成初始障碍物")
#	
#	if not obstacle_manager:
#		print("❌ [BattleScene] 障碍物管理器不存在，无法生成障碍物")
#		return
#	
#	# 等待一帧确保所有角色都已生成
#	await get_tree().process_frame
#	
#	# 生成地面平台
#	obstacle_manager.generate_ground_platform()
#	
#	# 生成乱石障碍物
#	obstacle_manager.generate_rocks(obstacle_manager.rock_count)
#	
#	# 可以根据需要添加其他类型的障碍物
#	# obstacle_manager.add_obstacle_at_position(Vector2(900, 980), 1)  # 墙壁
#	# obstacle_manager.add_obstacle_at_position(Vector2(1050, 980), 2)  # 水域
#	
#	print("✅ [BattleScene] 初始障碍物生成完成")

func _show_gameplay_tips() -> void:
	print("游戏已启动 - 按F11开始战斗，F10切换碰撞体积显示")
	

# 🚀 碰撞检测功能已迁移到PositionCollisionManager

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

# 🚀 移动处理功能已迁移到MovementCoordinator

# 🚀 委托方法：关卡加载（为向后兼容）
func load_dynamic_level(level_path: String = "res://Scenes/Levels/LEVEL_1_序幕.tscn"):
	if level_manager:
		await level_manager.load_dynamic_level(level_path)
	else:
		print("⚠️ [BattleScene] LevelManager不存在")

func _find_character_node_by_id(character_id: String) -> Node2D:
	return character_manager.find_character_node_by_id(character_id)

func _print_party_stats() -> void:
	character_manager.print_party_stats()

func _on_character_updated(character_id: String) -> void:
	pass

func _find_character_node(character_id: String) -> Node2D:
	return _find_character_node_by_id(character_id)

func _input(event):
	# 🚀 新增：切换战斗UI快捷键
	if Input.is_action_just_pressed("ui_accept"):  # 回车键
		if ui_coordinator: ui_coordinator.toggle_battle_ui()
	
	# 🚀 新增：输出当前回合状态调试信息
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("\n=== 🔍 回合状态调试信息 ===")
			if battle_manager and battle_manager.turn_manager:
				var turn_manager = battle_manager.turn_manager
				print("📊 [调试] 当前回合: %d" % turn_manager.get_current_turn())
				print("📊 [调试] 当前角色索引: %d" % turn_manager.current_character_index)
				print("📊 [调试] 回合队列大小: %d" % turn_manager.turn_queue.size())
				
				var current_character = turn_manager.get_current_character()
				if current_character:
					print("📊 [调试] 当前角色: %s (控制类型: %d)" % [current_character.name, current_character.control_type])
					var points = action_system.get_character_action_points(current_character)
					print("📊 [调试] 行动点数：移动%d，攻击%d" % [points.move_points, points.attack_points])
				else:
					print("📊 [调试] 当前角色: null")
				
				print("📊 [调试] 回合队列:")
				for i in range(turn_manager.turn_queue.size()):
					var char = turn_manager.turn_queue[i]
					var is_current = (i == turn_manager.current_character_index)
					var char_type = "友方" if char.is_player_controlled() else "敌方"
					var marker = "👉 " if is_current else "   "
					print("📊 [调试] %s%d. %s (%s) - HP: %d/%d" % [marker, i, char.name, char_type, char.current_hp, char.max_hp])
				
				print("📊 [调试] 战斗状态: is_battle_active = %s" % battle_manager.is_battle_active)
				print("📊 [调试] ActionSystem状态: %s" % action_system.current_state)
			else:
				print("⚠️ [调试] BattleManager或TurnManager未找到")
			print("=== 调试信息结束 ===\n")
	
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
				obstacle_manager._register_existing_obstacles()
			else:
				pass
		# 🚀 按Q键刷新障碍物
		elif event.keycode == KEY_R:
			if obstacle_manager:
				print("🔄 [BattleScene] R键触发 - 重新扫描障碍物")
				obstacle_manager._register_existing_obstacles()
			else:
				printerr("❌ [BattleScene] 障碍物管理器不存在")
		# 🚀 按W键输出障碍物系统状态信息（不刷新障碍物）
		elif event.keycode == KEY_W:
			_debug_obstacle_system_status()
	
func _check_and_fix_character_heights() -> void:
	character_manager.check_and_fix_character_heights()

func _process(delta):
	pass

# 🚀 移动完成处理（保留用于向后兼容和特殊逻辑）
func _on_move_completed(character: GameCharacter, final_position: Vector2):
	print("🏁 [BattleScene] 移动完成回调: %s -> %s" % [character.name, str(final_position)])
	
	# 🔍 调试：记录移动完成前的状态
	
	
	# ⚠️ 注意：不要直接设置character.position，因为这会触发GameCharacter的set_position方法
	# 该方法会错误地更新ground_position.y，导致位置修正问题
	# 位置应该已经在MovementCoordinator中正确设置了
	
	
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
		# 🚀 移动确认和取消信号已委托给MovementCoordinator处理
		pass
	else:
		push_error("[BattleScene] 未找到MoveRange/Controller节点")

func _connect_battle_manager_signals():
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.turn_ended.connect(_on_turn_ended)
	# 🚀 新增：连接表现层信号
	# 🚀 视觉更新请求已委托给专业管理器处理
	battle_manager.player_turn_started.connect(_on_player_turn_started)
	battle_manager.ai_turn_started.connect(_on_ai_turn_started)

func _on_battle_started():
	_update_battle_button_state()

func _on_battle_ended(result: Dictionary):
	# 🚀 修改：简化为只处理基本的战斗结束逻辑
	# 胜负判定和视觉效果现在通过battle_visual_update_requested信号处理
	_update_battle_button_state()
	print("🏁 [BattleScene] 战斗结束，结果: %s" % result.get("winner", "未知"))

# 🚀 战斗视觉更新委托给专业管理器

func _end_battle_with_visual_effects(winner: String) -> void:
	_force_close_all_player_menus()
	_stop_all_character_actions()
	
	# 委托给VisualizationManager处理战斗结果标记
	if visualization_manager:
		visualization_manager.add_battle_result_markers(winner, character_manager)

func _stop_all_character_actions() -> void:
	var tween_nodes = get_tree().get_nodes_in_group("character_tweens")
	for tween in tween_nodes:
		if is_instance_valid(tween) and tween is Tween:
			tween.kill()
	
	movement_coordinator.clear_all_moving_characters()
	action_system.reset_action_system()

# 🚀 回合管理已委托给专业管理器

func _on_turn_started(turn_number: int):
	action_system.start_new_turn_for_character(battle_manager.turn_manager.get_current_character())

# 🚀 玩家和AI回合处理
func _on_player_turn_started(character: GameCharacter) -> void:
	var character_node = _find_character_node_by_character_data(character)
	if character_node:
		call_deferred("_open_character_action_menu", character_node)

func _on_ai_turn_started(character: GameCharacter) -> void:
	# 委托给AI管理器处理AI行动
	if battle_ai_manager and battle_ai_manager.has_method("execute_ai_turn"):
		call_deferred("_delegate_ai_action", character)
	else:
		print("⚠️ [BattleScene] AI管理器不可用，跳过AI行动")

# 🚀 委托AI行动给AI管理器
func _delegate_ai_action(character: GameCharacter) -> void:
	if battle_ai_manager and battle_ai_manager.has_method("execute_ai_turn"):
		battle_ai_manager.execute_ai_turn(character)
	else:
		print("⚠️ [BattleScene] AI管理器不可用，跳过AI行动")
		# 如果AI管理器不可用，直接进入下一回合
		if battle_manager and battle_manager.turn_manager:
			battle_manager.turn_manager.next_turn()

func _on_turn_ended(turn_number: int):
	pass

# 🚀 角色行动处理已委托给BattleEventManager

# 🚀 移动处理已委托给MovementCoordinator

# 通过角色数据查找对应的角色节点
func _find_character_node_by_character_data(character_data: GameCharacter) -> Node2D:
	return character_manager.get_character_node_by_data(character_data)

# 🚀 根据角色数据获取对应的角色节点（用于技能系统高亮显示等）
func get_character_node_by_data(character_data: GameCharacter) -> Node2D:
	return character_manager.get_character_node_by_data(character_data)

# 这些函数已经迁移到BattleActionCoordinator，删除冗余代码


# 这些UI相关函数已经迁移到BattleUICoordinator，删除冗余代码

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
	# 🚀 修复：不再委托给BattleEventManager，避免循环调用
	# BattleEventManager会通过信号机制自动处理，这里直接执行本地逻辑
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
		if ui_coordinator: ui_coordinator.restore_current_turn_ui()
		
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
	print("🔍 [BattleScene] show_visual_skill_selection被调用")
	print("🔍 [BattleScene] 角色: %s, 技能数量: %d" % [character.name, available_skills.size()])
	print("🔍 [BattleScene] skill_selection_coordinator存在: %s" % (skill_selection_coordinator != null))
	
	if ui_coordinator: ui_coordinator.update_battle_ui("技能选择", "为 %s 选择技能..." % character.name, "skill_action")
	
	if skill_selection_coordinator:
		print("🔧 [BattleScene] 即将调用skill_selection_coordinator.show_visual_skill_selection")
		skill_selection_coordinator.show_visual_skill_selection(character, available_skills)
		print("✅ [BattleScene] skill_selection_coordinator.show_visual_skill_selection调用完成")
	else:
		print("❌ [BattleScene] skill_selection_coordinator为空！")

# 🚀 为技能系统提供的关键方法
func get_all_characters() -> Array:
	return character_manager.get_all_characters()

# 🚀 显示技能选择对话
func show_skill_menu(character: GameCharacter) -> void:
	print("🔥🔥🔥 [BattleScene] show_skill_menu 被调用！！！")
	print("🎯 [技能系统] 为角色 %s 显示技能菜单" % character.name)
	
	# 检查SkillManager是否可用
	print("🔍 [技能系统] 检查SkillManager: %s" % (skill_manager != null))
	if not skill_manager:
		print("❌ [技能系统] SkillManager不可用！")
		return
	
	# 检查SkillManager是否空闲
	print("🔍 [技能系统] SkillManager当前状态: %s" % skill_manager.current_state)
	if skill_manager.current_state != SkillManager.SkillState.IDLE:
		print("⚠️ [技能系统] SkillManager正忙，无法开始新的技能选择")
		return
	
	# 🎯 启动技能选择流程
	print("🚀 [技能系统] 即将调用 skill_manager.start_skill_selection")
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
	
		var skill_effects = get_node("SkillEffects")
		skill_effects.create_damage_numbers(test_character, 50, false)
		
		# 等待0.5秒后创建暴击伤害
		await get_tree().create_timer(0.5).timeout
		skill_effects.create_damage_numbers(test_character, 100, true)
		
		# 等待0.5秒后创建治疗数字
		await get_tree().create_timer(0.5).timeout
		skill_effects.create_healing_numbers(test_character, 30)

# 🚀 处理BattleUIManager的战斗按钮信号
func _on_battle_button_pressed() -> void:
	
	if battle_manager.is_battle_in_progress():
		print("⚠️ [战斗UI] 战斗已在进行中")
		return
	
	print("🎮 [战斗UI] 通过BattleUIManager按钮开始战斗")
	battle_manager.start_battle()
	
	# 通过UICoordinator更新按钮状态
	_update_battle_button_state()

# 🚀 处理BattleUIManager的UI更新请求信号
func _on_ui_update_requested(title: String, message: String, update_type: String) -> void:
	if update_type == "restore":
		# 恢复当前回合UI信息
		if ui_coordinator: ui_coordinator.restore_current_turn_ui()
	else:
		print("🔍 [UI更新请求] 类型: %s, 标题: %s, 消息: %s" % [update_type, title, message])

# 🚀 更新开始战斗按钮状态（通过UICoordinator）
func _update_battle_button_state() -> void:
	var is_battle_in_progress = battle_manager.is_battle_in_progress()
	
	# 通过UICoordinator委托更新按钮状态
	if ui_coordinator and ui_coordinator.battle_ui_manager:
		ui_coordinator.battle_ui_manager.update_battle_button_state(is_battle_in_progress)
	else:
		print("⚠️ [BattleScene] UICoordinator或BattleUIManager不可用，无法更新按钮状态")

# 🚀 移动取消处理已委托给MovementCoordinator

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

# 🚀 调试：输出障碍物系统状态信息
func _debug_obstacle_system_status() -> void:
	print("\n=== 🪨 障碍物系统状态报告 ===")
	
	# 检查障碍物管理器是否存在
	if not obstacle_manager:
		printerr("❌ 障碍物管理器不存在！")
		return
	
	print("✅ 障碍物管理器已找到: %s" % obstacle_manager.name)
	print("📍 障碍物管理器位置: %s" % obstacle_manager.global_position)
	
	# 输出障碍物管理器配置
	print("\n--- 配置信息 ---")
	print("🪨 障碍物数量: %d" % obstacle_manager.get_obstacle_count())
	# 注意：以下配置属性已在重构中移除，因为不再动态生成障碍物
	# print("📏 乱石半径范围: %.1f - %.1f" % [obstacle_manager.rock_radius_min, obstacle_manager.rock_radius_max])
	# print("🎯 生成区域大小: %s" % obstacle_manager.spawn_area_size)
	# print("📐 障碍物间最小距离: %.1f" % obstacle_manager.min_distance_between_obstacles)
	# print("👥 角色最小距离: %.1f" % obstacle_manager.min_distance_from_characters)
	
	# 检查当前障碍物数量
	var current_obstacles = obstacle_manager.get_children()
	print("\n--- 当前障碍物 ---")
	print("📊 当前障碍物总数: %d" % current_obstacles.size())
	
	if current_obstacles.size() > 0:
		for i in range(current_obstacles.size()):
			var obstacle = current_obstacles[i]
			var collision_layer_info = "未知"
			var collision_mask_info = "未知"
			if obstacle is Area2D:
				collision_layer_info = str(obstacle.collision_layer)
				collision_mask_info = str(obstacle.collision_mask)
			print("  %d. %s - 位置: %s, 碰撞层: %s, 碰撞掩码: %s" % [i+1, obstacle.name, obstacle.global_position, collision_layer_info, collision_mask_info])
	else:
		print("⚠️ 当前没有障碍物")
	
	# 检查角色位置（用于障碍物生成参考）
	print("\n--- 角色位置信息 ---")
	if character_manager:
		var party_nodes = character_manager.get_party_member_nodes()
		var enemy_nodes = character_manager.get_enemy_nodes()
		
		print("👥 玩家角色数量: %d" % party_nodes.size())
		for character_id in party_nodes:
			var character_node = party_nodes[character_id]
			print("  - %s: %s" % [character_id, character_node.global_position])
		
		print("👹 敌人角色数量: %d" % enemy_nodes.size())
		for character_id in enemy_nodes:
			var character_node = enemy_nodes[character_id]
			print("  - %s: %s" % [character_id, character_node.global_position])
	else:
		print("❌ 角色管理器不存在")
	
	# 状态信息输出完成
	print("\n--- 状态输出完成 ---")
	print("💡 提示: 按Q键可重新生成障碍物")
	
	print("\n=== 障碍物系统状态报告结束 ===\n")

# 🚀 委托方法：打开角色行动菜单（委托给BattleActionCoordinator）
func _open_character_action_menu(character_node: Node2D) -> void:
	if action_coordinator:
		action_coordinator.open_character_action_menu(character_node)
	else:
		print("❌ [BattleScene] ActionCoordinator不存在，无法打开行动菜单")

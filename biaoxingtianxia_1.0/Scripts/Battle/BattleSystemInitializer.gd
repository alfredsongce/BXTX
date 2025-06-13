class_name BattleSystemInitializer
extends RefCounted

## 战斗系统初始化器
## 负责统一管理BattleScene中所有系统的初始化工作

# 预加载新的协调器类
const BattleUICoordinator = preload("res://Scripts/Battle/BattleUICoordinator.gd")
const BattleActionCoordinator = preload("res://Scripts/Battle/BattleActionCoordinator.gd")
const BattleVisualizationManager = preload("res://Scripts/Battle/BattleVisualizationManager.gd")
const BattleLevelManager = preload("res://Scripts/Battle/BattleLevelManager.gd")

# 初始化状态跟踪
var _initialized_systems: Dictionary = {}

## 初始化所有战斗系统
func initialize_all_systems(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 开始初始化所有战斗系统")
	
	# 阶段1：核心系统初始化
	await setup_character_manager(scene)
	setup_move_range_system(scene)
	setup_collision_visualization(scene)
	
	# 阶段2：新协调器初始化（第一阶段）
	await setup_ui_coordinator(scene)
	await setup_action_coordinator(scene)
	
	# 阶段2.5：新管理器初始化（第二阶段）
	await setup_visualization_manager(scene)
	await setup_level_manager(scene)
	
	# 阶段3：传统UI系统初始化
	setup_skill_effects(scene)
	
	# 阶段4：战斗系统初始化
	setup_movement_coordinator(scene)
	setup_battle_flow_manager(scene)
	setup_battle_input_handler(scene)
	setup_battle_animation_manager(scene)
	setup_battle_visual_effects_manager(scene)
	setup_battle_combat_manager(scene)
	setup_battle_ai_manager(scene)
	
	# 阶段4：关卡和环境初始化
	await load_initial_level(scene)
	await setup_obstacle_manager(scene)
	
	# 阶段5：显示提示
	show_gameplay_tips(scene)
	
	print("✅ [BattleSystemInitializer] 所有系统初始化完成")

## 初始化角色管理器
func setup_character_manager(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 开始初始化角色管理器")
	
	var character_manager = BattleCharacterManager.new()
	character_manager.name = "BattleCharacterManager"
	scene.add_child(character_manager)
	scene.character_manager = character_manager
	print("✅ [BattleSystemInitializer] 角色管理器已创建并添加到场景树")
	
	# 连接角色管理器信号
	character_manager.character_spawned.connect(scene._on_character_spawned)
	character_manager.character_death.connect(scene._on_character_death_from_manager)
	character_manager.character_updated.connect(scene._on_character_updated_from_manager)
	
	print("⏳ [BattleSystemInitializer] 角色管理器等待关卡配置加载角色")
	_initialized_systems["character_manager"] = true

## 初始化移动范围系统
func setup_move_range_system(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化移动范围系统")
	
	var move_range_controller = scene.get_node_or_null("MoveRange/Controller")
	if move_range_controller:
		# 🚀 移动确认信号已委托给MovementCoordinator处理
		print("✅ [BattleSystemInitializer] 移动范围系统初始化完成（信号已委托给MovementCoordinator）")
	else:
		push_error("[BattleSystemInitializer] 未找到MoveRange/Controller节点")
	
	_initialized_systems["move_range_system"] = true

## 初始化碰撞可视化（委托给VisualizationManager）
func setup_collision_visualization(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化碰撞可视化")
	
	# 现在通过VisualizationManager处理碰撞可视化
	if scene.visualization_manager:
		scene.visualization_manager.setup_collision_visualization()
		print("✅ [BattleSystemInitializer] 碰撞可视化初始化完成")
	else:
		print("⚠️ [BattleSystemInitializer] VisualizationManager不存在，跳过碰撞可视化")
	
	_initialized_systems["collision_visualization"] = true

## 初始化战斗UI
func setup_battle_ui(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化战斗UI")
	scene._setup_battle_ui()
	_initialized_systems["battle_ui"] = true

## 初始化技能效果系统
func setup_skill_effects(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化技能效果系统")
	
	var skill_effects = scene.get_node_or_null("SkillEffects")
	if skill_effects:
		scene.skill_manager.skill_effects = skill_effects
		print("✅ [BattleSystemInitializer] 技能效果系统初始化完成")
	else:
		print("⚠️ [BattleSystemInitializer] 未找到SkillEffects节点")
	
	_initialized_systems["skill_effects"] = true

## 初始化移动协调器
func setup_movement_coordinator(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化MovementCoordinator")
	# MovementCoordinator会在其_ready函数中自动初始化
	_initialized_systems["movement_coordinator"] = true

## 初始化战斗流程管理器
func setup_battle_flow_manager(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化BattleFlowManager")
	# BattleFlowManager会在其_ready函数中自动初始化
	_initialized_systems["battle_flow_manager"] = true

## 初始化战斗输入处理器
func setup_battle_input_handler(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化BattleInputHandler")
	_initialized_systems["battle_input_handler"] = true

## 初始化战斗动画管理器
func setup_battle_animation_manager(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化BattleAnimationManager")
	
	var battle_animation_manager = scene.get_node_or_null("BattleSystems/BattleAnimationManager")
	if battle_animation_manager:
		# 设置必要的引用
		battle_animation_manager.battle_scene = scene
		battle_animation_manager.skill_manager = scene.skill_manager
		print("✅ [BattleSystemInitializer] BattleAnimationManager初始化完成")
	
	_initialized_systems["battle_animation_manager"] = true

## 初始化战斗视觉效果管理器
func setup_battle_visual_effects_manager(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化BattleVisualEffectsManager")
	
	var battle_visual_effects_manager = scene.get_node_or_null("BattleSystems/BattleVisualEffectsManager")
	if battle_visual_effects_manager:
		# 设置必要的引用
		battle_visual_effects_manager.battle_scene = scene
		battle_visual_effects_manager.skill_manager = scene.skill_manager
		
		# 设置SkillEffects引用
		var skill_effects = scene.get_node_or_null("SkillEffects")
		if skill_effects:
			battle_visual_effects_manager.skill_effects = skill_effects
		
		print("✅ [BattleSystemInitializer] BattleVisualEffectsManager初始化完成")
	
	_initialized_systems["battle_visual_effects_manager"] = true

## 初始化战斗逻辑管理器
func setup_battle_combat_manager(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化BattleCombatManager")
	
	var battle_combat_manager = scene.get_node_or_null("BattleSystems/BattleCombatManager")
	if battle_combat_manager:
		# 设置组件引用
		var refs = {
			"character_manager": scene.character_manager,
			"action_system": scene.action_system,
			"battle_manager": scene.battle_manager,
			"skill_manager": scene.skill_manager,
			"battle_animation_manager": scene.battle_animation_manager,
			"battle_visual_effects_manager": scene.battle_visual_effects_manager,
			"battle_input_handler": scene.battle_input_handler,
			"battle_ui_manager": scene.battle_ui_manager
		}
		battle_combat_manager.setup_references(refs)
		print("✅ [BattleSystemInitializer] BattleCombatManager初始化完成")
	
	_initialized_systems["battle_combat_manager"] = true

## 初始化战斗AI管理器
func setup_battle_ai_manager(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化BattleAIManager")
	
	var battle_ai_manager = scene.get_node_or_null("BattleSystems/BattleAIManager")
	if battle_ai_manager:
		# 设置组件引用
		var refs = {
			"character_manager": scene.character_manager,
			"action_system": scene.action_system,
			"battle_combat_manager": scene.battle_combat_manager,
			"movement_coordinator": scene.movement_coordinator,
			"battle_animation_manager": scene.battle_animation_manager
		}
		battle_ai_manager.setup_references(refs)
		print("✅ [BattleSystemInitializer] BattleAIManager初始化完成")
	
	_initialized_systems["battle_ai_manager"] = true

## 加载初始关卡
func load_initial_level(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 加载初始关卡")
	await scene.load_dynamic_level("res://Scenes/Levels/LEVEL_1_序幕.tscn")
	_initialized_systems["initial_level"] = true

## 初始化障碍物管理器
func setup_obstacle_manager(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 初始化障碍物管理器")
	
	var obstacle_manager = scene.get_node_or_null("TheLevel/ObstacleManager")
	if obstacle_manager:
		# 延迟重新扫描障碍物，确保关卡中的障碍物已经完全初始化
		print("⏰ [BattleSystemInitializer] 延迟重新扫描障碍物...")
		await scene.get_tree().process_frame  # 等待一帧
		await scene.get_tree().process_frame  # 再等待一帧确保完全初始化
		obstacle_manager._register_existing_obstacles()
		
		print("✅ [BattleSystemInitializer] 障碍物管理器初始化完成")
	else:
		print("❌ [BattleSystemInitializer] 未找到障碍物管理器节点")
	
	_initialized_systems["obstacle_manager"] = true

## 显示游戏提示
func show_gameplay_tips(scene: Node2D) -> void:
	print("🚀 [BattleSystemInitializer] 显示游戏操作提示")
	scene._show_gameplay_tips()
	_initialized_systems["gameplay_tips"] = true

## 设置UI协调器
func setup_ui_coordinator(scene: Node2D) -> void:
	print("🎨 [BattleSystemInitializer] 设置UI协调器")
	
	# 创建BattleUICoordinator实例
	var ui_coordinator = BattleUICoordinator.new()
	scene.ui_coordinator = ui_coordinator
	
	# 初始化UI协调器
	await ui_coordinator.initialize(scene)
	
	_initialized_systems["ui_coordinator"] = true

## 设置行动协调器
func setup_action_coordinator(scene: Node2D) -> void:
	print("🎯 [BattleSystemInitializer] 设置行动协调器")
	
	# 创建BattleActionCoordinator实例
	var action_coordinator = BattleActionCoordinator.new()
	scene.action_coordinator = action_coordinator
	
	# 初始化行动协调器
	await action_coordinator.initialize(scene)
	
	_initialized_systems["action_coordinator"] = true

## 设置可视化管理器（第二阶段）
func setup_visualization_manager(scene: Node2D) -> void:
	print("🎨 [BattleSystemInitializer] 设置可视化管理器")
	
	# 创建BattleVisualizationManager实例
	var visualization_manager = BattleVisualizationManager.new()
	visualization_manager.name = "BattleVisualizationManager"
	scene.add_child(visualization_manager)
	scene.visualization_manager = visualization_manager
	
	# 初始化可视化管理器
	visualization_manager.initialize(scene)
	
	_initialized_systems["visualization_manager"] = true

## 设置关卡管理器（第二阶段）
func setup_level_manager(scene: Node2D) -> void:
	print("🗺️ [BattleSystemInitializer] 设置关卡管理器")
	
	# 创建BattleLevelManager实例
	var level_manager = BattleLevelManager.new()
	level_manager.name = "BattleLevelManager"
	scene.add_child(level_manager)
	scene.level_manager = level_manager
	
	# 初始化关卡管理器
	level_manager.initialize(scene)
	
	_initialized_systems["level_manager"] = true

## 验证初始化状态
func validate_initialization() -> bool:
	var expected_systems = [
		"character_manager", "move_range_system", "collision_visualization",
		"battle_ui", "skill_effects", "movement_coordinator", 
		"battle_flow_manager", "battle_input_handler", "battle_animation_manager",
		"battle_visual_effects_manager", "battle_combat_manager", "battle_ai_manager",
		"initial_level", "obstacle_manager", "gameplay_tips"
	]
	
	var missing_systems = []
	for system in expected_systems:
		if not _initialized_systems.get(system, false):
			missing_systems.append(system)
	
	if missing_systems.is_empty():
		print("✅ [BattleSystemInitializer] 所有系统初始化验证通过")
		return true
	else:
		print("❌ [BattleSystemInitializer] 以下系统初始化失败: %s" % str(missing_systems))
		return false

## 获取初始化状态报告
func get_initialization_report() -> Dictionary:
	return {
		"initialized_systems": _initialized_systems,
		"total_systems": _initialized_systems.size(),
		"is_complete": validate_initialization()
	} 
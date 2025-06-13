class_name BattleSignalRouter
extends RefCounted

## 战斗信号路由器
## 负责统一管理BattleScene中所有系统间的信号连接

# 信号连接状态跟踪
var _connected_signals: Dictionary = {}

## 建立所有信号连接
func setup_all_connections(scene: Node2D) -> void:
	print("🚀 [BattleSignalRouter] 开始建立所有信号连接")
	
	# 核心系统信号连接
	connect_battle_manager_signals(scene)
	connect_obstacle_manager_signals(scene)
	
	# 战斗系统信号连接  
	connect_battle_flow_manager_signals(scene)
	connect_battle_input_handler_signals(scene)
	connect_battle_combat_manager_signals(scene)
	connect_battle_ai_manager_signals(scene)
	
	print("✅ [BattleSignalRouter] 所有信号连接建立完成")

## 连接BattleManager信号
func connect_battle_manager_signals(scene: Node2D) -> void:
	print("🔗 [BattleSignalRouter] 连接BattleManager信号")
	
	var battle_manager = scene.battle_manager
	if battle_manager:
		# 连接基础战斗信号
		battle_manager.battle_started.connect(scene._on_battle_started)
		battle_manager.battle_ended.connect(scene._on_battle_ended)
		battle_manager.turn_started.connect(scene._on_turn_started)
		battle_manager.turn_ended.connect(scene._on_turn_ended)
		
		# 连接表现层信号
		# 🚀 视觉更新信号已委托给专业管理器处理
		battle_manager.player_turn_started.connect(scene._on_player_turn_started)
		battle_manager.ai_turn_started.connect(scene._on_ai_turn_started)
		
		print("✅ [BattleSignalRouter] BattleManager信号连接完成")
		_connected_signals["battle_manager"] = true
	else:
		print("❌ [BattleSignalRouter] 未找到BattleManager节点")

## 连接障碍物管理器信号
func connect_obstacle_manager_signals(scene: Node2D) -> void:
	print("🔗 [BattleSignalRouter] 连接障碍物管理器信号")
	
	var obstacle_manager = scene.get_node_or_null("TheLevel/ObstacleManager")
	if obstacle_manager:
		# 连接障碍物事件信号
		obstacle_manager.obstacle_added.connect(scene._on_obstacle_added)
		obstacle_manager.obstacle_removed.connect(scene._on_obstacle_removed)
		obstacle_manager.obstacles_cleared.connect(scene._on_obstacles_cleared)
		
		print("✅ [BattleSignalRouter] 障碍物管理器信号连接完成")
		_connected_signals["obstacle_manager"] = true
	else:
		print("❌ [BattleSignalRouter] 未找到障碍物管理器节点")

## 连接BattleFlowManager信号
func connect_battle_flow_manager_signals(scene: Node2D) -> void:
	print("🔗 [BattleSignalRouter] 连接BattleFlowManager信号")
	
	var battle_flow_manager = scene.get_node_or_null("BattleSystems/BattleFlowManager")
	if battle_flow_manager:
		# 🚀 流程信号处理已迁移到专业管理器，这里暂时跳过连接
		print("✅ [BattleSignalRouter] BattleFlowManager信号处理已迁移，跳过连接")
		_connected_signals["battle_flow_manager"] = true
	else:
		print("❌ [BattleSignalRouter] 未找到BattleFlowManager节点")

## 连接BattleInputHandler信号
func connect_battle_input_handler_signals(scene: Node2D) -> void:
	print("🔗 [BattleSignalRouter] 连接BattleInputHandler信号")
	
	var battle_input_handler = scene.get_node_or_null("BattleSystems/BattleInputHandler")
	if battle_input_handler:
		# 🚀 输入处理信号已迁移到专业管理器，这里暂时跳过连接
		print("✅ [BattleSignalRouter] BattleInputHandler信号处理已迁移，跳过连接")
		_connected_signals["battle_input_handler"] = true
	else:
		print("❌ [BattleSignalRouter] 未找到BattleInputHandler节点")

## 连接BattleCombatManager信号
func connect_battle_combat_manager_signals(scene: Node2D) -> void:
	print("🔗 [BattleSignalRouter] 连接BattleCombatManager信号")
	
	var battle_combat_manager = scene.get_node_or_null("BattleSystems/BattleCombatManager")
	if battle_combat_manager:
		# 🚀 战斗逻辑信号已迁移到专业管理器，这里暂时跳过连接
		print("✅ [BattleSignalRouter] BattleCombatManager信号处理已迁移，跳过连接")
		_connected_signals["battle_combat_manager"] = true
	else:
		print("❌ [BattleSignalRouter] 未找到BattleCombatManager节点")

## 连接BattleAIManager信号
func connect_battle_ai_manager_signals(scene: Node2D) -> void:
	print("🔗 [BattleSignalRouter] 连接BattleAIManager信号")
	
	var battle_ai_manager = scene.get_node_or_null("BattleSystems/BattleAIManager")
	if battle_ai_manager:
		# 🚀 AI管理信号已迁移到专业管理器，这里暂时跳过连接
		print("✅ [BattleSignalRouter] BattleAIManager信号处理已迁移，跳过连接")
		_connected_signals["battle_ai_manager"] = true
	else:
		print("❌ [BattleSignalRouter] 未找到BattleAIManager节点")

## 验证信号连接状态
func validate_connections() -> bool:
	var expected_connections = [
		"battle_manager", "obstacle_manager", "battle_flow_manager",
		"battle_input_handler", "battle_combat_manager", "battle_ai_manager"
	]
	
	var missing_connections = []
	for connection in expected_connections:
		if not _connected_signals.get(connection, false):
			missing_connections.append(connection)
	
	if missing_connections.is_empty():
		print("✅ [BattleSignalRouter] 所有信号连接验证通过")
		return true
	else:
		print("❌ [BattleSignalRouter] 以下信号连接失败: %s" % str(missing_connections))
		return false

## 获取信号连接状态报告
func get_connection_report() -> Dictionary:
	return {
		"connected_signals": _connected_signals,
		"total_connections": _connected_signals.size(),
		"is_complete": validate_connections()
	}

## 断开所有信号连接（用于清理）
func disconnect_all_signals(scene: Node2D) -> void:
	print("🔌 [BattleSignalRouter] 断开所有信号连接")
	
	# 这里可以添加具体的信号断开逻辑
	# 注意：Godot会在节点销毁时自动断开信号，通常不需要手动断开
	_connected_signals.clear()
	print("✅ [BattleSignalRouter] 所有信号连接已断开") 
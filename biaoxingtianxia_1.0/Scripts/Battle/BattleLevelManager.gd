class_name BattleLevelManager
extends Node

## BattleLevelManager - 战斗关卡管理器
##
## 职责：
## - 动态关卡加载和卸载
## - 关卡环境配置管理
## - 障碍物系统协调
## - 生成点管理优化

# 引用
var battle_scene: Node2D
var obstacle_manager: Node
var level_data: Dictionary = {}
var current_level_path: String = ""

# 关卡配置
var environment_config: Dictionary = {}
var spawn_points: Array[Vector2] = []
var level_boundaries: Rect2

# 初始化
func initialize(scene: Node2D) -> void:
	print("🗺️ [BattleLevelManager] 初始化关卡管理器")
	battle_scene = scene
	_setup_default_environment()

## 设置默认环境
func _setup_default_environment() -> void:
	# 默认关卡边界
	level_boundaries = Rect2(-500, -500, 1000, 1000)
	
	# 默认环境配置
	environment_config = {
		"lighting": {
			"ambient_color": Color.WHITE,
			"ambient_intensity": 0.8
		},
		"audio": {
			"background_music": "",
			"ambient_sounds": []
		},
		"effects": {
			"fog_enabled": false,
			"weather": "clear"
		}
	}

## 动态加载关卡（从BattleScene迁移）
func load_dynamic_level(level_path: String) -> void:
	print("🗺️ [BattleLevelManager] 开始动态加载关卡: %s" % level_path)
	current_level_path = level_path
	
	# 异步加载关卡数据
	if ResourceLoader.exists(level_path):
		var level_resource = load(level_path)
		if level_resource:
			_on_level_data_ready(level_resource)
		else:
			print("❌ [BattleLevelManager] 关卡资源加载失败: %s" % level_path)
	else:
		print("❌ [BattleLevelManager] 关卡文件不存在: %s" % level_path)

## 关卡数据准备完成（从BattleScene迁移）
func _on_level_data_ready(level_resource: Resource) -> void:
	print("🗺️ [BattleLevelManager] 关卡数据准备完成")
	
	# 解析关卡数据
	if level_resource is PackedScene:
		var level_scene = level_resource.instantiate()
		_parse_level_scene(level_scene)
		# 不要删除场景，它已经添加到场景树中了
	elif level_resource is Resource and level_resource.has_method("get_level_data"):
		level_data = level_resource.get_level_data()
		_parse_level_data()
	else:
		print("⚠️ [BattleLevelManager] 未知的关卡资源类型")

## 解析关卡场景
func _parse_level_scene(level_scene: Node) -> void:
	# 不要销毁场景，而是将其添加到BattleScene中
	level_scene.name = "TheLevel"  # 重命名为一致的名称
	battle_scene.add_child(level_scene)
	
	# 查找生成点 - 现在从已添加的场景中查找
	_find_and_process_spawn_points(level_scene)
	
	# 触发角色生成
	_trigger_character_spawn()
	
	print("🗺️ [BattleLevelManager] 关卡场景已添加到战斗场景")

## 查找并处理生成点
func _find_and_process_spawn_points(level_scene: Node) -> void:
	spawn_points.clear()
	
	# 查找玩家生成点
	var player_spawns = _find_spawn_points_by_path(level_scene, "GameplayLayers/CharacterSpawns/PlayerSpawns")
	var enemy_spawns = _find_spawn_points_by_path(level_scene, "GameplayLayers/CharacterSpawns/EnemySpawns")
	
	print("🗺️ [BattleLevelManager] 发现 %d 个玩家生成点" % player_spawns.size())
	print("🗺️ [BattleLevelManager] 发现 %d 个敌人生成点" % enemy_spawns.size())
	
	# 将所有生成点添加到列表
	for spawn in player_spawns:
		spawn_points.append(spawn)
	for spawn in enemy_spawns:
		spawn_points.append(spawn)
	
	print("🗺️ [BattleLevelManager] 总共发现 %d 个生成点" % spawn_points.size())

## 根据路径查找生成点
func _find_spawn_points_by_path(root: Node, path: String) -> Array:
	var spawn_container = root.get_node_or_null(path)
	if not spawn_container:
		print("⚠️ [BattleLevelManager] 未找到生成点容器: %s" % path)
		return []
	
	var spawns = []
	for child in spawn_container.get_children():
		if child is Marker2D and child.has_method("get_character_id"):
			spawns.append(child)
	
	return spawns

## 触发角色生成
func _trigger_character_spawn() -> void:
	print("🗺️ [BattleLevelManager] 开始触发角色生成")
	
	# 获取角色管理器 - 使用正确的路径
	var character_manager = battle_scene.get_character_manager()
	if not character_manager:
		print("❌ [BattleLevelManager] 未找到角色管理器")
		return
	
	print("✅ [BattleLevelManager] 找到角色管理器，开始加载角色")
	
	# 获取关卡配置并调用角色管理器加载
	print("🔍 [BattleLevelManager] 查找关卡配置节点...")
	var level_config = battle_scene.get_node_or_null("TheLevel/LevelConfiguration")
	if not level_config:
		# 尝试其他可能的路径
		var possible_paths = [
			"TheLevel/LevelData",
			"TheLevel/Configuration", 
			"LevelConfiguration",
			"Configuration"
		]
		for path in possible_paths:
			level_config = battle_scene.get_node_or_null(path)
			if level_config:
				print("✅ [BattleLevelManager] 在路径 %s 找到关卡配置" % path)
				break
		
		if not level_config:
			print("⚠️ [BattleLevelManager] 所有路径都找不到关卡配置节点")
	
	if level_config and character_manager.has_method("load_from_level_config"):
		await character_manager.load_from_level_config(level_config)
		print("🎯 [BattleLevelManager] 成功从关卡配置加载角色")
	elif character_manager.has_method("spawn_party_members"):
		# 备用方案：使用传统方式生成角色
		await character_manager.spawn_party_members()
		print("🎯 [BattleLevelManager] 使用传统方式生成玩家角色")
		
		# 同时生成敌方角色
		if character_manager.has_method("spawn_enemies"):
			await character_manager.spawn_enemies()
			print("🎯 [BattleLevelManager] 使用传统方式生成敌方角色")
		else:
			print("⚠️ [BattleLevelManager] 角色管理器没有spawn_enemies方法")
	else:
		print("⚠️ [BattleLevelManager] 角色管理器没有可用的加载方法")

## 解析关卡数据
func _parse_level_data() -> void:
	if level_data.has("spawn_points"):
		spawn_points = level_data.spawn_points
	
	if level_data.has("boundaries"):
		var bounds = level_data.boundaries
		level_boundaries = Rect2(bounds.x, bounds.y, bounds.width, bounds.height)
	
	if level_data.has("environment"):
		environment_config.merge(level_data.environment, true)
	
	print("🗺️ [BattleLevelManager] 关卡数据解析完成")

## 查找特定组的节点
func _find_nodes_by_group(root: Node, group_name: String) -> Array:
	var result = []
	_find_nodes_by_group_recursive(root, group_name, result)
	return result

func _find_nodes_by_group_recursive(node: Node, group_name: String, result: Array) -> void:
	if node.is_in_group(group_name):
		result.append(node)
	
	for child in node.get_children():
		_find_nodes_by_group_recursive(child, group_name, result)

## 设置关卡环境（从BattleScene迁移）
func setup_level_environment(config: Dictionary = {}) -> void:
	print("🗺️ [BattleLevelManager] 设置关卡环境")
	
	# 合并传入的配置
	if config.size() > 0:
		environment_config.merge(config, true)
	
	_configure_level_lighting()
	_setup_level_audio()
	_configure_level_effects()
	_setup_obstacle_manager()

## 配置关卡光照（从BattleScene迁移）
func _configure_level_lighting() -> void:
	if not environment_config.has("lighting"):
		return
	
	var lighting_config = environment_config.lighting
	print("🗺️ [BattleLevelManager] 配置关卡光照: 环境色 %s, 强度 %s" % [
		lighting_config.get("ambient_color", Color.WHITE),
		lighting_config.get("ambient_intensity", 0.8)
	])
	
	# 这里可以设置全局光照
	# RenderingServer.canvas_set_global_illumination...

## 设置关卡音效（从BattleScene迁移）
func _setup_level_audio() -> void:
	if not environment_config.has("audio"):
		return
	
	var audio_config = environment_config.audio
	print("🗺️ [BattleLevelManager] 设置关卡音效")
	
	# 播放背景音乐
	var bg_music = audio_config.get("background_music", "")
	if bg_music != "":
		_play_background_music(bg_music)
	
	# 播放环境音效
	var ambient_sounds = audio_config.get("ambient_sounds", [])
	for sound in ambient_sounds:
		_play_ambient_sound(sound)

## 播放背景音乐
func _play_background_music(music_path: String) -> void:
	print("🗺️ [BattleLevelManager] 播放背景音乐: %s" % music_path)
	# TODO: 实现背景音乐播放

## 播放环境音效
func _play_ambient_sound(sound_path: String) -> void:
	print("🗺️ [BattleLevelManager] 播放环境音效: %s" % sound_path)
	# TODO: 实现环境音效播放

## 配置关卡特效
func _configure_level_effects() -> void:
	if not environment_config.has("effects"):
		return
	
	var effects_config = environment_config.effects
	print("🗺️ [BattleLevelManager] 配置关卡特效")
	
	# 设置雾效
	var fog_enabled = effects_config.get("fog_enabled", false)
	if fog_enabled:
		_enable_fog_effect()
	
	# 设置天气
	var weather = effects_config.get("weather", "clear")
	_set_weather_effect(weather)

## 启用雾效
func _enable_fog_effect() -> void:
	print("🗺️ [BattleLevelManager] 启用雾效")
	# TODO: 实现雾效

## 设置天气效果
func _set_weather_effect(weather_type: String) -> void:
	print("🗺️ [BattleLevelManager] 设置天气: %s" % weather_type)
	# TODO: 实现天气效果

## 设置障碍物管理器（从BattleScene迁移）
func _setup_obstacle_manager() -> void:
	print("🗺️ [BattleLevelManager] 设置障碍物管理器")
	
	# 查找或创建障碍物管理器
	obstacle_manager = battle_scene.get_node_or_null("ObstacleManager")
	if not obstacle_manager:
		# 如果没有障碍物管理器，创建一个简单的
		obstacle_manager = Node2D.new()
		obstacle_manager.name = "ObstacleManager"
		battle_scene.add_child(obstacle_manager)
	
	_configure_obstacles()

## 配置障碍物
func _configure_obstacles() -> void:
	if not obstacle_manager:
		return
	
	print("🗺️ [BattleLevelManager] 配置障碍物")
	
	# 从关卡数据中加载障碍物
	if level_data.has("obstacles"):
		var obstacles_data = level_data.obstacles
		for obstacle_info in obstacles_data:
			_create_obstacle(obstacle_info)

## 创建障碍物
func _create_obstacle(obstacle_info: Dictionary) -> void:
	print("🗺️ [BattleLevelManager] 创建障碍物: %s" % obstacle_info)
	
	# 创建简单的障碍物节点
	var obstacle = StaticBody2D.new()
	obstacle.name = obstacle_info.get("name", "Obstacle")
	
	# 设置位置
	if obstacle_info.has("position"):
		var pos = obstacle_info.position
		obstacle.position = Vector2(pos.x, pos.y)
	
	# 设置碰撞形状
	if obstacle_info.has("collision_shape"):
		var collision_shape = CollisionShape2D.new()
		# TODO: 根据obstacle_info创建具体的形状
		obstacle.add_child(collision_shape)
	
	obstacle_manager.add_child(obstacle)

## 获取随机生成点
func get_random_spawn_point() -> Vector2:
	if spawn_points.size() == 0:
		print("⚠️ [BattleLevelManager] 没有可用的生成点，使用默认位置")
		return Vector2.ZERO
	
	var random_index = randi() % spawn_points.size()
	return spawn_points[random_index]

## 获取指定索引的生成点
func get_spawn_point(index: int) -> Vector2:
	if index < 0 or index >= spawn_points.size():
		print("⚠️ [BattleLevelManager] 生成点索引超出范围: %d" % index)
		return Vector2.ZERO
	
	return spawn_points[index]

## 获取所有生成点
func get_all_spawn_points() -> Array[Vector2]:
	return spawn_points

## 检查位置是否在关卡边界内
func is_position_in_bounds(position: Vector2) -> bool:
	return level_boundaries.has_point(position)

## 获取关卡边界
func get_level_boundaries() -> Rect2:
	return level_boundaries

## 设置关卡边界
func set_level_boundaries(boundaries: Rect2) -> void:
	level_boundaries = boundaries
	print("🗺️ [BattleLevelManager] 设置关卡边界: %s" % boundaries)

## 清理关卡
func cleanup_level() -> void:
	print("🗺️ [BattleLevelManager] 清理关卡")
	
	# 清理障碍物
	if obstacle_manager:
		for child in obstacle_manager.get_children():
			child.queue_free()
	
	# 重置数据
	level_data.clear()
	spawn_points.clear()
	current_level_path = ""
	
	# 恢复默认环境
	_setup_default_environment()

## 获取当前关卡路径
func get_current_level_path() -> String:
	return current_level_path

## 获取关卡数据
func get_level_data() -> Dictionary:
	return level_data.duplicate()

## 获取环境配置
func get_environment_config() -> Dictionary:
	return environment_config.duplicate()

## 添加生成点
func add_spawn_point(position: Vector2) -> void:
	spawn_points.append(position)
	print("🗺️ [BattleLevelManager] 添加生成点: %s" % position)

## 移除生成点
func remove_spawn_point(position: Vector2) -> bool:
	var index = spawn_points.find(position)
	if index != -1:
		spawn_points.remove_at(index)
		print("🗺️ [BattleLevelManager] 移除生成点: %s" % position)
		return true
	return false

## 获取障碍物管理器
func get_obstacle_manager() -> Node:
	return obstacle_manager 

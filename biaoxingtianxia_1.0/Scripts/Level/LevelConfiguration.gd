extends Node
class_name LevelConfiguration

# 关卡基础信息
@export var level_name: String = "序幕"
@export var level_id: String = "level_1"
@export var description: String = "游戏开始的序幕关卡"

# 角色配置
@export_group("角色配置")
@export var player_character_ids: Array = []  # 从CSV配置中动态加载
@export var enemy_configurations: Array = []  # 从CSV配置中动态生成

# 环境配置
@export_group("环境配置") 
@export var ground_height: float = 1000.0
@export var gravity_scale: float = 1.0
@export var ambient_light_color: Color = Color.WHITE

# 视觉配置
@export_group("视觉配置")
@export var background_music: AudioStream
@export var ambient_sound: AudioStream
@export var weather_effects: Array[String] = []

# 信号
signal level_data_ready(config: LevelConfiguration)

func _ready():
	print("🎮 [关卡配置] 初始化关卡配置: %s" % level_name)
	
	# 延迟一帧确保场景树完全构建
	await get_tree().process_frame
	
	# 从CSV配置文件加载角色配置
	await load_character_configuration_from_csv()
	
	# 初始化所有配置组件
	await initialize_config_components()
	
	# 验证配置数据
	if validate_configuration():
		print("✅ [关卡配置] 配置验证成功，发出ready信号")
		level_data_ready.emit(self)
	else:
		printerr("❌ [关卡配置] 配置验证失败: " + level_name)

## 从CSV配置文件加载角色配置
func load_character_configuration_from_csv():
	"""从DataManager的关卡配置CSV中加载角色ID"""
	print("🎯 [关卡配置] 开始从CSV加载角色配置，关卡ID: %s" % level_id)
	
	# 获取关卡配置数据
	var level_config_data = DataManager.get_level_configuration(level_id)
	
	if level_config_data.is_empty():
		printerr("⚠️ [关卡配置] 未找到关卡ID '%s' 的配置，使用默认配置" % level_id)
		# 使用默认配置作为回退
		player_character_ids = ["1", "2", "3"]
		_generate_default_enemy_configurations(["101", "102", "103"])
		return
	
	# 从CSV数据更新关卡信息
	level_name = level_config_data.get("level_name", level_name)
	description = level_config_data.get("description", description)
	
	# 更新角色配置
	player_character_ids = Array(level_config_data.get("player_character_ids", []))
	var enemy_character_ids = Array(level_config_data.get("enemy_character_ids", []))
	
	print("📋 [关卡配置] CSV配置加载完成:")
	print("  - 关卡名称: %s" % level_name)
	print("  - 玩家角色: %s" % str(player_character_ids))
	print("  - 敌人角色: %s" % str(enemy_character_ids))
	
	# 生成敌人配置
	_generate_enemy_configurations_from_ids(enemy_character_ids)

## 生成敌人配置
func _generate_enemy_configurations_from_ids(enemy_ids: Array):
	"""根据敌人角色ID列表生成EnemyConfig配置"""
	enemy_configurations.clear()
	
	for i in range(enemy_ids.size()):
		var enemy_id = enemy_ids[i]
		if not enemy_id.is_empty():
			var enemy_config = EnemyConfig.new(enemy_id, i, -1)  # spawn_index使用索引，level_override使用默认值
			enemy_configurations.append(enemy_config)
			print("✅ [关卡配置] 生成敌人配置: %s -> 生成点%d" % [enemy_id, i])

## 生成默认敌人配置（回退方案）
func _generate_default_enemy_configurations(enemy_ids: Array):
	"""生成默认敌人配置作为回退方案"""
	enemy_configurations.clear()
	
	for i in range(enemy_ids.size()):
		var enemy_id = enemy_ids[i]
		var enemy_config = EnemyConfig.new(enemy_id, i, -1)
		enemy_configurations.append(enemy_config)
		print("⚠️ [关卡配置] 使用默认敌人配置: %s -> 生成点%d" % [enemy_id, i])

## 初始化所有配置组件
func initialize_config_components():
	"""初始化和协调所有配置组件"""
	print("🔧 [关卡配置] 初始化配置组件")
	
	# 初始化环境设置
	var env_settings = get_environment_settings()
	if env_settings:
		# 根据关卡ID加载环境配置
		env_settings.load_from_level_config(level_id)
		# 应用环境设置（视差滚动、光照、天气等）
		env_settings.apply_environment_settings()
		print("✅ [关卡配置] 环境设置组件已初始化")
	
	# 初始化生成点设置（验证生成点配置）
	var spawn_settings = get_spawn_settings()
	if spawn_settings:
		var spawn_errors = spawn_settings.validate_spawn_configuration()
		if spawn_errors.size() > 0:
			for error in spawn_errors:
				printerr("⚠️ [关卡配置] 生成点配置警告: " + error)
		print("✅ [关卡配置] 生成点设置组件已初始化")
	
	# 初始化游戏玩法设置
	var gameplay_settings = get_gameplay_settings()
	if gameplay_settings:
		var gameplay_errors = gameplay_settings.validate_gameplay_settings()
		if gameplay_errors.size() > 0:
			for error in gameplay_errors:
				printerr("⚠️ [关卡配置] 游戏玩法配置警告: " + error)
		print("✅ [关卡配置] 游戏玩法设置组件已初始化")
	
	print("🎯 [关卡配置] 所有配置组件初始化完成")

func validate_configuration() -> bool:
	"""验证关卡配置是否有效"""
	if player_character_ids.is_empty():
		printerr("⚠️ [关卡配置] 玩家角色列表不能为空")
		return false
	
	if level_name.is_empty():
		printerr("⚠️ [关卡配置] 关卡名称不能为空")
		return false
	
	print("🔍 [关卡配置] 验证通过 - 玩家角色数量: %d, 敌人配置数量: %d" % [player_character_ids.size(), enemy_configurations.size()])
	return true

func get_player_spawn_points() -> Array[Vector2]:
	"""获取玩家角色生成点位置"""
	# 优先使用SpawnSettings配置
	var spawn_settings = get_spawn_settings()
	if spawn_settings and spawn_settings.has_method("get_player_spawn_points"):
		return spawn_settings.get_player_spawn_points()
	
	# 备用方案：直接从场景节点获取
	var spawns: Array[Vector2] = []
	var spawn_nodes = get_node_or_null("../../GameplayLayers/CharacterSpawns/PlayerSpawns")
	
	if spawn_nodes:
		print("🎯 [关卡配置] 找到玩家生成点容器，子节点数量: %d" % spawn_nodes.get_child_count())
		for child in spawn_nodes.get_children():
			if child is Marker2D:
				spawns.append(child.global_position)
				print("📍 [关卡配置] 玩家生成点: %s" % child.global_position)
	else:
		printerr("⚠️ [关卡配置] 未找到玩家生成点容器")
	
	return spawns

func get_enemy_spawn_points() -> Array[Vector2]:
	"""获取敌人角色生成点位置"""
	# 优先使用SpawnSettings配置
	var spawn_settings = get_spawn_settings()
	if spawn_settings and spawn_settings.has_method("get_enemy_spawn_points"):
		return spawn_settings.get_enemy_spawn_points()
	
	# 备用方案：直接从场景节点获取
	var spawns: Array[Vector2] = []
	var spawn_nodes = get_node_or_null("../../GameplayLayers/CharacterSpawns/EnemySpawns")
	
	if spawn_nodes:
		print("🎯 [关卡配置] 找到敌人生成点容器，子节点数量: %d" % spawn_nodes.get_child_count())
		for child in spawn_nodes.get_children():
			if child is Marker2D:
				spawns.append(child.global_position)
				print("📍 [关卡配置] 敌人生成点: %s" % child.global_position)
	else:
		printerr("⚠️ [关卡配置] 未找到敌人生成点容器")
	
	return spawns

## 获取环境设置组件
func get_environment_settings() -> EnvironmentSettings:
	"""获取环境设置配置组件"""
	return get_node_or_null("../EnvironmentSettings") as EnvironmentSettings

## 获取游戏玩法设置组件
func get_gameplay_settings() -> GameplaySettings:
	"""获取游戏玩法设置配置组件"""
	return get_node_or_null("../GameplaySettings") as GameplaySettings

## 获取生成点设置组件
func get_spawn_settings() -> SpawnSettings:
	"""获取生成点设置配置组件"""
	return get_node_or_null("../SpawnSettings") as SpawnSettings

func get_character_configuration_summary() -> String:
	"""获取角色配置摘要，用于调试"""
	var summary = "关卡: %s\n" % level_name
	summary += "玩家角色: %s\n" % str(player_character_ids)
	summary += "敌人数量: %d\n" % enemy_configurations.size()
	
	for i in range(enemy_configurations.size()):
		var enemy_config = enemy_configurations[i]
		if enemy_config:
			summary += "  敌人%d: ID=%s, 生成点=%d\n" % [i+1, enemy_config.enemy_id, enemy_config.spawn_index]
	
	return summary

func debug_print_configuration():
	"""调试打印配置信息"""
	print("🔧 [关卡配置] 配置详情:")
	print(get_character_configuration_summary())
	
	var player_spawns = get_player_spawn_points()
	var enemy_spawns = get_enemy_spawn_points()
	
	print("🎯 [关卡配置] 生成点信息:")
	print("  玩家生成点数量: %d" % player_spawns.size())
	print("  敌人生成点数量: %d" % enemy_spawns.size()) 

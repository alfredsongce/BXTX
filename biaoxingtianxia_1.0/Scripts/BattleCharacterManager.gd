# BattleCharacterManager.gd
# 战斗场景中的角色管理组件
# 负责角色的生成、查找、状态管理等功能

class_name BattleCharacterManager
extends Node

# 信号定义
signal character_spawned(character_id: String, character_node: Node2D)
signal character_death(dead_character: GameCharacter)
signal character_updated(character_id: String)

# 预加载资源
@onready var player_scene = preload("res://player.tscn")

# ========== 场景配置 ==========
# 🎯 角色场景路径现在从CharacterData.csv中的scene_path字段读取
# 不再使用硬编码的场景映射表

func get_character_scene_path(character_id: String) -> String:
	"""从角色CSV原始数据中获取场景路径"""
	# 直接从DataManager的原始数据存储中获取
	var character_storage = DataManager.get_data("character", "")  # 获取整个字典
	if character_storage and character_storage.has(character_id):
		var character_data = character_storage[character_id]
		if character_data and character_data.has("scene_path"):
			var scene_path = character_data.scene_path
			if scene_path and scene_path != "":
				print("🎬 [BattleCharacterManager] 找到角色 %s 的场景路径: %s" % [character_id, scene_path])
				return scene_path
		print("⚠️ [BattleCharacterManager] 角色 %s 的场景路径为空或未配置" % character_id)
	else:
		print("❌ [BattleCharacterManager] 无法获取角色 %s 的数据" % character_id)
	
	# 如果没有配置场景路径，返回空字符串，使用默认场景
	return ""

# 角色节点容器引用
@onready var players_container: Node = null
@onready var enemies_container: Node = null

# 角色节点存储
var party_member_nodes = {}
var enemy_nodes = {}

# 🆕 关卡配置相关
var current_level_config: LevelConfiguration
var level_spawned_characters: Dictionary = {}
var is_level_mode: bool = false  # 标记是否使用关卡配置模式

# 角色初始位置配置 - 使用BattleScene中的定义
const GROUND_LEVEL: float = 1000.0

# 死亡标记绘制类
class _DeathMarkerDrawer extends Node2D:
	func _draw():
		var size = 30.0
		var thickness = 4.0
		var color = Color.RED
		draw_line(Vector2(-size/2, -size/2), Vector2(size/2, size/2), color, thickness)
		draw_line(Vector2(size/2, -size/2), Vector2(-size/2, size/2), color, thickness)

func _ready():
	# 获取容器节点引用
	_setup_container_references()
	
	# 确保数据管理器已加载
	DataManager.load_data("character")
	
	# 只有在非关卡模式下才使用硬编码角色生成
	# 注意：现在角色初始化由Main场景负责，这里不再重复添加

func _setup_container_references():
	"""设置容器节点引用"""
	var parent = get_parent()
	if parent:
		players_container = parent.get_node_or_null("Players")
		enemies_container = parent.get_node_or_null("Enemies")
		
		if not players_container:
			print("⚠️ [BattleCharacterManager] 未找到Players容器")
		if not enemies_container:
			print("⚠️ [BattleCharacterManager] 未找到Enemies容器")

# ===========================================
# 🆕 关卡配置方法
# ===========================================

func load_from_level_config(level_config: LevelConfiguration):
	"""从关卡配置加载角色"""
	current_level_config = level_config
	is_level_mode = true
	
	print("🎮 [角色管理器] 从关卡配置加载角色")
	print("关卡名称: " + level_config.level_name)
	
	# 清除现有角色
	clear_existing_characters()
	
	# 加载玩家角色
	await load_player_characters()
	
	# 加载敌人角色
	await load_enemy_characters()
	
	print("✅ [角色管理器] 关卡角色加载完成")

func load_player_characters():
	"""从关卡配置加载玩家角色"""
	var spawn_points = current_level_config.get_player_spawn_points()
	var character_ids = current_level_config.player_character_ids
	
	print("🎯 [角色管理器] 开始加载玩家角色，角色数量: %d" % character_ids.size())
	print("📍 [角色管理器] 玩家生成点数量: %d" % spawn_points.size())
	
	for i in range(character_ids.size()):
		var character_id = character_ids[i]
		var spawn_position = spawn_points[i] if i < spawn_points.size() else _get_fallback_player_spawn_position()
		
		print("🎯 [角色管理器] 生成玩家角色: ID=%s, 位置=%s" % [character_id, spawn_position])
		
		# 使用新的通用角色生成方法
		var character_node = await create_character_node(character_id, true)
		if character_node:
			character_node.set_base_position(spawn_position)
			level_spawned_characters[character_id] = character_node
			
			# 也添加到原有的party_member_nodes中以保持兼容性
			party_member_nodes[character_id] = character_node

func load_enemy_characters():
	"""从关卡配置加载敌人角色"""
	var spawn_points = current_level_config.get_enemy_spawn_points()
	
	print("🤖 [角色管理器] 开始加载敌人角色，敌人数量: %d" % current_level_config.enemy_configurations.size())
	print("📍 [角色管理器] 敌人生成点数量: %d" % spawn_points.size())
	
	for enemy_config in current_level_config.enemy_configurations:
		if not enemy_config or not enemy_config.validate():
			printerr("❌ [角色管理器] 敌人配置无效，跳过")
			continue
			
		var spawn_position = spawn_points[enemy_config.spawn_index] if enemy_config.spawn_index < spawn_points.size() else _get_fallback_enemy_spawn_position()
		
		print("🎯 [角色管理器] 生成敌人角色: ID=%s, 位置=%s" % [enemy_config.enemy_id, spawn_position])
		
		var character_node = await create_character_node(enemy_config.enemy_id, false)
		if character_node:
			character_node.set_base_position(spawn_position)
			
			# 应用敌人特殊配置
			if enemy_config.level_override > 0:
				var character_data = character_node.get_character_data()
				if character_data:
					# 这里可以设置等级覆盖
					print("⚡ [角色管理器] 敌人 %s 应用等级覆盖: %d" % [enemy_config.enemy_id, enemy_config.level_override])
			
			level_spawned_characters[enemy_config.enemy_id] = character_node
			
			# 也添加到原有的enemy_nodes中以保持兼容性
			enemy_nodes[enemy_config.enemy_id] = character_node

func create_character_node(character_id: String, is_player: bool) -> Node:
	"""创建通用角色节点"""
	print("🔧 [角色管理器] 创建角色节点: ID=%s, 是否玩家=%s" % [character_id, is_player])
	
	var instance
	
	# 🎯 从角色数据中获取专属场景路径
	var character_scene_path = get_character_scene_path(character_id)
	print("🎬 [角色管理器] 使用专属场景: %s" % character_scene_path)
	var character_scene = load(character_scene_path)
	instance = character_scene.instantiate()

	
	# 添加到相应的容器
	if is_player:
		if players_container:
			players_container.add_child(instance)
		else:
			get_parent().add_child(instance)
	else:
		if enemies_container:
			enemies_container.add_child(instance)
		else:
			get_parent().add_child(instance)
	
	# 等待一帧确保内部变量初始化
	await get_tree().process_frame
	
	if is_player:
		# 玩家角色设置逻辑
		var char_data_node = instance.get_node("Data")
		if not char_data_node:
			printerr("❌ [角色管理器] 角色实例 %s 没有Data节点" % instance.name)
			instance.queue_free()
			return null
		
		print("📊 [角色管理器] 开始为角色ID %s 加载数据" % character_id)
		char_data_node.load_character_data(character_id)
		print("✅ [角色管理器] 角色ID %s 数据加载完成" % character_id)
		
		# 获取加载后的角色数据
		var character_data = char_data_node.get_character()
		
		# 确保玩家角色设置为玩家控制
		character_data.set_as_player()
		
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		print("⚡ [角色管理器] 角色 %s 轻功值(来自CSV): %d" % [character_data.name, character_data.qinggong_skill])
		
		# 设置初始高度 - 所有角色初始都在地面，飞行技能只影响是否能够飞行
		character_data.set_height(0.0)
		if character_data.has_passive_skill("御剑飞行"):
			print("✈️ [角色管理器] 角色 %s 拥有御剑飞行技能，但初始位置设置在地面" % character_data.name)
		else:
			print("🚶 [角色管理器] 角色 %s 没有飞行技能，设置在地面" % character_data.name)
		
		# 检查是否有角色专属缩放配置
		var scale_config = instance.get_node_or_null("CharacterScaleConfig")
		if scale_config:
			print("🎛️ [角色管理器] 发现角色 %s 的专属缩放配置，将应用场景设置" % character_data.name)
			# 角色有专属配置，会自动应用
		else:
			# 应用全局角色缩放
			if GameSettings:
				GameSettings.apply_character_scale(instance)
		
		# 连接信号
		_connect_character_signals(character_data, character_id)
		
		character_spawned.emit(character_id, instance)
		
		# 验证被动技能加载结果
		var passive_skills = character_data.get_passive_skills()
		var can_fly = character_data.has_passive_skill("御剑飞行")
		print("🎉 [角色管理器] 角色生成完成: %s (ID: %s)" % [character_data.name, character_id])
		print("🔮 [角色管理器] 角色 %s 被动技能: %s" % [character_data.name, passive_skills])
		print("✈️ [角色管理器] 角色 %s 飞行能力: %s" % [character_data.name, "可以飞行" if can_fly else "不能飞行"])
	
	else:
		# 敌人角色设置逻辑
		var character_data_script = instance.get_character_data()
		if not character_data_script:
			printerr("❌ [角色管理器] 敌方角色实例 %s 没有get_character_data方法或返回null" % instance.name)
			instance.queue_free()
			return null
		
		character_data_script.load_from_id(character_id)
		character_data_script.set_as_enemy()
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		
		# 设置敌人外观
		_setup_enemy_appearance(instance, character_id)
		
		# 检查是否有敌人专属缩放配置
		var scale_config = instance.get_node_or_null("CharacterScaleConfig")
		if scale_config:
			print("🎛️ [角色管理器] 发现敌人 %s 的专属缩放配置，将应用场景设置" % character_data_script.name)
			# 角色有专属配置，会自动应用
		else:
			# 应用全局角色缩放
			if GameSettings:
				GameSettings.apply_character_scale(instance)
		
		# 连接信号
		_connect_enemy_signals(character_data_script, character_id)
		
		character_spawned.emit(character_id, instance)
		print("✅ [角色管理器] 生成敌人: %s (ID: %s)" % [character_data_script.name, character_id])
	
	return instance

func clear_existing_characters():
	"""清除现有的角色"""
	print("🧹 [角色管理器] 清除现有角色")
	
	# 清除现有的硬编码角色
	for child in party_member_nodes.values():
		if child and is_instance_valid(child):
			child.queue_free()
	for child in enemy_nodes.values():
		if child and is_instance_valid(child):
			child.queue_free()
			
	party_member_nodes.clear()
	enemy_nodes.clear()
	level_spawned_characters.clear()

# ===========================================
# 角色生成方法
# ===========================================

func spawn_party_members() -> void:
	"""生成队伍成员"""
	print("👥 [BattleCharacterManager] 开始生成队伍成员")
	print("🔍 [BattleCharacterManager] PartyManager状态检查:")
	print("  - PartyManager存在: %s" % str(PartyManager != null))
	if PartyManager:
		print("  - PartyManager成员数量: %d" % PartyManager.get_member_count())
		print("  - PartyManager成员ID列表: %s" % str(PartyManager.get_all_members()))
		# 详细调试PartyManager内部状态
		if PartyManager.current_party:
			print("  - current_party存在: true")
			print("  - current_party成员数量: %d" % PartyManager.current_party.get_current_size())
		else:
			print("  - current_party为null!")
		# 调用PartyManager的调试方法
		PartyManager.debug_print_party()
	print("📋 [BattleCharacterManager] 队伍成员ID列表: %s" % [PartyManager.get_all_members()])
	
	# 获取角色ID列表，如果PartyManager为空则使用默认列表
	var character_ids = PartyManager.get_all_members()
	if character_ids.is_empty():
		print("⚠️ [BattleCharacterManager] PartyManager为空，使用默认角色列表")
		character_ids = ["1", "2", "3"]  # 默认角色ID
	
	for character_id in character_ids:
		print("🎯 [BattleCharacterManager] 开始生成角色ID: %s" % character_id)
		
		# 🎯 从角色数据中获取专属场景路径
		var character_scene_path = get_character_scene_path(character_id)
		var instance
		print("🎬 [BattleCharacterManager] 使用专属场景: %s" % character_scene_path)
		var character_scene = load(character_scene_path)
		instance = character_scene.instantiate()

		
		if players_container:
			players_container.add_child(instance)
		else:
			get_parent().add_child(instance)
		
		# 等待一帧确保内部变量初始化
		await get_tree().process_frame
		
		# 从PartyManager获取角色数据并设置
		var character = PartyManager.get_member(character_id)
		var char_data_node = instance.get_node("Data")
		if not char_data_node:
			printerr("❌ [BattleCharacterManager] 角色实例 %s 没有Data节点" % instance.name)
			instance.queue_free()
			continue
		
		print("📊 [BattleCharacterManager] 开始为角色ID %s 加载数据" % character_id)
		char_data_node.load_character_data(character_id)
		print("✅ [BattleCharacterManager] 角色ID %s 数据加载完成" % character_id)
		
		# 获取加载后的角色数据
		var character_data = char_data_node.get_character()
		
		# 🚀 确保玩家角色设置为玩家控制
		character_data.set_as_player()
		
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		print("⚡ [BattleCharacterManager] 角色 %s 轻功值(来自CSV): %d" % [character_data.name, character_data.qinggong_skill])
		
		# 设置位置 - 使用BattleScene中的SPAWN_POSITIONS
		var battle_scene = AutoLoad.get_battle_scene()
		if battle_scene and battle_scene.SPAWN_POSITIONS.has(character_id):
			instance.set_base_position(battle_scene.SPAWN_POSITIONS[character_id])
		else:
			instance.set_base_position(Vector2(300, 200))
		
		# 设置初始高度 - 所有角色初始都在地面，飞行技能只影响是否能够飞行
		character_data.set_height(0.0)
		if character_data.has_passive_skill("御剑飞行"):
			print("✈️ [BattleCharacterManager] 角色 %s 拥有御剑飞行技能，但初始位置设置在地面" % character_data.name)
		else:
			print("🚶 [BattleCharacterManager] 角色 %s 没有飞行技能，设置在地面" % character_data.name)
		
		# 检查是否有角色专属缩放配置
		var scale_config = instance.get_node_or_null("CharacterScaleConfig")
		if scale_config:
			print("🎛️ [BattleCharacterManager] 发现角色 %s 的专属缩放配置，将应用场景设置" % character_data.name)
			# 角色有专属配置，会自动应用
		else:
			# 应用全局角色缩放
			if GameSettings:
				GameSettings.apply_character_scale(instance)
		
		# 连接信号
		_connect_character_signals(character_data, character_id)
		
		party_member_nodes[character_id] = instance
		character_spawned.emit(character_id, instance)
		
		# 🔍 验证被动技能加载结果
		var passive_skills = character_data.get_passive_skills()
		var can_fly = character_data.has_passive_skill("御剑飞行")
		print("🎉 [BattleCharacterManager] 角色生成完成: %s (ID: %s)" % [character_data.name, character_id])
		print("🔮 [BattleCharacterManager] 角色 %s 被动技能: %s" % [character_data.name, passive_skills])
		print("✈️ [BattleCharacterManager] 角色 %s 飞行能力: %s" % [character_data.name, "可以飞行" if can_fly else "不能飞行"])
		print("=".repeat(50))

func spawn_enemies() -> void:
	"""生成敌人"""
	print("🤖 [BattleCharacterManager] 开始生成敌人")
	
	# 从关卡配置获取敌人ID列表
	var enemy_ids = _get_enemy_ids_from_level_config()
	
	if enemy_ids.is_empty():
		printerr("⚠️ [BattleCharacterManager] 无法获取敌人ID列表，使用默认配置")
		enemy_ids = ["101", "102", "103"]  # 回退方案
	
	for enemy_id in enemy_ids:
		# 🎯 从角色数据中获取敌人专属场景路径
		var enemy_scene_path = get_character_scene_path(enemy_id)
		var instance
		
		print("🎬 [BattleCharacterManager] 使用敌人专属场景: %s" % enemy_scene_path)
		var enemy_scene = load(enemy_scene_path)
		instance = enemy_scene.instantiate()

		
		if enemies_container:
			enemies_container.add_child(instance)
		else:
			get_parent().add_child(instance)
		
		# 等待一帧确保实例内部变量初始化完成
		await get_tree().process_frame
		
		var character_data_script = instance.get_character_data()
		if not character_data_script:
			print("❌ [BattleCharacterManager] 敌方角色实例 %s 没有get_character_data方法或返回null" % instance.name)
			instance.queue_free()
			continue
		
		character_data_script.load_from_id(enemy_id)
		character_data_script.set_as_enemy()
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		
		# 设置位置 - 使用BattleScene中的ENEMY_SPAWN_POSITIONS
		var battle_scene = AutoLoad.get_battle_scene()
		if battle_scene and battle_scene.ENEMY_SPAWN_POSITIONS.has(enemy_id):
			var spawn_pos = battle_scene.ENEMY_SPAWN_POSITIONS[enemy_id]
			character_data_script.ground_position = spawn_pos
			character_data_script.position = spawn_pos
			instance.set_base_position(spawn_pos)
		else:
			var default_pos = Vector2(1000, 1000)
			character_data_script.ground_position = default_pos
			character_data_script.position = default_pos
			instance.set_base_position(default_pos)
		
		# 设置敌人外观
		_setup_enemy_appearance(instance, enemy_id)
		
		# 检查是否有角色专属缩放配置
		var scale_config = instance.get_node_or_null("CharacterScaleConfig")
		if scale_config:
			print("🎛️ [BattleCharacterManager] 发现敌人 %s 的专属缩放配置，将应用场景设置" % character_data_script.name)
			# 角色有专属配置，会自动应用
		else:
			# 应用全局角色缩放
			if GameSettings:
				GameSettings.apply_character_scale(instance)
		
		# 连接信号
		_connect_enemy_signals(character_data_script, enemy_id)
		
		enemy_nodes[enemy_id] = instance
		character_spawned.emit(enemy_id, instance)
		print("✅ [BattleCharacterManager] 生成敌人: %s (ID: %s)" % [character_data_script.name, enemy_id])

func _setup_enemy_appearance(enemy_instance: Node2D, enemy_id: String) -> void:
	"""设置敌人外观"""
	var sprite = enemy_instance.get_node_or_null("Graphic/Sprite2D")
	if sprite:
		sprite.modulate = Color.RED

func _connect_character_signals(character: GameCharacter, character_id: String) -> void:
	"""连接角色信号"""
	if character.has_signal("stats_changed"):
		character.stats_changed.connect(_on_character_updated.bind(character_id))
	else:
		print("⚠️ [BattleCharacterManager] 角色 %s 没有stats_changed信号" % character.name)
	
	if character.has_signal("health_depleted"):
		character.health_depleted.connect(_on_character_death.bind(character))
	else:
		print("⚠️ [BattleCharacterManager] 角色 %s 没有health_depleted信号" % character.name)

func _connect_enemy_signals(character_data: GameCharacter, enemy_id: String) -> void:
	"""连接敌人信号"""
	if character_data.has_signal("stats_changed"):
		character_data.stats_changed.connect(_on_enemy_updated.bind(enemy_id))
	else:
		print("⚠️ [BattleCharacterManager] 敌人 %s 没有stats_changed信号" % character_data.name)
	
	if character_data.has_signal("health_depleted"):
		character_data.health_depleted.connect(_on_character_death.bind(character_data))
		print("✅ [BattleCharacterManager] 敌人 %s 死亡信号连接成功" % character_data.name)
	else:
		print("⚠️ [BattleCharacterManager] 敌人 %s 没有health_depleted信号" % character_data.name)

# ===========================================
# 配置管理方法
# ===========================================

func _get_enemy_ids_from_level_config() -> Array:
	"""从关卡配置获取敌人ID列表"""
	print("🎯 [BattleCharacterManager] 从关卡配置获取敌人ID")
	
	# 尝试从LevelConfiguration获取
	var level_config = get_node_or_null("../LevelConfiguration")
	if level_config and level_config.has_method("get_character_configuration_summary"):
		if level_config.enemy_configurations.size() > 0:
			var enemy_ids: Array[String] = []
			for enemy_config in level_config.enemy_configurations:
				if enemy_config and enemy_config.enemy_id:
					enemy_ids.append(enemy_config.enemy_id)
			print("✅ [BattleCharacterManager] 从LevelConfiguration获取敌人ID: %s" % str(enemy_ids))
			return enemy_ids
	
	# 回退：从DataManager获取关卡配置
	var level_config_data = DataManager.get_level_configuration("level_1")
	if not level_config_data.is_empty():
		var enemy_ids = level_config_data.get("enemy_character_ids", [])
		print("✅ [BattleCharacterManager] 从DataManager获取敌人ID: %s" % str(enemy_ids))
		return enemy_ids
	
	printerr("⚠️ [BattleCharacterManager] 无法从任何来源获取敌人ID配置")
	return []

## 获取回退的玩家生成位置
func _get_fallback_player_spawn_position() -> Vector2:
	"""当无法从配置获取生成点时的回退位置"""
	print("⚠️ [BattleCharacterManager] 使用玩家回退生成位置")
	return Vector2(600, 1000)

## 获取回退的敌人生成位置  
func _get_fallback_enemy_spawn_position() -> Vector2:
	"""当无法从配置获取生成点时的回退位置"""
	print("⚠️ [BattleCharacterManager] 使用敌人回退生成位置")
	return Vector2(1000, 1000)

# ===========================================
# 角色查找和管理方法
# ===========================================

func get_all_characters() -> Array:
	"""获取所有角色数据"""
	var all_characters = []
	
	# 添加队友
	for character_id in party_member_nodes:
		var node = party_member_nodes[character_id]
		if node and node.has_method("get_character_data"):
			var character_data = node.get_character_data()
			if character_data:
				all_characters.append(character_data)
	
	# 添加敌人
	for enemy_id in enemy_nodes:
		var node = enemy_nodes[enemy_id]
		if node and node.has_method("get_character_data"):
			var character_data = node.get_character_data()
			if character_data:
				all_characters.append(character_data)
	
	return all_characters

func get_party_members() -> Array:
	"""获取队友角色列表"""
	var party_members_data = []
	for character_id in party_member_nodes:
		var node = party_member_nodes[character_id]
		if node and node.has_method("get_character_data"):
			var character_data = node.get_character_data()
			if character_data:
				party_members_data.append(character_data)
	return party_members_data

func get_enemies() -> Array:
	"""获取敌人角色列表"""
	var enemies_data = []
	for enemy_id in enemy_nodes:
		var node = enemy_nodes[enemy_id]
		if node and node.has_method("get_character_data"):
			var character_data = node.get_character_data()
			if character_data:
				enemies_data.append(character_data)
	return enemies_data

func get_character_node_by_data(character_data: GameCharacter) -> Node2D:
	"""通过角色数据查找对应的角色节点"""
	if not character_data:
		print("⚠️ [查找节点] 角色数据为空")
		return null
	
	# 先在队友节点中查找
	for character_id in party_member_nodes:
		var character_node = party_member_nodes[character_id]
		if character_node and character_node.has_method("get_character_data"):
			var node_character_data = character_node.get_character_data()
			if node_character_data == character_data:
				return character_node
	
	# 在敌人节点中查找
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node and enemy_node.has_method("get_character_data"):
			var node_character_data = enemy_node.get_character_data()
			if node_character_data == character_data:
				print("✅ [查找节点] 在敌人节点中找到: %s" % character_data.name)
				return enemy_node
	
	print("❌ [查找节点] 未找到角色节点: %s" % character_data.name)
	return null

func find_character_node_by_id(character_id: String) -> Node2D:
	"""通过ID查找角色节点"""
	if party_member_nodes.has(character_id):
		return party_member_nodes[character_id]
	
	if enemy_nodes.has(character_id):
		return enemy_nodes[character_id]
	
	return null

func get_character_at_mouse_position(mouse_pos: Vector2) -> GameCharacter:
	"""获取鼠标位置的角色"""
	var closest_character: GameCharacter = null
	var closest_distance = 50.0  # 检测范围
	
	for character_data in get_all_characters():
		var character_node = get_character_node_by_data(character_data)
		if character_node:
			var distance = mouse_pos.distance_to(character_node.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_character = character_data
	
	return closest_character

# ===========================================
# 角色状态管理方法
# ===========================================

func handle_character_death(dead_character: GameCharacter) -> void:
	"""处理角色死亡"""
	var character_node = get_character_node_by_data(dead_character)
	if character_node:
		character_node.modulate = Color(0.3, 0.3, 0.3, 0.6)
		print("💀 [BattleCharacterManager] %s 已阵亡，应用死亡视觉效果" % dead_character.name)
		_add_death_marker(character_node)
	else:
		print("⚠️ [BattleCharacterManager] 无法找到 %s 对应的角色节点" % dead_character.name)

func _add_death_marker(character_node: Node2D) -> void:
	"""添加死亡标记"""
	if character_node.get_node_or_null("DeathMarker"):
		return
	
	var death_marker = Node2D.new()
	death_marker.name = "DeathMarker"
	death_marker.z_index = 10
	
	var x_drawer = Node2D.new()
	x_drawer.name = "XDrawer"
	death_marker.add_child(x_drawer)
	
	var x_shape = _DeathMarkerDrawer.new()
	x_drawer.add_child(x_shape)
	
	character_node.add_child(death_marker)
	print("💀 [BattleCharacterManager] 为 %s 添加死亡标记" % character_node.name)

func check_and_fix_character_heights() -> void:
	"""检查并修正角色高度"""
	print("===== 检查所有角色高度 =====")
	var all_chars = get_all_characters()
	if all_chars.is_empty():
		print("队伍中没有角色。")
		print("===== 高度检查完成 =====")
		return
	
	for character_data_obj in all_chars:
		if not character_data_obj is GameCharacter:
			continue
		var qinggong_level = int(character_data_obj.qinggong_skill / 40)
		var height_level = character_data_obj.get_height_level()
		print("角色[%s] - 当前高度: %d, 轻功等级上限: %d" % [character_data_obj.id, height_level, qinggong_level])
		if height_level > qinggong_level:
			print("修正角色[%s]高度 %d -> %d (轻功限制)" % [character_data_obj.id, height_level, qinggong_level])
			character_data_obj.set_height(qinggong_level)
	print("===== 高度检查完成 =====")

# ===========================================
# 信号回调方法
# ===========================================

func _on_character_updated(character_id: String) -> void:
	"""角色更新回调"""
	character_updated.emit(character_id)

func _on_enemy_updated(enemy_id: String) -> void:
	"""敌人更新回调"""
	character_updated.emit(enemy_id)

func _on_character_death(dead_character: GameCharacter) -> void:
	"""角色死亡回调"""
	if dead_character:
		print("💀 [BattleCharacterManager] 角色死亡: %s" % dead_character.name)
		handle_character_death(dead_character)
		character_death.emit(dead_character)
	else:
		print("💀 [BattleCharacterManager] 收到角色死亡信号，但角色数据为空")

# ===========================================
# 调试和工具方法
# ===========================================

func get_survival_stats() -> Dictionary:
	"""获取存活统计信息"""
	var alive_players = 0
	var alive_enemies = 0
	var dead_players = []
	var dead_enemies = []
	
	# 检查队友存活情况
	for character_id in party_member_nodes:
		var character_node = party_member_nodes[character_id]
		if character_node:
			var character_data = character_node.get_character_data()
			if character_data:
				if character_data.is_alive():
					alive_players += 1
				else:
					dead_players.append(character_data.name)
	
	# 检查敌人存活情况
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node:
			var enemy_data = enemy_node.get_character_data()
			if enemy_data:
				if enemy_data.is_alive():
					alive_enemies += 1
				else:
					dead_enemies.append(enemy_data.name)
	
	return {
		"alive_players": alive_players,
		"alive_enemies": alive_enemies,
		"dead_players": dead_players,
		"dead_enemies": dead_enemies
	}

# ===========================================
# 调试和工具方法
# ===========================================

func get_enemy_nodes() -> Dictionary:
	"""获取敌人节点字典"""
	return enemy_nodes

func get_party_member_nodes() -> Dictionary:
	"""获取队友节点字典"""
	return party_member_nodes

func print_party_stats() -> void:
	"""打印队伍状态"""
	print("===== 队伍状态报告 =====")
	var all_chars = get_all_characters()
	if all_chars.is_empty():
		print("队伍中没有角色。")
		print("===== 报告结束 =====")
		return
	
	for character_data_obj in all_chars:
		if not character_data_obj is GameCharacter:
			print("发现非GameCharacter对象，跳过。")
			continue
		print("角色ID: %s, 名称: %s, 等级: %d, HP: %d/%d" % [character_data_obj.id, character_data_obj.name, character_data_obj.level, character_data_obj.current_hp, character_data_obj.max_hp])
		print("---------------------")
	print("===== 报告结束 =====")

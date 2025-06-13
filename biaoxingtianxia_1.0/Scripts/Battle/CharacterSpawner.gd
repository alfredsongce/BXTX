# CharacterSpawner.gd - 角色生成器
# 职责：生成队伍成员和敌人
extends Node

# 信号
signal character_spawned(character_node: Node2D, character_id: String, is_enemy: bool)
signal all_characters_spawned()

# 常量配置
const GROUND_LEVEL: float = 1000.0

# 位置配置使用BattleScene中的定义

# 预加载资源
@onready var player_scene = preload("res://player.tscn")

# 引用容器节点
var players_container: Node
var enemies_container: Node
var game_party: GameParty

# 保存角色节点引用
var party_member_nodes = {}
var enemy_nodes = {}

func _ready():
	print("📦 [角色生成器] 初始化...")
	
	# 获取容器节点引用
	var battle_scene = AutoLoad.get_battle_scene()
	players_container = battle_scene.get_node("Players")
	enemies_container = battle_scene.get_node("Enemies")
	
	# 初始化GameParty
	game_party = GameParty.new()

# 生成所有角色
func spawn_all_characters():
	print("🚀 [角色生成器] 开始生成所有角色...")
	
	# 确保数据管理器已加载
	DataManager.load_data("character")
	
	# 创建队伍
	game_party.add_member("1")
	game_party.add_member("2") 
	game_party.add_member("3")
	
	# 生成队伍成员
	_spawn_party_members()
	
	# 生成敌人
	_spawn_enemies()
	
	# 发出完成信号
	all_characters_spawned.emit()
	print("✅ [角色生成器] 所有角色生成完成")

# 生成队伍成员
func _spawn_party_members():
	print("👥 [角色生成器] 生成队伍成员...")
	
	for character_id in game_party.get_member_ids():
		# 创建角色实例
		var instance = player_scene.instantiate()
		players_container.add_child(instance)
		
		# 从GameParty获取角色数据并设置
		var character = game_party.get_member(character_id)
		instance.get_character_data().load_from_id(character_id)
		
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		# instance.get_character_data()中的qinggong_skill已经从CSV数据中正确加载
		
		# 设置位置 - 使用BattleScene中的SPAWN_POSITIONS
		var battle_scene = AutoLoad.get_battle_scene()
		if battle_scene and battle_scene.SPAWN_POSITIONS.has(character_id):
			var spawn_pos = battle_scene.SPAWN_POSITIONS[character_id]
			instance.set_base_position(spawn_pos)
		else:
			instance.set_base_position(Vector2(300, 200))
		
		# 保存角色节点引用
		party_member_nodes[character_id] = instance
		
		# 发出角色生成信号
		character_spawned.emit(instance, character_id, false)
		print("👤 [角色生成器] 队伍成员生成: %s" % character_id)

# 生成敌人
func _spawn_enemies():
	print("👹 [角色生成器] 生成敌人...")
	
	# 从关卡配置获取敌人ID列表
	var enemy_ids = _get_enemy_ids_from_level_config()
	
	if enemy_ids.is_empty():
		printerr("⚠️ [角色生成器] 无法获取敌人ID列表，使用默认配置")
		enemy_ids = ["101", "102", "103"]  # 回退方案
	
	for enemy_id in enemy_ids:
		# 创建敌人实例
		var instance = player_scene.instantiate()
		enemies_container.add_child(instance)
		
		# 加载敌人数据
		var character_data = instance.get_character_data()
		character_data.load_from_id(enemy_id)
		
		# 设置为敌人控制类型
		character_data.set_as_enemy()
		
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		
		# 设置敌人位置 - 使用BattleScene中的ENEMY_SPAWN_POSITIONS
		var battle_scene = AutoLoad.get_battle_scene()
		if battle_scene and battle_scene.ENEMY_SPAWN_POSITIONS.has(enemy_id):
			var spawn_pos = battle_scene.ENEMY_SPAWN_POSITIONS[enemy_id]
			character_data.ground_position = spawn_pos
			character_data.position = spawn_pos
			instance.set_base_position(spawn_pos)
		else:
			var default_pos = Vector2(1000, GROUND_LEVEL)
			character_data.ground_position = default_pos
			character_data.position = default_pos
			instance.set_base_position(default_pos)
		
		# 设置敌人外观
		_setup_enemy_appearance(instance, enemy_id)
		
		# 保存敌人节点引用
		enemy_nodes[enemy_id] = instance
		
		# 发出角色生成信号
		character_spawned.emit(instance, enemy_id, true)
		print("👹 [角色生成器] 敌人生成: %s" % enemy_id)

# 设置敌人外观
func _setup_enemy_appearance(enemy_instance: Node2D, enemy_id: String):
	# 简单的视觉区分：改变敌人颜色
	var sprite = enemy_instance.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color.RED  # 敌人显示为红色

# ===========================================
# 配置管理方法
# ===========================================

func _get_enemy_ids_from_level_config() -> Array:
	"""从关卡配置获取敌人ID列表"""
	print("🎯 [角色生成器] 从关卡配置获取敌人ID")
	
	# 从DataManager获取关卡配置
	var level_config_data = DataManager.get_level_configuration("level_1")
	if not level_config_data.is_empty():
		var enemy_ids = level_config_data.get("enemy_character_ids", [])
		print("✅ [角色生成器] 从DataManager获取敌人ID: %s" % str(enemy_ids))
		return enemy_ids
	
	printerr("⚠️ [角色生成器] 无法从任何来源获取敌人ID配置")
	return []

# 获取角色节点引用
func get_party_member_nodes() -> Dictionary:
	return party_member_nodes

func get_enemy_nodes() -> Dictionary:
	return enemy_nodes

# 🚀 根据角色ID查找角色节点
func find_character_node_by_id(character_id: String) -> Node2D:
	# 先在队伍成员中查找
	if party_member_nodes.has(character_id):
		return party_member_nodes[character_id]
	
	# 再在敌人中查找
	if enemy_nodes.has(character_id):
		return enemy_nodes[character_id]
	
	print("⚠️ [角色生成器] 未找到角色节点: %s" % character_id)
	return null

# 🚀 根据角色数据查找角色节点
func find_character_node_by_data(character_data: GameCharacter) -> Node2D:
	if not character_data:
		print("⚠️ [角色生成器] 角色数据为空")
		return null
	
	return find_character_node_by_id(character_data.id)
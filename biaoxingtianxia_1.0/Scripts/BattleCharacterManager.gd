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
@onready var game_party = GameParty.new()

# 角色节点容器引用
@onready var players_container: Node = null
@onready var enemies_container: Node = null

# 角色节点存储
var party_member_nodes = {}
var enemy_nodes = {}

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
	
	# 通过GameParty创建角色
	game_party.add_member("1")
	game_party.add_member("2")
	game_party.add_member("3")

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
# 角色生成方法
# ===========================================

func spawn_party_members() -> void:
	"""生成队伍成员"""
	print("👥 [BattleCharacterManager] 开始生成队伍成员")
	print("📋 [BattleCharacterManager] 队伍成员ID列表: %s" % [game_party.get_member_ids()])
	
	for character_id in game_party.get_member_ids():
		print("🎯 [BattleCharacterManager] 开始生成角色ID: %s" % character_id)
		
		var instance = player_scene.instantiate()
		
		if players_container:
			players_container.add_child(instance)
		else:
			get_parent().add_child(instance)
		
		# 等待一帧确保内部变量初始化
		await get_tree().process_frame
		
		# 从GameParty获取角色数据并设置
		var character = game_party.get_member(character_id)
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
		
		# 设置轻功值
		if character_id == "3":
			character_data.qinggong_skill = 120
		else:
			character_data.qinggong_skill = 280
		print("⚡ [BattleCharacterManager] 角色 %s 轻功值设置为: %d" % [character_data.name, character_data.qinggong_skill])
		
		# 设置位置 - 使用BattleScene中的SPAWN_POSITIONS
		var battle_scene = AutoLoad.get_battle_scene()
		if battle_scene and battle_scene.SPAWN_POSITIONS.has(character_id):
			instance.set_base_position(battle_scene.SPAWN_POSITIONS[character_id])
		else:
			instance.set_base_position(Vector2(300, 200))
		
		# 设置初始高度
		if character_id == "1":
			character_data.set_height(3.5)
		elif character_id == "2":
			character_data.set_height(2.5)
		
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
	var enemy_ids = ["101", "102", "103"]
	
	for enemy_id in enemy_ids:
		var instance = player_scene.instantiate()
		
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
		character_data_script.qinggong_skill = 400
		
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

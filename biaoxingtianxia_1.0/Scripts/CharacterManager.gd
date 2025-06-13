# CharacterManager.gd - 角色管理器 (保守模式)
extends Node2D

# 预加载资源
@onready var player_scene = preload("res://player.tscn")

# 🚀 game_party由CharacterManager自己管理
var game_party: GameParty = GameParty.new() # 直接在这里初始化
var party_member_nodes = {}
var enemy_nodes = {}

# 容器节点引用
@onready var players_container: Node = null
@onready var enemies_container: Node = null

const GROUND_LEVEL: float = 1000.0

# 角色初始生成位置（Y坐标将根据GroundAnchor动态调整）
const SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(200, GROUND_LEVEL),
	Vector2(300, GROUND_LEVEL),
	Vector2(400, GROUND_LEVEL),
	Vector2(500, GROUND_LEVEL)
]

# 敌人初始生成位置（Y坐标将根据GroundAnchor动态调整）
const ENEMY_SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(1600, GROUND_LEVEL),
	Vector2(1500, GROUND_LEVEL),
	Vector2(1400, GROUND_LEVEL),
	Vector2(1300, GROUND_LEVEL)
]

# 信号
signal character_spawned(character_id: String, character_node: Node2D)
signal character_death(character: GameCharacter)

func _ready():
	print("✅ [CharacterManager] 角色管理器初始化开始")
	
	# 获取容器节点引用
	players_container = get_node_or_null("../Players") # 使用get_node_or_null更安全
	enemies_container = get_node_or_null("../Enemies")
	
	# 确保DataManager和GameParty已准备好
	_ensure_data_and_party_ready()
	
	# 生成角色
	_spawn_party_members()
	_spawn_enemies()
	
	print("✅ [CharacterManager] 角色管理器初始化完成")

# 🚀 确保数据和队伍准备就绪
func _ensure_data_and_party_ready():
	# 确保数据管理器已加载
	DataManager.load_data("character") # 假设DataManager是自动加载的
	
	# 如果game_party因为某种原因没有成员，在这里添加
	if game_party.get_member_ids().is_empty():
		print("ℹ️ [CharacterManager] GameParty为空，添加默认成员")
		game_party.add_member("1")
		game_party.add_member("2")
		game_party.add_member("3")
	else:
		print("ℹ️ [CharacterManager] GameParty已有成员，数量: %d" % game_party.get_member_ids().size())


# 生成队伍成员
func _spawn_party_members() -> void:
	print("🎮 [CharacterManager] 开始生成队伍成员")
	
	if not game_party:
		print("❌ [CharacterManager] GameParty为空, 无法生成队伍成员")
		return
	
	if game_party.get_member_ids().is_empty():
		print("⚠️ [CharacterManager] GameParty中没有成员ID, 无法生成队伍成员")
		return

	for character_id in game_party.get_member_ids():
		var instance = player_scene.instantiate()
		
		if players_container:
			players_container.add_child.call_deferred(instance)
		else:
			print("⚠️ [CharacterManager] Players容器未找到, 尝试添加到父节点")
			get_parent().add_child.call_deferred(instance)

		# 🚀 等待一帧确保实例内部 @onready 变量初始化完成
		await get_tree().process_frame 

		var character = game_party.get_member(character_id)
		if not character:
			print("❌ [CharacterManager] 无法从GameParty获取ID为 %s 的角色数据" % character_id)
			instance.queue_free() # 清理未正确初始化的实例
			continue

		var char_data_node = instance.get_character_data()
		if not char_data_node:
			print("❌ [CharacterManager] 角色实例 %s 没有get_character_data方法或返回null" % instance.name)
			instance.queue_free()
			continue
		char_data_node.load_from_id(character_id)
		
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		# char_data_node中的qinggong_skill已经从CSV数据中正确加载
		
		if SPAWN_POSITIONS.has(character_id):
			instance.set_base_position(SPAWN_POSITIONS[character_id])
		else:
			instance.set_base_position(Vector2(300, 200))
		
		if character.has_signal("stats_changed"):
			character.stats_changed.connect(_on_character_updated.bind(character_id))
		else:
			print("⚠️ [CharacterManager] 角色 %s 没有stats_changed信号" % character.name)

		if character.has_signal("health_depleted"):
			character.health_depleted.connect(_on_character_death.bind(character))
		else:
			print("⚠️ [CharacterManager] 角色 %s 没有health_depleted信号" % character.name)
		
		party_member_nodes[character_id] = instance
		character_spawned.emit(character_id, instance)
		print("✅ [CharacterManager] 生成队友: %s (ID: %s)" % [character.name, character_id])

# 生成敌人
func _spawn_enemies() -> void:
	print("🤖 [CharacterManager] 开始生成敌人")
	
	# 从关卡配置获取敌人ID列表
	var enemy_ids = _get_enemy_ids_from_level_config()
	
	if enemy_ids.is_empty():
		printerr("⚠️ [CharacterManager] 无法获取敌人ID列表，使用默认配置")
		enemy_ids = ["101", "102", "103"]  # 回退方案
	
	for enemy_id in enemy_ids:
		var instance = player_scene.instantiate()
		
		if enemies_container:
			enemies_container.add_child.call_deferred(instance)
		else:
			print("⚠️ [CharacterManager] Enemies容器未找到, 尝试添加到父节点")
			get_parent().add_child.call_deferred(instance)

		# 🚀 等待一帧确保实例内部 @onready 变量初始化完成
		await get_tree().process_frame

		var character_data_script = instance.get_character_data()
		if not character_data_script:
			print("❌ [CharacterManager] 敌方角色实例 %s 没有get_character_data方法或返回null" % instance.name)
			instance.queue_free()
			continue
		character_data_script.load_from_id(enemy_id)
		
		character_data_script.set_as_enemy()
		# 轻功值现在从CSV数据中读取，不再需要硬编码设置
		
		if ENEMY_SPAWN_POSITIONS.has(enemy_id):
			var spawn_pos = ENEMY_SPAWN_POSITIONS[enemy_id]
			character_data_script.ground_position = spawn_pos
			character_data_script.position = spawn_pos
			instance.set_base_position(spawn_pos)
		else:
			var default_pos = Vector2(1000, 1000)
			character_data_script.ground_position = default_pos
			character_data_script.position = default_pos
			instance.set_base_position(default_pos)
		
		_setup_enemy_appearance(instance, enemy_id)
		
		if character_data_script.has_signal("stats_changed"):
			character_data_script.stats_changed.connect(_on_enemy_updated.bind(enemy_id))
		else:
			print("⚠️ [CharacterManager] 敌人 %s 没有stats_changed信号" % character_data_script.name)

		if character_data_script.has_signal("health_depleted"):
			character_data_script.health_depleted.connect(_on_character_death.bind(character_data_script))
			print("✅ [CharacterManager] 敌人 %s 死亡信号连接成功" % character_data_script.name)
		else:
			print("⚠️ [CharacterManager] 敌人 %s 没有health_depleted信号" % character_data_script.name)
		
		enemy_nodes[enemy_id] = instance
		character_spawned.emit(enemy_id, instance)
		print("✅ [CharacterManager] 生成敌人: %s (ID: %s)" % [character_data_script.name, enemy_id])

# 设置敌人外观
func _setup_enemy_appearance(enemy_instance: Node2D, enemy_id: String) -> void:
	# 简单的视觉区分：改变敌人颜色
	var sprite = enemy_instance.get_node_or_null("Graphic/Sprite2D")
	if sprite:
		sprite.modulate = Color.RED  # 敌人显示为红色

# ===========================================
# 配置管理方法
# ===========================================

func _get_enemy_ids_from_level_config() -> Array:
	"""从关卡配置获取敌人ID列表"""
	print("🎯 [CharacterManager] 从关卡配置获取敌人ID")
	
	# 回退：从DataManager获取关卡配置
	var level_config_data = DataManager.get_level_configuration("level_1")
	if not level_config_data.is_empty():
		var enemy_ids = level_config_data.get("enemy_character_ids", [])
		print("✅ [CharacterManager] 从DataManager获取敌人ID: %s" % str(enemy_ids))
		return enemy_ids
	
	printerr("⚠️ [CharacterManager] 无法从任何来源获取敌人ID配置")
	return []

# ===========================================
# 角色查找和管理方法
# ===========================================

# 获取所有角色
func get_all_characters() -> Array:
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

# 获取队友角色列表
func get_party_members() -> Array:
	var party_members_data = []
	for character_id in party_member_nodes:
		var node = party_member_nodes[character_id]
		if node and node.has_method("get_character_data"):
			var character_data = node.get_character_data()
			if character_data:
				party_members_data.append(character_data)
	return party_members_data

# 获取敌人角色列表
func get_enemies() -> Array:
	var enemies_data = []
	for enemy_id in enemy_nodes:
		var node = enemy_nodes[enemy_id]
		if node and node.has_method("get_character_data"):
			var character_data = node.get_character_data()
			if character_data:
				enemies_data.append(character_data)
	return enemies_data

# 根据角色数据获取对应的角色节点
func get_character_node_by_data(character_data: GameCharacter) -> Node2D:
	if not character_data:
		print("⚠️ [CharacterManager] get_character_node_by_data: 角色数据为空")
		return null
	
	var character_id = character_data.id
	
	if party_member_nodes.has(character_id):
		return party_member_nodes[character_id]
	
	if enemy_nodes.has(character_id):
		return enemy_nodes[character_id]
	
	print("❌ [CharacterManager] 未找到角色节点: %s (ID: %s)" % [character_data.name, character_id])
	return null

# 通过ID查找角色节点
func find_character_node_by_id(character_id: String) -> Node2D:
	if party_member_nodes.has(character_id):
		return party_member_nodes[character_id]
	
	if enemy_nodes.has(character_id):
		return enemy_nodes[character_id]
	
	return null

# ===========================================
# 信号回调方法
# ===========================================

func _on_character_updated(character_id: String) -> void:
	pass # 静默处理

func _on_enemy_updated(enemy_id: String) -> void:
	pass # 静默处理

func _on_character_death(dead_character: GameCharacter) -> void:
	if dead_character:
		print("💀 [CharacterManager] 角色死亡: %s" % dead_character.name)
		character_death.emit(dead_character)
	else:
		print("💀 [CharacterManager] 收到角色死亡信号，但角色数据为空")


# ===========================================
# 角色状态管理方法
# ===========================================

func handle_character_death(dead_character: GameCharacter) -> void:
	var character_node = get_character_node_by_data(dead_character)
	if character_node:
		character_node.modulate = Color(0.3, 0.3, 0.3, 0.6)
		print("💀 [CharacterManager] %s 已阵亡，应用死亡视觉效果" % dead_character.name)
		_add_death_marker(character_node)
		# character_death.emit(dead_character) # 信号已在 _on_character_death 中发出
	else:
		print("⚠️ [CharacterManager] 无法找到 %s 对应的角色节点" % dead_character.name)

func _add_death_marker(character_node: Node2D) -> void:
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
	print("💀 [CharacterManager] 为 %s 添加死亡标记" % character_node.name)

class _DeathMarkerDrawer extends Node2D:
	func _draw():
		var size = 30.0
		var thickness = 4.0
		var color = Color.RED
		draw_line(Vector2(-size/2, -size/2), Vector2(size/2, size/2), color, thickness)
		draw_line(Vector2(size/2, -size/2), Vector2(-size/2, size/2), color, thickness)

func print_party_stats() -> void:
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
		# ... (可以添加更多信息)
		print("---------------------")
	print("===== 报告结束 =====")

func check_and_fix_character_heights() -> void:
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

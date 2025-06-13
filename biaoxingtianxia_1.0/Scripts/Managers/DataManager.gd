# New file: res://Scripts/Managers/DataManager.gd
extends Node

# 数据路径配置（常量字典，便于集中管理）
# 🚀 新增：路径配置管理
const PATH_CONFIG_FILE := "res://data/PathConfiguration.csv"
var _path_cache := {}  # 缓存路径配置

# 动态获取数据路径（从路径配置文件读取）
func get_data_path(data_type: String) -> String:
	if _path_cache.is_empty():
		_load_path_configuration()
	
	var path_key = "data." + data_type
	if _path_cache.has(path_key):
		return _path_cache[path_key]
	else:
		printerr("⚠️ [DataManager] 未找到数据类型 '%s' 的路径配置" % data_type)
		return ""

# 数据存储字典（动态加载的数据会存储在这里）
var _data_stores := {}
# 加载状态记录（避免重复加载）
var _load_status := {}

func _ready() -> void:
	print("🚀 [DataManager] 开始初始化数据管理器")
	# 预加载基础数据
	load_data("character")
	load_data("skills")
	load_data("skill_learning")  # 🚀 新增：预加载技能学习数据
	load_data("passive_skills")  # 🚀 新增：预加载被动技能数据
	load_data("character_passive_skills")  # 🚀 新增：预加载角色被动技能数据
	print("✅ [DataManager] 数据管理器初始化完成")

# 公开方法：加载指定类型数据
func load_data(data_type: String) -> void:
	print("🔍 [DataManager] load_data被调用，数据类型: %s" % data_type)
	print("📋 [DataManager] 当前加载状态: %s" % str(_load_status.get(data_type, false)))
	
	if _load_status.get(data_type, false):
		print("✅ [DataManager] 数据类型 %s 已加载，跳过" % data_type)
		return

	print("🔍 [DataManager] 开始处理数据类型: %s" % data_type)
	print("📋 [DataManager] 请检查路径配置文件: %s" % PATH_CONFIG_FILE)
	
	# 获取数据文件路径
	var data_path = get_data_path(data_type)
	if data_path.is_empty():
		push_error("未知数据类型: %s" % data_type)
		return
	
	match data_type:
		"character":
			_data_stores[data_type] = _load_character_data(data_path)
		"skills":
			_data_stores[data_type] = _load_skills_data(data_path)
		"skill_learning":  # 🚀 新增：技能学习数据加载
			_data_stores[data_type] = _load_skill_learning_data(data_path)
		"passive_skills":  # 🚀 新增：被动技能数据加载
			_data_stores[data_type] = _load_passive_skills_data(data_path)
		"character_passive_skills":  # 🚀 新增：角色被动技能数据加载
			_data_stores[data_type] = _load_character_passive_skills_data(data_path)
		"level_configuration":  # 🚀 新增：关卡配置数据加载
			_data_stores[data_type] = _load_level_configuration_data(data_path)
		"spawn_configuration":  # 🚀 新增：生成点配置数据加载
			_data_stores[data_type] = _load_spawn_configuration_data(data_path)
		# 未来扩展其他数据类型：
		# "item":
		#     _data_stores[data_type] = _load_item_data(data_path)
		_:
			push_error("未实现的数据加载器: %s" % data_type)
			return
	
	_load_status[data_type] = true

# 公开方法：获取数据
func get_data(data_type: String, id: String = ""):
	print("🎯 [DataManager] get_data被调用，数据类型: %s, ID: %s" % [data_type, id])
	print("📋 [DataManager] 当前加载状态: %s" % str(_load_status.get(data_type, false)))
	
	if not _load_status.get(data_type, false):
		print("⚡ [DataManager] 数据未加载，开始加载数据类型: %s" % data_type)
		load_data(data_type)
	else:
		print("✅ [DataManager] 数据已加载，直接返回数据类型: %s" % data_type)

	if id == "":
		# 如果没有指定ID，返回整个数据集
		var result = _data_stores.get(data_type, {})
		print("📦 [DataManager] 返回整个数据集，数据类型: %s, 记录数: %d" % [data_type, result.size() if result is Dictionary else len(result) if result is Array else 0])
		return result
	else:
		# 返回指定ID的数据
		var data_store = _data_stores.get(data_type, {})
		print("🔍 [DataManager] 在数据存储中查找ID: %s, 数据存储类型: %s" % [id, str(type_string(typeof(data_store)))])
		
		if data_store is Dictionary:
			var result = data_store.get(id, null)
			print("📋 [DataManager] 字典查找结果: %s" % ("找到数据" if result != null else "未找到数据"))
			return result
		elif data_store is Array:
			# 对于Array类型的数据（如技能），查找对应ID的条目
			for item in data_store:
				if item is Dictionary and item.get("id", "") == id:
					print("📋 [DataManager] 数组查找成功，找到ID: %s" % id)
					return item
			print("📋 [DataManager] 数组查找失败，未找到ID: %s" % id)
			return null
		else:
			return null

# 公开方法：强制重载数据
func reload_data(data_type: String) -> void:
	# 检查数据类型是否有效（通过尝试获取路径）
	var data_path = get_data_path(data_type)
	if data_path.is_empty():
		push_error("尝试重载未知数据类型: %s" % data_type)
		return
	
	_load_status[data_type] = false
	_data_stores.erase(data_type)
	load_data(data_type)

# 🚀 修复：跳过中文注释行的CSV加载基础方法
func _load_csv_with_comments(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	
	if file == null:
		push_error("无法打开CSV文件: %s (错误: %d)" % [path, FileAccess.get_open_error()])
		return []
	
	# 🚀 读取第一行作为英文表头
	var headers := file.get_csv_line()
	print("📋 [DataManager] 使用英文表头: %s" % str(headers))
	
	# 🚀 跳过第二行（中文注释行）
	if not file.eof_reached():
		var comment_line := file.get_csv_line()
		print("📝 [DataManager] 跳过中文注释行: %s" % str(comment_line))
	
	var result := []
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < headers.size():  # 确保有足够列数
			continue
		
		# 将每行数据转换为字典
		var row_data := {}
		for i in range(headers.size()):
			row_data[headers[i]] = line[i] if i < line.size() else ""
		
		result.append(row_data)
	
	file.close()
	return result

# 私有方法：角色数据加载具体实现
func _load_character_data(path: String) -> Dictionary:
	print("🚀 [DataManager] 开始加载角色数据，文件路径: %s" % path)
	var result := {}
	var csv_data := _load_csv_with_comments(path)
	print("📊 [DataManager] CSV数据加载完成，共 %d 行数据" % csv_data.size())
	
	for i in range(csv_data.size()):
		var row_data = csv_data[i]
		print("🔍 [DataManager] 处理第 %d 行数据: %s" % [i, str(row_data)])
		print("🔍 [DataManager] 可用的字段名: %s" % str(row_data.keys()))
		
		# 🚀 修复：使用英文字段名（因为_load_csv_with_comments使用英文表头）
		var id: String = row_data.get("id", "")
		print("🆔 [DataManager] 提取角色ID: '%s'" % id)
		
		if id == "":
			print("⚠️ [DataManager] 跳过空角色ID的行")
			continue
		
		# 🚀 修复：处理空字符串的等级字段
		var level_str = row_data.get("level", "1")
		var level_value = 1 if level_str == "" else int(level_str)
		
		result[id] = {
			"id": id,
			"name": row_data.get("name", ""),
			"max_hp": int(row_data.get("max_hp", "100")),
			"attack": int(row_data.get("attack", "10")),
			"defense": int(row_data.get("defense", "5")),
			"level": level_value,
			"qinggong_skill": int(row_data.get("qinggong_skill", "120")),
			"scene_path": row_data.get("scene_path", "")  # 🎯 新增：保存场景路径字段
		}
		
		print("📋 [DataManager] 加载角色数据: ID=%s, 名称=%s, 等级=%d, 轻功=%d" % [id, result[id]["name"], result[id]["level"], result[id]["qinggong_skill"]])
	
	print("✅ [DataManager] 角色数据加载完成，共加载 %d 个角色" % result.size())
	print("📝 [DataManager] 已加载的角色ID列表: %s" % str(result.keys()))
	return result

# 私有方法：技能数据加载具体实现
func _load_skills_data(path: String) -> Array:
	return _load_csv_with_comments(path)

# 🚀 新增：技能学习数据加载
func _load_skill_learning_data(path: String) -> Array:
	print("📚 [DataManager] 加载技能学习配置: %s" % path)
	var csv_data := _load_csv_with_comments(path)
	print("✅ [DataManager] 技能学习配置加载完成，共 %d 条记录" % csv_data.size())
	return csv_data

# 🚀 新增：获取角色的技能学习配置
func get_character_skill_learning(character_id: String) -> Array:
	var skill_learning_data = get_data("skill_learning")
	var character_skills = []
	
	for learning_record in skill_learning_data:
		if learning_record.get("character_id", "") == character_id:
			character_skills.append(learning_record)
	
	return character_skills

# 🚀 新增：被动技能数据加载
func _load_passive_skills_data(path: String) -> Dictionary:
	print("🎯 [DataManager] 加载被动技能配置: %s" % path)
	var result := {}
	var csv_data := _load_csv_with_comments(path)
	
	print("🔍 [DataManager] CSV数据行数: %d" % csv_data.size())
	for i in range(csv_data.size()):
		var row_data = csv_data[i]
		print("📋 [DataManager] 第%d行数据: %s" % [i+1, str(row_data)])
		
		# 尝试不同的键名
		var id: String = ""
		if row_data.has("技能ID"):
			id = str(row_data["技能ID"]).strip_edges()
		elif row_data.has("id"):
			id = str(row_data["id"]).strip_edges()
		elif row_data.has("skill_id"):
			id = str(row_data["skill_id"]).strip_edges()
		
		if id == "":
			print("⚠️ [DataManager] 第%d行缺少技能ID" % [i+1])
			continue
		
		# 获取技能名称
		var skill_name: String = ""
		if row_data.has("技能名称"):
			skill_name = str(row_data["技能名称"]).strip_edges()
		elif row_data.has("name"):
			skill_name = str(row_data["name"]).strip_edges()
		
		# 获取技能描述
		var description: String = ""
		if row_data.has("技能描述"):
			description = str(row_data["技能描述"]).strip_edges()
		elif row_data.has("description"):
			description = str(row_data["description"]).strip_edges()
		
		# 获取效果类型
		var effect_type: String = ""
		if row_data.has("效果类型"):
			effect_type = str(row_data["效果类型"]).strip_edges()
		elif row_data.has("effect_type"):
			effect_type = str(row_data["effect_type"]).strip_edges()
		
		result[id] = {
			"id": id,
			"name": skill_name,
			"description": description,
			"effect_type": effect_type
		}
		print("✅ [DataManager] 成功解析技能: %s" % str(result[id]))
	
	print("✅ [DataManager] 被动技能配置加载完成，共 %d 个技能" % result.size())
	return result

# 🚀 新增：角色被动技能数据加载
func _load_character_passive_skills_data(path: String) -> Array:
	var csv_data := _load_csv_with_comments(path)
	return csv_data

# 🚀 新增：获取角色的被动技能列表
func get_character_passive_skills(character_id: String) -> Array:
	# 确保数据已加载（但不强制重载）
	load_data("character_passive_skills")
	
	var passive_skills_data = get_data("character_passive_skills")
	if passive_skills_data.is_empty():
		return []
	
	var matching_skills = []
	for skill_record in passive_skills_data:
		var record_character_id = str(skill_record.get("character_id", ""))
		
		if record_character_id == character_id:
			matching_skills.append(skill_record)
	
	return matching_skills

# 🚀 新增：获取被动技能数据
func get_passive_skill_data(skill_id: String) -> Dictionary:
	var passive_skills_data = get_data("passive_skills")
	return passive_skills_data.get(skill_id, {})

# 🚀 新增：关卡配置数据加载
func _load_level_configuration_data(path: String) -> Dictionary:
	print("🏟️ [DataManager] 加载关卡配置: %s" % path)
	var result := {}
	var csv_data := _load_csv_with_comments(path)
	
	for row_data in csv_data:
		var level_id = row_data.get("level_id", "")
		if level_id.is_empty():
			continue
			
		# 解析角色ID列表（处理CSV中的逗号分隔字符串）
		var player_ids_str = row_data.get("player_character_ids", "")
		var enemy_ids_str = row_data.get("enemy_character_ids", "")
		
		# 移除引号并分割
		player_ids_str = player_ids_str.strip_edges().trim_prefix("\"").trim_suffix("\"")
		enemy_ids_str = enemy_ids_str.strip_edges().trim_prefix("\"").trim_suffix("\"")
		
		var player_ids = player_ids_str.split(",") if not player_ids_str.is_empty() else []
		var enemy_ids = enemy_ids_str.split(",") if not enemy_ids_str.is_empty() else []
		
		# 清理数组中的空白字符
		for i in range(player_ids.size()):
			player_ids[i] = player_ids[i].strip_edges()
		for i in range(enemy_ids.size()):
			enemy_ids[i] = enemy_ids[i].strip_edges()
		
		result[level_id] = {
			"level_id": level_id,
			"level_name": row_data.get("level_name", ""),
			"player_character_ids": player_ids,
			"enemy_character_ids": enemy_ids,
			"description": row_data.get("description", "")
		}
		
		print("📋 [DataManager] 加载关卡配置: ID=%s, 名称=%s, 玩家=%s, 敌人=%s" % [level_id, result[level_id]["level_name"], str(player_ids), str(enemy_ids)])
	
	print("✅ [DataManager] 关卡配置加载完成，共 %d 个关卡" % result.size())
	return result

# 🚀 新增：获取关卡配置
func get_level_configuration(level_id: String) -> Dictionary:
	var level_configs = get_data("level_configuration")
	return level_configs.get(level_id, {})

# 🚀 新增：获取生成点配置
func get_spawn_configuration(level_id: String) -> Dictionary:
	var spawn_configs = get_data("spawn_configuration")
	return spawn_configs.get(level_id, {})

# 🚀 新增：生成点配置数据加载
func _load_spawn_configuration_data(path: String) -> Dictionary:
	print("🎯 [DataManager] 加载生成点配置: %s" % path)
	var result := {}
	var csv_data := _load_csv_with_comments(path)
	
	for row_data in csv_data:
		var level_id = row_data.get("level_id", "")
		if level_id.is_empty():
			continue
			
		# 初始化关卡数据结构
		if not result.has(level_id):
			result[level_id] = {
				"player_spawns": [],
				"enemy_spawns": []
			}
		
		var spawn_type = row_data.get("spawn_type", "")
		var spawn_data = {
			"spawn_index": int(row_data.get("spawn_index", "0")),
			"position": Vector2(
				float(row_data.get("position_x", "0")),
				float(row_data.get("position_y", "0"))
			),
			"pattern": row_data.get("pattern", "line"),
			"spacing": float(row_data.get("spacing", "100")),
			"description": row_data.get("description", "")
		}
		
		if spawn_type == "player":
			result[level_id]["player_spawns"].append(spawn_data)
		elif spawn_type == "enemy":
			result[level_id]["enemy_spawns"].append(spawn_data)
		
		print("📍 [DataManager] 加载生成点: 关卡=%s, 类型=%s, 位置=%s" % [level_id, spawn_type, spawn_data.position])
	
	print("✅ [DataManager] 生成点配置加载完成，共 %d 个关卡" % result.size())
	return result

# 🚀 新增：路径配置加载方法
func _load_path_configuration():
	"""加载路径配置文件"""
	print("🗂️ [DataManager] 加载路径配置: %s" % PATH_CONFIG_FILE)
	var csv_data := _load_csv_with_comments(PATH_CONFIG_FILE)
	
	for row_data in csv_data:
		var path_type = row_data.get("path_type", "")
		var path_key = row_data.get("path_key", "")
		var file_path = row_data.get("file_path", "")
		
		if path_type.is_empty() or path_key.is_empty() or file_path.is_empty():
			continue
			
		var cache_key = path_type + "." + path_key
		_path_cache[cache_key] = file_path
		print("📁 [DataManager] 注册路径: %s -> %s" % [cache_key, file_path])
	
	print("✅ [DataManager] 路径配置加载完成，共 %d 个路径" % _path_cache.size())

# 未来可添加其他数据加载方法：
# func _load_item_data(path: String) -> Dictionary:
#     ...

# 在DataManager中添加
func watch_for_changes() -> void:
	# 可以连接文件系统变化信号
	pass

# New file: res://Scripts/Managers/DataManager.gd
extends Node

# 数据路径配置（常量字典，便于集中管理）
const DATA_PATHS := {
	"character": "res://data/CharacterData.csv",
	"skills": "res://data/skill_database.csv",
	"skill_learning": "res://data/skill_learning.csv",  # 🚀 新增：技能学习配置
	"passive_skills": "res://data/passive_skills.csv",  # 🚀 新增：被动技能配置
	"character_passive_skills": "res://data/character_passive_skills.csv",  # 🚀 新增：角色被动技能配置
	"items": "res://data/Items.csv",
	# 未来可扩展添加：
	# "item": "res://data/ItemData.json",
}

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

	print("🔍 [DataManager] 检查DATA_PATHS是否包含 %s: %s" % [data_type, DATA_PATHS.has(data_type)])
	print("📋 [DataManager] 可用的数据类型: %s" % str(DATA_PATHS.keys()))
	
	if not DATA_PATHS.has(data_type):
		push_error("未知数据类型: %s" % data_type)
		return
	
	match data_type:
		"character":
			_data_stores[data_type] = _load_character_data(DATA_PATHS[data_type])
		"skills":
			_data_stores[data_type] = _load_skills_data(DATA_PATHS[data_type])
		"skill_learning":  # 🚀 新增：技能学习数据加载
			_data_stores[data_type] = _load_skill_learning_data(DATA_PATHS[data_type])
		"passive_skills":  # 🚀 新增：被动技能数据加载
			_data_stores[data_type] = _load_passive_skills_data(DATA_PATHS[data_type])
		"character_passive_skills":  # 🚀 新增：角色被动技能数据加载
			_data_stores[data_type] = _load_character_passive_skills_data(DATA_PATHS[data_type])
		# 未来扩展其他数据类型：
		# "item":
		#     _data_stores[data_type] = _load_item_data(DATA_PATHS[data_type])
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
	if not DATA_PATHS.has(data_type):
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
			"level": level_value
		}
		
		print("📋 [DataManager] 加载角色数据: ID=%s, 名称=%s, 等级=%d" % [id, result[id]["name"], result[id]["level"]])
	
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
		var name: String = ""
		if row_data.has("技能名称"):
			name = str(row_data["技能名称"]).strip_edges()
		elif row_data.has("name"):
			name = str(row_data["name"]).strip_edges()
		
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
			"name": name,
			"description": description,
			"effect_type": effect_type
		}
		print("✅ [DataManager] 成功解析技能: %s" % str(result[id]))
	
	print("✅ [DataManager] 被动技能配置加载完成，共 %d 个技能" % result.size())
	return result

# 🚀 新增：角色被动技能数据加载
func _load_character_passive_skills_data(path: String) -> Array:
	print("👤 [DataManager] 加载角色被动技能配置: %s" % path)
	var csv_data := _load_csv_with_comments(path)
	print("✅ [DataManager] 角色被动技能配置加载完成，共 %d 条记录" % csv_data.size())
	
	# 打印前几条记录用于调试
	for i in range(min(5, csv_data.size())):
		print("📋 [DataManager] 记录 %d: %s" % [i, csv_data[i]])
	
	return csv_data

# 🚀 新增：获取角色的被动技能列表
func get_character_passive_skills(character_id: String) -> Array:
	print("🔍 [DataManager] 开始查找角色 %s 的被动技能" % character_id)
	
	# 强制重载数据以确保获取最新的CSV内容
	reload_data("character_passive_skills")
	print("🔄 [DataManager] 已强制重载被动技能数据")
	
	var passive_skills_data = get_data("character_passive_skills")
	if passive_skills_data.is_empty():
		printerr("❌ [DataManager] 被动技能数据为空")
		return []
	
	print("📋 [DataManager] 被动技能数据总数: %d" % passive_skills_data.size())
	print("📝 [DataManager] CSV文件路径: %s" % DATA_PATHS["character_passive_skills"])
	
	# 显示前3条记录作为样本
	for i in range(min(3, passive_skills_data.size())):
		print("📄 [DataManager] 样本记录 %d: %s" % [i, passive_skills_data[i]])
	
	var matching_skills = []
	for skill_record in passive_skills_data:
		# 🚀 修复：使用正确的英文列名
		var record_character_id = str(skill_record.get("character_id", ""))
		var passive_skill_id = str(skill_record.get("passive_skill_id", ""))
		var learn_level = str(skill_record.get("learn_level", ""))
		
		if record_character_id == character_id:
			print("✅ [DataManager] 找到匹配的被动技能记录: character_id=%s, passive_skill_id=%s, learn_level=%s" % [record_character_id, passive_skill_id, learn_level])
			matching_skills.append(skill_record)
	
	print("📊 [DataManager] 角色 %s 的被动技能记录总数: %d" % [character_id, matching_skills.size()])
	print("🎯 [DataManager] 匹配的技能列表: %s" % [matching_skills])
	return matching_skills

# 🚀 新增：获取被动技能数据
func get_passive_skill_data(skill_id: String) -> Dictionary:
	var passive_skills_data = get_data("passive_skills")
	return passive_skills_data.get(skill_id, {})

# 未来可添加其他数据加载方法：
# func _load_item_data(path: String) -> Dictionary:
#     ...

# 在DataManager中添加
func watch_for_changes() -> void:
	# 可以连接文件系统变化信号
	pass

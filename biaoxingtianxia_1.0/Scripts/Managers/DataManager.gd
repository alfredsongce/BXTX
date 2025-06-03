# New file: res://Scripts/Managers/DataManager.gd
extends Node

# 数据路径配置（常量字典，便于集中管理）
const DATA_PATHS := {
	"character": "res://data/CharacterData.csv",
	"skills": "res://data/skill_database.csv",
	"skill_learning": "res://data/skill_learning.csv",  # 🚀 新增：技能学习配置
	"items": "res://data/Items.csv",
	# 未来可扩展添加：
	# "item": "res://data/ItemData.json",
}

# 数据存储字典（动态加载的数据会存储在这里）
var _data_stores := {}
# 加载状态记录（避免重复加载）
var _load_status := {}

func _ready() -> void:
	# 可在此预加载核心数据（按需启用）
	# load_data("character")
	pass

# 公开方法：加载指定类型数据
func load_data(data_type: String) -> void:
	if _load_status.get(data_type, false):
		return
	
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
		# 未来扩展其他数据类型：
		# "item":
		#     _data_stores[data_type] = _load_item_data(DATA_PATHS[data_type])
		_:
			push_error("未实现的数据加载器: %s" % data_type)
			return
	
	_load_status[data_type] = true

# 公开方法：获取数据
func get_data(data_type: String, id: String = ""):
	if not _load_status.get(data_type, false):
		load_data(data_type)
	
	if id == "":
		# 如果没有指定ID，返回整个数据集
		return _data_stores.get(data_type, {})
	else:
		# 返回指定ID的数据
		var data_store = _data_stores.get(data_type, {})
		if data_store is Dictionary:
			return data_store.get(id, null)
		elif data_store is Array:
			# 对于Array类型的数据（如技能），查找对应ID的条目
			for item in data_store:
				if item is Dictionary and item.get("id", "") == id:
					return item
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
	
	# 读取表头行
	var headers := file.get_csv_line()
	
	# 🚀 跳过中文注释行（第二行）
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
	var result := {}
	var csv_data := _load_csv_with_comments(path)
	
	for row_data in csv_data:
		var id: String = row_data.get("id", "")
		if id == "":
			continue
		
		result[id] = {
			"id": id,
			"name": row_data.get("name", ""),
			"max_hp": int(row_data.get("max_hp", "100")),
			"attack": int(row_data.get("attack", "10")),
			"defense": int(row_data.get("defense", "5")),
			"level": int(row_data.get("level", "1"))
		}
	
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

# 未来可添加其他数据加载方法：
# func _load_item_data(path: String) -> Dictionary:
#     ...

# 在DataManager中添加
func watch_for_changes() -> void:
	# 可以连接文件系统变化信号
	pass

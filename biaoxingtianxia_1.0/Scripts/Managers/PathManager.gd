# PathManager.gd - 文件路径配置管理器
# 负责管理项目中所有文件路径，支持从CSV配置文件动态加载

extends Node

# 路径配置文件
const PATH_CONFIG_FILE := "res://data/PathConfiguration.csv"

# 路径缓存
var _path_cache := {}

# 初始化
func _ready():
	print("🗂️ [PathManager] 初始化路径管理器")
	_load_path_configuration()

# 加载路径配置
func _load_path_configuration():
	"""从CSV文件加载路径配置"""
	print("📂 [PathManager] 开始加载路径配置: %s" % PATH_CONFIG_FILE)
	
	var file = FileAccess.open(PATH_CONFIG_FILE, FileAccess.READ)
	if not file:
		printerr("❌ [PathManager] 无法打开路径配置文件: %s" % PATH_CONFIG_FILE)
		return
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	if lines.size() < 3:  # 至少需要表头、中文注释和一行数据
		printerr("❌ [PathManager] 路径配置文件格式错误")
		return
	
	# 解析表头
	var headers = lines[0].split(",")
	
	# 跳过中文注释行，从第三行开始处理数据
	for i in range(2, lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue
			
		var values = line.split(",")
		if values.size() < headers.size():
			continue
			
		var row_data = {}
		for j in range(headers.size()):
			if j < values.size():
				row_data[headers[j]] = values[j].strip_edges()
		
		var path_type = row_data.get("path_type", "")
		var path_key = row_data.get("path_key", "")
		var file_path = row_data.get("file_path", "")
		
		if path_type.is_empty() or path_key.is_empty() or file_path.is_empty():
			continue
			
		var cache_key = path_type + "." + path_key
		_path_cache[cache_key] = file_path
		print("📁 [PathManager] 注册路径: %s -> %s" % [cache_key, file_path])
	
	print("✅ [PathManager] 路径配置加载完成，共 %d 个路径" % _path_cache.size())

# 获取数据文件路径
func get_data_path(data_key: String) -> String:
	"""获取数据文件路径"""
	var cache_key = "data." + data_key
	if _path_cache.has(cache_key):
		return _path_cache[cache_key]
	else:
		printerr("⚠️ [PathManager] 未找到数据路径: %s" % data_key)
		return ""

# 获取场景文件路径
func get_scene_path(scene_key: String) -> String:
	"""获取场景文件路径"""
	var cache_key = "scene." + scene_key
	if _path_cache.has(cache_key):
		return _path_cache[cache_key]
	else:
		printerr("⚠️ [PathManager] 未找到场景路径: %s" % scene_key)
		return ""

# 获取脚本文件路径
func get_script_path(script_key: String) -> String:
	"""获取脚本文件路径"""
	var cache_key = "script." + script_key
	if _path_cache.has(cache_key):
		return _path_cache[cache_key]
	else:
		printerr("⚠️ [PathManager] 未找到脚本路径: %s" % script_key)
		return ""

# 获取任意文件路径
func get_file_path(path_type: String, path_key: String) -> String:
	"""获取指定类型和键的文件路径"""
	var cache_key = path_type + "." + path_key
	if _path_cache.has(cache_key):
		return _path_cache[cache_key]
	else:
		printerr("⚠️ [PathManager] 未找到路径: %s" % cache_key)
		return ""

# 重新加载路径配置
func reload_paths():
	"""重新加载路径配置"""
	_path_cache.clear()
	_load_path_configuration()

# 获取所有已加载的路径
func get_all_paths() -> Dictionary:
	"""获取所有已加载的路径"""
	return _path_cache.duplicate()
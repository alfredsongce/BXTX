# 🚀 移动范围显示系统 - 缓存组件（增强版）
extends Node
class_name MoveRangeCache

# 🚀 缓存存储（深度性能优化版）
var _global_cache: Dictionary = {}
var _predictive_cache: Dictionary = {}
var _quick_cache: Dictionary = {}  # 🚀 新增：快速预览缓存
var _cache_lookup_table: Dictionary = {}  # 🚀 新增：快速查找表
var _performance_stats: Dictionary = {
	"cache_hits": 0,
	"cache_misses": 0,
	"avg_compute_time": 0.0,
	"memory_usage_mb": 0.0,
	"gpu_compute_count": 0,
	"predictive_hits": 0,
	"batch_processed": 0,
	"quick_cache_hits": 0  # 🚀 新增
}

# 🚀 新增：移动历史记录用于预测
var _movement_history: Array = []
var _batch_queue: Array = []
var _preload_queue: Array = []  # 🚀 新增：预加载队列

# 📡 信号
signal cache_hit(key: String, cache_type: String)
signal cache_miss(key: String)
signal memory_warning(current_mb: float, limit_mb: float)
signal cache_cleaned(removed_count: int)
signal preload_completed(character_name: String)  # 🚀 新增

# 🔧 组件引用
var config  # 改为动态类型

func _ready():
	print("🚀 [Cache] 缓存组件初始化完成")
	
	# 获取配置组件引用
	call_deferred("_setup_config_reference")
	
	# 启动定时清理
	_setup_cleanup_timer()
	
	# 启动预测缓存定时器
	_setup_predictive_timer()
	
	# 🚀 新增：启动预加载处理器
	_setup_preload_processor()

func _setup_config_reference():
	config = get_node("../Config")
	if not config:
		push_warning("[Cache] 未找到Config组件")

func _setup_cleanup_timer():
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 30.0
	cleanup_timer.timeout.connect(_cleanup_expired_cache)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)

func _setup_predictive_timer():
	var predict_timer = Timer.new()
	predict_timer.wait_time = 2.0
	predict_timer.timeout.connect(_update_predictive_cache)
	predict_timer.autostart = true
	add_child(predict_timer)

func _setup_preload_processor():
	var preload_timer = Timer.new()
	preload_timer.wait_time = 0.1  # 100ms处理一次预加载队列
	preload_timer.timeout.connect(_process_preload_queue)
	preload_timer.autostart = true
	add_child(preload_timer)

# 🎯 增强的缓存查询接口（性能优化版）
func get_cached_texture(key: String) -> ImageTexture:
	var start_time = Time.get_ticks_usec()
	
	# 🚀 优化1: 使用查找表快速定位
	if _cache_lookup_table.has(key):
		var cache_type = _cache_lookup_table[key]
		var texture = null
		
		match cache_type:
			"quick":
				texture = _quick_cache[key].texture
				_performance_stats.quick_cache_hits += 1
				cache_hit.emit(key, "quick")
			"predictive":
				texture = _predictive_cache[key].texture
				_performance_stats.predictive_hits += 1
				cache_hit.emit(key, "predictive")
			"global":
				texture = _global_cache[key].texture
				_performance_stats.cache_hits += 1
				cache_hit.emit(key, "global")
		
		if texture:
			# 更新最后使用时间
			_update_last_used_time(key, cache_type)
			
			var lookup_time = (Time.get_ticks_usec() - start_time) / 1000.0
			if config and config.debug_mode >= 4:
				print("⚡ [Cache] 快速命中 %s (%.1fms)" % [cache_type, lookup_time])
			
			return texture
	
	# 缓存未命中
	_performance_stats.cache_misses += 1
	cache_miss.emit(key)
	return null

# 🚀 新增：更新最后使用时间（优化版）
func _update_last_used_time(key: String, cache_type: String):
	var current_time = Time.get_ticks_msec()
	match cache_type:
		"quick":
			if _quick_cache.has(key):
				_quick_cache[key].last_used = current_time
		"predictive":
			if _predictive_cache.has(key):
				_predictive_cache[key].last_used = current_time
		"global":
			if _global_cache.has(key):
				_global_cache[key].last_used = current_time

# 🎯 增强的缓存存储接口（性能优化版）
func store_texture(key: String, texture: ImageTexture, cache_type: String = "global"):
	if not texture:
		push_warning("[Cache] 尝试存储空纹理")
		return
	
	var cache_entry = {
		"texture": texture,
		"last_used": Time.get_ticks_msec(),
		"size_mb": _estimate_texture_size_mb(texture),
		"computation_time": 0.0
	}
	
	# 🚀 优化：同时更新缓存和查找表
	match cache_type:
		"global":
			_global_cache[key] = cache_entry
		"predictive":
			_predictive_cache[key] = cache_entry
		"quick":
			_quick_cache[key] = cache_entry
		_:
			push_warning("[Cache] 未知的缓存类型: " + cache_type)
			return
	
	# 更新查找表
	_cache_lookup_table[key] = cache_type
	
	_update_memory_usage()
	_check_memory_limit()

# 🚀 新增：预加载纹理（后台处理）
func preload_texture_for_character(character_name: String, qinggong_skill: int, position: Vector2):
	var preload_item = {
		"character_name": character_name,
		"qinggong_skill": qinggong_skill,
		"position": position,
		"timestamp": Time.get_ticks_msec(),
		"priority": 1  # 1=高优先级，2=中等，3=低优先级
	}
	
	_preload_queue.append(preload_item)
	
	if config and config.debug_mode >= 3:
		print("📥 [Cache] 添加预加载任务: %s" % character_name)

# 🚀 新增：处理预加载队列
func _process_preload_queue():
	if _preload_queue.is_empty():
		return
	
	# 每次只处理一个，避免阻塞
	var item = _preload_queue.pop_front()
	_execute_preload_item(item)

func _execute_preload_item(item: Dictionary):
	var char_name = item.character_name
	var qinggong = item.qinggong_skill
	var position = item.position
	
	# 生成预加载的缓存key
	var preload_key = "preload_%s_%d_%.0f_%.0f" % [char_name, qinggong, position.x, position.y]
	
	# 检查是否已存在
	if _cache_lookup_table.has(preload_key):
		return
	
	# 创建简化的预览纹理
	var preview_texture = _create_simple_preview_texture(qinggong)
	if preview_texture:
		store_texture(preload_key, preview_texture, "quick")
		preload_completed.emit(char_name)
		
		if config and config.debug_mode >= 3:
			print("✅ [Cache] 预加载完成: %s" % char_name)

# 🚀 新增：创建简化预览纹理
func _create_simple_preview_texture(qinggong_skill: int) -> ImageTexture:
	var resolution = 64  # 固定低分辨率
	var image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var center = Vector2(int(resolution / 2), int(resolution / 2))  # 使用int()函数进行整数除法
	var scale = float(qinggong_skill * 2) / resolution
	
	# 快速圆形填充
	for x in range(resolution):
		for y in range(resolution):
			var distance = Vector2(x, y).distance_to(center) * scale
			if distance <= qinggong_skill:
				var alpha = 0.4 * (1.0 - distance / qinggong_skill)
				image.set_pixel(x, y, Color(0.0, 0.8, 0.0, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

# 🚀 智能预测性缓存更新（优化版）
func _update_predictive_cache():
	if not config or not config.enable_predictive_cache:
		return
	
	if _movement_history.size() < 2:  # 降低要求，提高响应性
		return
	
	# 🚀 异步处理，避免阻塞
	call_deferred("_predict_and_preload")

func _predict_and_preload():
	var recent_movements = _movement_history.slice(-2)  # 只用最近2次
	var predicted_positions = _predict_next_positions_fast(recent_movements)
	
	# 添加到预加载队列而不是批量队列
	for prediction in predicted_positions:
		var char_name = prediction.get("character_name", "unknown")
		preload_texture_for_character(char_name, prediction.range, prediction.position)

# 🚀 快速位置预测（减少计算量）
func _predict_next_positions_fast(movements: Array) -> Array:
	var predictions = []
	
	if movements.size() < 2:
		return predictions
	
	var last_move = movements[-1]
	var prev_move = movements[-2]
	
	# 简化预测：只预测一个最可能的位置
	var direction = last_move.position - prev_move.position
	var predicted_pos = last_move.position + direction
	
	predictions.append({
		"position": predicted_pos,
		"range": last_move.range,
		"character_name": last_move.get("character_name", "unknown"),
		"weight": 1.0
	})
	
	return predictions

# 🚀 新增：记录移动历史
func record_movement_history(position: Vector2, range_val: int):
	var record = {
		"position": position,
		"range": range_val,
		"timestamp": Time.get_ticks_msec()
	}
	
	_movement_history.append(record)
	
	# 只保留最近20条记录
	if _movement_history.size() > 20:
		_movement_history = _movement_history.slice(-20)

# 🚀 新增：批量处理
func add_to_batch_queue(character_id: String, position: Vector2, range_val: int):
	var batch_item = {
		"character_id": character_id,
		"position": position,
		"range": range_val,
		"timestamp": Time.get_ticks_msec()
	}
	_batch_queue.append(batch_item)

func process_batch_queue():
	if _batch_queue.is_empty():
		return
	
	var batch_size = min(3, _batch_queue.size())
	var current_batch = _batch_queue.slice(0, batch_size)
	_batch_queue = _batch_queue.slice(batch_size)
	
	for batch_item in current_batch:
		_execute_batch_computation(batch_item)
	
	_performance_stats.batch_processed += batch_size

func _execute_batch_computation(batch_item: Dictionary):
	var char_id = batch_item.get("character_id", "")
	var position = batch_item.get("position", Vector2.ZERO)
	var range_val = batch_item.get("range", 0)
	
	var cache_key = _generate_batch_cache_key(char_id, position, range_val)
	if not _global_cache.has(cache_key):
		# 通知Controller需要计算这个范围
		_request_background_computation(cache_key, position, range_val)

func _generate_batch_cache_key(char_id: String, position: Vector2, range_val: int) -> String:
	return "batch_%s_%.0f_%.0f_%d" % [char_id, position.x, position.y, range_val]

func _request_background_computation(cache_key: String, position: Vector2, range_val: int):
	# 发送信号请求后台计算
	# 这里可以连接到Controller的后台计算方法
	pass

# 🚀 增强的性能统计
func update_computation_stats(computation_time: float):
	if _performance_stats.avg_compute_time == 0.0:
		_performance_stats.avg_compute_time = computation_time
	else:
		_performance_stats.avg_compute_time = (_performance_stats.avg_compute_time + computation_time) / 2.0

func get_cache_efficiency() -> float:
	var total = _performance_stats.cache_hits + _performance_stats.cache_misses
	if total == 0:
		return 0.0
	return (_performance_stats.cache_hits * 100.0) / total

# 🧹 增强的缓存管理
func clear_all_cache():
	var total_removed = _global_cache.size() + _predictive_cache.size() + _quick_cache.size()
	_global_cache.clear()
	_predictive_cache.clear()
	_quick_cache.clear()
	_movement_history.clear()
	_batch_queue.clear()
	_preload_queue.clear()
	_reset_performance_stats()
	cache_cleaned.emit(total_removed)
	print("🧹 [Cache] 清除所有缓存: %d 项" % total_removed)

# 🚀 新增：清理包含特定信息的缓存条目
func clear_cache_containing(search_pattern: String) -> int:
	var removed_count = 0
	var keys_to_remove = []
	
	# 🚀 优化：批量收集要删除的key
	for key in _cache_lookup_table.keys():
		if search_pattern in key:
			keys_to_remove.append(key)
	
	# 🚀 批量删除，减少Dictionary操作次数
	for key in keys_to_remove:
		var cache_type = _cache_lookup_table[key]
		
		match cache_type:
			"global":
				_global_cache.erase(key)
			"predictive":
				_predictive_cache.erase(key)
			"quick":
				_quick_cache.erase(key)
		
		_cache_lookup_table.erase(key)
		removed_count += 1
	
	if removed_count > 0:
		call_deferred("_update_memory_usage")  # 异步更新，避免阻塞
		cache_cleaned.emit(removed_count)
		
		if config and config.debug_mode >= 2:
			print("🗑️ [Cache] 快速清理匹配缓存 '%s': %d 项" % [search_pattern, removed_count])
	
	return removed_count

# 🚀 新增：清理与特定角色相关的所有缓存
func clear_character_cache(character_name: String) -> int:
	var removed_count = 0
	
	# 清理包含角色名称的缓存
	removed_count += clear_cache_containing(character_name)
	
	# 清理移动历史中该角色的记录
	var old_history_size = _movement_history.size()
	_movement_history = _movement_history.filter(func(record): return not (character_name in str(record)))
	var history_removed = old_history_size - _movement_history.size()
	
	# 清理批量队列中该角色的任务
	var old_queue_size = _batch_queue.size()
	_batch_queue = _batch_queue.filter(func(item): return item.get("character_id", "") != character_name)
	var queue_removed = old_queue_size - _batch_queue.size()
	
	if history_removed > 0 or queue_removed > 0:
		print("🗑️ [Cache] 清理角色 '%s' 相关数据: 历史记录 %d 项, 队列任务 %d 项" % [character_name, history_removed, queue_removed])
	
	return removed_count + history_removed + queue_removed

# 🚀 新增：清理包含任何指定位置的缓存
func clear_position_related_cache(positions: Array) -> int:
	var removed_count = 0
	
	for position in positions:
		var pos_str = "%.0f,%.0f" % [position.x, position.y]
		removed_count += clear_cache_containing(pos_str)
	
	return removed_count

func _cleanup_expired_cache():
	var current_time = Time.get_ticks_msec()
	var removed_count = 0
	
	# 清理5分钟未使用的全局缓存
	var expired_keys = []
	for key in _global_cache.keys():
		if current_time - _global_cache[key].last_used > 300000:  # 5分钟
			expired_keys.append(key)
	
	for key in expired_keys:
		_global_cache.erase(key)
		removed_count += 1
	
	# 清理2分钟未使用的预测缓存
	expired_keys.clear()
	for key in _predictive_cache.keys():
		if current_time - _predictive_cache[key].last_used > 120000:  # 2分钟
			expired_keys.append(key)
	
	for key in expired_keys:
		_predictive_cache.erase(key)
		removed_count += 1
	
	if removed_count > 0:
		_update_memory_usage()
		cache_cleaned.emit(removed_count)
		print("🧹 [Cache] 清理过期缓存: %d 项" % removed_count)

# 📊 详细的性能统计接口
func get_performance_stats() -> Dictionary:
	return _performance_stats.duplicate()

func get_cache_hit_rate() -> float:
	var total = _performance_stats.cache_hits + _performance_stats.cache_misses + _performance_stats.quick_cache_hits
	return 0.0 if total == 0 else ((_performance_stats.cache_hits + _performance_stats.quick_cache_hits) * 100.0) / total

# 📊 详细的性能统计接口（优化版）
func get_detailed_cache_info() -> Dictionary:
	return {
		"global_cache_size": _global_cache.size(),
		"predictive_cache_size": _predictive_cache.size(),
		"quick_cache_size": _quick_cache.size(),  # 🚀 新增
		"lookup_table_size": _cache_lookup_table.size(),  # 🚀 新增
		"memory_usage_mb": _performance_stats.memory_usage_mb,
		"hit_rate": get_cache_hit_rate(),
		"avg_compute_time": _performance_stats.avg_compute_time,
		"movement_history_size": _movement_history.size(),
		"batch_queue_size": _batch_queue.size(),
		"preload_queue_size": _preload_queue.size(),  # 🚀 新增
		"gpu_compute_count": _performance_stats.gpu_compute_count,
		"predictive_hits": _performance_stats.predictive_hits,
		"quick_cache_hits": _performance_stats.quick_cache_hits  # 🚀 新增
	}

# 🔧 内部辅助方法
func _estimate_texture_size_mb(texture: ImageTexture) -> float:
	if not texture:
		return 0.0
	var image = texture.get_image()
	if not image:
		return 0.0
	return (image.get_width() * image.get_height() * 4) / (1024.0 * 1024.0)  # RGBA8

func _update_memory_usage():
	if _pending_cleanup:
		return
	
	_pending_cleanup = true
	call_deferred("_do_memory_update")

func _do_memory_update():
	var total_mb = 0.0
	
	# 快速计算总内存使用
	for entry in _global_cache.values():
		total_mb += entry.size_mb
	for entry in _predictive_cache.values():
		total_mb += entry.size_mb
	for entry in _quick_cache.values():
		total_mb += entry.size_mb
	
	_performance_stats.memory_usage_mb = total_mb
	_pending_cleanup = false

func _check_memory_limit():
	if not config:
		return
	
	if _performance_stats.memory_usage_mb > config.memory_limit_mb:
		memory_warning.emit(_performance_stats.memory_usage_mb, config.memory_limit_mb)
		_force_cleanup_oldest()

func _force_cleanup_oldest():
	var all_entries = []
	
	for key in _global_cache.keys():
		all_entries.append({
			"key": key,
			"last_used": _global_cache[key].last_used,
			"cache_type": "global"
		})
	
	for key in _predictive_cache.keys():
		all_entries.append({
			"key": key,
			"last_used": _predictive_cache[key].last_used,
			"cache_type": "predictive"
		})
	
	for key in _quick_cache.keys():
		all_entries.append({
			"key": key,
			"last_used": _quick_cache[key].last_used,
			"cache_type": "quick"
		})
	
	all_entries.sort_custom(func(a, b): return a.last_used < b.last_used)
	
	var remove_count = int(all_entries.size() / 2)  # 使用int()函数进行整数除法
	var removed = 0
	
	for entry in all_entries:
		if removed >= remove_count:
			break
		
		if entry.cache_type == "global":
			_global_cache.erase(entry.key)
		elif entry.cache_type == "predictive":
			_predictive_cache.erase(entry.key)
		elif entry.cache_type == "quick":
			_quick_cache.erase(entry.key)
		removed += 1
	
	_update_memory_usage()
	cache_cleaned.emit(removed)
	print("🗑️ [Cache] 强制清理: %d 项，当前内存: %.1fMB" % [removed, _performance_stats.memory_usage_mb])

func _reset_performance_stats():
	_performance_stats = {
		"cache_hits": 0,
		"cache_misses": 0,
		"avg_compute_time": 0.0,
		"memory_usage_mb": 0.0,
		"gpu_compute_count": 0,
		"predictive_hits": 0,
		"batch_processed": 0,
		"quick_cache_hits": 0
	} 

# 🚀 新增：获取快速缓存统计
func get_quick_cache_stats() -> Dictionary:
	return {
		"quick_cache_hits": _performance_stats.quick_cache_hits,
		"quick_cache_size": _quick_cache.size(),
		"preload_queue_size": _preload_queue.size()
	}

# 🚀 新增：内存优化：延迟垃圾回收
var _pending_cleanup: bool = false 
 

# 🚀 移动范围显示系统 - 主控制器（增强版）
extends Node
class_name MoveRangeController

# 🧩 组件引用
var config  # 改为动态类型
var cache  # 改为动态类型
var renderer  # 改为动态类型
var input_handler  # 改为动态类型
# validator组件已移除，现在直接使用PositionCollisionManager
var preview_area  # 🚀 新增：Area2D预检测组件

# 📡 信号 - 对外接口
signal move_confirmed(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float)
signal move_cancelled()
signal range_calculated(character: GameCharacter, texture: ImageTexture)

# 🚀 当前状态
var _current_character: GameCharacter = null
var _is_active: bool = false

# 🚀 性能监控和自适应算法选择
var _last_computation_time: float = 0.0
var _performance_threshold: float = 0.1  # 100ms阈值
var _auto_algorithm_selection: bool = true

# 🚀 新增：深度性能监控系统
var _performance_monitor: Dictionary = {
	"frame_times": [],  # 最近帧时间记录
	"computation_times": [],  # 计算时间记录
	"cache_hit_rates": [],  # 缓存命中率记录
	"last_performance_check": 0,
	"performance_warnings": 0,
	"auto_adjustments_made": 0,
	"current_performance_level": "optimal"  # optimal, good, poor, critical
}

var _frame_time_samples: int = 30  # 保留最近30帧的数据
var _performance_check_interval: float = 1.0  # 每秒检查一次性能

func _ready():
	# print("🚀 [Controller] 移动范围系统主控制器初始化完成")
	
	# 获取组件引用
	call_deferred("_setup_component_references")
	call_deferred("_connect_signals")
	
	# 🚀 新增：启动性能监控
	call_deferred("_setup_performance_monitoring")

func _setup_component_references():
	config = get_node("../Config")
	cache = get_node("../Cache")
	renderer = get_node("../Renderer")
	input_handler = get_node("../Input")
	# validator组件已移除
	
	# 🚀 新增：预览区域组件（从场景中获取）
	preview_area = get_node("../PreviewArea")
	if not preview_area:
		# print("⚠️ [Controller] 未找到PreviewArea节点，将动态创建")
		preview_area = MovePreviewArea.new()
		preview_area.name = "PreviewArea"
		get_parent().add_child(preview_area)
	
	if not config or not cache or not renderer or not input_handler:
		push_error("[Controller] 缺少必要的子组件")
	# else:
		# print("🔧 [Controller] 组件引用设置完成（包含优化组件）")

func _connect_signals():
	# 连接输入信号
	if input_handler:
		input_handler.move_confirmed.connect(_on_move_confirmed)
		input_handler.move_cancelled.connect(_on_move_cancelled)
		input_handler.mouse_moved.connect(_on_mouse_moved)
	
	# 连接渲染器信号
	if renderer:
		renderer.texture_ready.connect(_on_texture_ready)
	
	# 🚀 连接Area2D预检测信号
	if preview_area:
		preview_area.collision_state_changed.connect(_on_preview_collision_changed)
		preview_area.preview_position_updated.connect(_on_preview_position_updated)

# 🎯 主要公共接口（优化版 - 集成Area2D预检测）
func show_move_range(character: GameCharacter):
	if not character:
		# print("❌ [Controller] 无效的角色")
		return
	
	_current_character = character
	_is_active = true
	
	# 🚀 设置Area2D预检测系统
	if preview_area:
		var character_node = _get_character_node(character)
		if character_node:
			preview_area.setup_movement_preview_area(character_node)
			# print("✅ [Controller] Area2D预检测系统已启动")
		# else:
			# print("⚠️ [Controller] 无法找到角色节点，跳过Area2D预检测")
	
	# 🎨 UX优化：启动圆形扩张动画 + 异步计算
	if renderer:
		# 🔧 修复：使用角色节点的实际位置而不是GameCharacter的position
		var character_node = _get_character_node(character)
		var actual_position = character_node.position if character_node else character.position
		renderer.start_expanding_circle_animation(character, actual_position)
	
	# 🚀 异步清理缓存，不阻塞显示
	call_deferred("_clear_character_related_cache_async", character)
	
	# 🚀 异步计算精确纹理，同时播放动画
	call_deferred("_calculate_range_texture_with_animation", character)
	
	# 暂时禁用输入处理，直到纹理生成完成
	if input_handler:
		input_handler.set_input_enabled(false)
	
	# print("🎯 [Controller] 显示移动范围（优化模式） - %s (轻功: %d)" % [character.name, character.qinggong_skill])

func hide_move_range():
	# print("🎯 [Controller] 隐藏移动范围")
	
	_is_active = false
	_current_character = null
	
	# 🚀 清理Area2D预检测系统
	if preview_area:
		preview_area._cleanup_preview_area()
	
	# 停止渲染
	if renderer:
		renderer.hide_range()
	
	# 停止输入处理
	if input_handler:
		input_handler.stop_input_handling()

# 🚀 新增：带动画的纹理计算
func _calculate_range_texture_with_animation(character: GameCharacter):
	var cache_key = _generate_cache_key(character)
	
	# 检查是否已有精确缓存
	var cached_texture = null
	if cache:
		cached_texture = cache.get_cached_texture(cache_key)
	
	if cached_texture:
		# 立即完成动画并显示缓存纹理
		call_deferred("_on_texture_ready_with_animation", cached_texture, 0.0)
		# print("📦 [Controller] 使用缓存纹理（快速完成动画）")
		return
	
	# 启动后台计算
	_start_background_texture_computation_with_animation(character, cache_key)

# 🚀 新增：带动画的后台纹理计算
func _start_background_texture_computation_with_animation(character: GameCharacter, cache_key: String):
	# 🚀 修复：在主线程中预先收集障碍物数据和角色位置
	var obstacles_data = _collect_obstacle_data_safely(character)
	# 🔧 修复：在主线程中获取角色节点的实际位置
	var character_node = _get_character_node(character)
	var char_position = character_node.position if character_node else character.position
	
	# 使用WorkerThreadPool进行真正的后台计算
	if config and config.enable_threading:
		var callable = _compute_texture_in_background_animated.bind(character, cache_key, obstacles_data, char_position)
		WorkerThreadPool.add_task(callable)
		# print("🧵 [Controller] 启动后台纹理计算（动画模式）")
	else:
		# 主线程分帧计算（保持动画流畅）
		_start_framewise_computation_animated(character, cache_key)

# 🚀 新增：带动画的后台纹理计算方法
func _compute_texture_in_background_animated(character: GameCharacter, cache_key: String, obstacles_data: Array, char_position: Vector2):
	var start_time = Time.get_ticks_msec()
	
	# 在后台线程中计算纹理（使用预先收集的障碍物数据和角色位置）
	var texture: ImageTexture = null
	if _should_use_gpu_computation(character):
		texture = _calculate_range_texture_gpu_with_obstacles(character, obstacles_data, char_position)
	else:
		texture = _calculate_range_texture_cpu_with_obstacles(character, obstacles_data, char_position)
	
	var computation_time = (Time.get_ticks_msec() - start_time) / 1000.0
	
	# 回到主线程更新UI（带动画）
	call_deferred("_on_texture_ready_with_animation", texture, computation_time)

# 🚀 新增：安全收集障碍物数据（主线程）
func _collect_obstacle_data_safely(character: GameCharacter) -> Array:
	var obstacles = []
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if not battle_scene:
		return obstacles
	
	var search_radius = character.qinggong_skill + 50
	
	# 🔧 恢复精确的胶囊形状障碍物检测
	for node in battle_scene.get_children():
		if not node.is_in_group("party_members"):
			continue
		
		var char_data = node.get_character_data() if node.has_method("get_character_data") else null
		if not char_data or char_data.id == character.id:
			continue
		
		var distance = character.position.distance_to(node.position)
		if distance <= search_radius:
			# 获取精确的碰撞形状信息
			var character_area = node.get_node_or_null("CharacterArea")
			if not character_area:
				continue
			
			var collision_shape = character_area.get_node_or_null("CollisionShape2D")
			if not collision_shape or not collision_shape.shape:
				continue
			
			# 构建完整的障碍物数据
			obstacles.append({
				"position": node.position,
				"shape": collision_shape.shape,
				"character_id": char_data.id
			})
	
	return obstacles

# 🚀 新增：带障碍物数据的CPU纹理计算
func _calculate_range_texture_cpu_with_obstacles(character: GameCharacter, obstacles_data: Array, char_position: Vector2) -> ImageTexture:
	if not renderer:
		return null
	
	var resolution = _get_adaptive_resolution(character)
	# 🔧 修复：传递角色地面Y坐标参数
	var char_ground_y = character.ground_position.y
	return renderer._compute_range_texture_cpu_with_obstacles(character, resolution, obstacles_data, char_position, char_ground_y)

# 🚀 新增：带障碍物数据的GPU纹理计算
func _calculate_range_texture_gpu_with_obstacles(character: GameCharacter, obstacles_data: Array, char_position: Vector2) -> ImageTexture:
	if not renderer:
		return _calculate_range_texture_cpu_with_obstacles(character, obstacles_data, char_position)
	
	var resolution = _get_adaptive_resolution(character)
	return renderer.compute_range_texture_gpu_with_obstacles(character, resolution, obstacles_data, char_position)

# 🚀 新增：纹理准备完成回调（带动画）
func _on_texture_ready_with_animation(texture: ImageTexture, computation_time: float):
	if not texture or not _is_active:
		return
	
	# 记录计算时间用于性能监控
	if computation_time > 0:
		_performance_monitor.computation_times.append(computation_time * 1000.0)
		if _performance_monitor.computation_times.size() > 10:
			_performance_monitor.computation_times.pop_front()
		
		# 存储到缓存
		if cache:
			var cache_key = _generate_cache_key(_current_character)
			cache.store_texture(cache_key, texture)
			cache.update_computation_stats(computation_time)
	
	# 🚀 修复：确保扩张动画完成后再淡入纹理
	if renderer:
		if renderer._animation_type == "expanding_circle" and renderer._animation_progress < 1.0:
			# 扩张动画还没完成，等待完成后再淡入
			renderer._pending_fade_texture = texture
			# print("🎨 [Controller] 纹理准备完成，等待扩张动画结束")
		else:
			# 扩张动画已完成或不在扩张状态，立即开始淡入
			# 🔧 修复：使用角色节点的实际位置
			var character_node = _get_character_node(_current_character)
			var actual_position = character_node.position if character_node else _current_character.position
			print("🎨 [DEBUG] Controller调用complete_animation - character_node: %s" % character_node)
			print("🎨 [DEBUG] Controller调用complete_animation - actual_position: %s" % actual_position)
			print("🎨 [DEBUG] Controller调用complete_animation - renderer当前位置: %s" % renderer.global_position)
			renderer.complete_animation_and_fade_in_texture(texture, _current_character, actual_position)
			_enable_input_after_animation()
	
	var time_str = "%.1fms" % (computation_time * 1000) if computation_time > 0 else "缓存"
	# print("🧮 [Controller] 纹理生成完成，用时: %s" % time_str)

# 🚀 新增：动画完成后启用输入
func _enable_input_after_animation():
	# 重新启用输入处理
	if input_handler:
		input_handler.set_input_enabled(true)
		input_handler.start_input_handling(_current_character)

# 🚀 新增：带动画的分帧计算
func _start_framewise_computation_animated(character: GameCharacter, cache_key: String):
	# 🚀 修复：预先收集障碍物数据，避免每帧重复扫描
	var obstacles_data = _collect_obstacle_data_safely(character)
	
	# 分帧计算，但保持动画流畅（减少每帧处理量）
	var computation_data = {
		"character": character,
		"cache_key": cache_key,
		"start_time": Time.get_ticks_msec(),
		"current_chunk": 0,
		"total_chunks": 16,  # 🚀 减少分帧数以提高效率（原32改为16）
		"image": null,
		"resolution": _get_adaptive_resolution(character),
		"obstacles_data": obstacles_data,  # 🚀 预先收集的障碍物数据
		"animated": true
	}
	
	_framewise_data = computation_data
	set_process(true)  # 🚀 确保启用处理
	# print("📊 [Controller] 启动分帧计算（动画友好模式）- 障碍物: %d" % obstacles_data.size())

# 🚀 新增：分帧计算处理器
var _framewise_data: Dictionary = {}

func _process(delta):
	if not config or not config.enable_performance_monitoring:
		# 处理分帧计算
		if not _framewise_data.is_empty():
			_process_texture_chunk()
		return
	
	# 记录帧时间
	_record_frame_time(delta)
	
	# 处理分帧计算
	if not _framewise_data.is_empty():
		_process_texture_chunk()

func _process_texture_chunk():
	var data = _framewise_data
	var character = data.character
	var resolution = data.resolution
	var chunk_size = int(resolution / data.total_chunks)  # 使用int()函数进行整数除法
	var current_chunk = data.current_chunk
	
	# 初始化图像
	if not data.image:
		data.image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	
	# 处理当前块
	var start_y = current_chunk * chunk_size
	var end_y = min((current_chunk + 1) * chunk_size, resolution)
	
	_compute_texture_chunk(data.image, character, start_y, end_y, resolution)
	
	data.current_chunk += 1
	
	# 检查是否完成
	if data.current_chunk >= data.total_chunks:
		_finalize_framewise_computation()

# 🚀 新增：计算纹理块（优化版）
func _compute_texture_chunk(image: Image, character: GameCharacter, start_y: int, end_y: int, resolution: int):
	var max_range = character.qinggong_skill
	var half_size = int(resolution / 2)
	var pixel_scale = float(max_range * 2) / resolution
	var char_position = character.position
	var char_ground_y = character.ground_position.y
	
	# 🚀 使用预先收集的障碍物数据
	var obstacles_data = _framewise_data.get("obstacles_data", [])
	
	for y in range(start_y, end_y):
		for x in range(resolution):
			var local_x = (x - half_size) * pixel_scale
			var local_y = (y - half_size) * pixel_scale
			var world_pos = char_position + Vector2(local_x, local_y)
			
			# 🚀 使用验证器进行完整验证（但使用预先收集的障碍物数据）
			var is_valid = _validate_position_fast(char_position, world_pos, max_range, char_ground_y, obstacles_data)
			
			if is_valid:
				# 🟢 可移动区域
				var color = Color.GREEN
				color.a = 0.6
				image.set_pixel(x, y, color)
			else:
				# 🚀 区分圆形范围外和障碍物阻挡
				var distance = char_position.distance_to(world_pos)
				if distance > max_range:
					# 圆形范围外：设为透明
					image.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					# 🔴 范围内但被阻挡的区域
					var color = Color.RED
					color.a = 0.6
					image.set_pixel(x, y, color)

# 🚀 新增：快速位置验证（使用预先收集的数据）
func _validate_position_fast(char_pos: Vector2, target_pos: Vector2, max_range: int, char_ground_y: float, obstacles_data: Array) -> bool:
	# 检查1：圆形范围检查
	var distance = char_pos.distance_to(target_pos)
	if distance > max_range:
		return false
	
	# 检查2：地面限制检查
	if target_pos.y > char_ground_y:
		return false
	
	# 检查3：障碍物碰撞检查（使用预先收集的数据）
	for obstacle_data in obstacles_data:
		if _point_intersects_capsule_fast(target_pos, obstacle_data):
			return false
	
	return true

# 🚀 新增：快速胶囊体碰撞检测
func _point_intersects_capsule_fast(point: Vector2, obstacle_data: Dictionary) -> bool:
	var shape = obstacle_data.shape
	var obstacle_pos = obstacle_data.position
	
	if shape is CapsuleShape2D:
		return _point_in_capsule_fast(point, obstacle_pos, shape as CapsuleShape2D)
	elif shape is CircleShape2D:
		return _point_in_circle_fast(point, obstacle_pos, shape as CircleShape2D)
	elif shape is RectangleShape2D:
		return _point_in_rectangle_fast(point, obstacle_pos, shape as RectangleShape2D)
	
	return false

# 🚀 新增：快速碰撞检测方法
func _point_in_capsule_fast(point: Vector2, capsule_pos: Vector2, capsule: CapsuleShape2D) -> bool:
	var radius = capsule.radius
	var height = capsule.height
	var local_point = point - capsule_pos
	var rect_height = height - 2 * radius
	
	if rect_height > 0:
		if abs(local_point.x) <= radius and abs(local_point.y) <= rect_height / 2:
			return true
		var top_center = Vector2(0, -rect_height / 2)
		var bottom_center = Vector2(0, rect_height / 2)
		return (local_point.distance_to(top_center) <= radius or 
				local_point.distance_to(bottom_center) <= radius)
	else:
		return local_point.length() <= radius

func _point_in_circle_fast(point: Vector2, circle_pos: Vector2, circle: CircleShape2D) -> bool:
	var distance = point.distance_to(circle_pos)
	return distance <= circle.radius

func _point_in_rectangle_fast(point: Vector2, rect_pos: Vector2, rect: RectangleShape2D) -> bool:
	var local_point = point - rect_pos
	var half_size = rect.size / 2
	return (abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y)

# 🚀 新增：完成分帧计算
func _finalize_framewise_computation():
	var data = _framewise_data
	var computation_time = (Time.get_ticks_msec() - data.start_time) / 1000.0
	
	# 创建纹理
	var texture = ImageTexture.new()
	texture.set_image(data.image)
	
	# 存储和显示（根据是否为动画模式选择回调）
	if data.get("animated", false):
		_on_texture_ready_with_animation(texture, computation_time)
	else:
		_on_background_texture_ready(texture, data.cache_key, computation_time)
	
	# 清理
	_framewise_data.clear()
	set_process(false)
	
	var mode_str = "动画友好" if data.get("animated", false) else "普通"
	# print("📊 [Controller] 分帧计算完成（%s），总用时: %.1fms" % [mode_str, computation_time * 1000])

# 🚀 新增：异步缓存清理
func _clear_character_related_cache_async(character: GameCharacter):
	if not cache:
		return
	
	# 只清理明显过时的缓存，不做完整清理
	var removed_count = cache.clear_character_cache(character.name)
	
	# if config and config.debug_mode >= 2 and removed_count > 0:
		# print("🗑️ [Controller] 异步清理缓存: %d 项" % removed_count)

# 🚀 保留原来的后台计算完成回调（用于非动画模式）
func _on_background_texture_ready(texture: ImageTexture, cache_key: String, computation_time: float):
	if not texture or not _is_active:
		return
	
	# 记录计算时间用于性能监控
	_performance_monitor.computation_times.append(computation_time * 1000.0)
	if _performance_monitor.computation_times.size() > 10:
		_performance_monitor.computation_times.pop_front()
	
	# 存储到缓存
	if cache:
		cache.store_texture(cache_key, texture)
		cache.update_computation_stats(computation_time)
	
	# 更新显示
	if renderer and _current_character:
		# 🔧 修复：使用角色节点的实际位置
		var character_node = _get_character_node(_current_character)
		var actual_position = character_node.position if character_node else _current_character.position
		renderer.update_display(texture, _current_character, actual_position)
	
	# print("🧮 [Controller] 后台计算完成，用时: %.1fms" % (computation_time * 1000))

# 🚀 智能算法选择
func _calculate_range_texture_smart(character: GameCharacter) -> ImageTexture:
	var cache_key = _generate_cache_key(character)
	
	# 1. 尝试从缓存获取
	var cached_texture = null
	if cache:
		cached_texture = cache.get_cached_texture(cache_key)
	
	if cached_texture:
		# print("📦 [Controller] 使用缓存纹理")
		return cached_texture
	
	# 2. 选择计算算法
	var texture: ImageTexture = null
	var start_time = Time.get_ticks_msec()
	
	if _should_use_gpu_computation(character):
		texture = _calculate_range_texture_gpu(character)
	else:
		texture = _calculate_range_texture_cpu(character)
	
	_last_computation_time = (Time.get_ticks_msec() - start_time) / 1000.0
	
	# 3. 更新性能统计
	if cache:
		cache.update_computation_stats(_last_computation_time)
	
	# 4. 存储到缓存
	if cache and texture:
		cache.store_texture(cache_key, texture)
	
	# 5. 自适应算法调整
	if _auto_algorithm_selection:
		_adjust_algorithm_selection()
	
	# print("🧮 [Controller] 计算新纹理完成，用时: %.1fms" % (_last_computation_time * 1000))
	return texture

# 🚀 判断是否应该使用GPU计算
func _should_use_gpu_computation(character: GameCharacter) -> bool:
	if not config or not config.is_gpu_enabled():
		return false
	
	if not renderer:
		return false
	
	# 基于复杂度决策
	var max_range = character.qinggong_skill
	var complexity_score = max_range * config.texture_resolution / 100000.0
	
	# 复杂度高或上次CPU计算时间过长时使用GPU
	return complexity_score > 2.0 or _last_computation_time > _performance_threshold

# 🚀 GPU纹理计算
func _calculate_range_texture_gpu(character: GameCharacter) -> ImageTexture:
	if not renderer:
		return _calculate_range_texture_cpu(character)
	
	var resolution = _get_adaptive_resolution(character)
	return renderer.compute_range_texture_gpu(character, resolution)

# 🚀 CPU纹理计算
func _calculate_range_texture_cpu(character: GameCharacter) -> ImageTexture:
	if not renderer:
		return null
	
	var resolution = _get_adaptive_resolution(character)
	return renderer._compute_range_texture_cpu(character, resolution)

# 🚀 自适应分辨率调整
func _get_adaptive_resolution(character: GameCharacter) -> int:
	if not config:
		return 256
	
	var base_resolution: int
	var max_range = character.qinggong_skill
	
	if max_range <= 200:
		base_resolution = 128
	elif max_range <= 400:
		base_resolution = 256
	elif max_range <= 600:
		base_resolution = 512
	else:
		base_resolution = 1024
	
	# GPU计算时可以使用更高分辨率
	if config.is_gpu_enabled():
		return min(base_resolution * 2, 2048)
	else:
		return base_resolution

# 🚀 自适应算法调整
func _adjust_algorithm_selection():
	if not _auto_algorithm_selection:
		return
	
	# 如果性能不达标，降低质量设置
	if _last_computation_time > _performance_threshold * 2:
		if config and config.adaptive_resolution:
			# 可以动态调整分辨率
			pass
		# print("⚠️ [Controller] 性能警告，考虑降低质量设置")

# 🧮 原来的基础范围计算（保持兼容性）
func _compute_range_texture(character: GameCharacter) -> ImageTexture:
	return _calculate_range_texture_cpu(character)

func _generate_cache_key(character: GameCharacter) -> String:
	var resolution = _get_adaptive_resolution(character)
	var algorithm = "gpu" if _should_use_gpu_computation(character) else "cpu"
	
	# 🔧 基础key：角色信息 + 分辨率 + 算法
	var key_parts = [
		character.name,
		str(character.qinggong_skill),
		str(resolution),
		algorithm,
		"%.0f,%.0f" % [character.position.x, character.position.y]  # 当前角色位置
	]
	
	# 🚀 关键修复：包含所有可能影响移动范围的其他角色位置
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if battle_scene:
		var other_positions = []
		var max_range = character.qinggong_skill
		
		# 找到所有在影响范围内的角色
		for node in battle_scene.get_children():
			if not node.is_in_group("party_members"):
				continue
			
			var character_data = node.get_character_data() if node.has_method("get_character_data") else null
			if not character_data or character_data.id == character.id:
				continue
			
			# 只包含可能影响移动范围的角色（距离在移动范围+安全边距内）
			var distance_to_current = character.position.distance_to(node.position)
			if distance_to_current <= max_range + 100:  # 安全边距100像素
				# 位置取整以提高缓存命中率，但保持足够精度
				other_positions.append("%.0f,%.0f" % [node.position.x, node.position.y])
		
		# 排序确保一致性
		other_positions.sort()
		if other_positions.size() > 0:
			key_parts.append("others:" + "|".join(other_positions))
	
	var final_key = "|".join(key_parts)
	
	# 🔍 调试输出
	# if config and config.debug_mode >= 3:
		# print("🔑 [Controller] 缓存key: %s" % final_key.substr(0, 80))
	
	return final_key

# 📡 信号处理
func _on_move_confirmed(character: GameCharacter, target_position: Vector2, target_height: float, movement_cost: float):
	# print("✅ [Controller] 移动确认 - %s -> %s, 高度: %.1f级, 成本: %.1f" % [character.name, str(target_position), target_height, movement_cost])
	move_confirmed.emit(character, target_position, target_height, movement_cost)
	hide_move_range()

func _on_move_cancelled():
	# print("❌ [Controller] 移动取消")
	move_cancelled.emit()
	hide_move_range()

func _on_mouse_moved(position: Vector2):
	# 🎨 更新可视化碰撞体位置
	if preview_area:
		preview_area.update_preview_position(position)
		

func _on_texture_ready(texture: ImageTexture):
	# 纹理计算完成的回调
	if renderer:
		renderer.set_pending_texture(texture)

# 🎯 状态查询接口
func is_active() -> bool:
	return _is_active

func get_current_character() -> GameCharacter:
	return _current_character

# 🚀 新增：性能监控接口
func get_last_computation_time() -> float:
	return _last_computation_time

func get_performance_info() -> Dictionary:
	var info = {
		"last_computation_time": _last_computation_time,
		"performance_threshold": _performance_threshold,
		"auto_algorithm_selection": _auto_algorithm_selection,
		"current_algorithm": "gpu" if _should_use_gpu_computation(_current_character) else "cpu" if _current_character else "none"
	}
	
	# 添加深度性能监控信息
	if config and config.enable_performance_monitoring:
		info.merge({
			"average_frame_time_ms": _calculate_average_frame_time(),
			"average_computation_time_ms": _calculate_average_computation_time(),
			"current_performance_level": _performance_monitor.current_performance_level,
			"performance_warnings": _performance_monitor.performance_warnings,
			"auto_adjustments_made": _performance_monitor.auto_adjustments_made,
			"cache_hit_rate": _get_current_cache_hit_rate()
		})
	
	if cache:
		info.merge(cache.get_detailed_cache_info())
	
	return info

func set_performance_threshold(threshold: float):
	_performance_threshold = threshold
	# print("🎯 [Controller] 性能阈值设置为: %.1fms" % (threshold * 1000))

func set_auto_algorithm_selection(enabled: bool):
	_auto_algorithm_selection = enabled
	# print("🎯 [Controller] 自动算法选择: %s" % ("启用" if enabled else "禁用"))

# 🔧 工具方法
func clear_cache():
	if cache:
		cache.clear_all_cache()

func get_performance_stats() -> Dictionary:
	if cache:
		return cache.get_performance_stats()
	return {}

func get_cache_info() -> Dictionary:
	if cache:
		return cache.get_detailed_cache_info()
	return {}

# 🚀 新增：批量处理接口
func process_batch_queue():
	if cache:
		cache.process_batch_queue()

func add_to_batch_queue(character_id: String, position: Vector2, range_val: int):
	if cache:
		cache.add_to_batch_queue(character_id, position, range_val)

# 🚀 新增：调试和测试接口
func force_gpu_mode(enabled: bool):
	if config:
		config.enable_gpu_compute = enabled
		# print("🔧 [Controller] 强制GPU模式: %s" % ("启用" if enabled else "禁用"))

func force_resolution(resolution: int):
	if config:
		config.texture_resolution = resolution
		# print("🔧 [Controller] 强制分辨率: %dx%d" % [resolution, resolution])

func get_algorithm_recommendation(character: GameCharacter) -> String:
	if not character:
		return "none"
	
	return "gpu" if _should_use_gpu_computation(character) else "cpu"

# 🚀 新增：启动性能监控
func _setup_performance_monitoring():
	if not config or not config.enable_performance_monitoring:
		return
	
	# 启动性能监控定时器
	var perf_timer = Timer.new()
	perf_timer.wait_time = _performance_check_interval
	perf_timer.timeout.connect(_check_performance)
	perf_timer.autostart = true
	add_child(perf_timer)
	
	# 设置帧时间监控
	set_process(true)  # 启用_process进行帧时间监控
	
	# print("📊 [Controller] 性能监控系统已启动")

# 🚀 新增：记录帧时间
func _record_frame_time(delta: float):
	var frame_time_ms = delta * 1000.0
	_performance_monitor.frame_times.append(frame_time_ms)
	
	# 只保留最近的帧时间样本
	if _performance_monitor.frame_times.size() > _frame_time_samples:
		_performance_monitor.frame_times.pop_front()

# 🚀 新增：性能检查
func _check_performance():
	if not config or not config.enable_performance_monitoring:
		return
	
	var current_time = Time.get_ticks_msec()
	_performance_monitor.last_performance_check = current_time
	
	# 计算性能指标
	var avg_frame_time = _calculate_average_frame_time()
	var avg_computation_time = _calculate_average_computation_time()
	var cache_hit_rate = _get_current_cache_hit_rate()
	
	# 更新性能级别
	var new_level = _determine_performance_level(avg_frame_time, avg_computation_time)
	var old_level = _performance_monitor.current_performance_level
	_performance_monitor.current_performance_level = new_level
	
	# 记录性能数据
	_performance_monitor.cache_hit_rates.append(cache_hit_rate)
	if _performance_monitor.cache_hit_rates.size() > 10:
		_performance_monitor.cache_hit_rates.pop_front()
	
	# 性能警告检查
	if avg_frame_time > config.performance_warning_threshold:
		_performance_monitor.performance_warnings += 1
		print("⚠️ [Performance] 性能警告: 平均帧时间 %.1fms 超过阈值 %.1fms" % [avg_frame_time, config.performance_warning_threshold])
	
	# 自动性能调整
	if config.performance_auto_adjust and new_level != old_level:
		_auto_adjust_performance(new_level)
	
	# 定期性能报告 - 修复类型不匹配
	var log_interval_ms = int(config.performance_log_interval * 1000)
	if _performance_monitor.last_performance_check % log_interval_ms < 1000:
		_log_performance_report(avg_frame_time, avg_computation_time, cache_hit_rate)

# 🚀 新增：计算平均帧时间
func _calculate_average_frame_time() -> float:
	if _performance_monitor.frame_times.is_empty():
		return 0.0
	
	var total = 0.0
	for time in _performance_monitor.frame_times:
		total += time
	
	return total / _performance_monitor.frame_times.size()

# 🚀 新增：计算平均计算时间
func _calculate_average_computation_time() -> float:
	if _performance_monitor.computation_times.is_empty():
		return 0.0
	
	var total = 0.0
	for time in _performance_monitor.computation_times:
		total += time
	
	return total / _performance_monitor.computation_times.size()

# 🚀 新增：获取当前缓存命中率
func _get_current_cache_hit_rate() -> float:
	if not cache:
		return 0.0
	
	return cache.get_cache_hit_rate()

# 🚀 新增：确定性能级别
func _determine_performance_level(avg_frame_time: float, avg_computation_time: float) -> String:
	var target_frame_time = config.target_frame_time_ms
	
	if avg_frame_time <= target_frame_time * 0.8:
		return "optimal"  # 优秀：低于80%目标帧时间
	elif avg_frame_time <= target_frame_time:
		return "good"     # 良好：在目标帧时间内
	elif avg_frame_time <= target_frame_time * 1.5:
		return "poor"     # 较差：超过目标帧时间50%
	else:
		return "critical" # 糟糕：严重超过目标帧时间

# 🚀 新增：自动性能调整
func _auto_adjust_performance(performance_level: String):
	if not config:
		return
	
	_performance_monitor.auto_adjustments_made += 1
	
	match performance_level:
		"critical":
			# 严重性能问题：激进优化
			config.enable_quick_preview = true
			config.enable_framewise_computation = true
			config.texture_resolution = min(config.texture_resolution, 128)
			config.framewise_chunks = max(int(config.framewise_chunks / 2), 8)  # 使用int()函数进行整数除法
			config.simplified_obstacle_detection = true
			print("🚨 [Performance] 激进优化: 降低分辨率至 %d, 增加分帧至 %d" % [config.texture_resolution, config.framewise_chunks])
		
		"poor":
			# 性能较差：适度优化
			config.enable_quick_preview = true
			config.texture_resolution = min(config.texture_resolution, 256)
			config.framewise_chunks = max(int(config.framewise_chunks / 2), 8)  # 使用int()函数进行整数除法
			print("🔧 [Performance] 适度优化: 分辨率 %d, 分帧 %d" % [config.texture_resolution, config.framewise_chunks])
		
		"good":
			# 性能良好：保持当前设置
			pass
		
		"optimal":
			# 性能优秀：可以提升质量
			if config.texture_resolution < 512:
				config.texture_resolution = min(config.texture_resolution * 2, 512)
				config.framewise_chunks = max(int(config.framewise_chunks / 2), 8)  # 使用int()函数进行整数除法
				print("⬆️ [Performance] 性能提升: 分辨率 %d, 分帧 %d" % [config.texture_resolution, config.framewise_chunks])

# 🚀 新增：性能报告日志
func _log_performance_report(avg_frame_time: float, avg_computation_time: float, cache_hit_rate: float):
	print("📊 [Performance Report] ═══════════════════════")
	print("   平均帧时间: %.1fms (目标: %.1fms)" % [avg_frame_time, config.target_frame_time_ms])
	print("   平均计算时间: %.1fms" % avg_computation_time)
	print("   缓存命中率: %.1f%%" % cache_hit_rate)
	print("   性能级别: %s" % _performance_monitor.current_performance_level)
	print("   性能警告数: %d" % _performance_monitor.performance_warnings)
	print("   自动调整次数: %d" % _performance_monitor.auto_adjustments_made)
	
	if cache:
		var cache_info = cache.get_detailed_cache_info()
		print("   缓存详情: 全局=%d, 预测=%d, 快速=%d" % [
			cache_info.global_cache_size,
			cache_info.predictive_cache_size,
			cache_info.get("quick_cache_size", 0)
		])
	
	print("═══════════════════════════════════════════")



# 🚀 新增：Area2D预检测信号处理
func _on_preview_collision_changed(is_colliding: bool, objects: Array):
	"""处理Area2D预检测碰撞状态变化"""
	if not _is_active:
		return
	
	# 更新渲染器的视觉反馈
	if renderer:
		renderer.update_collision_feedback(is_colliding, objects)
	
	# 记录碰撞状态用于调试
	var status = "碰撞" if is_colliding else "无碰撞"
	# print("🎯 [Controller] Area2D预检测状态: %s (对象数: %d)" % [status, objects.size()])

func _on_preview_position_updated(position: Vector2):
	"""处理Area2D预检测位置更新"""
	if not _is_active:
		return
	
	# 可以在这里添加位置相关的逻辑
	# 例如：更新UI指示器、触发额外的验证等
	pass

# 🔧 获取角色节点的辅助方法
func _get_character_node(character: GameCharacter):
	"""根据角色数据获取对应的节点"""
	if not character:
		return null
	
	# 尝试通过BattleScene查找角色节点
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if battle_scene and battle_scene.has_method("_find_character_node_by_id"):
		return battle_scene._find_character_node_by_id(character.id)
	
	return null

# 🚀 强制刷新动态障碍物检测
func force_refresh_dynamic_obstacles():
	"""强制刷新动态障碍物检测，用于同步移动的角色"""
	if preview_area:
		preview_area.force_refresh_collision_detection()
		# print("🔄 [Controller] 强制刷新动态障碍物检测")

# 🎯 获取当前预检测状态
func get_preview_collision_state() -> Dictionary:
	"""获取当前Area2D预检测的碰撞状态"""
	if preview_area:
		return preview_area.get_collision_state()
	else:
		return {
			"is_colliding": false,
			"collision_count": 0,
			"collision_objects": [],
			"preview_active": false
		}

# 🚀 新增：性能重置
func reset_performance_stats():
	_performance_monitor = {
		"frame_times": [],
		"computation_times": [],
		"cache_hit_rates": [],
		"last_performance_check": 0,
		"performance_warnings": 0,
		"auto_adjustments_made": 0,
		"current_performance_level": "optimal"
	}
	print("🔄 [Performance] 性能统计已重置")

# 🚀 新增：强制性能级别
func force_performance_level(level: String):
	_performance_monitor.current_performance_level = level
	_auto_adjust_performance(level)
	print("🔧 [Performance] 强制设置性能级别: %s" % level)
 

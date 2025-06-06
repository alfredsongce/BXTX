# 🎨 移动范围显示系统 - 渲染组件（增强版）
extends Node2D
class_name MoveRangeRenderer

# 🎨 渲染状态
var _current_texture: ImageTexture = null
var _current_character: GameCharacter = null
var _mouse_position: Vector2 = Vector2.ZERO
var _visual_effects_time: float = 0.0
var _animation_phases: Array = []
var _edge_gradient_texture: ImageTexture = null
var _show_invalid_indicator: bool = false  # 🚀 新增：控制X号显示

# 🚀 新增：GPU渲染支持
var _compute_shader: RenderingDevice = null
var _is_computing: bool = false
var _pending_texture: ImageTexture = null
var _mutex: Mutex = null

# 🚀 新增：动画系统状态
var _animation_active: bool = false
var _animation_type: String = ""  # "expanding_circle", "fade_in"
var _animation_progress: float = 0.0
var _animation_duration: float = 1.0
var _target_radius: float = 0.0
var _current_radius: float = 0.0
var _animation_center: Vector2 = Vector2.ZERO
var _fade_in_texture: ImageTexture = null
var _fade_alpha: float = 0.0
var _pending_fade_texture: ImageTexture = null  # 🚀 新增：等待淡入的纹理

# 📡 信号
signal range_shown()
signal range_hidden()
signal mouse_indicator_updated(position: Vector2)
signal texture_ready(texture: ImageTexture)

# 🔧 组件引用
var config  # 改为动态类型
var position_collision_manager  # 🚀 新增：位置碰撞管理器引用

func _ready():
	# print("🎨 [Renderer] 渲染组件初始化完成")
	set_process(true)
	visible = false
	
	# 🔧 设置层级：移动范围应该在人物下方
	z_index = -10  # 负值确保在其他元素下方
	z_as_relative = false  # 使用全局层级
	
	# 初始化互斥锁
	_mutex = Mutex.new()
	
	# 获取配置组件引用
	call_deferred("_setup_config_reference")
	call_deferred("_setup_position_collision_manager_reference")
	call_deferred("_initialize_visual_effects")
	call_deferred("_initialize_gpu_compute")

func _setup_config_reference():
	config = get_node("../Config")
	if not config:
		push_warning("[Renderer] 未找到Config组件")

func _setup_position_collision_manager_reference():
	position_collision_manager = AutoLoad.get_battle_scene().get_node_or_null("BattleSystems/PositionCollisionManager") if AutoLoad.get_battle_scene() else null
	if not position_collision_manager:
		push_warning("[Renderer] 未找到PositionCollisionManager组件")

# 🚀 初始化GPU计算系统
func _initialize_gpu_compute():
	if not config or not config.is_gpu_enabled():
		return
	
	if RenderingServer.get_rendering_device():
		_compute_shader = RenderingServer.get_rendering_device()
		# print("🚀 [Renderer] GPU计算系统初始化成功")
	# else:
		# print("⚠️ [Renderer] 当前平台不支持GPU计算，使用CPU渲染")

# 🎯 主要接口
func update_display(texture: ImageTexture, character: GameCharacter, position: Vector2):
	_current_texture = texture
	_current_character = character
	# 🔧 修复：使用传入的position参数而不是character.position
	global_position = position
	visible = true
	queue_redraw()
	range_shown.emit()
	# print("🎨 [Renderer] 显示移动范围")

func hide_range():
	visible = false
	_current_texture = null
	_current_character = null
	_stop_all_animations()  # 停止所有动画
	range_hidden.emit()
	# print("🎨 [Renderer] 隐藏移动范围")

func update_mouse_indicator(mouse_pos: Vector2):
	_mouse_position = mouse_pos
	
	# 检查位置有效性
	var is_valid = _check_mouse_position_validity()
	
	# 🐛 调试X号显示问题
	# 调试输出已禁用以减少控制台输出
	# if OS.is_debug_build() and Input.is_key_pressed(KEY_CTRL):
	#	print("🐛 [渲染器] 更新鼠标指示器: 位置%s, 有效性%s, 将显示X号: %s" % [mouse_pos, is_valid, not is_valid])
	
	# 更新指示器状态
	_show_invalid_indicator = not is_valid
	
	# 触发重绘
	queue_redraw()
	
	mouse_indicator_updated.emit(mouse_pos)

# 🚀 新增：更新碰撞反馈的视觉效果
func update_collision_feedback(is_colliding: bool, collision_objects: Array):
	"""更新碰撞状态的视觉反馈"""
	if not _current_character:
		return
	
	# 根据碰撞状态更新视觉效果
	# if is_colliding:
		# 有碰撞时的视觉反馈
		# print("🔴 [Renderer] 检测到碰撞，对象数: %d" % collision_objects.size())
		# 可以在这里添加更多视觉效果，比如改变鼠标指示器颜色等
	# else:
		# 无碰撞时的视觉反馈
		# print("🟢 [Renderer] 无碰撞检测")
	
	# 强制重绘以更新视觉效果
	queue_redraw()
	if visible:
		queue_redraw()

# 🚀 新增：GPU纹理计算接口
func compute_range_texture_gpu(character: GameCharacter, texture_resolution: int) -> ImageTexture:
	if not _compute_shader or not character:
		return _compute_range_texture_cpu(character, texture_resolution)
	
	_is_computing = true
	var start_time = Time.get_ticks_msec()
	
	# 🚀 GPU计算的简化实现（在Godot 4中使用优化的CPU计算模拟）
	var texture = _generate_range_texture_gpu_optimized(character, texture_resolution)
	
	var computation_time = (Time.get_ticks_msec() - start_time) / 1000.0
	_is_computing = false
	
	# print("🚀 [Renderer] GPU计算完成，分辨率: %dx%d, 用时: %.1fms" % [
		# texture_resolution, texture_resolution, computation_time * 1000
	# ])
	
	texture_ready.emit(texture)
	return texture

# 🚀 GPU优化的纹理生成（像素级精度版）
func _generate_range_texture_gpu_optimized(character: GameCharacter, resolution: int) -> ImageTexture:
	if not character:
		return null
	
	# print("🚀 [Renderer] GPU优化纹理生成: 角色=%s, 轻功=%d" % [character.name, character.qinggong_skill])
	
	var image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	if not image:
		return null
	
	var max_range = character.qinggong_skill
	# 🔧 修复：获取角色节点的实际位置
	var character_node = _get_character_node(character)
	var char_position = character_node.position if character_node else character.position
	var char_ground_y = character.ground_position.y
	var pixel_scale = float(max_range * 2) / resolution
	var half_resolution = resolution / 2
	
	# 🔧 获取障碍物数据（使用位置碰撞管理器）
	var obstacle_characters = []
	if position_collision_manager:
		obstacle_characters = position_collision_manager._get_obstacle_characters_cached(character.id)
	
	# 🚀 GPU友好的块处理（模拟并行计算）
	var chunk_size = 32  # 减小块大小以提高精度
	for chunk_x in range(0, resolution, chunk_size):
		for chunk_y in range(0, resolution, chunk_size):
			_process_gpu_chunk_precise(image, chunk_x, chunk_y, chunk_size, resolution, 
										 half_resolution, pixel_scale, max_range, 
										 char_position, char_ground_y, obstacle_characters)
	
	var texture = ImageTexture.new()
	if texture:
		texture.set_image(image)
	# print("🚀 [Renderer] GPU优化纹理生成完成，分辨率: %dx%d" % [resolution, resolution])
	return texture

# 🚀 处理GPU计算块（精确版本）
func _process_gpu_chunk_precise(image: Image, start_x: int, start_y: int, chunk_size: int, 
							   resolution: int, half_resolution: int, pixel_scale: float, 
							   max_range: int, char_position: Vector2, char_ground_y: float, 
							   obstacles: Array):
	var end_x = min(start_x + chunk_size, resolution)
	var end_y = min(start_y + chunk_size, resolution)
	
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			# 计算世界坐标
			var local_x = (x - half_resolution) * pixel_scale
			var local_y = (y - half_resolution) * pixel_scale
			var world_pos = char_position + Vector2(local_x, local_y)
			
			# 执行所有检查 - 使用位置碰撞管理器（移除高度限制检查）
			var is_movable = true
			if position_collision_manager:
				# 检查1：圆形范围
				if not position_collision_manager._check_circular_range(char_position, world_pos, max_range):
					is_movable = false
				# 检查2：地面限制
				elif not position_collision_manager._check_ground_limit_comprehensive(world_pos, char_ground_y):
					is_movable = false
				# 检查3：障碍物碰撞
				elif not position_collision_manager._check_capsule_obstacles_comprehensive(world_pos, obstacles):
					is_movable = false
			else:
				is_movable = false  # 如果位置碰撞管理器不可用，标记为不可移动
			
			# 设置像素颜色
			if is_movable:
				# 🟢 纯绿色表示可移动区域（不要渐变）
				var color = Color.GREEN
				color.a = 0.6  # 固定透明度
				image.set_pixel(x, y, color)
			else:
				# 🚀 修复：区分圆形范围外和障碍物阻挡
				var distance = char_position.distance_to(world_pos)
				if distance > max_range:
					# 圆形范围外：设为透明
					image.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					# 🔴 纯红色表示范围内但被阻挡的区域（不要渐变）
					var color = Color.RED
					color.a = 0.6  # 固定透明度
					image.set_pixel(x, y, color)

# 🚀 真实的移动能力检查（使用位置碰撞管理器）
func _is_position_movable_realistic(world_pos: Vector2, char_height: float, max_range: int, char_position: Vector2) -> bool:
	if not _current_character:
		return false
	
	# 🚀 使用位置碰撞管理器进行验证
	if position_collision_manager:
		var validation_result = position_collision_manager.validate_position_comprehensive(
			_current_character, 
			world_pos, 
			char_position
		)
		return validation_result.is_valid
	else:
		return false

# 🚀 CPU精确纹理计算（使用位置碰撞管理器优化版）
func _compute_range_texture_cpu(character: GameCharacter, resolution: int) -> ImageTexture:
	if not character:
		return null
	
	# print("🎨 [Renderer] 生成移动范围纹理: 角色=%s, 轻功=%d" % [character.name, character.qinggong_skill])
	
	# 🎯 第1步：创建与移动范围大小相同的图像
	var image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var max_range = character.qinggong_skill
	# 🔧 修复：获取角色节点的实际位置
	var character_node = _get_character_node(character)
	var char_position = character_node.position if character_node else character.position
	var pixel_scale = float(max_range * 2) / resolution  # 每像素对应的游戏单位
	var half_resolution = resolution / 2
	
	# 🎯 第2步：双重循环遍历每个像素点
	for y in range(resolution):
		for x in range(resolution):
			# 🎯 第3步：计算对应的世界坐标位置
			var local_x = (x - half_resolution) * pixel_scale
			var local_y = (y - half_resolution) * pixel_scale
			var world_pos = char_position + Vector2(local_x, local_y)
			
			# 🎯 第4步：使用位置碰撞管理器进行验证
			var is_valid = false
			if position_collision_manager:
				var validation_result = position_collision_manager.validate_position_comprehensive(
					character, 
					world_pos, 
					char_position
				)
				is_valid = validation_result.is_valid
			
			# 🎯 第5步：根据验证结果设置像素颜色
			if is_valid:
				# 🟢 纯绿色表示可移动区域
				var color = Color.GREEN
				color.a = 0.6  # 固定透明度
				image.set_pixel(x, y, color)
			else:
				# 🚀 区分圆形范围外和障碍物阻挡
				var distance = char_position.distance_to(world_pos)
				if distance > max_range:
					# 圆形范围外：设为透明
					image.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					# 🔴 纯红色表示范围内但被阻挡的区域
					var color = Color.RED
					color.a = 0.6  # 固定透明度
					image.set_pixel(x, y, color)
	
	# 创建并返回纹理
	var texture = ImageTexture.new()
	texture.set_image(image)
	# print("🎨 [Renderer] 纹理生成完成，分辨率: %dx%d" % [resolution, resolution])
	return texture

# 🎨 渲染实现
func _process(delta):
	# 🚀 更新动画状态
	if _animation_active:
		_animation_progress += delta / _animation_duration
		
		if _animation_type == "expanding_circle":
			_current_radius = _target_radius * smoothstep(0.0, 1.0, _animation_progress)
			queue_redraw()
			
			# 检查动画是否完成，如果有等待的纹理则开始淡入
			if _animation_progress >= 1.0:
				_current_radius = _target_radius
				print("🎨 [DEBUG] 扩张动画完成 - 当前global_position: %s" % global_position)
				
				# 🚀 修复：扩张动画完成后，检查是否有等待的淡入纹理
				if _pending_fade_texture:
					print("🎨 [DEBUG] 开始淡入等待的纹理")
					_start_fade_in_with_pending_texture()
		
		elif _animation_type == "fade_in":
			_fade_alpha = smoothstep(0.0, 1.0, _animation_progress)
			queue_redraw()
			
			# 淡入完成后停止动画并启用输入
			if _animation_progress >= 1.0:
				_fade_alpha = 1.0
				_animation_active = false
				_animation_type = ""
				print("🎨 [DEBUG] 淡入动画完成 - 最终global_position: %s" % global_position)
				_notify_animation_complete()
	
	# 原有的视觉效果更新
	if visible and config and config.is_visual_effects_enabled():
		_visual_effects_time += delta * config.animation_speed
		for i in range(_animation_phases.size()):
			_animation_phases[i] += delta * config.animation_speed * 0.5
		queue_redraw()
	
	# 🚀 检查是否有待处理的纹理
	if _pending_texture and _mutex:
		_mutex.lock()
		if _pending_texture and not _is_computing:
			_current_texture = _pending_texture
			_pending_texture = null
		_mutex.unlock()

func _draw():
	# 🚀 绘制动画
	if _animation_active:
		if _animation_type == "expanding_circle":
			_draw_expanding_circle()
			return  # 扩张动画期间不绘制其他内容
		elif _animation_type == "fade_in":
			# 🚀 修复：淡入期间同时绘制纹理和流光边框
			_draw_fade_in_texture()
			if _current_character and config and config.is_visual_effects_enabled():
				var local_center = to_local(_current_character.position)
				_draw_animated_border(local_center)  # 恢复流光边框
			return
	
	# 原有的绘制逻辑
	if not _current_texture or not _current_character:
		return
	
	var local_center = to_local(_current_character.position)
	
	# 绘制范围纹理
	_draw_enhanced_range_texture(local_center)
	
	# 🔧 恢复流光边框（不再优先显示静态扩张边框）
	if config and config.is_visual_effects_enabled():
		_draw_animated_border(local_center)  # 始终显示流光边框
	else:
		_draw_static_border(local_center)
	
	# 原有的鼠标指示器已移除，现在使用可视化碰撞体作为指示器

# 🎨 增强的范围纹理绘制
func _draw_enhanced_range_texture(local_center: Vector2):
	if not _current_texture or not _current_character:
		return
	
	var max_range = _current_character.qinggong_skill
	var texture_size = Vector2(max_range * 2, max_range * 2)
	# 🔧 修复：使用渲染器自身的中心点
	var renderer_center = Vector2.ZERO
	var texture_rect = Rect2(renderer_center - texture_size / 2, texture_size)
	
	# 基础纹理
	draw_texture_rect(_current_texture, texture_rect, false)
	
	# 🚀 视觉效果增强
	if config and config.is_visual_effects_enabled():
		# 边缘光晕效果
		var glow_color = Color(config.movable_color.r, config.movable_color.g, config.movable_color.b, 0.3)
		var glow_size = texture_size * 1.1
		var glow_rect = Rect2(renderer_center - glow_size / 2, glow_size)
		
		if _edge_gradient_texture:
			draw_texture_rect(_edge_gradient_texture, glow_rect, false, glow_color)

func _draw_static_border(local_center: Vector2):
	if not _current_character:
		return
	
	var max_range = _current_character.qinggong_skill
	# 🔧 修复：使用渲染器自身的中心点
	var renderer_center = Vector2.ZERO
	draw_arc(renderer_center, max_range, 0, 2 * PI, 36, Color.WHITE, 2.0)

func _draw_animated_border(local_center: Vector2):
	if not _current_character:
		return
	
	var max_range = _current_character.qinggong_skill
	var time_offset = _visual_effects_time * 1.5  # 适中的转动速度
	
	# 🔧 修复：使用渲染器自身的中心点，而不是角色位置
	# 这样确保流光边框与纹理的圆心一致
	var renderer_center = Vector2.ZERO  # 渲染器的本地坐标中心
	
	# 🎯 先绘制完整的基础圆圈（确保底色）
	draw_arc(renderer_center, max_range, 0, 2 * PI, 64, Color(0.6, 0.7, 0.9, 0.5), 2.0)
	
	# 🌟 然后只在光点位置绘制亮色段，不覆盖其他位置
	for light_id in range(3):
		var light_offset = light_id * (2 * PI / 3)  # 120度间隔
		var light_center_angle = time_offset + light_offset
		
		# 每个光点的扩散范围
		var light_spread = PI / 8  # 减小到22.5度，避免重叠过多
		
		# 为每个光点绘制一个短弧
		var segments_in_light = 16  # 光点内的细分段数
		for i in range(segments_in_light):
			var t = float(i) / float(segments_in_light - 1)  # 0到1
			var angle_in_light = (t - 0.5) * light_spread * 2  # -light_spread 到 +light_spread
			var actual_angle = light_center_angle + angle_in_light
			
			# 计算该位置的亮度（中心最亮，边缘最暗）
			var distance_from_center = abs(angle_in_light)
			var brightness = 1.0 - (distance_from_center / light_spread)
			brightness = smoothstep(0.0, 1.0, brightness)
			
			# 只绘制足够亮的点
			if brightness > 0.3:
				# 计算该点在圆周上的位置
				var point_pos = renderer_center + Vector2(cos(actual_angle), sin(actual_angle)) * max_range
				
				# 绘制光点（使用小圆点而不是弧段）
				var light_color = Color.WHITE.lerp(Color.CYAN, 0.3)
				light_color.a = brightness * 0.7
				var point_size = 2.0 + brightness * 3.0
				
				draw_circle(point_pos, point_size, light_color)
	
	# 🌟 最后绘制一个很淡的内圈
	if max_range > 15:
		var inner_radius = max_range - 6
		var inner_alpha = 0.1 + 0.05 * sin(time_offset * 2.0)
		var inner_color = Color(0.7, 0.8, 1.0, inner_alpha)
		draw_arc(renderer_center, inner_radius, 0, 2 * PI, 32, inner_color, 1.5)

# 🚀 增强的鼠标指示器
func _draw_enhanced_mouse_indicator():
	if _mouse_position == Vector2.ZERO or not _current_character:
		return
	
	var local_target = to_local(_mouse_position)
	var circle_radius: float = 20.0
	
	# 🚀 关键增强：根据位置有效性确定颜色
	var is_valid_position = _check_mouse_position_validity()
	var base_color = Color.GREEN if is_valid_position else Color.RED
	
	# 🚀 增强的脉冲动画
	if config and config.is_visual_effects_enabled():
		var pulse = sin(_visual_effects_time * 4.0) * 0.3 + 0.7
		circle_radius *= pulse
		
		# 根据有效性选择颜色效果
		if is_valid_position:
			# 可移动位置：彩虹颜色效果
			var hue = fmod(_visual_effects_time * 0.5, 1.0)
			base_color = Color.from_hsv(hue, 0.8, 1.0)
		else:
			# 不可移动位置：红色脉冲警告
			var warning_intensity = sin(_visual_effects_time * 8.0) * 0.3 + 0.7
			base_color = Color.RED * warning_intensity
	
	if circle_radius > 0:
		# 外圈半透明
		draw_circle(local_target, circle_radius, Color(base_color.r, base_color.g, base_color.b, 0.3))
		
		# 边框
		var border_width = 4.0 if not is_valid_position else 3.0
		draw_arc(local_target, circle_radius, 0, 2 * PI, 32, base_color, border_width)
		
		# 中心点
		draw_circle(local_target, 4 if not is_valid_position else 3, base_color)
		
		# 🚀 十字标记
		var cross_size = 10.0 if not is_valid_position else 8.0
		var cross_width = 3.0 if not is_valid_position else 2.0
		draw_line(local_target + Vector2(-cross_size, 0), local_target + Vector2(cross_size, 0), base_color, cross_width)
		draw_line(local_target + Vector2(0, -cross_size), local_target + Vector2(0, cross_size), base_color, cross_width)
		
		# 🚀 无效位置额外警告标记
		if not is_valid_position:
			var x_size = 6.0
			var x_color = Color.WHITE
			# 绘制X标记
			draw_line(local_target + Vector2(-x_size, -x_size), local_target + Vector2(x_size, x_size), x_color, 2.0)
			draw_line(local_target + Vector2(-x_size, x_size), local_target + Vector2(x_size, -x_size), x_color, 2.0)

# 🚀 检查鼠标位置的移动有效性（简化版）
func _check_mouse_position_validity() -> bool:
	if not _current_character or _mouse_position == Vector2.ZERO:
		return false
	
	# 获取输入组件来验证当前鼠标位置
	var input_handler = get_node("../Input")
	if input_handler and input_handler.has_method("is_position_valid"):
		var result = input_handler.is_position_valid()
		return result
	
	# 无法获取输入处理器时直接返回false，不使用备用验证
	push_error("[MoveRangeRenderer] 无法获取输入处理器，位置验证失败")
	return false

# 🎨 视觉效果初始化
func _initialize_visual_effects():
	if not config or not config.is_visual_effects_enabled():
		return
	
	# 创建边缘渐变纹理
	_create_gradient_texture()
	
	# 初始化动画相位
	_animation_phases.clear()
	for i in range(8):
		_animation_phases.append(randf() * 2.0 * PI)
	
	# print("🎨 [Renderer] 视觉效果初始化完成")

# 🚀 创建边缘渐变纹理
func _create_gradient_texture():
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	var max_distance = size / 2
	
	for x in range(size):
		for y in range(size):
			var distance = Vector2(x, y).distance_to(center)
			var alpha = 1.0 - (distance / max_distance)
			alpha = max(0.0, alpha)
			alpha = smoothstep(0.0, 1.0, alpha)  # 平滑过渡
			
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	
	_edge_gradient_texture = ImageTexture.new()
	_edge_gradient_texture.set_image(image)

# 🔧 工具方法
func get_current_character() -> GameCharacter:
	return _current_character

func is_range_visible() -> bool:
	return visible and _current_texture != null

# 🚀 性能监控
func is_computing() -> bool:
	return _is_computing

func set_pending_texture(texture: ImageTexture):
	if _mutex:
		_mutex.lock()
		_pending_texture = texture
		_mutex.unlock()

# 🚀 清理资源
func _exit_tree():
	if _mutex:
		_mutex = null
	if _compute_shader:
		_compute_shader = null 

# 🚀 新增：开始圆形扩张动画
func start_expanding_circle_animation(character: GameCharacter, center_position: Vector2):
	_current_character = character
	_animation_center = center_position
	global_position = center_position
	_target_radius = float(character.qinggong_skill)
	_current_radius = 0.0
	_animation_progress = 0.0
	_animation_type = "expanding_circle"
	_animation_active = true
	_animation_duration = config.expanding_animation_duration if config else 0.5  # 从配置获取时长
	visible = true
	
	print("🎨 [DEBUG] 开始圆形扩张动画 - 中心位置: %s, 目标半径: %.0f" % [center_position, _target_radius])
	print("🎨 [DEBUG] 设置global_position为: %s" % global_position)

# 🚀 新增：完成动画并淡入纹理
func complete_animation_and_fade_in_texture(texture: ImageTexture, character: GameCharacter, position: Vector2):
	print("🎨 [DEBUG] complete_animation_and_fade_in_texture - 传入位置: %s" % position)
	print("🎨 [DEBUG] complete_animation_and_fade_in_texture - 设置前global_position: %s" % global_position)
	if _animation_type == "expanding_circle":
		# 完成扩张动画
		_current_radius = _target_radius
		_animation_progress = 1.0
	
	# 开始淡入动画
	_fade_in_texture = texture
	_current_texture = texture
	_fade_alpha = 0.0
	_animation_progress = 0.0
	_animation_type = "fade_in"
	_animation_duration = config.fade_in_animation_duration if config else 0.4  # 从配置获取淡入时长
	
	# 🔧 修复：只有当位置确实不同时才设置新位置，避免不必要的跳动
	var position_diff = global_position.distance_to(position)
	print("🎨 [DEBUG] complete_animation_and_fade_in_texture - 位置差距: %s" % position_diff)
	if position_diff > 1.0:  # 只有差距大于1像素时才更新位置
		print("🎨 [DEBUG] complete_animation_and_fade_in_texture - 位置差距较大，更新位置从 %s 到 %s" % [global_position, position])
		global_position = position
	else:
		print("🎨 [DEBUG] complete_animation_and_fade_in_texture - 位置差距很小，保持当前位置: %s" % global_position)
	
	# print("🎨 [Renderer] 开始淡入真实纹理")

# 🚀 新增：停止所有动画
func _stop_all_animations():
	_animation_active = false
	_animation_type = "none"
	_animation_progress = 0.0
	_fade_alpha = 1.0
	_pending_fade_texture = null

# 🚀 新增：使用等待的纹理开始淡入
func _start_fade_in_with_pending_texture():
	if not _pending_fade_texture or not _current_character:
		return
	
	print("🎨 [DEBUG] _start_fade_in_with_pending_texture - 进入时global_position: %s" % global_position)
	
	# 🔧 修复：保持扩张动画时的位置，不要重新设置global_position
	# 因为扩张动画已经将位置设置为正确的动画中心位置
	# global_position应该保持不变，避免位置跳动
	print("🎨 [DEBUG] 保持位置不变，当前global_position: %s" % global_position)
	
	# 开始淡入动画
	_fade_in_texture = _pending_fade_texture
	_current_texture = _pending_fade_texture
	_fade_alpha = 0.0
	_animation_progress = 0.0
	_animation_type = "fade_in"
	_animation_duration = config.fade_in_animation_duration if config else 0.4  # 从配置获取淡入时长
	
	# 清理等待的纹理
	_pending_fade_texture = null
	
	# print("🎨 [Renderer] 扩张动画完成，开始淡入真实纹理")

# 🚀 新增：通知动画完成
func _notify_animation_complete():
	# 通知Controller启用输入
	var controller = get_node("../Controller")
	if controller and controller.has_method("_enable_input_after_animation"):
		controller._enable_input_after_animation()

# 🚀 新增：绘制扩张圆形动画
func _draw_expanding_circle():
	if not _current_character:
		return
	
	var local_center = Vector2.ZERO  # 因为global_position已经设置为角色位置
	var circle_color = config.expanding_border_color if config else Color.WHITE  # 🚀 使用配置的颜色
	circle_color.a = 0.8  # 提高透明度使边框更明显
	
	# 🚀 修复：只绘制扩张的圆形边框，不要内部填充
	if _current_radius > 0:
		# 主边框 - 使用配置的宽度
		var border_width = config.expanding_border_width if config else 4.0
		draw_arc(local_center, _current_radius, 0, 2 * PI, 64, circle_color, border_width)
		
		# 内侧细边框（增强效果）
		var inner_color = Color(circle_color.r, circle_color.g, circle_color.b, 0.5)
		draw_arc(local_center, _current_radius - 2, 0, 2 * PI, 64, inner_color, border_width * 0.5)
		
		# 动态效果：脉冲边框（如果启用）
		if config and config.enable_pulse_effect:
			var pulse_intensity = config.pulse_intensity if config else 5.0
			var pulse_radius = _current_radius + sin(_visual_effects_time * 6.0) * pulse_intensity
			if pulse_radius > 0:
				var pulse_color = Color(circle_color.r, circle_color.g, circle_color.b, 0.3)
				draw_arc(local_center, pulse_radius, 0, 2 * PI, 64, pulse_color, border_width * 0.5)

# 🚀 新增：绘制淡入纹理动画
func _draw_fade_in_texture():
	if not _fade_in_texture or not _current_character:
		return
	
	# 🔧 修复：使用渲染器自身的中心点
	var renderer_center = Vector2.ZERO
	var max_range = _current_character.qinggong_skill
	var texture_size = Vector2(max_range * 2, max_range * 2)
	var texture_rect = Rect2(renderer_center - texture_size / 2, texture_size)
	
	# 绘制淡入的纹理
	var fade_color = Color(1.0, 1.0, 1.0, _fade_alpha)
	draw_texture_rect(_fade_in_texture, texture_rect, false, fade_color)
	
	# 边框也渐变显示
	if _fade_alpha > 0.5:  # 纹理显示到一半时开始显示边框
		var border_alpha = (_fade_alpha - 0.5) * 2.0
		var border_color = Color.WHITE
		border_color.a = border_alpha
		draw_arc(renderer_center, max_range, 0, 2 * PI, 36, border_color, 2.0)

# 🚀 新增：带障碍物数据的CPU纹理计算
func _compute_range_texture_cpu_with_obstacles(character: GameCharacter, resolution: int, obstacles_data: Array, char_position: Vector2, char_ground_y: float) -> ImageTexture:
	var start_time = Time.get_ticks_msec()
	
	# 创建图像
	var image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var half_size = int(resolution / 2)
	var max_range = character.qinggong_skill
	var pixel_scale = float(max_range * 2) / resolution
	# 🔧 修复：使用传入的角色地面Y坐标（线程安全）
	
	# 逐像素计算
	for y in range(resolution):
		for x in range(resolution):
			var local_x = (x - half_size) * pixel_scale
			var local_y = (y - half_size) * pixel_scale
			var world_pos = char_position + Vector2(local_x, local_y)
			
			# 使用快速验证方法
			var is_valid = _validate_position_for_texture(char_position, world_pos, max_range, char_ground_y, obstacles_data)
			
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
	
	# 创建纹理
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	var computation_time = (Time.get_ticks_msec() - start_time)
	# print("🧮 [Renderer] CPU纹理计算完成，分辨率: %dx%d, 用时: %dms" % [resolution, resolution, computation_time])
	
	return texture

# 🚀 新增：带障碍物数据的GPU纹理计算
func compute_range_texture_gpu_with_obstacles(character: GameCharacter, resolution: int, obstacles_data: Array, char_position: Vector2) -> ImageTexture:
	# print("⚠️ [Renderer] GPU计算暂未支持障碍物数据，回退到CPU")
	# 🔧 修复：传递角色地面Y坐标参数
	var char_ground_y = character.ground_position.y
	return _compute_range_texture_cpu_with_obstacles(character, resolution, obstacles_data, char_position, char_ground_y)

# 🚀 新增：纹理生成的快速位置验证
func _validate_position_for_texture(char_pos: Vector2, target_pos: Vector2, max_range: int, char_ground_y: float, obstacles_data: Array) -> bool:
	# 检查1：圆形范围检查
	var distance = char_pos.distance_to(target_pos)
	if distance > max_range:
		return false
	
	# 检查2：地面限制检查
	if target_pos.y > char_ground_y:
		return false
	
	# 检查3：障碍物碰撞检查（使用预先收集的数据）
	for obstacle_data in obstacles_data:
		if _point_intersects_capsule_for_texture(target_pos, obstacle_data):
			return false
	
	return true

# 🚀 新增：纹理生成专用的胶囊体碰撞检测
func _point_intersects_capsule_for_texture(point: Vector2, obstacle_data: Dictionary) -> bool:
	var shape = obstacle_data.shape
	var obstacle_pos = obstacle_data.position
	
	if shape is CapsuleShape2D:
		return _point_in_capsule_for_texture(point, obstacle_pos, shape as CapsuleShape2D)
	elif shape is CircleShape2D:
		return _point_in_circle_for_texture(point, obstacle_pos, shape as CircleShape2D)
	elif shape is RectangleShape2D:
		return _point_in_rectangle_for_texture(point, obstacle_pos, shape as RectangleShape2D)
	
	return false

# 🚀 新增：纹理生成专用的快速碰撞检测方法
func _point_in_capsule_for_texture(point: Vector2, capsule_pos: Vector2, capsule: CapsuleShape2D) -> bool:
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

func _point_in_circle_for_texture(point: Vector2, circle_pos: Vector2, circle: CircleShape2D) -> bool:
	var distance = point.distance_to(circle_pos)
	return distance <= circle.radius

func _point_in_rectangle_for_texture(point: Vector2, rect_pos: Vector2, rect: RectangleShape2D) -> bool:
	var local_point = point - rect_pos
	var half_size = rect.size / 2
	return (abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y)

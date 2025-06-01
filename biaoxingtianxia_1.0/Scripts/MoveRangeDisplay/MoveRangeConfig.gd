# 🔧 移动范围显示系统 - 配置组件（增强版）
extends Node
class_name MoveRangeConfig

# 🎨 视觉配置
@export_group("视觉配置")
@export var movable_color: Color = Color(0.0, 0.8, 0.0, 0.6)    # 可移动区域
@export var blocked_color: Color = Color(1.0, 0.2, 0.2, 0.5)    # 阻挡区域
@export var collision_debug_color: Color = Color(0.0, 1.0, 1.0, 0.4)  # 调试碰撞

# 🚀 动画配置
@export_group("动画配置")
@export var expanding_animation_duration: float = 0.5  # 扩张动画持续时间（秒）
@export var fade_in_animation_duration: float = 0.4  # 淡入动画持续时间（秒）
@export var expanding_border_color: Color = Color.WHITE  # 扩张动画边框颜色
@export var expanding_border_width: float = 4.0  # 扩张动画边框宽度
@export var enable_pulse_effect: bool = true  # 启用脉冲效果
@export var pulse_intensity: float = 5.0  # 脉冲强度（像素）

# ⚡ 性能配置
@export_group("性能配置")
@export var texture_resolution: int = 256  # 纹理分辨率
@export var enable_threading: bool = true  # 启用多线程计算
@export var adaptive_resolution: bool = true  # 自适应分辨率
@export var memory_limit_mb: int = 50  # 内存限制(MB)

# 🚀 深度性能优化配置
@export_group("深度性能优化")
@export var enable_quick_preview: bool = true  # 启用快速预览
@export var enable_framewise_computation: bool = true  # 启用分帧计算
@export var max_computation_time_ms: float = 16.0  # 最大计算时间（毫秒）
@export var preview_resolution: int = 64  # 预览纹理分辨率
@export var framewise_chunks: int = 16  # 分帧计算块数
@export var enable_worker_threads: bool = true  # 启用工作线程池
@export var max_worker_threads: int = 2  # 最大工作线程数

# 🚀 缓存优化配置
@export_group("缓存优化")
@export var enable_lookup_table: bool = true  # 启用快速查找表
@export var enable_preload_cache: bool = true  # 启用预加载缓存
@export var preload_queue_size: int = 5  # 预加载队列大小
@export var cache_cleanup_interval: float = 10.0  # 缓存清理间隔（秒）
@export var async_cache_operations: bool = true  # 异步缓存操作

# 🚀 算法优化配置
@export_group("算法优化")
@export var simplified_obstacle_detection: bool = true  # 简化障碍物检测
@export var obstacle_detection_radius: float = 25.0  # 固定障碍物半径
@export var enable_spatial_optimization: bool = true  # 启用空间优化
@export var spatial_grid_size: float = 50.0  # 空间网格大小

# 🚀 性能监控配置
@export_group("性能监控")
@export var enable_performance_monitoring: bool = false  # 默认关闭性能监控
@export var performance_log_interval: float = 5.0  # 性能日志间隔（秒）
@export var target_frame_time_ms: float = 16.6  # 目标帧时间（60FPS）
@export var performance_auto_adjust: bool = true  # 自动性能调整
@export var performance_warning_threshold: float = 32.0  # 性能警告阈值（毫秒）

# 🚀 高级功能配置
@export_group("高级功能")
@export var enable_gpu_compute: bool = true  # 启用GPU计算
@export var enable_predictive_cache: bool = true  # 启用预测性缓存
@export var enable_visual_effects: bool = true  # 启用视觉效果
@export var batch_computation: bool = true  # 启用批量计算
@export var animation_speed: float = 2.0  # 动画速度

# 🚀 性能优化配置
@export var enable_smart_algorithm_selection: bool = true  # 智能算法选择
@export var gpu_threshold_complexity: float = 2.0  # GPU计算复杂度阈值

# 🚀 缓存配置
@export var cache_expiry_global_minutes: float = 5.0  # 全局缓存过期时间（分钟）
@export var cache_expiry_predictive_minutes: float = 2.0  # 预测缓存过期时间（分钟）
@export var max_movement_history: int = 20  # 最大移动历史记录数
@export var batch_process_size: int = 3  # 批量处理大小

# 🚀 调试配置
@export var debug_mode: int = 0  # 0=关闭, 1=边界, 2=碰撞形状, 3=性能, 4=GPU调试, 5=预测缓存
@export var enable_performance_logging: bool = false  # 启用性能日志
@export var show_algorithm_choice: bool = false  # 显示算法选择信息

# 📡 信号
signal config_changed(setting_name: String, old_value, new_value)
signal performance_warning(message: String)
signal debug_mode_changed(mode: int)

func _ready():
	print("🔧 [Config] 配置组件初始化完成")
	_validate_configuration()

# 🔧 配置验证
func _validate_configuration():
	var warnings = []
	
	# 验证纹理分辨率
	if texture_resolution < 64 or texture_resolution > 4096:
		warnings.append("纹理分辨率应在64-4096之间")
		texture_resolution = clamp(texture_resolution, 64, 4096)
	
	# 验证内存限制
	if memory_limit_mb < 10 or memory_limit_mb > 500:
		warnings.append("内存限制应在10-500MB之间")
		memory_limit_mb = clamp(memory_limit_mb, 10, 500)
	
	# 验证动画速度
	if animation_speed < 0.1 or animation_speed > 10.0:
		warnings.append("动画速度应在0.1-10.0之间")
		animation_speed = clamp(animation_speed, 0.1, 10.0)
	
	# 🚀 验证扩张动画配置
	if expanding_animation_duration < 0.1 or expanding_animation_duration > 2.0:
		warnings.append("扩张动画时长应在0.1-2.0秒之间")
		expanding_animation_duration = clamp(expanding_animation_duration, 0.1, 2.0)
	
	if fade_in_animation_duration < 0.1 or fade_in_animation_duration > 1.0:
		warnings.append("淡入动画时长应在0.1-1.0秒之间")
		fade_in_animation_duration = clamp(fade_in_animation_duration, 0.1, 1.0)
	
	if expanding_border_width < 1.0 or expanding_border_width > 10.0:
		warnings.append("扩张边框宽度应在1.0-10.0之间")
		expanding_border_width = clamp(expanding_border_width, 1.0, 10.0)
	
	if pulse_intensity < 0.0 or pulse_intensity > 20.0:
		warnings.append("脉冲强度应在0.0-20.0之间")
		pulse_intensity = clamp(pulse_intensity, 0.0, 20.0)
	
	if warnings.size() > 0:
		for warning in warnings:
			push_warning("[Config] " + warning)

# 🎯 配置查询接口
func is_gpu_enabled() -> bool:
	return enable_gpu_compute

func is_visual_effects_enabled() -> bool:
	return enable_visual_effects

func is_threading_enabled() -> bool:
	return enable_threading

func is_adaptive_resolution_enabled() -> bool:
	return adaptive_resolution

func is_batch_computation_enabled() -> bool:
	return batch_computation

func is_predictive_cache_enabled() -> bool:
	return enable_predictive_cache

func is_smart_algorithm_selection_enabled() -> bool:
	return enable_smart_algorithm_selection

func is_performance_auto_adjust_enabled() -> bool:
	return performance_auto_adjust

func is_debug_mode_enabled() -> bool:
	return debug_mode > 0

func is_performance_logging_enabled() -> bool:
	return enable_performance_logging

# 🎯 动态配置更新接口
func set_gpu_enabled(enabled: bool):
	var old_value = enable_gpu_compute
	enable_gpu_compute = enabled
	config_changed.emit("enable_gpu_compute", old_value, enabled)
	print("🔧 [Config] GPU计算: %s" % ("启用" if enabled else "禁用"))

func set_visual_effects_enabled(enabled: bool):
	var old_value = enable_visual_effects
	enable_visual_effects = enabled
	config_changed.emit("enable_visual_effects", old_value, enabled)
	print("🔧 [Config] 视觉效果: %s" % ("启用" if enabled else "禁用"))

func set_texture_resolution(resolution: int):
	var old_value = texture_resolution
	texture_resolution = clamp(resolution, 64, 4096)
	config_changed.emit("texture_resolution", old_value, texture_resolution)
	print("🔧 [Config] 纹理分辨率: %dx%d" % [texture_resolution, texture_resolution])

func set_memory_limit(limit_mb: int):
	var old_value = memory_limit_mb
	memory_limit_mb = clamp(limit_mb, 10, 500)
	config_changed.emit("memory_limit_mb", old_value, memory_limit_mb)
	print("🔧 [Config] 内存限制: %dMB" % memory_limit_mb)

func set_animation_speed(speed: float):
	var old_value = animation_speed
	animation_speed = clamp(speed, 0.1, 10.0)
	config_changed.emit("animation_speed", old_value, animation_speed)
	print("🔧 [Config] 动画速度: %.1f" % animation_speed)

func set_debug_mode(mode: int):
	var old_value = debug_mode
	debug_mode = clamp(mode, 0, 5)
	config_changed.emit("debug_mode", old_value, debug_mode)
	debug_mode_changed.emit(debug_mode)
	
	var mode_names = ["关闭", "边界", "碰撞形状", "性能", "GPU调试", "预测缓存"]
	print("🔧 [Config] 调试模式: %s" % mode_names[debug_mode])

func set_performance_logging(enabled: bool):
	var old_value = enable_performance_logging
	enable_performance_logging = enabled
	config_changed.emit("enable_performance_logging", old_value, enabled)
	print("🔧 [Config] 性能日志: %s" % ("启用" if enabled else "禁用"))

# 🚀 动画配置设置接口
func set_expanding_animation_duration(duration: float):
	var old_value = expanding_animation_duration
	expanding_animation_duration = clamp(duration, 0.1, 2.0)
	config_changed.emit("expanding_animation_duration", old_value, expanding_animation_duration)
	print("🔧 [Config] 扩张动画时长: %.1f秒" % expanding_animation_duration)

func set_fade_in_animation_duration(duration: float):
	var old_value = fade_in_animation_duration
	fade_in_animation_duration = clamp(duration, 0.1, 1.0)
	config_changed.emit("fade_in_animation_duration", old_value, fade_in_animation_duration)
	print("🔧 [Config] 淡入动画时长: %.1f秒" % fade_in_animation_duration)

func set_expanding_border_color(color: Color):
	var old_value = expanding_border_color
	expanding_border_color = color
	config_changed.emit("expanding_border_color", old_value, expanding_border_color)
	print("🔧 [Config] 扩张边框颜色: %s" % str(color))

func set_expanding_border_width(width: float):
	var old_value = expanding_border_width
	expanding_border_width = clamp(width, 1.0, 10.0)
	config_changed.emit("expanding_border_width", old_value, expanding_border_width)
	print("🔧 [Config] 扩张边框宽度: %.1f" % expanding_border_width)

func set_pulse_effect_enabled(enabled: bool):
	var old_value = enable_pulse_effect
	enable_pulse_effect = enabled
	config_changed.emit("enable_pulse_effect", old_value, enabled)
	print("🔧 [Config] 脉冲效果: %s" % ("启用" if enabled else "禁用"))

func set_pulse_intensity(intensity: float):
	var old_value = pulse_intensity
	pulse_intensity = clamp(intensity, 0.0, 20.0)
	config_changed.emit("pulse_intensity", old_value, pulse_intensity)
	print("🔧 [Config] 脉冲强度: %.1f像素" % pulse_intensity)

# 🚀 智能配置建议
func get_recommended_settings_for_device() -> Dictionary:
	var settings = {}
	
	# 基于设备性能的推荐设置
	var platform = OS.get_name()
	var processor_count = OS.get_processor_count()
	
	match platform:
		"Windows", "macOS", "Linux":
			# 桌面平台 - 高性能设置
			settings["texture_resolution"] = 512
			settings["enable_gpu_compute"] = true
			settings["enable_visual_effects"] = true
			settings["enable_predictive_cache"] = true
			settings["memory_limit_mb"] = 100
		
		"Android", "iOS":
			# 移动平台 - 优化设置
			settings["texture_resolution"] = 256
			settings["enable_gpu_compute"] = false
			settings["enable_visual_effects"] = false
			settings["enable_predictive_cache"] = false
			settings["memory_limit_mb"] = 30
		
		_:
			# 其他平台 - 保守设置
			settings["texture_resolution"] = 128
			settings["enable_gpu_compute"] = false
			settings["enable_visual_effects"] = true
			settings["enable_predictive_cache"] = true
			settings["memory_limit_mb"] = 50
	
	# 基于处理器核心数调整
	if processor_count >= 8:
		settings["batch_computation"] = true
		settings["enable_threading"] = true
	elif processor_count >= 4:
		settings["batch_computation"] = true
		settings["enable_threading"] = true
	else:
		settings["batch_computation"] = false
		settings["enable_threading"] = false
	
	return settings

func apply_recommended_settings():
	var recommended = get_recommended_settings_for_device()
	
	for setting_name in recommended.keys():
		var value = recommended[setting_name]
		
		match setting_name:
			"texture_resolution":
				set_texture_resolution(value)
			"enable_gpu_compute":
				set_gpu_enabled(value)
			"enable_visual_effects":
				set_visual_effects_enabled(value)
			"enable_predictive_cache":
				enable_predictive_cache = value
			"memory_limit_mb":
				set_memory_limit(value)
			"batch_computation":
				batch_computation = value
			"enable_threading":
				enable_threading = value
	
	print("🚀 [Config] 已应用推荐设置")

# 🚀 性能配置文件
enum PerformanceProfile {
	ULTRA,     # 最高质量
	HIGH,      # 高质量
	MEDIUM,    # 中等质量
	LOW,       # 低质量
	POTATO     # 最低质量
}

func apply_performance_profile(profile: PerformanceProfile):
	match profile:
		PerformanceProfile.ULTRA:
			set_texture_resolution(1024)
			set_gpu_enabled(true)
			set_visual_effects_enabled(true)
			enable_predictive_cache = true
			batch_computation = true
			adaptive_resolution = true
			set_memory_limit(200)
			set_animation_speed(3.0)
		
		PerformanceProfile.HIGH:
			set_texture_resolution(512)
			set_gpu_enabled(true)
			set_visual_effects_enabled(true)
			enable_predictive_cache = true
			batch_computation = true
			adaptive_resolution = true
			set_memory_limit(100)
			set_animation_speed(2.5)
		
		PerformanceProfile.MEDIUM:
			set_texture_resolution(256)
			set_gpu_enabled(true)
			set_visual_effects_enabled(true)
			enable_predictive_cache = false
			batch_computation = false
			adaptive_resolution = true
			set_memory_limit(50)
			set_animation_speed(2.0)
		
		PerformanceProfile.LOW:
			set_texture_resolution(128)
			set_gpu_enabled(false)
			set_visual_effects_enabled(false)
			enable_predictive_cache = false
			batch_computation = false
			adaptive_resolution = false
			set_memory_limit(30)
			set_animation_speed(1.5)
		
		PerformanceProfile.POTATO:
			set_texture_resolution(64)
			set_gpu_enabled(false)
			set_visual_effects_enabled(false)
			enable_predictive_cache = false
			batch_computation = false
			adaptive_resolution = false
			set_memory_limit(20)
			set_animation_speed(1.0)
	
	var profile_names = ["超高", "高", "中", "低", "最低"]
	print("🚀 [Config] 已应用 %s 质量配置文件" % profile_names[profile])

# 📊 配置信息导出
func get_all_settings() -> Dictionary:
	return {
		# 颜色配置
		"movable_color": movable_color,
		"blocked_color": blocked_color,
		"collision_debug_color": collision_debug_color,
		
		# 性能配置
		"texture_resolution": texture_resolution,
		"enable_threading": enable_threading,
		"adaptive_resolution": adaptive_resolution,
		"memory_limit_mb": memory_limit_mb,
		
		# GPU配置
		"enable_gpu_compute": enable_gpu_compute,
		"enable_predictive_cache": enable_predictive_cache,
		"enable_visual_effects": enable_visual_effects,
		"batch_computation": batch_computation,
		"animation_speed": animation_speed,
		
		# 智能配置
		"enable_smart_algorithm_selection": enable_smart_algorithm_selection,
		"gpu_threshold_complexity": gpu_threshold_complexity,
		"performance_auto_adjust": performance_auto_adjust,
		
		# 缓存配置
		"cache_expiry_global_minutes": cache_expiry_global_minutes,
		"cache_expiry_predictive_minutes": cache_expiry_predictive_minutes,
		"max_movement_history": max_movement_history,
		"batch_process_size": batch_process_size,
		
		# 调试配置
		"debug_mode": debug_mode,
		"enable_performance_logging": enable_performance_logging,
		"show_algorithm_choice": show_algorithm_choice,
		
		# 深度性能优化配置
		"enable_quick_preview": enable_quick_preview,
		"enable_framewise_computation": enable_framewise_computation,
		"max_computation_time_ms": max_computation_time_ms,
		"preview_resolution": preview_resolution,
		"framewise_chunks": framewise_chunks,
		"enable_worker_threads": enable_worker_threads,
		"max_worker_threads": max_worker_threads,
		
		# 缓存优化配置
		"enable_lookup_table": enable_lookup_table,
		"enable_preload_cache": enable_preload_cache,
		"preload_queue_size": preload_queue_size,
		"cache_cleanup_interval": cache_cleanup_interval,
		"async_cache_operations": async_cache_operations,
		
		# 算法优化配置
		"simplified_obstacle_detection": simplified_obstacle_detection,
		"obstacle_detection_radius": obstacle_detection_radius,
		"enable_spatial_optimization": enable_spatial_optimization,
		"spatial_grid_size": spatial_grid_size,
		
		# 性能监控配置
		"enable_performance_monitoring": enable_performance_monitoring,
		"performance_log_interval": performance_log_interval,
		"target_frame_time_ms": target_frame_time_ms,
		"performance_warning_threshold": performance_warning_threshold
	}

func load_settings(settings: Dictionary):
	for key in settings.keys():
		var value = settings[key]
		
		match key:
			"movable_color":
				movable_color = value
			"blocked_color":
				blocked_color = value
			"collision_debug_color":
				collision_debug_color = value
			"texture_resolution":
				set_texture_resolution(value)
			"enable_threading":
				enable_threading = value
			"adaptive_resolution":
				adaptive_resolution = value
			"memory_limit_mb":
				set_memory_limit(value)
			"enable_gpu_compute":
				set_gpu_enabled(value)
			"enable_predictive_cache":
				enable_predictive_cache = value
			"enable_visual_effects":
				set_visual_effects_enabled(value)
			"batch_computation":
				batch_computation = value
			"animation_speed":
				set_animation_speed(value)
			"enable_smart_algorithm_selection":
				enable_smart_algorithm_selection = value
			"gpu_threshold_complexity":
				gpu_threshold_complexity = value
			"performance_auto_adjust":
				performance_auto_adjust = value
			"cache_expiry_global_minutes":
				cache_expiry_global_minutes = value
			"cache_expiry_predictive_minutes":
				cache_expiry_predictive_minutes = value
			"max_movement_history":
				max_movement_history = value
			"batch_process_size":
				batch_process_size = value
			"debug_mode":
				set_debug_mode(value)
			"enable_performance_logging":
				set_performance_logging(value)
			"show_algorithm_choice":
				show_algorithm_choice = value
			"enable_quick_preview":
				enable_quick_preview = value
			"enable_framewise_computation":
				enable_framewise_computation = value
			"max_computation_time_ms":
				max_computation_time_ms = value
			"preview_resolution":
				preview_resolution = value
			"framewise_chunks":
				framewise_chunks = value
			"enable_worker_threads":
				enable_worker_threads = value
			"max_worker_threads":
				max_worker_threads = value
			"enable_lookup_table":
				enable_lookup_table = value
			"enable_preload_cache":
				enable_preload_cache = value
			"preload_queue_size":
				preload_queue_size = value
			"cache_cleanup_interval":
				cache_cleanup_interval = value
			"async_cache_operations":
				async_cache_operations = value
			"simplified_obstacle_detection":
				simplified_obstacle_detection = value
			"obstacle_detection_radius":
				obstacle_detection_radius = value
			"enable_spatial_optimization":
				enable_spatial_optimization = value
			"spatial_grid_size":
				spatial_grid_size = value
			"enable_performance_monitoring":
				enable_performance_monitoring = value
			"performance_log_interval":
				performance_log_interval = value
			"target_frame_time_ms":
				target_frame_time_ms = value
			"performance_warning_threshold":
				performance_warning_threshold = value
	
	print("🚀 [Config] 配置已加载") 

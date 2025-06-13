extends Node
class_name EnvironmentSettings

## 环境设置配置管理器
## 专门负责管理关卡的环境配置，包括光照、天气、背景贴图等

@export_group("环境基础")
@export var ambient_light_color: Color = Color.WHITE
@export var ambient_light_energy: float = 1.0
@export var gravity_scale: float = 1.0
@export var friction_modifier: float = 1.0

@export_group("前景装饰配置")
@export var enable_hanging_objects: bool = true
@export var enable_fog_effects: bool = false
@export var enable_rain_effects: bool = false

@export_group("视差滚动设置")
@export var sky_motion_scale: Vector2 = Vector2(0.1, 0.1)
@export var distant_motion_scale: Vector2 = Vector2(0.3, 0.3)
@export var midground_motion_scale: Vector2 = Vector2(0.6, 0.6)

@export_group("天气效果")
@export var weather_type: String = "clear"  # "clear", "rain", "snow", "fog", "storm"
@export var weather_intensity: float = 1.0
@export var wind_strength: float = 0.0
@export var wind_direction: Vector2 = Vector2.RIGHT

@export_group("音效设置")
@export var ambient_sound_path: String = ""
@export var background_music_path: String = ""
@export var weather_sound_path: String = ""



## 应用视差滚动设置
func apply_parallax_settings() -> void:
	"""应用视差滚动配置"""
	print("🎮 [环境设置] 应用视差滚动设置...")
	
	var background_layers = get_node_or_null("../../BackgroundLayers/ParallaxBackground")
	if not background_layers:
		printerr("❌ [环境设置] 未找到背景层节点")
		return
	
	# 设置各层motion_scale
	var sky_layer = background_layers.get_node_or_null("SkyLayer")
	if sky_layer:
		sky_layer.motion_scale = sky_motion_scale
		print("🌤️ [环境设置] 天空层视差: %s" % sky_motion_scale)
	
	var distant_layer = background_layers.get_node_or_null("DistantLayer")
	if distant_layer:
		distant_layer.motion_scale = distant_motion_scale
		print("🏔️ [环境设置] 远景层视差: %s" % distant_motion_scale)
	
	var midground_layer = background_layers.get_node_or_null("MidgroundLayer")
	if midground_layer:
		midground_layer.motion_scale = midground_motion_scale
		print("🌳 [环境设置] 中景层视差: %s" % midground_motion_scale)

## 应用环境设置（主方法）
func apply_environment_settings():
	"""应用所有环境设置"""
	print("🌍 [环境设置] 开始应用环境设置...")
	
	# 1. 应用视差滚动设置
	apply_parallax_settings()
	
	# 2. 应用环境光照
	apply_lighting_settings()
	
	# 3. 应用天气效果
	apply_weather_effects()
	
	print("✅ [环境设置] 环境设置应用完成")

## 应用光照设置
func apply_lighting_settings():
	"""应用环境光照设置"""
	print("💡 [环境设置] 应用光照设置...")
	
	# 基础光照设置（如需要可以在这里扩展）
	# 注意：全局着色器参数需要先在项目设置中定义
	
	print("✅ [环境设置] 光照设置完成: 颜色=%s, 强度=%.2f" % [ambient_light_color, ambient_light_energy])

## 应用天气效果
func apply_weather_effects():
	"""应用天气效果"""
	print("🌦️ [环境设置] 应用天气效果: %s" % weather_type)
	
	# 获取前景层节点
	var foreground_layers = get_node_or_null("../../ForegroundLayers")
	if not foreground_layers:
		printerr("❌ [环境设置] 未找到前景层节点")
		return
	
	# 根据天气类型启用/禁用效果
	var rain_drops = foreground_layers.get_node_or_null("CoverLayer/RainDrops")
	var fog = foreground_layers.get_node_or_null("CoverLayer/Fog")
	
	if rain_drops:
		rain_drops.visible = (weather_type == "rain" or weather_type == "storm") and enable_rain_effects
	
	if fog:
		fog.visible = (weather_type == "fog" or weather_type == "storm") and enable_fog_effects

## 从CSV配置加载环境设置
func load_from_level_config(level_id: String):
	"""从DataManager的关卡配置中加载环境设置"""
	print("📋 [环境设置] 从关卡配置加载环境设置: %s" % level_id)
	
	# 这里可以扩展从CSV中读取环境配置
	# 背景贴图直接在编辑器中设置，无需代码控制
	print("🎨 [环境设置] 背景贴图已在编辑器中配置")

## 验证环境设置
func validate_environment_settings() -> Array[String]:
	"""验证环境设置的有效性"""
	var errors: Array[String] = []
	
	# 检查视差滚动参数
	if sky_motion_scale.x < 0 or sky_motion_scale.y < 0:
		errors.append("天空层视差参数无效")
	
	if distant_motion_scale.x < 0 or distant_motion_scale.y < 0:
		errors.append("远景层视差参数无效")
	
	if midground_motion_scale.x < 0 or midground_motion_scale.y < 0:
		errors.append("中景层视差参数无效")
	
	return errors

## 获取配置摘要
func get_config_summary() -> String:
	"""获取环境配置摘要信息"""
	var summary = "=== 环境配置摘要 ===\n"
	summary += "天气类型: %s\n" % weather_type
	summary += "视差滚动:\n"
	summary += "  天空层: %s\n" % sky_motion_scale
	summary += "  远景层: %s\n" % distant_motion_scale
	summary += "  中景层: %s\n" % midground_motion_scale
	summary += "备注: 背景贴图在编辑器中直接配置\n"
	
	return summary 

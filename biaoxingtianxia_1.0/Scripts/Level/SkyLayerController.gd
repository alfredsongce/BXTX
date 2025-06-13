extends ParallaxLayer
class_name SkyLayerController

## SkyLayer控制器 - 修复版天空背景管理
## 使用正确的坐标系统和可见区域检测

@export_group("自动移动设置")
@export var enable_auto_movement: bool = true
@export var sky_move_speed: float = 20.0  # 天空移动速度（像素/秒）
@export var cloud_move_speed: float = 12.0  # 云朵移动速度（像素/秒）

@export_group("视差效果设置")
@export var enable_parallax: bool = true
@export var custom_motion_scale: Vector2 = Vector2(0.1, 0.0)  # Y轴为0表示只水平移动

# 内部变量
var sky_sprites: Node2D
var sky_sprite: Sprite2D
var sky_sprite_2: Sprite2D  # 第二个天空贴图用于无缝循环
var cloud_sprites: Array[Sprite2D] = []
var viewport: Viewport
var camera: Camera2D
var sky_texture_width: float
var sky_texture_height: float

func _ready():
	# 设置视差参数
	if enable_parallax:
		motion_scale = custom_motion_scale
	
	# 获取视窗和相机
	viewport = get_viewport()
	
	# 查找节点
	_find_sprite_nodes()
	
	# 设置无缝循环
	if sky_sprite:
		_setup_seamless_loop()
	
	# 开始自动移动
	if enable_auto_movement and sky_sprite:
		_start_auto_movement()

func _find_sprite_nodes():
	"""查找天空和云朵节点"""
	# 查找SkySprites容器
	sky_sprites = get_node_or_null("SkySprites")
	if not sky_sprites:
		return
	
	# 查找Sky节点
	sky_sprite = sky_sprites.get_node_or_null("Sky")
	
	# 查找所有云朵节点
	cloud_sprites.clear()
	for child in sky_sprites.get_children():
		if child is Sprite2D and child.name.begins_with("Cloud"):
			cloud_sprites.append(child)

func _setup_seamless_loop():
	"""设置无缝循环系统"""
	if not sky_sprite or not sky_sprite.texture:
		return
	
	# 获取贴图信息
	var texture_size = sky_sprite.texture.get_size()
	var sprite_scale = sky_sprite.scale
	sky_texture_width = texture_size.x * sprite_scale.x
	sky_texture_height = texture_size.y * sprite_scale.y
	
	# 创建第二个天空贴图
	sky_sprite_2 = Sprite2D.new()
	sky_sprite_2.name = "Sky_Loop"
	sky_sprite_2.texture = sky_sprite.texture
	sky_sprite_2.scale = sky_sprite.scale
	sky_sprites.add_child(sky_sprite_2)
	
	# 设置第二个贴图位置（紧挨着第一个贴图右边）
	sky_sprite_2.position = Vector2(sky_sprite.position.x + sky_texture_width, sky_sprite.position.y)

func _start_auto_movement():
	"""开始自动移动"""
	pass

func _process(delta):
	if enable_auto_movement and sky_sprite and sky_sprite_2:
		_move_sky_seamlessly(delta)
		_move_clouds(delta)

func _get_camera_bounds() -> Rect2:
	"""获取相机的实际可见区域边界"""
	# 尝试找到主相机
	if not camera:
		camera = get_viewport().get_camera_2d()
	
	if camera:
		# 有相机的情况：使用相机的可见区域
		var camera_pos = camera.global_position
		var viewport_size = viewport.get_visible_rect().size
		var zoom = camera.zoom
		
		# 计算实际可见区域
		var visible_size = viewport_size / zoom
		var visible_rect = Rect2(
			camera_pos - visible_size / 2,
			visible_size
		)
		
		return visible_rect
	else:
		# 没有相机的情况：使用视窗大小
		var viewport_size = viewport.get_visible_rect().size
		var visible_rect = Rect2(Vector2.ZERO, viewport_size)
		
		return visible_rect

func _move_sky_seamlessly(delta):
	"""无缝移动天空背景"""
	var move_distance = -sky_move_speed * delta
	
	# 移动两个天空贴图
	sky_sprite.position.x += move_distance
	sky_sprite_2.position.x += move_distance
	
	# 获取相机可见区域
	var camera_bounds = _get_camera_bounds()
	var screen_left = camera_bounds.position.x
	
	# 计算贴图边界
	var sky1_right = sky_sprite.position.x + sky_texture_width / 2
	var sky2_right = sky_sprite_2.position.x + sky_texture_width / 2
	
	# 检查第一张图是否完全移出屏幕左边
	if sky1_right < screen_left:
		# 将第一张图移动到第二张图的右边
		sky_sprite.position.x = sky_sprite_2.position.x + sky_texture_width
	
	# 检查第二张图是否完全移出屏幕左边
	elif sky2_right < screen_left:
		# 将第二张图移动到第一张图的右边
		sky_sprite_2.position.x = sky_sprite.position.x + sky_texture_width

func _move_clouds(delta):
	"""移动云朵"""
	var cloud_move_distance = -cloud_move_speed * delta
	var camera_bounds = _get_camera_bounds()
	var screen_left = camera_bounds.position.x
	var screen_right = camera_bounds.position.x + camera_bounds.size.x
	
	for cloud in cloud_sprites:
		if cloud and is_instance_valid(cloud):
			cloud.position.x += cloud_move_distance
			
			# 云朵循环逻辑：如果完全移出屏幕左边，则移动到屏幕右边外
			if cloud.position.x < screen_left - 100:  # 留一些缓冲
				cloud.position.x = screen_right + randf_range(100, 500)  # 随机间距

# 编辑器中的帮助信息
func _get_configuration_warnings():
	var warnings = []
	
	if not get_node_or_null("SkySprites"):
		warnings.append("需要子节点 'SkySprites' 作为贴图容器")
	
	var sky_node = get_node_or_null("SkySprites/Sky")
	if not sky_node:
		warnings.append("需要在 SkySprites 下创建名为 'Sky' 的 Sprite2D 节点")
	elif not sky_node.texture:
		warnings.append("Sky 节点需要设置 texture")
	
	return warnings 

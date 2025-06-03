# 障碍物系统 - 乱石障碍物
class_name Obstacle
extends Area2D

# 障碍物类型枚举
enum ObstacleType {
	ROCK,      # 乱石
	WALL,      # 墙壁
	WATER,     # 水域
	PIT,       # 陷阱
	PLATFORM   # 平台
}

# 障碍物配置
@export var obstacle_type: ObstacleType = ObstacleType.ROCK
@export var obstacle_radius: float = 20.0
@export var obstacle_color: Color = Color.RED
@export var is_passable: bool = false  # 是否可通行
@export var blocks_vision: bool = false  # 是否阻挡视线

# 平台专用配置
@export var platform_width: float = 200.0  # 平台宽度
@export var platform_height: float = 10.0  # 平台厚度

# 内部组件
var collision_shape: CollisionShape2D
var visual_shape: Node2D

func _ready():
	_setup_obstacle()
	_setup_collision()
	_setup_visual()

func _setup_obstacle():
	# 设置Area2D基本属性
	name = "Obstacle_" + ObstacleType.keys()[obstacle_type]
	collision_layer = 8  # 障碍物层
	collision_mask = 0   # 不检测其他物体
	monitoring = false   # 不需要监测进入
	monitorable = true   # 允许被其他物体检测

func _setup_collision():
	# 获取已存在的碰撞形状节点
	collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape:
		# 如果没有找到，创建一个新的
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	
	# 根据障碍物类型更新形状
	match obstacle_type:
		ObstacleType.ROCK:
			if not collision_shape.shape or not collision_shape.shape is CircleShape2D:
				var circle_shape = CircleShape2D.new()
				circle_shape.radius = obstacle_radius
				collision_shape.shape = circle_shape
			else:
				(collision_shape.shape as CircleShape2D).radius = obstacle_radius
		ObstacleType.WALL:
			if not collision_shape.shape or not collision_shape.shape is RectangleShape2D:
				var rect_shape = RectangleShape2D.new()
				rect_shape.size = Vector2(obstacle_radius * 2, obstacle_radius * 3)
				collision_shape.shape = rect_shape
		ObstacleType.WATER, ObstacleType.PIT:
			if not collision_shape.shape or not collision_shape.shape is CircleShape2D:
				var circle_shape = CircleShape2D.new()
				circle_shape.radius = obstacle_radius
				collision_shape.shape = circle_shape
			else:
				(collision_shape.shape as CircleShape2D).radius = obstacle_radius
		ObstacleType.PLATFORM:
			if not collision_shape.shape or not collision_shape.shape is RectangleShape2D:
				var rect_shape = RectangleShape2D.new()
				rect_shape.size = Vector2(platform_width, platform_height)
				collision_shape.shape = rect_shape
			else:
				(collision_shape.shape as RectangleShape2D).size = Vector2(platform_width, platform_height)
		_:
			# 默认使用圆形
			if not collision_shape.shape or not collision_shape.shape is CircleShape2D:
				var circle_shape = CircleShape2D.new()
				circle_shape.radius = obstacle_radius
				collision_shape.shape = circle_shape
			else:
				(collision_shape.shape as CircleShape2D).radius = obstacle_radius

func _setup_visual():
	# 直接在当前节点绘制，不需要额外的可视化节点
	queue_redraw()

func _draw():
	# 绘制障碍物
	match obstacle_type:
		ObstacleType.ROCK:
			_draw_rock()
		ObstacleType.WALL:
			_draw_wall()
		ObstacleType.WATER:
			_draw_water()
		ObstacleType.PIT:
			_draw_pit()
		ObstacleType.PLATFORM:
			_draw_platform()
		_:
			_draw_default()

func _draw_rock():
	# 绘制乱石 - 红色圆圈
	draw_circle(Vector2.ZERO, obstacle_radius, obstacle_color)
	# 添加边框
	draw_arc(Vector2.ZERO, obstacle_radius, 0, TAU, 32, Color.DARK_RED, 2.0)

func _draw_wall():
	# 绘制墙壁 - 棕色矩形
	var rect = Rect2(-obstacle_radius, -obstacle_radius * 1.5, obstacle_radius * 2, obstacle_radius * 3)
	draw_rect(rect, obstacle_color)
	# 添加边框
	draw_rect(rect, Color.DARK_GRAY, false, 2.0)

func _draw_water():
	# 绘制水域 - 半透明蓝色圆圈
	draw_circle(Vector2.ZERO, obstacle_radius, obstacle_color)
	# 添加波纹效果
	for i in range(3):
		var radius = obstacle_radius * (0.3 + i * 0.2)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 16, Color.CYAN, 1.0)

func _draw_pit():
	# 绘制陷阱 - 深色圆圈
	draw_circle(Vector2.ZERO, obstacle_radius, obstacle_color)
	# 添加内圈表示深度
	draw_circle(Vector2.ZERO, obstacle_radius * 0.7, Color.BLACK)
	draw_arc(Vector2.ZERO, obstacle_radius, 0, TAU, 32, Color.DARK_RED, 2.0)

func _draw_platform():
	# 绘制平台 - 浅绿色矩形
	var rect = Rect2(-platform_width/2, -platform_height/2, platform_width, platform_height)
	draw_rect(rect, Color.LIGHT_GREEN)
	# 添加边框
	draw_rect(rect, Color.GREEN, false, 2.0)

func _draw_default():
	# 默认绘制
	draw_circle(Vector2.ZERO, obstacle_radius, obstacle_color)

# 检查位置是否被此障碍物阻挡
func is_position_blocked(pos: Vector2) -> bool:
	if is_passable:
		return false
	
	var distance = global_position.distance_to(pos)
	return distance <= obstacle_radius

# 获取障碍物信息
func get_obstacle_info() -> Dictionary:
	return {
		"type": obstacle_type,
		"position": global_position,
		"radius": obstacle_radius,
		"passable": is_passable,
		"blocks_vision": blocks_vision
	}

# 设置障碍物位置
func set_obstacle_position(pos: Vector2):
	global_position = pos
	queue_redraw()

# 设置障碍物大小
func set_obstacle_size(radius: float):
	obstacle_radius = radius
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = radius
	queue_redraw()

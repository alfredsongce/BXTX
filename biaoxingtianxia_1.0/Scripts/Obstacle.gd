# 障碍物系统 - 乱石障碍物
class_name Obstacle
extends StaticBody2D

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
@export var obstacle_color: Color = Color.RED
@export var is_passable: bool = false  # 是否可通行
@export var blocks_vision: bool = false  # 是否阻挡视线

# 内部组件
var collision_shape: CollisionShape2D

func _ready():
	_setup_obstacle()
	_get_collision_shape()
	_setup_visual()

func _setup_obstacle():
	# 设置Area2D基本属性
	name = "Obstacle_" + ObstacleType.keys()[obstacle_type]
	
	# 根据障碍物类型设置不同的碰撞层
	match obstacle_type:
		ObstacleType.PLATFORM:
			collision_layer = 1  # 地面层 - 用于地面约束检查
		ObstacleType.WATER:
			collision_layer = 16  # 水面层 - 用于水面约束检查
		_:
			collision_layer = 8  # 其他障碍物层
	
	collision_mask = 0   # 不检测其他物体
	
	print("🏗️ 障碍物设置完成: %s, 碰撞层: %d" % [ObstacleType.keys()[obstacle_type], collision_layer])

func _get_collision_shape():
	# 获取场景中预配置的碰撞形状节点
	collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape:
		printerr("错误：障碍物场景必须包含预配置的CollisionShape2D节点")
		return
	
	if not collision_shape.shape:
		printerr("错误：CollisionShape2D节点必须预配置碰撞形状")
		return
	
	print("✅ 障碍物碰撞形状已加载: %s" % collision_shape.shape.get_class())

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
	# 绘制乱石 - 使用碰撞形状的实际大小
	if collision_shape and collision_shape.shape is CircleShape2D:
		var radius = (collision_shape.shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, radius, obstacle_color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.DARK_RED, 2.0)

func _draw_wall():
	# 绘制墙壁 - 使用碰撞形状的实际大小
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var size = (collision_shape.shape as RectangleShape2D).size
		var rect = Rect2(-size.x/2, -size.y/2, size.x, size.y)
		draw_rect(rect, obstacle_color)
		draw_rect(rect, Color.DARK_GRAY, false, 2.0)

func _draw_water():
	# 绘制水域 - 使用碰撞形状的实际大小
	if collision_shape and collision_shape.shape is CircleShape2D:
		var radius = (collision_shape.shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, radius, obstacle_color)
		# 添加波纹效果
		for i in range(3):
			var wave_radius = radius * (0.3 + i * 0.2)
			draw_arc(Vector2.ZERO, wave_radius, 0, TAU, 16, Color.CYAN, 1.0)

func _draw_pit():
	# 绘制陷阱 - 使用碰撞形状的实际大小
	if collision_shape and collision_shape.shape is CircleShape2D:
		var radius = (collision_shape.shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, radius, obstacle_color)
		draw_circle(Vector2.ZERO, radius * 0.7, Color.BLACK)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.DARK_RED, 2.0)

func _draw_platform():
	# 绘制平台 - 使用碰撞形状的实际大小
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var size = (collision_shape.shape as RectangleShape2D).size
		var rect = Rect2(-size.x/2, -size.y/2, size.x, size.y)
		draw_rect(rect, Color.LIGHT_GREEN)
		draw_rect(rect, Color.GREEN, false, 2.0)

func _draw_default():
	# 默认绘制 - 尝试从碰撞形状获取大小
	if collision_shape and collision_shape.shape is CircleShape2D:
		var radius = (collision_shape.shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, radius, obstacle_color)
	elif collision_shape and collision_shape.shape is RectangleShape2D:
		var size = (collision_shape.shape as RectangleShape2D).size
		var rect = Rect2(-size.x/2, -size.y/2, size.x, size.y)
		draw_rect(rect, obstacle_color)
	else:
		# 如果没有碰撞形状，绘制默认圆形
		draw_circle(Vector2.ZERO, 20.0, obstacle_color)

# 检查位置是否被此障碍物阻挡
func is_position_blocked(pos: Vector2) -> bool:
	if is_passable:
		return false
	
	# 使用实际的碰撞形状进行检测
	if not collision_shape or not collision_shape.shape:
		return false
	
	var local_pos = to_local(pos)
	
	if collision_shape.shape is CircleShape2D:
		var radius = (collision_shape.shape as CircleShape2D).radius
		return local_pos.length() <= radius
	elif collision_shape.shape is RectangleShape2D:
		var size = (collision_shape.shape as RectangleShape2D).size
		var rect = Rect2(-size.x/2, -size.y/2, size.x, size.y)
		return rect.has_point(local_pos)
	
	return false

# 获取障碍物信息
func get_obstacle_info() -> Dictionary:
	var info = {
		"type": obstacle_type,
		"position": global_position,
		"passable": is_passable,
		"blocks_vision": blocks_vision
	}
	
	# 根据实际碰撞形状添加尺寸信息
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CircleShape2D:
			info["radius"] = (collision_shape.shape as CircleShape2D).radius
		elif collision_shape.shape is RectangleShape2D:
			info["size"] = (collision_shape.shape as RectangleShape2D).size
	
	return info

# 设置障碍物位置
func set_obstacle_position(pos: Vector2):
	global_position = pos
	queue_redraw()

# 设置障碍物大小（仅用于运行时调整）
func set_obstacle_size(new_size):
	if not collision_shape or not collision_shape.shape:
		printerr("错误：无法设置障碍物大小，缺少碰撞形状")
		return
	
	if collision_shape.shape is CircleShape2D and new_size is float:
		(collision_shape.shape as CircleShape2D).radius = new_size
	elif collision_shape.shape is RectangleShape2D and new_size is Vector2:
		(collision_shape.shape as RectangleShape2D).size = new_size
	else:
		printerr("错误：障碍物大小类型不匹配")
		return
	
	queue_redraw()

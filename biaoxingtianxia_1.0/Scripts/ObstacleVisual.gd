# 障碍物可视化脚本
extends Node2D

# 障碍物属性
var obstacle_radius: float = 20.0
var obstacle_color: Color = Color.RED
var obstacle_type: int = 0  # 对应Obstacle.ObstacleType

func _ready():
	queue_redraw()

func _draw():
	match obstacle_type:
		0:  # ROCK
			_draw_rock()
		_:
			_draw_default()

func _draw_rock():
	# 绘制乱石 - 红色圆圈带纹理效果
	# 主体
	draw_circle(Vector2.ZERO, obstacle_radius, obstacle_color)
	
	# 边框
	draw_arc(Vector2.ZERO, obstacle_radius, 0, TAU, 32, Color.DARK_RED, 3.0)
	
	# 添加一些细节线条模拟石头纹理
	var line_color = Color.DARK_RED
	line_color.a = 0.7
	
	# 绘制几条随机的裂纹线
	for i in range(3):
		var angle = (i * TAU / 3.0) + randf() * 0.5
		var start = Vector2(cos(angle), sin(angle)) * (obstacle_radius * 0.3)
		var end = Vector2(cos(angle), sin(angle)) * (obstacle_radius * 0.8)
		draw_line(start, end, line_color, 2.0)

func _draw_default():
	# 默认绘制
	draw_circle(Vector2.ZERO, obstacle_radius, obstacle_color)
	draw_arc(Vector2.ZERO, obstacle_radius, 0, TAU, 32, obstacle_color.darkened(0.3), 2.0)
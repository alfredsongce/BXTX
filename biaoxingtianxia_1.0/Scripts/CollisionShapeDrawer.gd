# 碰撞形状可视化绘制器
extends Node2D
class_name CollisionShapeDrawer

# 绘制属性
var shape_type: String = ""
var shape_color: Color = Color.CYAN
var border_color: Color = Color.WHITE
var border_width: float = 2.0
var fill_alpha: float = 0.3

# 胶囊形状属性
var capsule_radius: float = 0.0
var capsule_height: float = 0.0

# 圆形属性
var circle_radius: float = 0.0

# 矩形属性
var rect_size: Vector2 = Vector2.ZERO

# 角色ID（用于调试）
var character_id: String = ""

# 是否显示X号（表示不可移动）
var show_x_mark: bool = false

# 设置胶囊形状
func setup_capsule(radius: float, height: float, char_id: String):
	shape_type = "capsule"
	capsule_radius = radius
	capsule_height = height
	character_id = char_id
	
	# 根据角色ID设置不同颜色
	shape_color = _get_character_color(char_id)
	queue_redraw()

# 设置圆形
func setup_circle(radius: float, char_id: String):
	shape_type = "circle"
	circle_radius = radius
	character_id = char_id
	
	shape_color = _get_character_color(char_id)
	queue_redraw()

# 设置矩形
func setup_rectangle(size: Vector2, char_id: String):
	shape_type = "rectangle"
	rect_size = size
	character_id = char_id
	
	shape_color = _get_character_color(char_id)
	queue_redraw()

# 根据角色ID获取颜色
func _get_character_color(char_id: String) -> Color:
	match char_id:
		"1":
			return Color.CYAN
		"2":
			return Color.YELLOW
		"3":
			return Color.MAGENTA
		_:
			return Color.GREEN

# 绘制碰撞形状
func _draw():
	match shape_type:
		"capsule":
			_draw_capsule()
		"circle":
			_draw_circle()
		"rectangle":
			_draw_rectangle()
	
	# 如果需要显示X号，在中心绘制
	if show_x_mark:
		_draw_x_mark()

# 绘制胶囊形状
func _draw_capsule():
	if capsule_radius <= 0 or capsule_height <= 0:
		return
	
	# 胶囊 = 矩形 + 两个半圆
	var rect_height = capsule_height - 2 * capsule_radius
	
	# 绘制中间的矩形部分
	if rect_height > 0:
		var rect = Rect2(-capsule_radius, -rect_height/2, capsule_radius * 2, rect_height)
		draw_rect(rect, Color(shape_color.r, shape_color.g, shape_color.b, fill_alpha))
		
		# 绘制矩形边框
		draw_line(Vector2(-capsule_radius, -rect_height/2), Vector2(-capsule_radius, rect_height/2), border_color, border_width)
		draw_line(Vector2(capsule_radius, -rect_height/2), Vector2(capsule_radius, rect_height/2), border_color, border_width)
	
	# 绘制上半圆
	var top_center = Vector2(0, -rect_height/2)
	draw_circle(top_center, capsule_radius, Color(shape_color.r, shape_color.g, shape_color.b, fill_alpha))
	draw_arc(top_center, capsule_radius, 0, 2 * PI, 32, border_color, border_width)
	
	# 绘制下半圆
	var bottom_center = Vector2(0, rect_height/2)
	draw_circle(bottom_center, capsule_radius, Color(shape_color.r, shape_color.g, shape_color.b, fill_alpha))
	draw_arc(bottom_center, capsule_radius, 0, 2 * PI, 32, border_color, border_width)

# 绘制圆形
func _draw_circle():
	if circle_radius <= 0:
		return
	
	# 绘制填充圆
	draw_circle(Vector2.ZERO, circle_radius, Color(shape_color.r, shape_color.g, shape_color.b, fill_alpha))
	
	# 绘制边框
	draw_arc(Vector2.ZERO, circle_radius, 0, 2 * PI, 32, border_color, border_width)

# 绘制矩形
func _draw_rectangle():
	if rect_size == Vector2.ZERO:
		return
	
	var rect = Rect2(-rect_size/2, rect_size)
	
	# 绘制填充矩形
	draw_rect(rect, Color(shape_color.r, shape_color.g, shape_color.b, fill_alpha))
	
	# 绘制边框
	draw_rect(rect, border_color, false, border_width)

# 设置可见性
func set_visibility(visible_state: bool):
	visible = visible_state

# 更新颜色
func update_color(new_color: Color):
	shape_color = new_color
	queue_redraw()

# 设置是否显示X号
func set_x_mark(show: bool):
	show_x_mark = show
	queue_redraw()

# 绘制X号标记
func _draw_x_mark():
	var x_size = 15.0
	var x_width = 3.0
	var x_color = Color.RED
	
	# 绘制X的两条对角线
	draw_line(Vector2(-x_size, -x_size), Vector2(x_size, x_size), x_color, x_width)
	draw_line(Vector2(-x_size, x_size), Vector2(x_size, -x_size), x_color, x_width)

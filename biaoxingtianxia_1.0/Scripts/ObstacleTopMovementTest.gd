# 障碍物顶部移动功能测试脚本
# 用于验证新实现的障碍物顶部移动算法

class_name ObstacleTopMovementTest
extends Node2D

# 引用必要的组件
var position_collision_manager: PositionCollisionManager
var test_character: Node2D
var test_obstacles: Array = []

# 测试结果
var test_results: Dictionary = {}

func _ready():
	print("🧪 [ObstacleTopMovementTest] 开始障碍物顶部移动功能测试")
	
	# 初始化测试环境
	_setup_test_environment()
	
	# 运行测试用例
	_run_all_tests()
	
	# 输出测试结果
	_print_test_results()

func _setup_test_environment():
	print("🔧 [ObstacleTopMovementTest] 设置测试环境")
	
	# 创建PositionCollisionManager实例
	position_collision_manager = PositionCollisionManager.new()
	add_child(position_collision_manager)
	
	# 创建测试角色
	test_character = Node2D.new()
	test_character.name = "TestCharacter"
	test_character.position = Vector2(100, 100)
	add_child(test_character)
	
	# 添加GroundAnchor到测试角色
	var ground_anchor = Node2D.new()
	ground_anchor.name = "GroundAnchor" 
	ground_anchor.position = Vector2(0, 22)  # 测试角色的GroundAnchor偏移
	test_character.add_child(ground_anchor)
	print("✅ [测试环境] 创建测试角色GroundAnchor，偏移: %s" % ground_anchor.position)
	
	# 创建测试障碍物
	_create_test_obstacles()

func _create_test_obstacles():
	print("🏗️ [ObstacleTopMovementTest] 创建测试障碍物")
	
	# 创建平台障碍物
	var platform = _create_test_obstacle("Platform", Vector2(200, 150), Obstacle.ObstacleType.PLATFORM, Vector2(50, 20))
	test_obstacles.append(platform)
	
	# 创建墙壁障碍物
	var wall = _create_test_obstacle("Wall", Vector2(300, 120), Obstacle.ObstacleType.WALL, Vector2(20, 80))
	test_obstacles.append(wall)
	
	# 创建圆形障碍物
	var circle_obstacle = _create_test_obstacle("Circle", Vector2(400, 140), Obstacle.ObstacleType.WALL, Vector2(30, 30), true)
	test_obstacles.append(circle_obstacle)

func _create_test_obstacle(obstacle_name: String, pos: Vector2, obstacle_type: int, size: Vector2, is_circle: bool = false) -> StaticBody2D:
	var obstacle = StaticBody2D.new()
	obstacle.name = obstacle_name
	obstacle.position = pos
	obstacle.collision_layer = 8  # 障碍物层
	obstacle.collision_mask = 0
	
	# 设置障碍物类型
	obstacle.set_meta("obstacle_type", obstacle_type)
	
	# 创建碰撞形状
	var collision_shape = CollisionShape2D.new()
	if is_circle:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = size.x / 2
		collision_shape.shape = circle_shape
	else:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = size
		collision_shape.shape = rect_shape
	
	obstacle.add_child(collision_shape)
	add_child(obstacle)
	
	print("✅ [ObstacleTopMovementTest] 创建障碍物: %s (类型: %d, 位置: %s, 大小: %s)" % [obstacle_name, obstacle_type, pos, size])
	return obstacle

func _run_all_tests():
	print("🚀 [ObstacleTopMovementTest] 开始运行测试用例")
	
	# 测试1: 基础表面检测
	_test_basic_surface_detection()
	
	# 测试2: 障碍物顶部检测
	_test_obstacle_top_detection()
	
	# 测试3: 边缘情况测试
	_test_edge_cases()
	
	# 测试4: 性能测试
	_test_performance()

func _test_basic_surface_detection():
	print("📋 [ObstacleTopMovementTest] 测试1: 基础表面检测")
	
	var test_positions = [
		Vector2(50, 100),   # 普通地面
		Vector2(150, 100),  # 普通地面
		Vector2(500, 100),  # 空中位置
	]
	
	for pos in test_positions:
		var result = position_collision_manager._is_position_on_valid_surface(pos)
		test_results["basic_surface_%s" % pos] = result
		print("  位置 %s: %s (类型: %s)" % [pos, "有效" if result.is_valid else "无效", result.surface_type if result.is_valid else "无"])

func _test_obstacle_top_detection():
	print("📋 [ObstacleTopMovementTest] 测试2: 障碍物顶部检测")
	
	# 测试平台顶部
	var platform_top_pos = Vector2(200, 130)  # 平台顶部
	var platform_result = position_collision_manager._is_position_on_valid_surface(platform_top_pos)
	test_results["platform_top"] = platform_result
	print("  平台顶部 %s: %s" % [platform_top_pos, "有效" if platform_result.is_valid else "无效"])
	
	# 测试墙壁顶部
	var wall_top_pos = Vector2(300, 80)  # 墙壁顶部
	var wall_result = position_collision_manager._is_position_on_valid_surface(wall_top_pos)
	test_results["wall_top"] = wall_result
	print("  墙壁顶部 %s: %s" % [wall_top_pos, "有效" if wall_result.is_valid else "无效"])
	
	# 测试圆形障碍物顶部
	var circle_top_pos = Vector2(400, 125)  # 圆形障碍物顶部
	var circle_result = position_collision_manager._is_position_on_valid_surface(circle_top_pos)
	test_results["circle_top"] = circle_result
	print("  圆形障碍物顶部 %s: %s" % [circle_top_pos, "有效" if circle_result.is_valid else "无效"])

func _test_edge_cases():
	print("📋 [ObstacleTopMovementTest] 测试3: 边缘情况测试")
	
	# 测试障碍物边缘
	var edge_positions = [
		Vector2(175, 130),  # 平台左边缘
		Vector2(225, 130),  # 平台右边缘
		Vector2(290, 80),   # 墙壁左边缘
		Vector2(310, 80),   # 墙壁右边缘
	]
	
	for pos in edge_positions:
		var result = position_collision_manager._is_position_on_valid_surface(pos)
		test_results["edge_%s" % pos] = result
		print("  边缘位置 %s: %s" % [pos, "有效" if result.is_valid else "无效"])

func _test_performance():
	print("📋 [ObstacleTopMovementTest] 测试4: 性能测试")
	
	var start_time = Time.get_time_dict_from_system()
	var test_count = 1000
	
	for i in range(test_count):
		var random_pos = Vector2(randf_range(0, 500), randf_range(50, 200))
		position_collision_manager._is_position_on_valid_surface(random_pos)
	
	var end_time = Time.get_time_dict_from_system()
	var start_total_ms = (start_time.hour * 3600 + start_time.minute * 60 + start_time.second) * 1000
	if start_time.has("millisecond"):
		start_total_ms += start_time.millisecond
	elif start_time.has("msec"):
		start_total_ms += start_time.msec
	
	var end_total_ms = (end_time.hour * 3600 + end_time.minute * 60 + end_time.second) * 1000
	if end_time.has("millisecond"):
		end_total_ms += end_time.millisecond
	elif end_time.has("msec"):
		end_total_ms += end_time.msec
	var duration_ms = end_total_ms - start_total_ms
	
	var avg_time = float(duration_ms) / test_count
	test_results["performance"] = {"total_time": duration_ms, "avg_time": avg_time, "test_count": test_count}
	print("  性能测试: %d次调用，总时间: %dms，平均时间: %.3fms" % [test_count, duration_ms, avg_time])

func _print_test_results():
	print("\n📊 [ObstacleTopMovementTest] 测试结果汇总:")
	print("=".repeat(50))
	
	var passed_tests = 0
	var total_tests = 0
	
	for test_name in test_results.keys():
		if test_name == "performance":
			continue
		
		total_tests += 1
		var result = test_results[test_name]
		if result.is_valid:
			passed_tests += 1
			print("✅ %s: 通过 (表面类型: %s, Y坐标: %.1f)" % [test_name, result.surface_type, result.surface_y])
		else:
			print("❌ %s: 失败" % test_name)
	
	print("\n📈 测试统计:")
	print("  通过: %d/%d (%.1f%%)" % [passed_tests, total_tests, float(passed_tests) / total_tests * 100])
	
	if "performance" in test_results:
		var perf = test_results["performance"]
		print("  性能: 平均 %.3fms/次" % perf.avg_time)
	
	print("=".repeat(50))
	print("🎯 [ObstacleTopMovementTest] 测试完成!")
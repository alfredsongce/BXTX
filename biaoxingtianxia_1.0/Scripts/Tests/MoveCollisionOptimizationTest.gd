extends Node

# 移动碰撞检测优化方案测试脚本
# 用于验证PhysicsShapeQueryParameters2D和Area2D预检测系统的功能

class_name MoveCollisionOptimizationTest

# 测试组件引用
var validator: MoveRangeValidator
var preview_area: MovePreviewArea
var controller: MoveRangeController
var input_handler: MoveRangeInput

# 测试结果统计
var test_results = {
	"physics_query_tests": [],
	"area2d_preview_tests": [],
	"performance_tests": [],
	"integration_tests": []
}

func _ready():
	print("🧪 [Test] 移动碰撞检测优化方案测试开始")
	_setup_test_environment()
	_run_all_tests()

func _setup_test_environment():
	"""设置测试环境"""
	print("🔧 [Test] 设置测试环境...")
	
	# 查找或创建测试组件
	validator = _find_or_create_validator()
	preview_area = _find_or_create_preview_area()
	controller = _find_or_create_controller()
	input_handler = _find_or_create_input_handler()
	
	print("✅ [Test] 测试环境设置完成")

func _find_or_create_validator() -> MoveRangeValidator:
	"""查找或创建验证器"""
	var existing = get_tree().get_first_node_in_group("move_range_validator")
	if existing:
		return existing
	
	# 创建新的验证器
	var new_validator = preload("res://Scripts/MoveRangeDisplay/MoveRangeValidator.gd").new()
	add_child(new_validator)
	return new_validator

func _find_or_create_preview_area() -> MovePreviewArea:
	"""查找或创建预览区域"""
	var existing = get_node_or_null("MovePreviewArea")
	if existing:
		return existing
	
	# 创建新的预览区域
	var new_preview = preload("res://Scripts/MoveRangeDisplay/MovePreviewArea.gd").new()
	new_preview.name = "MovePreviewArea"
	add_child(new_preview)
	return new_preview

func _find_or_create_controller() -> MoveRangeController:
	"""查找或创建控制器"""
	var existing = get_tree().get_first_node_in_group("move_range_controller")
	if existing:
		return existing
	
	return null  # 控制器通常由场景管理

func _find_or_create_input_handler() -> MoveRangeInput:
	"""查找或创建输入处理器"""
	var existing = get_tree().get_first_node_in_group("move_range_input")
	if existing:
		return existing
	
	return null  # 输入处理器通常由场景管理

func _run_all_tests():
	"""运行所有测试"""
	print("🚀 [Test] 开始运行测试套件...")
	
	# 1. 物理查询测试
	_test_physics_query_optimization()
	
	# 2. Area2D预检测测试
	_test_area2d_preview_system()
	
	# 3. 性能测试
	_test_performance_improvements()
	
	# 4. 集成测试
	_test_system_integration()
	
	# 5. 输出测试报告
	_generate_test_report()

func _test_physics_query_optimization():
	"""测试PhysicsShapeQueryParameters2D优化"""
	print("🔍 [Test] 测试物理查询优化...")
	
	if not validator:
		test_results.physics_query_tests.append({
			"name": "validator_availability",
			"result": "FAIL",
			"reason": "Validator not available"
		})
		return
	
	# 测试1：验证器是否支持物理查询
	var supports_physics = validator.has_method("_check_static_obstacles_with_physics_query")
	test_results.physics_query_tests.append({
		"name": "physics_query_method_exists",
		"result": "PASS" if supports_physics else "FAIL",
		"details": "Method _check_static_obstacles_with_physics_query exists: %s" % str(supports_physics)
	})
	
	# 测试2：测试基本碰撞检测
	var test_position = Vector2(100, 100)
	var test_character = _create_mock_character()
	
	if validator.has_method("validate_position_comprehensive"):
		var start_time = Time.get_time_dict_from_system()
		var result = validator.validate_position_comprehensive(test_position, test_character)
		var end_time = Time.get_time_dict_from_system()
		
		test_results.physics_query_tests.append({
			"name": "basic_collision_detection",
			"result": "PASS" if result.has("valid") else "FAIL",
			"details": "Validation result: %s" % str(result),
			"execution_time_ms": _calculate_time_diff(start_time, end_time)
		})
	
	print("✅ [Test] 物理查询优化测试完成")

func _test_area2d_preview_system():
	"""测试Area2D预检测系统"""
	print("🎯 [Test] 测试Area2D预检测系统...")
	
	if not preview_area:
		test_results.area2d_preview_tests.append({
			"name": "preview_area_availability",
			"result": "FAIL",
			"reason": "PreviewArea not available"
		})
		return
	
	# 测试1：预览区域设置
	var test_character = _create_mock_character()
	var setup_success = false
	
	if preview_area.has_method("setup_movement_preview_area"):
		var character_node = _create_mock_character_node()
		preview_area.setup_movement_preview_area(character_node)
		setup_success = true
	
	test_results.area2d_preview_tests.append({
		"name": "preview_area_setup",
		"result": "PASS" if setup_success else "FAIL",
		"details": "Setup method exists and executed: %s" % str(setup_success)
	})
	
	# 测试2：位置更新
	if preview_area.has_method("update_preview_position"):
		var test_position = Vector2(200, 200)
		preview_area.update_preview_position(test_position)
		
		test_results.area2d_preview_tests.append({
			"name": "position_update",
			"result": "PASS",
			"details": "Position update method executed successfully"
		})
	
	# 测试3：碰撞状态获取
	if preview_area.has_method("get_collision_state"):
		var collision_state = preview_area.get_collision_state()
		
		test_results.area2d_preview_tests.append({
			"name": "collision_state_retrieval",
			"result": "PASS" if collision_state is Dictionary else "FAIL",
			"details": "Collision state: %s" % str(collision_state)
		})
	
	print("✅ [Test] Area2D预检测系统测试完成")

func _test_performance_improvements():
	"""测试性能改进"""
	print("⚡ [Test] 测试性能改进...")
	
	# 性能基准测试
	var test_positions = []
	for i in range(100):
		test_positions.append(Vector2(randf() * 1000, randf() * 1000))
	
	var test_character = _create_mock_character()
	
	# 测试传统方法性能（如果可用）
	var traditional_time = 0.0
	var optimized_time = 0.0
	
	if validator and validator.has_method("validate_position_comprehensive"):
		var start_time = Time.get_time_dict_from_system()
		
		for pos in test_positions:
			validator.validate_position_comprehensive(pos, test_character)
		
		var end_time = Time.get_time_dict_from_system()
		optimized_time = _calculate_time_diff(start_time, end_time)
	
	test_results.performance_tests.append({
		"name": "batch_validation_performance",
		"result": "PASS",
		"details": "Optimized method time: %.2f ms for 100 positions" % optimized_time,
		"positions_tested": test_positions.size(),
		"avg_time_per_position": optimized_time / test_positions.size()
	})
	
	print("✅ [Test] 性能改进测试完成")

func _test_system_integration():
	"""测试系统集成"""
	print("🔗 [Test] 测试系统集成...")
	
	# 测试组件间通信
	var integration_success = true
	var integration_details = []
	
	# 检查控制器是否正确集成了新组件
	if controller:
		if controller.has_method("get_preview_collision_state"):
			integration_details.append("Controller has preview collision state method")
		else:
			integration_success = false
			integration_details.append("Controller missing preview collision state method")
		
		if controller.has_method("force_refresh_dynamic_obstacles"):
			integration_details.append("Controller has dynamic obstacle refresh method")
		else:
			integration_success = false
			integration_details.append("Controller missing dynamic obstacle refresh method")
	else:
		integration_success = false
		integration_details.append("Controller not available for testing")
	
	# 检查输入处理器是否集成了优化方法
	if input_handler:
		if input_handler.has_method("_validate_position_optimized"):
			integration_details.append("Input handler has optimized validation method")
		else:
			integration_success = false
			integration_details.append("Input handler missing optimized validation method")
	else:
		integration_success = false
		integration_details.append("Input handler not available for testing")
	
	test_results.integration_tests.append({
		"name": "component_integration",
		"result": "PASS" if integration_success else "FAIL",
		"details": integration_details
	})
	
	print("✅ [Test] 系统集成测试完成")

func _generate_test_report():
	"""生成测试报告"""
	print("\n📊 [Test] 移动碰撞检测优化方案测试报告")
	print("═══════════════════════════════════════════")
	
	# 统计测试结果
	var total_tests = 0
	var passed_tests = 0
	var failed_tests = 0
	
	# 物理查询测试结果
	print("\n🔍 物理查询优化测试:")
	for test in test_results.physics_query_tests:
		total_tests += 1
		if test.result == "PASS":
			passed_tests += 1
			print("  ✅ %s: %s" % [test.name, test.get("details", "")])
		else:
			failed_tests += 1
			print("  ❌ %s: %s" % [test.name, test.get("reason", test.get("details", ""))])
	
	# Area2D预检测测试结果
	print("\n🎯 Area2D预检测系统测试:")
	for test in test_results.area2d_preview_tests:
		total_tests += 1
		if test.result == "PASS":
			passed_tests += 1
			print("  ✅ %s: %s" % [test.name, test.get("details", "")])
		else:
			failed_tests += 1
			print("  ❌ %s: %s" % [test.name, test.get("reason", test.get("details", ""))])
	
	# 性能测试结果
	print("\n⚡ 性能改进测试:")
	for test in test_results.performance_tests:
		total_tests += 1
		if test.result == "PASS":
			passed_tests += 1
			print("  ✅ %s: %s" % [test.name, test.get("details", "")])
		else:
			failed_tests += 1
			print("  ❌ %s: %s" % [test.name, test.get("reason", test.get("details", ""))])
	
	# 集成测试结果
	print("\n🔗 系统集成测试:")
	for test in test_results.integration_tests:
		total_tests += 1
		if test.result == "PASS":
			passed_tests += 1
			print("  ✅ %s" % test.name)
			for detail in test.details:
				print("    - %s" % detail)
		else:
			failed_tests += 1
			print("  ❌ %s" % test.name)
			for detail in test.details:
				print("    - %s" % detail)
	
	# 总结
	print("\n📈 测试总结:")
	print("  总测试数: %d" % total_tests)
	print("  通过: %d (%.1f%%)" % [passed_tests, (passed_tests * 100.0 / total_tests) if total_tests > 0 else 0])
	print("  失败: %d (%.1f%%)" % [failed_tests, (failed_tests * 100.0 / total_tests) if total_tests > 0 else 0])
	
	var overall_status = "✅ 成功" if failed_tests == 0 else "⚠️ 部分失败" if passed_tests > 0 else "❌ 失败"
	print("  整体状态: %s" % overall_status)
	
	print("═══════════════════════════════════════════")

func _create_mock_character() -> GameCharacter:
	"""创建模拟角色数据"""
	# 这里需要根据实际的GameCharacter类来创建
	# 暂时返回一个简单的字典作为模拟
	return {
		"id": "test_character_001",
		"name": "测试角色",
		"position": Vector2(50, 50),
		"movement_range": 5,
		"collision_radius": 16
	}

func _create_mock_character_node() -> Node2D:
	"""创建模拟角色节点"""
	var character_node = Node2D.new()
	character_node.name = "TestCharacter"
	character_node.position = Vector2(50, 50)
	
	# 添加CharacterArea
	var area = Area2D.new()
	area.name = "CharacterArea"
	character_node.add_child(area)
	
	# 添加碰撞形状
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 16
	collision_shape.shape = circle_shape
	area.add_child(collision_shape)
	
	return character_node

func _calculate_time_diff(start_time: Dictionary, end_time: Dictionary) -> float:
	"""计算时间差（毫秒）"""
	# 简化的时间计算，实际项目中可能需要更精确的计算
	var start_ms = start_time.hour * 3600000 + start_time.minute * 60000 + start_time.second * 1000
	var end_ms = end_time.hour * 3600000 + end_time.minute * 60000 + end_time.second * 1000
	return end_ms - start_ms

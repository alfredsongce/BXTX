extends SceneTree

func _init():
	print("🧪 [测试] 开始测试MoveRangeInput初始化")
	
	# 切换到主场景
	var main_scene = load("res://main.tscn").instantiate()
	current_scene = main_scene
	
	# 等待一帧让场景完全加载
	await process_frame
	
	# 查找MoveRangeInput节点
	var move_range_input = main_scene.find_child("Input", true, false)
	if move_range_input:
		print("✅ [测试] 找到MoveRangeInput节点")
		print("📍 [测试] 节点路径: ", move_range_input.get_path())
		
		# 检查position_collision_manager状态
		if move_range_input.has_method("get") and move_range_input.get("position_collision_manager"):
			print("✅ [测试] position_collision_manager已连接")
		else:
			print("❌ [测试] position_collision_manager未连接")
			
			# 手动触发重试
			if move_range_input.has_method("_retry_setup_position_collision_manager"):
				print("🔄 [测试] 手动触发重试机制")
				move_range_input._retry_setup_position_collision_manager()
	else:
		print("❌ [测试] 未找到MoveRangeInput节点")
	
	# 等待一秒让重试机制完成
	await create_timer(1.0).timeout
	
	print("🏁 [测试] 测试完成")
	quit()

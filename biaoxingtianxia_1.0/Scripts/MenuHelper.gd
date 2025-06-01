# 行动菜单辅助工具
extends Node

# 此函数在游戏启动时运行，修改所有行动菜单
func _ready():
	# 等待一帧，确保场景已完全加载
	await get_tree().process_frame
	
	# 修改全局变量或设置，以便行动菜单包含移动选项
	setup_action_menu()

# 设置行动菜单
func setup_action_menu():
	print("设置行动菜单，添加移动选项")
	
	# 如果行动菜单已经创建，可以在这里进行修改
	# 这是一个示例，实际实现取决于你的UI结构
	
	# 监听所有即将创建的行动菜单
	get_tree().node_added.connect(_on_node_added)

# 当新节点添加到场景时调用
func _on_node_added(node):
	# 检查是否是行动菜单
	if node.get_name() == "ActionMenu" or (node.get_script() and node.get_script().resource_path.ends_with("ActionMenu.gd")):
		print("检测到行动菜单创建，添加移动选项")
		
		# 给行动菜单添加处理
		call_deferred("_add_move_option", node)

# 添加移动选项到行动菜单
func _add_move_option(menu_node):
	# 等待一帧，确保菜单已完全初始化
	await get_tree().process_frame
	
	# 检查菜单是否已经有移动选项
	if menu_node.get_node_or_null("VBoxContainer/MoveButton") != null:
		print("菜单已存在移动选项，不再重复添加")
		return
	
	print("尝试向菜单添加移动选项")
	
	# 假设菜单有一个add_action方法
	if menu_node.has_method("add_action"):
		menu_node.add_action("移动", "move")
	# 或者如果菜单有一个actions数组
	elif menu_node.get("actions") != null:
		if not menu_node.actions.has("move"):
			menu_node.actions["move"] = "移动"
	# 如果菜单直接使用按钮，则尝试添加按钮
	else:
		# 不再自动添加移动按钮，因为菜单已经内置了移动按钮
		# 只记录日志以便调试
		print("行动菜单已内置移动按钮，不再手动添加")
		
		# 下面的代码被注释掉，不再额外添加按钮
		# var move_button = Button.new()
		# move_button.text = "移动"
		# move_button.name = "MoveButton"
		# 
		# # 连接信号
		# move_button.pressed.connect(func(): menu_node.emit_signal("action_selected", "move"))
		# 
		# # 找到适合放置按钮的容器
		# var container = _find_button_container(menu_node)
		# if container:
		#     container.add_child(move_button)

# 查找适合放置按钮的容器
func _find_button_container(node):
	# 首先检查是否有名为"ButtonContainer"的节点
	var container = node.get_node_or_null("ButtonContainer")
	if container:
		return container
	
	# 尝试查找VBoxContainer或HBoxContainer
	for child in node.get_children():
		if child is VBoxContainer or child is HBoxContainer:
			return child
	
	# 如果找不到合适的容器，返回节点本身
	return node 
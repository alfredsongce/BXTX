# AutoLoad脚本 - 在游戏启动时加载
extends Node

# 预加载辅助脚本
var menu_helper = preload("res://Scripts/MenuHelper.gd").new()

# 战斗场景引用管理器
var battle_scene_ref: Node2D = null

func _ready():
	# 添加菜单辅助器
	add_child(menu_helper)
	print("自动加载脚本初始化完成")

# 获取战斗场景引用的统一方法
func get_battle_scene() -> Node2D:
	if battle_scene_ref == null:
		var battle_scenes = get_tree().get_nodes_in_group("battle_scene")
		if battle_scenes.size() > 0:
			battle_scene_ref = battle_scenes[0]
		else:
			# 如果通过组找不到，尝试直接路径
			battle_scene_ref = get_tree().get_root().get_node_or_null("Main/战斗场景")
			if battle_scene_ref == null:
				printerr("[AutoLoad] 无法找到战斗场景节点")
	return battle_scene_ref

# 重置战斗场景引用（场景切换时使用）
func reset_battle_scene_ref():
	battle_scene_ref = null
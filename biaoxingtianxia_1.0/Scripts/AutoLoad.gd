# AutoLoad脚本 - 在游戏启动时加载
extends Node

# 预加载辅助脚本
var menu_helper = preload("res://Scripts/MenuHelper.gd").new()

func _ready():
	# 添加菜单辅助器
	add_child(menu_helper)
	print("自动加载脚本初始化完成") 
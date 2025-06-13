# Main场景脚本
# 负责游戏的初始化设置，包括队伍初始化

extends Node

func _ready():
	print("🎮 [Main] 游戏主场景初始化开始")
	
	# 初始化队伍成员
	_initialize_party_members()
	
	print("🎮 [Main] 游戏主场景初始化完成")

# 初始化队伍成员
func _initialize_party_members():
	print("👥 [Main] 开始初始化队伍成员")
	
	# 确保PartyManager已经加载
	if not PartyManager:
		printerr("❌ [Main] PartyManager未找到，无法初始化队伍")
		return
	
	# 添加初始队伍成员（觉远、柳生、兰斯洛特）
	PartyManager.add_member("1")  # 觉远
	PartyManager.add_member("2")  # 柳生  
	PartyManager.add_member("3")  # 兰斯洛特
	
	print("👥 [Main] 队伍初始化完成，当前成员数量: %d" % PartyManager.get_member_count())
	
	# 输出队伍信息用于调试
	var members = PartyManager.get_all_members()
	for member_id in members:
		var member_data = PartyManager.get_member_data(member_id)
		if member_data:
			print("  📋 [Main] 队伍成员: %s (ID: %s)" % [member_data.name, member_id])
		else:
			print("  ⚠️ [Main] 队伍成员 ID %s 的数据未找到" % member_id) 

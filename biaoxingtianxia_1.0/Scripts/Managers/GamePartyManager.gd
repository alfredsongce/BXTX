# 游戏队伍管理器（单例）
# 管理游戏中的队伍系统

extends Node

# 当前活跃的队伍实例
var current_party: GameParty

# 信号
signal party_changed
signal member_updated(character_id: String)

func _ready():
	print("👥 [GamePartyManager] 队伍管理器初始化")
	current_party = GameParty.new()
	
	# 连接队伍信号
	current_party.party_changed.connect(_on_party_changed)
	current_party.member_updated.connect(_on_member_updated)

# ========== 队伍操作方法 ==========

# 添加成员
func add_member(character_id: String) -> bool:
	return current_party.add_member(character_id)

# 移除成员
func remove_member(character_id: String) -> bool:
	return current_party.remove_member(character_id)

# 获取成员
func get_member(character_id: String) -> GameCharacter:
	return current_party.get_member(character_id)

# 获取成员数据（用于兼容之前的代码）
func get_member_data(character_id: String) -> GameCharacter:
	return current_party.get_member(character_id)

# 获取所有成员ID
func get_all_members() -> Array:
	return current_party.get_member_ids()

# 获取成员数量
func get_member_count() -> int:
	return current_party.get_current_size()

# 检查是否有成员
func has_member(character_id: String) -> bool:
	return current_party.has_member(character_id)

# 清空队伍
func clear_party() -> void:
	current_party.clear_party()

# 获取最大队伍大小
func get_max_size() -> int:
	return current_party.max_size

# 设置最大队伍大小
func set_max_size(size: int) -> void:
	current_party.max_size = size

# ========== 存档系统 ==========

# 保存队伍数据
func save_party() -> Dictionary:
	return current_party.save_to_dict()

# 加载队伍数据
func load_party(data: Dictionary) -> void:
	current_party.load_from_dict(data)

# ========== 信号处理 ==========

func _on_party_changed():
	party_changed.emit()

func _on_member_updated(character_id: String):
	member_updated.emit(character_id)

# ========== 调试方法 ==========

# 打印队伍信息
func debug_print_party():
	print("👥 [GamePartyManager] 当前队伍状态:")
	print("  队伍大小: %d/%d" % [get_member_count(), get_max_size()])
	for member_id in get_all_members():
		var member = get_member(member_id)
		if member:
			print("  成员: %s (ID: %s) HP: %d/%d" % [member.name, member_id, member.current_hp, member.max_hp])
		else:
			print("  成员ID %s 数据异常" % member_id) 

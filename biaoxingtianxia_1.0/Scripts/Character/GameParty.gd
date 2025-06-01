class_name GameParty
extends Resource

signal party_changed  # 当队伍成员变化时触发
signal member_updated(character_id: String)  # 当特定角色更新时触发

# 队伍成员存储 { character_id: GameCharacter }
var _members := {}

# 当前队伍最大人数限制
var max_size: int = 4:
	set(value):
		max_size = max(1, value)  # 确保至少有1个位置
		_validate_party_size()

# 添加角色到队伍
func add_member(character_id: String) -> bool:
	if _members.size() >= max_size:
		push_error("队伍已满，无法添加角色: %s" % character_id)
		return false
	
	if _members.has(character_id):
		push_warning("角色已存在于队伍中: %s" % character_id)
		return false
	
	# 从数据库创建基础角色
	var base_data = DataManager.get_data("character", character_id)
	if not base_data or (base_data is Dictionary and base_data.is_empty()):
		push_error("无效的角色ID: %s" % character_id)
		return false
	
	var new_char = GameCharacter.new()
	new_char.load_from_id(character_id)
	_members[character_id] = new_char
	
	# 连接信号以便监听角色变化
	new_char.stats_changed.connect(_on_character_updated.bind(character_id))
	
	emit_signal("party_changed")
	return true

# 移除队伍成员
func remove_member(character_id: String) -> bool:
	if not _members.has(character_id):
		return false
	
	var character = _members[character_id]
	character.stats_changed.disconnect(_on_character_updated)
	
	_members.erase(character_id)
	emit_signal("party_changed")
	return true

# 获取队伍中特定角色
func get_member(character_id: String) -> GameCharacter:
	return _members.get(character_id)

# 获取所有成员ID列表
func get_member_ids() -> Array:
	return _members.keys()

# 获取所有成员实例列表
func get_all_members() -> Array:
	return _members.values()

# 队伍当前人数
func get_current_size() -> int:
	return _members.size()

# 检查角色是否在队伍中
func has_member(character_id: String) -> bool:
	return _members.has(character_id)

# 交换队伍位置 (用于UI排序)
func swap_members(id1: String, id2: String) -> void:
	if not _members.has(id1) or not _members.has(id2):
		return
	
	var temp = _members[id1]
	_members[id1] = _members[id2]
	_members[id2] = temp
	emit_signal("party_changed")

# 保存队伍数据到字典 (用于存档)
func save_to_dict() -> Dictionary:
	var saved_data := {
		"max_size": max_size,
		"members": {}
	}
	
	for id in _members:
		saved_data["members"][id] = _members[id].get_stats()
	
	return saved_data

# 从字典加载队伍数据 (用于读档)
func load_from_dict(data: Dictionary) -> void:
	clear_party()
	max_size = data.get("max_size", 4)
	
	var members_data = data.get("members", {})
	for id in members_data:
		var character = GameCharacter.new()
		character.id = id
		character.name = members_data[id].get("name", "")
		character.max_hp = members_data[id].get("max_hp", 100)
		character.current_hp = members_data[id].get("current_hp", character.max_hp)
		character.level = members_data[id].get("level", 1)
		character.attack = members_data[id].get("attack", 10)
		character.defense = members_data[id].get("defense", 5)
		
		_members[id] = character
		character.stats_changed.connect(_on_character_updated.bind(id))
	
	emit_signal("party_changed")

# 清空队伍
func clear_party() -> void:
	for id in _members:
		_members[id].stats_changed.disconnect(_on_character_updated)
	
	_members.clear()
	emit_signal("party_changed")

# 内部方法：确保队伍不超过最大人数限制
func _validate_party_size() -> void:
	while _members.size() > max_size:
		var to_remove = _members.keys()[0]
		remove_member(to_remove)

# 内部方法：处理角色更新事件
func _on_character_updated(character_id: String) -> void:
	emit_signal("member_updated", character_id)

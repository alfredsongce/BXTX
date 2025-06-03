# 参战者管理器
# 职责：专门负责参战角色注册、阵营管理、生存检查
# 上级：BattleManager
extends Node

#region 信号
signal participant_added(character)
signal participant_removed(character)
signal team_eliminated(team_name: String)
#endregion

#region 调试日志控制
var debug_logging_enabled: bool = false  # 默认关闭调试日志
#endregion

#region 状态
var participants: Array = []
var player_team: Array = []
var enemy_team: Array = []
#endregion

func _ready() -> void:
	_debug_print("👥 [ParticipantManager] 参战者管理器初始化")

#region 调试日志方法
func _debug_print(message: String) -> void:
	if debug_logging_enabled:
		print(message)

func toggle_debug_logging() -> void:
	debug_logging_enabled = not debug_logging_enabled
	
#endregion

#region 公共API
func setup_participants(character_list: Array) -> void:
	_debug_print("📝 [ParticipantManager] 设置参战者，数量: %d" % character_list.size())
	
	participants.clear()
	player_team.clear()
	enemy_team.clear()
	
	for character in character_list:
		add_participant(character)

func add_participant(character) -> void:
	if character in participants:
		_debug_print("⚠️ [ParticipantManager] 角色 %s 已在参战列表中" % character.name)
		return
	
	participants.append(character)
	
	# 根据控制类型分配阵营
	if character.is_player_controlled():
		player_team.append(character)
		_debug_print("✅ [ParticipantManager] 玩家角色加入: %s" % character.name)
	else:
		enemy_team.append(character)
		_debug_print("✅ [ParticipantManager] 敌方角色加入: %s" % character.name)
	
	participant_added.emit(character)

func remove_participant(character) -> void:
	if character not in participants:
		return
	
	participants.erase(character)
	player_team.erase(character)
	enemy_team.erase(character)
	
	_debug_print("❌ [ParticipantManager] 角色退出战斗: %s" % character.name)
	participant_removed.emit(character)

func get_alive_participants() -> Array:
	return participants.filter(func(char): return char.is_alive())

func get_alive_players() -> Array:
	return player_team.filter(func(char): return char.is_alive())

func get_alive_enemies() -> Array:
	return enemy_team.filter(func(char): return char.is_alive())

func check_battle_end() -> Dictionary:
	var alive_players = get_alive_players()
	var alive_enemies = get_alive_enemies()
	
	_debug_print("🔍 [ParticipantManager] 存活检查 - 玩家: %d, 敌人: %d" % [alive_players.size(), alive_enemies.size()])
	
	# 详细打印存活角色信息
	for player in alive_players:
		_debug_print("👤 [ParticipantManager] 存活玩家: %s (HP: %d/%d)" % [player.name, player.current_hp, player.max_hp])
	for enemy in alive_enemies:
		_debug_print("👹 [ParticipantManager] 存活敌人: %s (HP: %d/%d)" % [enemy.name, enemy.current_hp, enemy.max_hp])
	
	if alive_players.is_empty():
		_debug_print("💀 [ParticipantManager] 玩家全灭")
		team_eliminated.emit("player")
		return {"should_end": true, "reason": "player_defeat", "winner": "enemy"}
	
	if alive_enemies.is_empty():
		_debug_print("🏆 [ParticipantManager] 敌方全灭")
		team_eliminated.emit("enemy")
		return {"should_end": true, "reason": "enemy_defeat", "winner": "player"}
	
	return {"should_end": false}

func get_participants() -> Array:
	return participants.duplicate()

func get_participant_count() -> int:
	return participants.size()

func print_team_status() -> void:
	print("📊 [ParticipantManager] 队伍状态:")
	print("  玩家队伍: %d/%d 存活" % [get_alive_players().size(), player_team.size()])
	print("  敌方队伍: %d/%d 存活" % [get_alive_enemies().size(), enemy_team.size()])
#endregion
# 🎮 战斗输入处理器
class_name BattleInputHandler
extends Node

# 🎯 输入模式枚举
enum InputMode {
	NORMAL,      # 正常模式
	ATTACK,      # 攻击模式
	SKILL,       # 技能模式
	MOVE,        # 移动模式
	DISABLED     # 禁用输入
}

# 🚀 当前状态
var current_input_mode: InputMode = InputMode.NORMAL
var input_enabled: bool = true

# 🚀 组件引用
var battle_scene: Node = null
var action_system: Node = null
var battle_flow_manager: Node = null
var battle_combat_manager: Node = null

# 🚀 攻击模式相关
var attack_mode_active: bool = false
var attacking_character: GameCharacter = null
var highlighted_targets: Array = []

# 🚀 信号定义
signal input_mode_changed(old_mode: InputMode, new_mode: InputMode)
signal attack_target_selected(attacker: GameCharacter, target: GameCharacter)
signal attack_cancelled()
signal action_menu_requested()

func _ready() -> void:
	print("🚀 [BattleInputHandler] 开始初始化")
	_find_component_references()
	_connect_signals()
	print("✅ [BattleInputHandler] 初始化完成")

func _find_component_references() -> void:
	# 查找BattleScene引用
	battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		# 尝试通过父节点查找
		var current = get_parent()
		while current and not battle_scene:
			if current.name == "BattleScene" or current.has_method("_check_victory_condition"):
				battle_scene = current
				break
			current = current.get_parent()
	
	# 查找ActionSystem
	action_system = get_node_or_null("../ActionSystem")
	if not action_system:
		action_system = get_node_or_null("/root/BattleScene/ActionSystem")
	
	# 查找BattleFlowManager
	battle_flow_manager = get_node_or_null("../BattleFlowManager")
	if not battle_flow_manager:
		battle_flow_manager = get_node_or_null("/root/BattleScene/BattleSystems/BattleFlowManager")
	
	# 查找BattleCombatManager
	battle_combat_manager = get_node_or_null("../BattleCombatManager")
	if not battle_combat_manager:
		battle_combat_manager = get_node_or_null("/root/BattleScene/BattleSystems/BattleCombatManager")

func _connect_signals() -> void:
	# 连接信号
	if battle_flow_manager:
		if battle_flow_manager.has_signal("input_mode_changed"):
			battle_flow_manager.input_mode_changed.connect(_on_battle_flow_input_mode_changed)

# 🚀 主要输入处理函数
func handle_input(event: InputEvent) -> bool:
	if not input_enabled or current_input_mode == InputMode.DISABLED:
		return false
	
	# 处理不同类型的输入事件
	if event is InputEventMouseButton:
		return _handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		return _handle_mouse_motion(event)
	elif event is InputEventKey:
		return _handle_keyboard_input(event)
	
	return false

# 🖱️ 鼠标按钮处理
func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	if not event.pressed:
		return false
	
	# 攻击模式下的鼠标点击处理
	if attack_mode_active and event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_attack_mode_click(event)
	
	# 右键取消操作
	if event.button_index == MOUSE_BUTTON_RIGHT:
		return _handle_right_click(event)
	
	return false

# 🖱️ 鼠标移动处理
func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	# 在攻击模式下更新目标高亮
	if attack_mode_active:
		_update_attack_target_highlight(event.global_position)
		return true
	
	return false

# ⌨️ 键盘输入处理
func _handle_keyboard_input(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	
	# 处理特殊按键
	if event.is_action_pressed("ui_accept"):
		return _handle_accept_key()
	elif event.is_action_pressed("ui_cancel"):
		return _handle_cancel_key()
	
	return false

# 🎯 攻击模式点击处理
func _handle_attack_mode_click(event: InputEventMouseButton) -> bool:
	if not battle_scene:
		return false
	
	var clicked_target = _get_character_at_mouse_position(event.global_position)
	if clicked_target:
		var target_character = clicked_target.get_character_data()
		if target_character and highlighted_targets.has(clicked_target):
			_execute_attack(attacking_character, target_character)
			return true
	
	# 点击空白处取消攻击
	_cancel_attack()
	return true

# 🖱️ 右键点击处理
func _handle_right_click(event: InputEventMouseButton) -> bool:
	# 取消当前操作
	if attack_mode_active:
		_cancel_attack()
		return true
	
	return false

# ⌨️ 确认键处理
func _handle_accept_key() -> bool:
	if not action_system:
		return false
	
	# 预加载ActionSystemScript以访问枚举
	var ActionSystemScript = preload("res://Scripts/ActionSystemNew.gd")
	
	if action_system.current_state == ActionSystemScript.SystemState.IDLE:
		action_system.start_action_selection()
		return true
	
	return false

# ⌨️ 取消键处理
func _handle_cancel_key() -> bool:
	if attack_mode_active:
		_cancel_attack()
		return true
	
	return false

# 🎯 开始攻击模式
func start_attack_mode(attacker: GameCharacter, targets: Array) -> void:
	attack_mode_active = true
	attacking_character = attacker
	highlighted_targets = targets
	_set_input_mode(InputMode.ATTACK)
	
	print("🎯 [输入处理器] 开始攻击模式 - 攻击者: %s, 目标数量: %d" % [attacker.name, targets.size()])

# 🎯 取消攻击模式
func _cancel_attack() -> void:
	attack_mode_active = false
	attacking_character = null
	highlighted_targets.clear()
	_set_input_mode(InputMode.NORMAL)
	attack_cancelled.emit()
	
	print("❌ [输入处理器] 攻击模式已取消")

# 🎯 更新攻击目标高亮
func _update_attack_target_highlight(mouse_position: Vector2) -> void:
	if not battle_scene or not attack_mode_active:
		return
	
	# 这里可以添加鼠标悬停时的目标高亮逻辑
	# 例如改变目标角色的颜色或显示攻击预览
	pass

# 🚀 设置输入模式
func _set_input_mode(new_mode: InputMode) -> void:
	var old_mode = current_input_mode
	current_input_mode = new_mode
	input_mode_changed.emit(old_mode, new_mode)
	
	var mode_names = ["正常", "攻击", "技能", "移动", "禁用"]
	print("🎮 [输入处理器] 输入模式切换: %s -> %s" % [mode_names[old_mode], mode_names[new_mode]])

# 🚀 启用/禁用输入
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	var status = "启用" if enabled else "禁用"
	print("🎮 [输入处理器] 输入处理%s" % status)

# 🚀 获取当前输入模式
func get_current_input_mode() -> InputMode:
	return current_input_mode

# 🚀 检查是否在攻击模式
func is_in_attack_mode() -> bool:
	return attack_mode_active

# 🚀 获取攻击中的角色
func get_attacking_character() -> GameCharacter:
	return attacking_character

# 🚀 获取高亮目标列表
func get_highlighted_targets() -> Array:
	return highlighted_targets

# 🚀 获取鼠标位置的角色
func _get_character_at_mouse_position(mouse_pos: Vector2) -> Node2D:
	# 简单的距离检测
	var closest_character = null
	var closest_distance = 100.0  # 最大检测距离
	
	if battle_scene and battle_scene.character_manager:
		var party_nodes = battle_scene.character_manager.get_party_member_nodes()
		for character_id in party_nodes:
			var character_node = party_nodes[character_id]
			if character_node:
				var distance = character_node.global_position.distance_to(mouse_pos)
				if distance < closest_distance:
					closest_distance = distance
					closest_character = character_node
	
	return closest_character

# 🚀 执行攻击
func _execute_attack(attacker: GameCharacter, target: GameCharacter) -> void:
	print("⚔️ [输入处理器] %s 攻击 %s" % [attacker.name, target.name])
	
	# 清除攻击模式
	_cancel_attack()
	
	# 直接调用战斗管理器执行攻击
	if battle_combat_manager:
		await battle_combat_manager.execute_attack(attacker, target)
	else:
		print("⚠️ [输入处理器] 无法执行攻击：BattleCombatManager不可用")

# 🚀 清除攻击目标高亮
func clear_attack_targets() -> void:
	if battle_combat_manager:
		battle_combat_manager.clear_attack_targets()
	
	highlighted_targets.clear()

# 🚀 信号处理函数
func _on_battle_flow_input_mode_changed(new_mode: String) -> void:
	# 根据BattleFlowManager的输入模式调整本地状态
	if new_mode == "DEBUG":
		_set_input_mode(InputMode.DISABLED)
	elif new_mode == "NORMAL":
		_set_input_mode(InputMode.NORMAL)

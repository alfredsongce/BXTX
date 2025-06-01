class_name SkillSelectionCoordinator
extends Node

# 预加载行动系统脚本以访问其枚举和常量
const ActionSystemScript = preload("res://Scripts/ActionSystemNew.gd")

# 🎯 技能选择协调器
# 负责管理技能选择相关的UI和逻辑，包括：
# - 技能选择菜单管理
# - 目标选择逻辑
# - 技能范围显示
# - 可视化技能选择器
# - 相关的UI交互逻辑

# 信号定义
signal skill_selected(skill_id: String)
signal skill_selection_cancelled()
signal target_selected(targets: Array)
signal target_selection_cancelled()
signal visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array)
signal visual_skill_selection_cancelled()

# UI组件引用
var skill_selection_menu: Control = null
var target_selection_menu: Control = null
var skill_range_display: Node2D = null
var visual_skill_selector: Node = null

# 状态管理
var current_character: GameCharacter = null
var current_skill: SkillData = null
var is_initialized: bool = false

# 外部依赖引用
var battle_ui_manager: BattleUIManager = null
var skill_manager: SkillManager = null
var action_system = null
var battle_manager = null
var character_manager = null

func _ready():
	print("🎯 [技能选择协调器] 初始化开始")
	# 直接初始化，不使用延迟
	_initialize()

func _initialize():
	if is_initialized:
		return
	
	print("🔍 [技能选择协调器] 开始_initialize方法")
	
	# 获取外部依赖
	print("🔍 [技能选择协调器] 调用_setup_dependencies")
	_setup_dependencies()
	
	# 初始化UI组件
	print("🔍 [技能选择协调器] 调用_setup_skill_selection_menu")
	_setup_skill_selection_menu()
	print("🔍 [技能选择协调器] 调用_setup_target_selection_menu")
	_setup_target_selection_menu()
	print("🔍 [技能选择协调器] 调用_setup_skill_range_display")
	_setup_skill_range_display()
	print("🔍 [技能选择协调器] 调用_setup_visual_skill_selector")
	_setup_visual_skill_selector()
	
	is_initialized = true
	print("✅ [技能选择协调器] 初始化完成")

# 设置外部依赖
func _setup_dependencies():
	var battle_scene = get_tree().current_scene
	if battle_scene:
		# 直接通过节点路径获取BattleUIManager
		battle_ui_manager = battle_scene.get_node_or_null("BattleSystems/BattleUIManager")
		skill_manager = battle_scene.get_node_or_null("SkillManager")
		action_system = battle_scene.get_node_or_null("ActionSystem")
		battle_manager = battle_scene.get_node_or_null("BattleManager")
		character_manager = battle_scene.get("character_manager")
		
	if not battle_ui_manager:
		print("⚠️ [技能选择协调器] 无法获取BattleUIManager引用")
	if not skill_manager:
		print("⚠️ [技能选择协调器] 无法获取SkillManager引用")

# 🚀 技能选择菜单相关方法

# 初始化技能选择菜单
func _setup_skill_selection_menu() -> void:
	if not battle_ui_manager:
		print("⚠️ [技能选择协调器] BattleUIManager未找到，无法初始化技能选择菜单")
		return
	
	# 加载技能选择菜单场景
	var skill_menu_scene = preload("res://UI/SkillSelectionMenu.tscn")
	skill_selection_menu = skill_menu_scene.instantiate()
	
	# 添加到UI容器
	battle_ui_manager.get_ui_container().add_child(skill_selection_menu)
	
	# 连接信号
	skill_selection_menu.skill_selected.connect(_on_skill_selected)
	skill_selection_menu.menu_closed.connect(_on_skill_menu_closed)
	
	print("✅ [技能选择协调器] 技能选择菜单初始化完成")

# 显示技能选择菜单
func show_skill_selection_menu(character: GameCharacter, available_skills: Array) -> void:
	if not skill_selection_menu:
		print("⚠️ [技能选择协调器] 技能选择菜单未初始化")
		return
	
	current_character = character
	print("🎯 [技能选择协调器] 显示技能选择菜单，角色: %s，技能数量: %d" % [character.name, available_skills.size()])
	skill_selection_menu.open_menu(character, available_skills)

# 技能选择回调
func _on_skill_selected(skill_id: String) -> void:
	print("🎯 [技能选择协调器] 玩家选择技能: %s" % skill_id)
	skill_selected.emit(skill_id)

# 技能菜单关闭回调
func _on_skill_menu_closed() -> void:
	print("❌ [技能选择协调器] 技能选择菜单关闭")
	skill_selection_cancelled.emit()

# 🚀 目标选择菜单相关方法

# 初始化目标选择菜单
func _setup_target_selection_menu() -> void:
	if not battle_ui_manager:
		print("⚠️ [技能选择协调器] BattleUIManager未找到，无法初始化目标选择菜单")
		return
	
	# 加载目标选择菜单场景
	var target_menu_scene = preload("res://UI/TargetSelectionMenu.tscn")
	target_selection_menu = target_menu_scene.instantiate()
	
	# 添加到UI容器
	battle_ui_manager.get_ui_container().add_child(target_selection_menu)
	
	# 连接信号
	target_selection_menu.target_selected.connect(_on_target_selected)
	target_selection_menu.menu_closed.connect(_on_target_menu_closed)
	
	print("✅ [技能选择协调器] 目标选择菜单初始化完成")

# 显示目标选择菜单
func show_target_selection_menu(skill: SkillData, caster: GameCharacter, available_targets: Array) -> void:
	if not target_selection_menu:
		print("⚠️ [技能选择协调器] 目标选择菜单未初始化")
		return
	
	current_skill = skill
	current_character = caster
	print("🎯 [技能选择协调器] 显示目标选择菜单，技能: %s，目标数量: %d" % [skill.name, available_targets.size()])
	target_selection_menu.open_menu(skill, caster, available_targets)

# 目标选择回调
func _on_target_selected(targets: Array) -> void:
	print("🎯 [技能选择协调器] 玩家选择目标: %d 个" % targets.size())
	target_selected.emit(targets)

# 目标菜单关闭回调
func _on_target_menu_closed() -> void:
	print("❌ [技能选择协调器] 目标选择菜单关闭")
	target_selection_cancelled.emit()

# 🚀 技能范围显示相关方法

# 初始化技能范围显示组件
func _setup_skill_range_display() -> void:
	if not battle_ui_manager:
		print("⚠️ [技能选择协调器] BattleUIManager未找到，无法初始化技能范围显示")
		return
	
	# 创建技能范围显示组件
	var SkillRangeDisplay = load("res://Scripts/SkillRangeDisplay.gd")
	skill_range_display = SkillRangeDisplay.new()
	
	# 添加到UI容器
	battle_ui_manager.get_ui_container().add_child(skill_range_display)
	
	print("✅ [技能选择协调器] 技能范围显示组件初始化完成")

# 显示技能范围
func show_skill_range(skill: SkillData, caster: GameCharacter, target_position: Vector2 = Vector2.ZERO) -> void:
	if not skill_range_display:
		print("⚠️ [技能选择协调器] 技能范围显示组件未初始化")
		return
	
	if skill_range_display.has_method("show_skill_range"):
		skill_range_display.show_skill_range(skill, caster, target_position)

# 隐藏技能范围
func hide_skill_range() -> void:
	if skill_range_display and skill_range_display.has_method("hide_range"):
		skill_range_display.hide_range()

# 🚀 可视化技能选择器相关方法

# 初始化可视化技能选择器
func _setup_visual_skill_selector() -> void:
	print("🔍 [技能选择协调器] 开始初始化可视化技能选择器")
	print("🔍 [技能选择协调器] battle_ui_manager状态: %s" % ("存在" if battle_ui_manager else "不存在"))
	
	if not battle_ui_manager:
		print("⚠️ [技能选择协调器] BattleUIManager未找到，无法初始化可视化技能选择器")
		return
	
	# 加载可视化技能选择器脚本
	print("🔍 [技能选择协调器] 尝试加载VisualSkillSelector脚本")
	var VisualSkillSelector = load("res://UI/VisualSkillSelector.gd")
	if not VisualSkillSelector:
		print("❌ [技能选择协调器] 无法加载VisualSkillSelector脚本")
		return
	
	print("🔍 [技能选择协调器] 创建VisualSkillSelector实例")
	visual_skill_selector = VisualSkillSelector.new()
	if not visual_skill_selector:
		print("❌ [技能选择协调器] 无法创建VisualSkillSelector实例")
		return
	
	# 连接信号
	print("🔍 [技能选择协调器] 连接VisualSkillSelector信号")
	visual_skill_selector.skill_cast_completed.connect(_on_visual_skill_cast_completed)
	visual_skill_selector.skill_selection_cancelled.connect(_on_visual_skill_selection_cancelled)
	
	# 添加到UI容器
	print("🔍 [技能选择协调器] 添加VisualSkillSelector到UI容器")
	var ui_container = battle_ui_manager.get_ui_container()
	if not ui_container:
		print("❌ [技能选择协调器] 无法获取UI容器")
		return
	
	ui_container.add_child(visual_skill_selector)
	print("✅ [技能选择协调器] 可视化技能选择器初始化完成")

# 显示可视化技能选择界面
func show_visual_skill_selection(character: GameCharacter, available_skills: Array) -> void:
	if not visual_skill_selector:
		print("⚠️ [技能选择协调器] 可视化技能选择器未初始化")
		return
	
	current_character = character
	print("🎯 [技能选择协调器] 显示可视化技能选择界面，角色: %s，技能数量: %d" % [character.name, available_skills.size()])
	
	visual_skill_selector.start_skill_selection(character, available_skills)

# 可视化技能释放完成回调
func _on_visual_skill_cast_completed(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("✅ [技能选择协调器] 可视化技能释放完成: %s，施法者: %s，目标数量: %d" % [skill.name, caster.name, targets.size()])
	visual_skill_cast_completed.emit(skill, caster, targets)

# 可视化技能选择取消回调
func _on_visual_skill_selection_cancelled() -> void:
	print("❌ [技能选择协调器] 可视化技能选择被取消")
	visual_skill_selection_cancelled.emit()

# 🚀 公共接口方法

# 取消所有技能选择
func cancel_all_selections() -> void:
	print("🔄 [技能选择协调器] 取消所有技能选择")
	
	# 关闭技能选择菜单
	if skill_selection_menu and skill_selection_menu.visible:
		skill_selection_menu.close_menu()
	
	# 关闭目标选择菜单
	if target_selection_menu and target_selection_menu.visible:
		target_selection_menu.close_menu()
	
	# 隐藏技能范围显示
	hide_skill_range()
	
	# 关闭可视化技能选择器
	if visual_skill_selector and visual_skill_selector.has_method("close_selector"):
		visual_skill_selector.close_selector(true)  # 发出取消信号
	
	# 重置状态
	current_character = null
	current_skill = null

# 检查是否有活跃的选择界面
func has_active_selection() -> bool:
	var has_active = false
	
	if skill_selection_menu and skill_selection_menu.visible:
		has_active = true
	
	if target_selection_menu and target_selection_menu.visible:
		has_active = true
	
	if visual_skill_selector and visual_skill_selector.has_method("is_active"):
		if visual_skill_selector.is_active():
			has_active = true
	
	return has_active

# 获取当前选择的角色
func get_current_character() -> GameCharacter:
	return current_character

# 获取当前选择的技能
func get_current_skill() -> SkillData:
	return current_skill

# 🚀 辅助方法

# 查找角色节点（从BattleScene迁移）
func _find_character_node_by_character_data(character_data: GameCharacter):
	if not character_manager:
		return null
	
	# 尝试从友方角色中查找
	var ally_nodes = character_manager.get_ally_nodes()
	for ally_id in ally_nodes:
		var ally_node = ally_nodes[ally_id]
		if ally_node and ally_node.get_character_data() == character_data:
			return ally_node
	
	# 尝试从敌方角色中查找
	var enemy_nodes = character_manager.get_enemy_nodes()
	for enemy_id in enemy_nodes:
		var enemy_node = enemy_nodes[enemy_id]
		if enemy_node and enemy_node.get_character_data() == character_data:
			return enemy_node
	
	return null

# 恢复行动菜单（从BattleScene迁移的逻辑）
func restore_action_menu() -> void:
	print("🔙 [技能选择协调器] 恢复行动菜单")
	
	# 获取当前角色节点
	var character_node = null
	
	# 首先尝试从ActionSystem获取选中的角色
	if action_system and action_system.selected_character:
		character_node = action_system.selected_character
		print("🔙 [技能选择协调器] 从ActionSystem获取角色节点")
	else:
		# 如果ActionSystem的选中角色为空，从BattleManager获取当前回合角色
		if battle_manager and battle_manager.turn_manager:
			var current_character_data = battle_manager.turn_manager.get_current_character()
			if current_character_data:
				character_node = _find_character_node_by_character_data(current_character_data)
				print("🔙 [技能选择协调器] 从BattleManager获取当前回合角色: %s" % current_character_data.name)
				
				# 重新设置ActionSystem的状态
				if action_system:
					action_system.selected_character = character_node
					action_system.current_state = ActionSystemScript.SystemState.SELECTING_ACTION
					print("🔧 [技能选择协调器] 重新设置ActionSystem状态")
	
	if character_node:
		print("🔙 [技能选择协调器] 技能选择取消，重新显示行动菜单")
		
		# 直接通过角色节点的UI组件重新打开行动菜单
		var ui_component = character_node.get_node_or_null("ComponentContainer/UIComponent")
		if ui_component and ui_component.has_method("open_action_menu"):
			print("✅ [技能选择协调器] 重新打开行动菜单")
			ui_component.open_action_menu()
		else:
			print("⚠️ [技能选择协调器] 无法恢复行动菜单，重置行动系统")
			# 最后的备选方案
			if action_system:
				action_system.reset_action_system()
	else:
		print("⚠️ [技能选择协调器] 无法找到当前角色节点")

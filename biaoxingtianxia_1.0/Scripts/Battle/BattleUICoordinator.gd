class_name BattleUICoordinator
extends RefCounted

## 战斗UI协调器
## 负责管理战斗场景中所有UI相关的职责

# 组件引用
var battle_scene: Node2D
var battle_ui_manager: BattleUIManager
var skill_selection_coordinator: SkillSelectionCoordinator
var skill_manager: SkillManager

# UI状态管理
var ui_initialized: bool = false
var current_ui_mode: String = "normal"

## 初始化UI协调器
func initialize(scene: Node2D) -> void:
	print("🎨 [BattleUICoordinator] 开始初始化UI协调器")
	battle_scene = scene
	
	# 获取UI组件引用
	battle_ui_manager = scene.get_node("BattleSystems/BattleUIManager")
	skill_selection_coordinator = scene.get_node("BattleSystems/SkillSelectionCoordinator")
	skill_manager = scene.get_node("SkillManager")
	
	# 设置UI
	await setup_battle_ui()
	await setup_skill_selection_coordinator()
	
	ui_initialized = true
	print("✅ [BattleUICoordinator] UI协调器初始化完成")

## 设置战斗UI（从BattleScene迁移）
func setup_battle_ui() -> void:
	print("🎨 [BattleUICoordinator] 设置战斗UI")
	
	# 连接BattleUIManager的信号
	battle_ui_manager.ui_update_requested.connect(_on_ui_update_requested)
	battle_ui_manager.battle_button_pressed.connect(_on_battle_button_pressed)
	
	# 连接SkillManager的信号
	if skill_manager:
		skill_manager.skill_selection_started.connect(_on_skill_selection_started)
		print("✅ [BattleUICoordinator] 已连接SkillManager的skill_selection_started信号")
	else:
		print("⚠️ [BattleUICoordinator] SkillManager不存在，无法连接信号")
	
	print("✅ [BattleUICoordinator] 战斗UI设置完成")

## 初始化技能选择协调器（从BattleScene迁移）
func setup_skill_selection_coordinator() -> void:
	print("🎨 [BattleUICoordinator] 开始设置技能选择协调器")
	
	# 等待SkillSelectionCoordinator初始化完成
	if not skill_selection_coordinator.is_initialized:
		print("🔍 [BattleUICoordinator] 等待SkillSelectionCoordinator初始化完成")
		await skill_selection_coordinator.tree_entered
		# 给一点时间让_initialize函数执行
		await battle_scene.get_tree().process_frame
		await battle_scene.get_tree().process_frame
	
	# 连接信号
	skill_selection_coordinator.skill_selected.connect(_on_skill_selected_from_coordinator)
	skill_selection_coordinator.skill_selection_cancelled.connect(_on_skill_selection_cancelled_from_coordinator)
	skill_selection_coordinator.target_selected.connect(_on_target_selected_from_coordinator)
	skill_selection_coordinator.target_selection_cancelled.connect(_on_target_selection_cancelled_from_coordinator)
	
	print("✅ [BattleUICoordinator] 技能选择协调器设置完成")

## 更新战斗UI（从BattleScene迁移）
func update_battle_ui(title: String, message: String, update_type: String = "general") -> void:
	print("🎨 [BattleUICoordinator] 更新UI: %s - %s (%s)" % [title, message, update_type])
	
	if battle_ui_manager:
		battle_ui_manager.update_battle_ui(title, message, update_type)
	else:
		print("⚠️ [BattleUICoordinator] BattleUIManager不存在，无法更新UI")

## 恢复当前回合UI（从BattleScene迁移）
func restore_current_turn_ui() -> void:
	print("🎨 [BattleUICoordinator] 恢复当前回合UI")
	
	var current_character = battle_scene.battle_manager.turn_manager.get_current_character()
	if current_character:
		var turn_message = "轮到 %s 行动" % current_character.name
		update_battle_ui("回合进行中", turn_message, "turn")
	else:
		update_battle_ui("战斗准备", "准备开始战斗", "ready")

## 切换战斗UI显示（从BattleScene迁移）
func toggle_battle_ui():
	print("🎨 [BattleUICoordinator] 切换战斗UI显示")
	
	if battle_ui_manager:
		battle_ui_manager.toggle_visibility()
	else:
		print("⚠️ [BattleUICoordinator] BattleUIManager不存在，无法切换UI")

## 显示目标选择菜单（从BattleScene迁移）
func show_target_selection_menu(skill: SkillData, caster: GameCharacter, available_targets: Array) -> void:
	print("🎯 [BattleUICoordinator] 显示目标选择菜单，技能: %s" % skill.name)
	
	if skill_selection_coordinator:
		skill_selection_coordinator.show_target_selection(skill, caster, available_targets)
	else:
		print("⚠️ [BattleUICoordinator] SkillSelectionCoordinator不存在")

## 显示可视化技能选择界面（从BattleScene迁移）
func show_visual_skill_selection(character: GameCharacter, available_skills: Array) -> void:
	print("🎨 [BattleUICoordinator] 显示技能选择界面，角色: %s" % character.name)
	
	if skill_selection_coordinator:
		skill_selection_coordinator.show_visual_skill_selection(character, available_skills)
	else:
		print("⚠️ [BattleUICoordinator] SkillSelectionCoordinator不存在")

# ===========================================
# 信号回调函数（从BattleScene迁移）
# ===========================================

## UI更新请求回调
func _on_ui_update_requested(data: Dictionary) -> void:
	print("🎨 [BattleUICoordinator] 收到UI更新请求: %s" % data)
	# 处理UI更新逻辑

## 战斗按钮按下回调
func _on_battle_button_pressed() -> void:
	print("🎨 [BattleUICoordinator] 战斗按钮按下")
	
	# 委托给BattleScene处理战斗开始逻辑
	if battle_scene.has_method("_on_battle_button_pressed"):
		battle_scene._on_battle_button_pressed()
	else:
		print("⚠️ [BattleUICoordinator] BattleScene没有_on_battle_button_pressed方法")

## 技能选择开始回调
func _on_skill_selection_started(character: GameCharacter) -> void:
	print("🎯 [BattleUICoordinator] 收到skill_selection_started信号，角色: %s" % character.name)
	
	# 获取角色的可用技能
	var available_skills = skill_manager.get_available_skills(character)
	print("🔍 [BattleUICoordinator] 角色 %s 的可用技能数量: %d" % [character.name, available_skills.size()])
	
	# 显示可视化技能选择界面
	show_visual_skill_selection(character, available_skills)

## 技能选择回调（从协调器）
func _on_skill_selected_from_coordinator(skill_id: String) -> void:
	print("🎯 [BattleUICoordinator] 技能选择: %s" % skill_id)
	
	# 直接通知SkillManager选择了技能
	if skill_manager:
		skill_manager.select_skill(skill_id)

## 技能选择取消回调
func _on_skill_selection_cancelled_from_coordinator() -> void:
	print("❌ [BattleUICoordinator] 技能选择取消")
	
	# 直接处理技能选择取消
	if skill_manager.current_state == SkillManager.SkillState.SELECTING_SKILL:
		skill_manager.cancel_skill_selection()

## 目标选择回调
func _on_target_selected_from_coordinator(targets: Array) -> void:
	print("🎯 [BattleUICoordinator] 目标选择: %d 个" % targets.size())
	
	# 通知BattleScene处理目标选择
	if battle_scene.has_method("_on_target_selected"):
		battle_scene._on_target_selected(targets)

## 目标选择取消回调
func _on_target_selection_cancelled_from_coordinator() -> void:
	print("❌ [BattleUICoordinator] 目标选择取消")
	
	# 通知BattleScene处理目标选择取消
	if battle_scene.has_method("_on_target_menu_closed"):
		battle_scene._on_target_menu_closed()

## 可视化技能释放完成回调
func _on_visual_skill_cast_completed_from_coordinator(skill: SkillData, caster: GameCharacter, targets: Array) -> void:
	print("✅ [BattleUICoordinator] 可视化技能释放完成")
	
	# 委托给BattleScene处理
	if battle_scene.has_method("_on_visual_skill_cast_completed"):
		battle_scene._on_visual_skill_cast_completed(skill, caster, targets)

## 可视化技能选择取消回调
func _on_visual_skill_selection_cancelled_from_coordinator() -> void:
	print("❌ [BattleUICoordinator] 可视化技能选择取消")
	
	# 委托给BattleScene处理
	if battle_scene.has_method("_on_visual_skill_selection_cancelled"):
		battle_scene._on_visual_skill_selection_cancelled()

## 获取当前UI状态
func get_ui_state() -> String:
	return current_ui_mode

## 设置UI模式
func set_ui_mode(mode: String) -> void:
	current_ui_mode = mode
	print("🎨 [BattleUICoordinator] UI模式切换为: %s" % mode) 
 

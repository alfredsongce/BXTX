# BattleVisualEffectsManager.gd
# 战斗视觉效果管理器 - 负责管理所有战斗相关的视觉效果

class_name BattleVisualEffectsManager
extends Node

# 🎨 信号定义
signal visual_effect_completed(effect_type: String, character: GameCharacter)
signal damage_numbers_displayed(character: GameCharacter, damage: int)
signal healing_numbers_displayed(character: GameCharacter, healing: int)
signal marker_added(character: GameCharacter, marker_type: String)

# 🎯 视觉效果配置
var damage_number_duration: float = 1.5
var healing_number_duration: float = 1.5
var marker_fade_duration: float = 2.0
var highlight_intensity: float = 1.5
var highlight_duration: float = 0.5

# 🎮 引用
var battle_scene: Node
var character_manager: BattleCharacterManager
var skill_effects: Node
var skill_manager: Node  # SkillManager引用

# 🎨 视觉效果缓存
var active_markers: Dictionary = {}
var active_highlights: Dictionary = {}

# 🚀 初始化
func _ready() -> void:
	print("🎨 [视觉效果管理器] BattleVisualEffectsManager 初始化")

# 🔧 设置引用
func setup_references(scene: Node, char_manager: BattleCharacterManager, effects: Node) -> void:
	battle_scene = scene
	character_manager = char_manager
	skill_effects = effects
	print("🔧 [视觉效果管理器] 引用设置完成")

# 💥 创建伤害数字
func create_damage_numbers(character: GameCharacter, damage: int, is_critical: bool = false) -> void:
	if not character:
		print("⚠️ [伤害数字] 角色为空")
		return
	
	print("💥 [伤害数字] 为 %s 创建伤害数字: %d %s" % [character.name, damage, "(暴击!)" if is_critical else ""])
	
	# 如果有SkillEffects节点，优先使用它
	if skill_effects and skill_effects.has_method("create_damage_numbers"):
		skill_effects.create_damage_numbers(character, damage, is_critical)
	else:
		# 备用方案：自己创建伤害数字
		_create_damage_numbers_fallback(character, damage, is_critical)
	
	damage_numbers_displayed.emit(character, damage)
	visual_effect_completed.emit("damage_numbers", character)

# 🎬 为AI攻击创建伤害跳字（从BattleScene迁移）
func create_ai_attack_damage_numbers(target: GameCharacter, damage: int) -> void:
	# 获取SkillEffects节点
	if not skill_effects:
		print("⚠️ [AI伤害跳字] 找不到SkillEffects节点")
		return
	
	print("🎬 [AI伤害跳字] 为目标 %s 创建伤害数字: %d" % [target.name, damage])
	
	# 🎯 判断是否暴击（10%几率）
	var is_critical = randf() < 0.1
	
	print("🎬 [AI伤害跳字] 伤害类型: %s" % ("暴击!" if is_critical else "普通"))
	
	# 调用SkillEffects创建伤害数字
	create_damage_numbers(target, damage, is_critical)
	
	print("✅ [AI伤害跳字] 伤害跳字创建完成")

# 💚 创建治疗数字
func create_healing_numbers(character: GameCharacter, healing: int) -> void:
	if not character:
		print("⚠️ [治疗数字] 角色为空")
		return
	
	print("💚 [治疗数字] 为 %s 创建治疗数字: %d" % [character.name, healing])
	
	# 如果有SkillEffects节点，优先使用它
	if skill_effects and skill_effects.has_method("create_healing_numbers"):
		skill_effects.create_healing_numbers(character, healing)
	else:
		# 备用方案：自己创建治疗数字
		_create_healing_numbers_fallback(character, healing)
	
	healing_numbers_displayed.emit(character, healing)
	visual_effect_completed.emit("healing_numbers", character)

# 💀 添加死亡标记
func add_death_marker(character_node: Node2D) -> void:
	if not character_node:
		print("⚠️ [死亡标记] 角色节点为空")
		return
	
	# 检查是否已经有死亡标记
	if character_node.get_node_or_null("DeathMarker"):
		return
	
	print("💀 [死亡标记] 为 %s 添加死亡标记" % character_node.name)
	
	# 创建死亡标记容器
	var death_marker = Node2D.new()
	death_marker.name = "DeathMarker"
	death_marker.z_index = 10
	
	# 创建X绘制器
	var x_drawer = Node2D.new()
	x_drawer.name = "XDrawer"
	death_marker.add_child(x_drawer)
	
	# 创建X形状绘制节点
	var x_shape = _DeathMarkerDrawer.new()
	x_drawer.add_child(x_shape)
	
	# 添加到角色节点
	character_node.add_child(death_marker)
	
	# 记录到活跃标记中
	active_markers[character_node.name + "_death"] = death_marker

# 🎉 添加胜利标记
func add_victory_markers(characters: Array[GameCharacter]) -> void:
	print("🎉 [胜利标记] 为 %d 个角色添加胜利标记" % characters.size())
	
	for character in characters:
		if not character:
			continue
			
		var character_node = _find_character_node(character)
		if not character_node:
			continue
		
		print("🎉 [胜利标记] 为 %s 添加胜利标记" % character.name)
		
		# 创建胜利标记
		var victory_marker = _create_text_marker("胜利!", Color.GOLD, character_node.global_position)
		active_markers[character.name + "_victory"] = victory_marker
		
		marker_added.emit(character, "victory")
	
	visual_effect_completed.emit("victory_markers", null)

# 💔 添加失败标记
func add_defeat_markers(characters: Array[GameCharacter]) -> void:
	print("💔 [失败标记] 为 %d 个角色添加失败标记" % characters.size())
	
	for character in characters:
		if not character:
			continue
			
		var character_node = _find_character_node(character)
		if not character_node:
			continue
		
		print("💔 [失败标记] 为 %s 添加失败标记" % character.name)
		
		# 创建失败标记
		var defeat_marker = _create_text_marker("败北", Color.GRAY, character_node.global_position)
		active_markers[character.name + "_defeat"] = defeat_marker
		
		marker_added.emit(character, "defeat")
	
	visual_effect_completed.emit("defeat_markers", null)

# ⭐ 高亮角色
func highlight_character(character: GameCharacter, color: Color = Color.YELLOW) -> void:
	if not character:
		print("⚠️ [角色高亮] 角色为空")
		return
	
	var character_node = _find_character_node(character)
	if not character_node:
		print("⚠️ [角色高亮] 无法找到角色节点")
		return
	
	print("⭐ [角色高亮] 高亮角色: %s" % character.name)
	
	# 移除之前的高亮
	clear_character_highlight(character)
	
	# 创建高亮效果
	var original_modulate = character_node.modulate
	var highlight_tween = create_tween()
	highlight_tween.set_loops()
	highlight_tween.tween_property(character_node, "modulate", color * highlight_intensity, highlight_duration)
	highlight_tween.tween_property(character_node, "modulate", original_modulate, highlight_duration)
	
	active_highlights[character.name] = {
		"tween": highlight_tween,
		"original_modulate": original_modulate,
		"node": character_node
	}
	
	visual_effect_completed.emit("highlight", character)

# 🔄 清除角色高亮
func clear_character_highlight(character: GameCharacter) -> void:
	if not character:
		return
	
	var highlight_key = character.name
	if active_highlights.has(highlight_key):
		var highlight_data = active_highlights[highlight_key]
		
		# 停止高亮动画
		if highlight_data.tween and is_instance_valid(highlight_data.tween):
			highlight_data.tween.kill()
		
		# 恢复原始颜色
		if highlight_data.node and is_instance_valid(highlight_data.node):
			highlight_data.node.modulate = highlight_data.original_modulate
		
		active_highlights.erase(highlight_key)
		print("🔄 [角色高亮] 清除 %s 的高亮效果" % character.name)

# 🧹 清除所有高亮
func clear_all_highlights() -> void:
	print("🧹 [角色高亮] 清除所有高亮效果")
	
	for highlight_key in active_highlights.keys():
		var highlight_data = active_highlights[highlight_key]
		
		# 停止高亮动画
		if highlight_data.tween and is_instance_valid(highlight_data.tween):
			highlight_data.tween.kill()
		
		# 恢复原始颜色
		if highlight_data.node and is_instance_valid(highlight_data.node):
			highlight_data.node.modulate = highlight_data.original_modulate
	
	active_highlights.clear()
	print("✅ [角色高亮] 所有高亮效果已清除")

# 🗑️ 清除所有标记
func clear_all_markers() -> void:
	print("🗑️ [标记管理] 清除所有标记")
	
	for marker_key in active_markers.keys():
		var marker = active_markers[marker_key]
		if is_instance_valid(marker):
			marker.queue_free()
	
	active_markers.clear()
	print("✅ [标记管理] 所有标记已清除")

# 📝 创建文本标记
func _create_text_marker(text: String, color: Color, position: Vector2) -> Label:
	var marker = Label.new()
	marker.text = text
	marker.add_theme_color_override("font_color", color)
	marker.add_theme_font_size_override("font_size", 24)
	marker.global_position = position + Vector2(0, -50)  # 在角色上方显示
	marker.z_index = 100
	
	# 添加到场景
	battle_scene.add_child(marker)
	
	# 创建淡出动画
	var fade_tween = create_tween()
	fade_tween.tween_property(marker, "modulate:a", 0.0, marker_fade_duration)
	fade_tween.tween_callback(marker.queue_free)
	
	return marker

# 💥 备用伤害数字创建
func _create_damage_numbers_fallback(character: GameCharacter, damage: int, is_critical: bool) -> void:
	var character_node = _find_character_node(character)
	if not character_node:
		return
	
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.add_theme_font_size_override("font_size", 32 if is_critical else 24)
	damage_label.add_theme_color_override("font_color", Color.RED if not is_critical else Color.ORANGE)
	damage_label.global_position = character_node.global_position + Vector2(0, -30)
	damage_label.z_index = 100
	
	battle_scene.add_child(damage_label)
	
	# 动画效果
	var damage_tween = create_tween()
	damage_tween.set_parallel(true)
	damage_tween.tween_property(damage_label, "global_position", damage_label.global_position + Vector2(0, -50), damage_number_duration)
	damage_tween.tween_property(damage_label, "modulate:a", 0.0, damage_number_duration)
	damage_tween.tween_callback(damage_label.queue_free)
	
	print("💥 [备用伤害数字] 创建完成")

# 💚 备用治疗数字创建
func _create_healing_numbers_fallback(character: GameCharacter, healing: int) -> void:
	var character_node = _find_character_node(character)
	if not character_node:
		return
	
	var healing_label = Label.new()
	healing_label.text = "+" + str(healing)
	healing_label.add_theme_font_size_override("font_size", 24)
	healing_label.add_theme_color_override("font_color", Color.GREEN)
	healing_label.global_position = character_node.global_position + Vector2(0, -30)
	healing_label.z_index = 100
	
	battle_scene.add_child(healing_label)
	
	# 动画效果
	var healing_tween = create_tween()
	healing_tween.set_parallel(true)
	healing_tween.tween_property(healing_label, "global_position", healing_label.global_position + Vector2(0, -50), healing_number_duration)
	healing_tween.tween_property(healing_label, "modulate:a", 0.0, healing_number_duration)
	healing_tween.tween_callback(healing_label.queue_free)
	
	print("💚 [备用治疗数字] 创建完成")

# 🔍 查找角色节点
func _find_character_node(character: GameCharacter) -> Node2D:
	if not character_manager:
		print("⚠️ [查找节点] CharacterManager未设置")
		return null
	
	# 尝试从玩家节点中查找
	var party_nodes = character_manager.get_party_member_nodes()
	for character_id in party_nodes:
		var node = party_nodes[character_id]
		if node and node.get_character_data() == character:
			return node
	
	# 尝试从敌人节点中查找
	var enemy_nodes = character_manager.get_enemy_nodes()
	for character_id in enemy_nodes:
		var node = enemy_nodes[character_id]
		if node and node.get_character_data() == character:
			return node
	
	print("⚠️ [查找节点] 未找到角色 %s 的节点" % character.name)
	return null

# 🎯 设置视觉效果配置
func set_visual_config(config: Dictionary) -> void:
	if config.has("damage_number_duration"):
		damage_number_duration = config.damage_number_duration
	
	if config.has("healing_number_duration"):
		healing_number_duration = config.healing_number_duration
	
	if config.has("marker_fade_duration"):
		marker_fade_duration = config.marker_fade_duration
	
	if config.has("highlight_intensity"):
		highlight_intensity = config.highlight_intensity
	
	if config.has("highlight_duration"):
		highlight_duration = config.highlight_duration
	
	print("🎯 [视觉效果管理器] 视觉效果配置已更新")

# 🧪 测试伤害跳字（从BattleScene迁移）
func test_damage_numbers() -> void:
	# 获取SkillEffects节点
	var skill_effects = battle_scene.get_node_or_null("SkillEffects") if battle_scene else null
	if not skill_effects:
		return
	
	# 获取第一个敌人来测试
	var test_character = null
	var test_node = null
	
	if character_manager:
		var enemy_nodes = character_manager.get_enemy_nodes()
		if enemy_nodes.size() > 0:
			var first_enemy_id = enemy_nodes.keys()[0]
			test_node = enemy_nodes[first_enemy_id]
			if test_node:
				test_character = test_node.get_character_data()
	
	if not test_character or not test_node:
		return
	
	# 测试伤害数字
	skill_effects.create_damage_numbers(test_character, 50, false)
	
	# 等待0.5秒后创建暴击伤害
	await battle_scene.get_tree().create_timer(0.5).timeout
	skill_effects.create_damage_numbers(test_character, 100, true)
	
	# 等待0.5秒后创建治疗数字
	await battle_scene.get_tree().create_timer(0.5).timeout
	skill_effects.create_healing_numbers(test_character, 30)



# 🚀 处理角色死亡视觉效果（从BattleScene迁移）
func handle_character_death_visuals(dead_character: GameCharacter) -> void:
	# 找到对应的角色节点
	var character_node = _find_character_node(dead_character)
	if character_node:
		# 🚀 更明显的死亡效果：更深的灰色，更低的透明度
		character_node.modulate = Color(0.3, 0.3, 0.3, 0.6)  # 更深的灰色，更明显的死亡效果
		print("💀 [死亡] %s 已阵亡，应用死亡视觉效果" % dead_character.name)
		
		# 🚀 添加死亡标记（可选：添加一个红色X标记）
		add_death_marker(character_node)
		
		# 🚀 播放死亡动画
		play_death_animation(character_node)
	else:
		print("⚠️ [死亡] 无法找到 %s 对应的角色节点" % dead_character.name)

# 🚀 处理角色死亡（兼容性方法）
func handle_character_death(dead_character: GameCharacter) -> void:
	handle_character_death_visuals(dead_character)

# 🚀 播放死亡动画
func play_death_animation(character_node: Node2D) -> void:
	if not character_node:
		return
	
	print("🎬 [死亡动画] 播放 %s 的死亡动画" % character_node.name)
	
	# 创建死亡动画：缩放+旋转+淡出
	var tween = create_tween()
	tween.set_parallel(true)  # 允许并行动画
	
	# 缩放动画：从正常大小缩小到0.5
	tween.tween_property(character_node, "scale", Vector2(0.5, 0.5), 1.0)
	
	# 旋转动画：轻微旋转
	tween.tween_property(character_node, "rotation", deg_to_rad(15), 1.0)
	
	# 透明度动画：逐渐变透明
	tween.tween_property(character_node, "modulate:a", 0.3, 1.0)
	
	# 动画完成后的回调
	tween.tween_callback(_on_death_animation_completed.bind(character_node))

func _on_death_animation_completed(character_node: Node2D) -> void:
	print("✅ [死亡动画] %s 死亡动画播放完成" % character_node.name)
	# 可以在这里添加额外的死亡后处理

# 🚀 播放死亡特效（兼容性方法）
func play_death_effect(character_node: Node2D) -> void:
	play_death_animation(character_node)

# 注意：add_death_marker函数已在第77行定义，此处删除重复声明

# 🚀 死亡标记绘制类（从BattleScene迁移）
class _DeathMarkerDrawer extends Node2D:
	func _draw():
		var size = 30.0
		var thickness = 4.0
		var color = Color.RED
		
		# 绘制X形状
		draw_line(Vector2(-size/2, -size/2), Vector2(size/2, size/2), color, thickness)
		draw_line(Vector2(size/2, -size/2), Vector2(-size/2, size/2), color, thickness)

# 🧪 测试视觉效果
func test_visual_effects() -> void:
	pass

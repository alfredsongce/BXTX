# 🎬 战斗动画管理器
# 负责管理战斗中的所有动画效果
class_name BattleAnimationManager
extends Node

# 🎯 信号定义
signal animation_started(animation_type: String, character: GameCharacter)
signal animation_completed(animation_type: String, character: GameCharacter)
signal attack_animation_finished(attacker: GameCharacter, target: GameCharacter)

# 🎮 核心组件引用
@onready var battle_scene: Node = get_parent().get_parent()  # BattleScene
@onready var skill_effects: Node = battle_scene.get_node_or_null("SkillEffects")
var skill_manager: Node  # SkillManager引用

# 🎭 动画状态管理
var active_animations: Dictionary = {}
var animation_queue: Array[Dictionary] = []
var is_processing_queue: bool = false

# 🚀 初始化
func _ready() -> void:
	print("🎬 [动画管理器] 初始化完成")
	name = "BattleAnimationManager"

# 🎯 播放攻击动画（从BattleScene迁移）
func play_attack_animation(attacker: GameCharacter, target: GameCharacter, skill_data: Dictionary) -> void:
	print("🎬 [攻击动画] %s 对 %s 使用 %s" % [attacker.name, target.name, skill_data.get("name", "未知技能")])
	
	# 发出动画开始信号
	animation_started.emit("attack", attacker)
	
	# 如果有SkillEffects组件，委托给它处理
	if skill_effects and skill_effects.has_method("play_attack_animation"):
		skill_effects.play_attack_animation(attacker, target, skill_data)
	else:
		# 备用动画逻辑
		_play_attack_animation_fallback(attacker, target, skill_data)
	
	# 发出动画完成信号
	animation_completed.emit("attack", attacker)
	attack_animation_finished.emit(attacker, target)

# 🎬 播放AI攻击动画（从BattleScene迁移）
func play_ai_attack_animation(attacker: GameCharacter, target: GameCharacter) -> void:
	# 获取攻击者和目标的节点
	var attacker_node = _find_character_node(attacker)
	var target_node = _find_character_node(target)
	
	if not attacker_node or not target_node:
		print("⚠️ [AI攻击动画] 无法找到攻击者或目标节点")
		return
	
	print("🎬 [AI攻击动画] %s 攻击 %s" % [attacker.name, target.name])
	
	# 🎯 第一阶段：攻击者发光效果（准备攻击）
	var original_attacker_modulate = attacker_node.modulate
	var preparation_tween = create_tween()
	preparation_tween.tween_property(attacker_node, "modulate", Color.RED * 1.5, 0.3)
	preparation_tween.tween_property(attacker_node, "modulate", original_attacker_modulate, 0.2)
	
	# 等待准备动画完成
	await preparation_tween.finished
	
	# 🚀 第二阶段：攻击特效（从攻击者到目标的能量波）
	create_attack_projectile(attacker_node.global_position, target_node.global_position)
	
	# 等待弹道到达时间
	await get_tree().create_timer(0.4).timeout
	
	# 💥 第三阶段：目标受击效果
	var original_target_modulate = target_node.modulate
	var hit_tween = create_tween()
	hit_tween.set_parallel(true)
	
	# 目标闪烁受击效果
	hit_tween.tween_property(target_node, "modulate", Color.WHITE * 2.0, 0.1)
	hit_tween.tween_property(target_node, "modulate", original_target_modulate, 0.2)
	
	# 目标轻微震动效果
	var original_position = target_node.position
	for i in range(3):
		hit_tween.tween_property(target_node, "position", original_position + Vector2(randf_range(-5, 5), 0), 0.05)
		hit_tween.tween_property(target_node, "position", original_position, 0.05)
	
	# 创建命中爆炸效果
	create_hit_explosion_effect(target_node.global_position)
	
	# 等待所有受击效果完成
	await hit_tween.finished
	
	print("✅ [AI攻击动画] 攻击动画播放完成")

# 🚀 创建攻击弹道效果（从BattleScene迁移）
func create_attack_projectile(start_pos: Vector2, end_pos: Vector2) -> void:
	# 创建能量弹效果
	var projectile = ColorRect.new()
	projectile.size = Vector2(16, 16)
	projectile.color = Color.ORANGE
	projectile.global_position = start_pos - projectile.size / 2  # 居中
	projectile.z_index = 50
	
	# 添加到场景
	battle_scene.add_child(projectile)
	
	# 计算方向和旋转
	var direction = (end_pos - start_pos).normalized()
	projectile.rotation = direction.angle()
	
	# 弹道飞行动画
	var tween = create_tween()
	tween.tween_property(projectile, "global_position", end_pos - projectile.size / 2, 0.4)
	tween.tween_callback(projectile.queue_free)
	
	print("🚀 [攻击弹道] 创建攻击弹道效果")

# 💥 创建命中爆炸效果（从BattleScene迁移）
func create_hit_explosion_effect(position: Vector2) -> void:
	# 创建爆炸效果容器
	var explosion = Node2D.new()
	explosion.global_position = position
	battle_scene.add_child(explosion)
	
	# 创建爆炸粒子
	for i in range(8):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color.YELLOW
		particle.position = -particle.size / 2  # 居中
		
		explosion.add_child(particle)
		
		# 粒子扩散动画
		var angle = i * 45.0  # 8个方向
		var direction = Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
		var end_pos = direction * 40
		
		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "position", end_pos, 0.3)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.3)
	
	# 清理爆炸效果
	get_tree().create_timer(0.3).timeout.connect(explosion.queue_free)
	
	print("💥 [命中效果] 创建命中爆炸效果")

# 🎭 备用攻击动画实现
func _play_attack_animation_fallback(attacker: GameCharacter, target: GameCharacter, skill_data: Dictionary) -> void:
	print("🎭 [备用动画] 播放攻击动画: %s -> %s" % [attacker.name, target.name])
	
	# 简单的动画效果
	var attacker_node = _find_character_node(attacker)
	var target_node = _find_character_node(target)
	
	if attacker_node and target_node:
		# 攻击者向目标移动一点
		var original_pos = attacker_node.global_position
		var target_pos = target_node.global_position
		var move_distance = (target_pos - original_pos).normalized() * 20
		
		# 创建简单的移动动画
		var tween = create_tween()
		tween.tween_property(attacker_node, "global_position", original_pos + move_distance, 0.2)
		tween.tween_property(attacker_node, "global_position", original_pos, 0.2)

# 🔍 查找角色节点
func _find_character_node(character: GameCharacter) -> Node2D:
	if not character or not battle_scene:
		return null
	
	# 尝试通过BattleScene的方法查找
	if battle_scene.has_method("_find_character_node_by_character_data"):
		return battle_scene._find_character_node_by_character_data(character)
	
	# 备用查找方法
	var characters_container = battle_scene.get_node_or_null("Characters")
	if characters_container:
		for child in characters_container.get_children():
			if child.has_method("get_character_data"):
				var char_data = child.get_character_data()
				if char_data and char_data.name == character.name:
					return child
	
	return null

# 🎮 动画队列管理
func queue_animation(animation_data: Dictionary) -> void:
	animation_queue.append(animation_data)
	if not is_processing_queue:
		_process_animation_queue()

func _process_animation_queue() -> void:
	if animation_queue.is_empty():
		is_processing_queue = false
		return
	
	is_processing_queue = true
	var next_animation = animation_queue.pop_front()
	
	# 处理动画...
	# 完成后继续处理队列
	call_deferred("_process_animation_queue")

# 🧹 清理资源
func _exit_tree() -> void:
	print("🎬 [动画管理器] 清理资源")
	active_animations.clear()
	animation_queue.clear()

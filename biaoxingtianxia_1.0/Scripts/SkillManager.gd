extends Node
class_name SkillManager

# 技能数据缓存
var skill_database: Dictionary = {}
var active_skill_selection: SkillData = null
var current_caster: GameCharacter = null

# 状态管理
enum SkillState {
	IDLE,
	SELECTING_SKILL,
	SELECTING_TARGET,
	EXECUTING_SKILL
}
var current_state: SkillState = SkillState.IDLE

# 调试开关
var debug_enabled: bool = false

# 🎬 技能效果系统
var skill_effects: Node2D = null

# 信号定义
signal skill_selection_started(caster: GameCharacter)
signal skill_selected(skill: SkillData)
signal skill_target_selected(skill: SkillData, targets: Array)
signal skill_execution_completed(skill: SkillData, results: Dictionary, caster: GameCharacter)
signal skill_cancelled()

func _ready():
	print("🎯 [技能系统] SkillManager初始化...")
	_load_skill_database()
	
	# 🎬 初始化技能效果系统
	_setup_skill_effects()
	
	# 添加到技能管理器组
	add_to_group("skill_manager")

# 加载技能数据库
func _load_skill_database():
	print("📚 [技能系统] 加载技能数据库...")
	
	# 确保DataManager已加载技能数据
	DataManager.load_data("skills")
	
	# 从DataManager获取技能数据
	var skills_data = DataManager.get_data("skills")
	if not skills_data or not skills_data is Array:
		print("⚠️ [技能系统] 未找到技能数据或数据格式错误")
		return
	
	# 解析技能数据
	for skill_row in skills_data:
		var skill = SkillData.new()
		skill.load_from_csv_row(skill_row)
		skill_database[skill.id] = skill
	
	print("✅ [技能系统] 技能数据库加载完成，共 %d 个技能" % skill_database.size())

# 获取角色可用技能列表
func get_available_skills(character: GameCharacter) -> Array:
	var available_skills = []
	
	# 🚀 修复：根据角色的技能学习配置获取可用技能
	print("🎯 [技能系统] 为角色 %s (等级%d) 获取可用技能" % [character.name, character.level])
	
	# 确保技能学习数据已加载
	DataManager.load_data("skill_learning")
	
	# 获取角色的技能学习配置
	var character_skill_learning = DataManager.get_character_skill_learning(character.id)
	
	print("🔍 [技能系统] 角色 %s 的技能学习配置: %d 条" % [character.name, character_skill_learning.size()])
	
	for learning_record in character_skill_learning:
		var skill_id = learning_record.get("skill_id", "")
		var learn_type = learning_record.get("learn_type", "")
		var learn_level = int(learning_record.get("learn_level", "0"))
		
		# 检查是否应该学会这个技能
		var should_learn = false
		
		match learn_type.to_upper():
			"INITIAL":
				# 初始学会的技能
				should_learn = true
				print("📚 [技能系统] %s 初始掌握技能: %s" % [character.name, skill_id])
			"LEVEL":
				# 等级学会的技能
				if character.level >= learn_level:
					should_learn = true
					print("📚 [技能系统] %s 等级%d学会技能: %s (需求等级%d)" % [character.name, character.level, skill_id, learn_level])
				else:
					print("📚 [技能系统] %s 等级不足，无法学会技能: %s (当前%d/需求%d)" % [character.name, skill_id, character.level, learn_level])
		
		# 如果应该学会，添加到可用技能列表
		if should_learn and skill_database.has(skill_id):
			var skill = skill_database[skill_id]
			available_skills.append(skill)
	
	print("✅ [技能系统] 角色 %s 最终可用技能数量: %d" % [character.name, available_skills.size()])
	return available_skills

# 🎬 技能效果系统
func _setup_skill_effects():
	# 从场景中获取SkillEffects节点
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_node("SkillEffects"):
		print("✨ [技能系统] 找到场景中的SkillEffects节点")
	else:
		print("⚠️ [技能系统] 未找到SkillEffects节点，技能视觉效果将不可用")
 

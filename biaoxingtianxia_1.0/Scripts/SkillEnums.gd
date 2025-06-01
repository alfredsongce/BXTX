class_name SkillEnums

# 目标选择类型
enum TargetingType {
	PROJECTILE_SINGLE,    # 弹道单点型：需要视线，不能有障碍物遮挡
	PROJECTILE_PATH,      # 弹道路径型：向方向发射，遇到第一个目标
	PROJECTILE_PIERCE,    # 弹道路径穿刺型：穿透路径上所有目标
	NORMAL,               # 普通型：范围内选择目标，无视线要求
	FREE,                 # 自由型：选择任意位置释放
	SELF                  # 自身型：只能对自己释放
}

# 目标范围类型
enum RangeType {
	SINGLE,               # 单体型：只影响选中的目标
	RANGE                 # 范围型：影响目标周围一定范围内的角色
}

# 生效目标类型
enum TargetType {
	SELF,                 # 自身型：只对施法者生效
	ENEMY,                # 敌方型：只对敌人生效
	ALLY,                 # 我方型：只对友方生效（包含自身）
	ALLYONLY,             # 友方专用型：只对友方生效（不包含自身）
	ALL                   # 无视敌我型：对所有角色生效
}

# 技能效果类型
enum EffectType {
	DAMAGE,               # 伤害效果
	HEAL,                 # 治疗效果
	BUFF,                 # 增益效果
	DEBUFF,               # 减益效果
	STATUS                # 状态效果
} 
# SkillSelectionMenu 实现文档

## 概述

SkillSelectionMenu 是一个传统的基于列表的技能选择菜单系统，用于在战斗中为角色选择技能。该系统包含UI界面、逻辑控制和信号处理等多个组件。

## 文件结构

### 1. 核心文件

#### UI/SkillSelectionMenu.gd (141行)
- **功能**: 技能选择菜单的主要逻辑脚本
- **信号**:
  - `skill_selected(skill_id: String)` - 技能被选择时发出
  - `menu_closed()` - 菜单关闭时发出
- **主要变量**:
  - `current_character: GameCharacter` - 当前选择技能的角色
  - `available_skills: Array` - 可用技能列表
  - `skill_buttons: Array` - 技能按钮数组
- **UI组件引用**:
  - `title_label: Label` - 标题标签
  - `skill_list_container: VBoxContainer` - 技能列表容器
  - `skill_info_panel: Panel` - 技能信息面板
  - `skill_name_label: Label` - 技能名称标签
  - `skill_desc_label: Label` - 技能描述标签
  - `skill_cost_label: Label` - 技能消耗标签
  - `skill_range_label: Label` - 技能范围标签
  - `cancel_button: Button` - 取消按钮

#### UI/SkillSelectionMenu.tscn (90行)
- **功能**: 技能选择菜单的场景文件
- **结构**:
  - Panel (根节点)
    - VBoxContainer
      - TitleLabel
      - HSeparator
      - ScrollContainer
        - SkillListContainer
      - HSeparator2
      - SkillInfoPanel
        - VBoxContainer
          - SkillNameLabel
          - SkillDescLabel
          - SkillCostLabel
          - SkillRangeLabel
      - HSeparator3
      - CancelButton

### 2. 集成文件

#### Scripts/UIManager.gd
- **变量**: `skill_selection_menu: Control = null`
- **初始化方法**: `_setup_skill_selection_menu()`
- **显示方法**: `show_skill_selection_menu(character: GameCharacter, available_skills: Array)`
- **信号处理**:
  - `_on_skill_selected(skill_id: String)`
  - `_on_skill_menu_closed()`

#### Scripts/Battle/SkillSelectionCoordinator.gd
- **变量**: `skill_selection_menu: Control = null`
- **初始化方法**: `_setup_skill_selection_menu()`
- **显示方法**: `show_skill_selection_menu(character: GameCharacter, available_skills: Array)`
- **信号处理**:
  - `_on_skill_selected(skill_id: String)`
  - `_on_skill_menu_closed()`

#### Scripts/BattleScene.gd
- **委托方法**: `show_skill_selection_menu(character: GameCharacter, available_skills: Array)`
- **信号处理**:
  - `_on_skill_selected(skill_id: String)`
  - `_on_skill_menu_closed()`

#### Scripts/ActionSystemNew.gd
- **调用**: 通过 `battle_scene.show_skill_selection_menu(character_data, available_skills)` 调用

## 主要功能

### 1. 菜单显示
- `open_menu(character: GameCharacter, skills: Array)`: 打开技能选择菜单
- `close_menu()`: 关闭菜单
- `_center_on_screen()`: 将菜单居中显示

### 2. 技能按钮管理
- `_create_skill_buttons()`: 创建技能按钮
- `_clear_skill_buttons()`: 清除技能按钮
- `_get_unusable_reason(skill: SkillData)`: 获取技能不可用的原因

### 3. 技能信息显示
- `_show_skill_info(skill: SkillData)`: 显示技能详细信息
- 悬停时显示技能信息，离开时隐藏

### 4. 事件处理
- `_on_skill_button_pressed(skill: SkillData)`: 技能按钮点击事件
- `_on_skill_button_hovered(skill: SkillData)`: 技能按钮悬停事件
- `_on_skill_button_unhovered()`: 技能按钮离开事件
- `_on_cancel_pressed()`: 取消按钮事件

## 信号流程

### 技能选择流程
1. ActionSystemNew 调用 BattleScene.show_skill_selection_menu()
2. BattleScene 委托给 SkillSelectionCoordinator.show_skill_selection_menu()
3. SkillSelectionCoordinator 调用 skill_selection_menu.open_menu()
4. 用户选择技能后，发出 skill_selected 信号
5. 信号依次传递：SkillSelectionMenu → SkillSelectionCoordinator → BattleScene → SkillManager

### 菜单关闭流程
1. 用户点击取消或选择技能后，发出 menu_closed 信号
2. 信号依次传递：SkillSelectionMenu → SkillSelectionCoordinator → BattleScene
3. BattleScene 根据当前状态决定是否取消技能选择

## 技能验证
- 检查角色MP是否足够
- 检查技能冷却时间（预留接口）
- 不可用技能显示为灰色并标注原因

## UI特性
- 居中显示
- 滚动容器支持大量技能
- 悬停显示技能详细信息
- 响应式布局
- z_index = 100 确保在最上层显示

## 调试信息
- 所有关键操作都有详细的print输出
- 使用表情符号标识不同类型的日志
- 包含角色名称、技能数量等上下文信息

## 依赖关系
- GameCharacter: 角色数据类
- SkillData: 技能数据类
- UIManager: UI管理器
- SkillSelectionCoordinator: 技能选择协调器
- BattleScene: 战斗场景
- ActionSystemNew: 行动系统
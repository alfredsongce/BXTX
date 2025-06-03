# PositionCollisionManager 物理空间查询优化方案

## 问题分析

当前的 `PositionCollisionManager` 使用距离检测方法，虽然性能较好，但检测结果严重失真，无法满足实际游戏需求。物理空间查询检测才是准确的碰撞检测方法。

## 优化目标

将 `PositionCollisionManager` 改造为基于物理空间查询的统一验证器，确保检测结果的准确性。

## 核心优化思路

### 1. 完全替换检测机制

- **移除距离检测逻辑**：删除当前的 `safe_distance` 和距离计算相关代码
- **采用物理空间查询**：使用 `PhysicsDirectSpaceState2D.intersect_shape()` 作为唯一检测方法
- **统一形状参数**：使用标准的 `PhysicsShapeQueryParameters2D` 配置

### 2. 物理查询参数标准化

```gdscript
# 标准物理查询配置
var query_params = PhysicsShapeQueryParameters2D.new()
query_params.shape = character_shape  # 角色实际碰撞形状
query_params.collision_mask = 14      # 检测静态障碍物、角色、障碍物
query_params.exclude = [character_rid] # 排除自身
```

### 3. 缓存机制重构

- **基于物理查询结果缓存**：缓存 `intersect_shape` 的返回结果
- **缓存键值优化**：使用位置+形状+碰撞掩码作为缓存键
- **缓存失效策略**：当场景中有角色移动时立即清空缓存

### 4. 性能优化策略

#### 4.1 查询范围限制
- 设置合理的查询范围，避免全场景检测
- 使用角色移动范围作为查询边界

#### 4.2 形状复用
- 预创建常用的碰撞形状对象
- 避免每次查询都创建新的形状实例

#### 4.3 批量查询
- 对于连续的位置验证，考虑批量处理
- 减少单次查询的开销

## 具体实现方案

### 1. 核心验证函数重写

```gdscript
func validate_position(position: Vector2, character_shape: Shape2D, exclude_character: RID = RID()) -> bool:
    var cache_key = _generate_cache_key(position, character_shape, exclude_character)
    
    if validation_cache.has(cache_key):
        cache_hits += 1
        return validation_cache[cache_key]
    
    var query_params = PhysicsShapeQueryParameters2D.new()
    query_params.shape = character_shape
    query_params.transform.origin = position
    query_params.collision_mask = collision_mask
    query_params.exclude = [exclude_character] if exclude_character != RID() else []
    
    var space_state = get_world_2d().direct_space_state
    var result = space_state.intersect_shape(query_params, 1)
    
    var is_valid = result.is_empty()
    validation_cache[cache_key] = is_valid
    physics_checks += 1
    
    return is_valid
```

### 2. 统一接口设计

所有调用方（MoveRangeInput、MovementCoordinator、MoveRangeValidator等）都通过统一的接口访问：

```gdscript
# 标准调用接口
func check_position_collision(position: Vector2, character: Node2D) -> bool:
    var character_shape = _get_character_shape(character)
    var character_rid = _get_character_rid(character)
    return validate_position(position, character_shape, character_rid)
```

### 3. 移除冗余检测

- **删除所有距离检测代码**：包括 `_distance_collision_check` 等函数
- **移除备选方案**：不保留任何fallback机制
- **统一错误处理**：物理查询失败时直接返回false（位置无效）

## 性能考虑

### 1. 查询频率控制
- 避免每帧都进行大量查询
- 使用事件驱动的缓存更新机制

### 2. 内存管理
- 定期清理过期缓存
- 限制缓存大小，防止内存泄漏

### 3. 查询优化
- 使用最小必要的碰撞掩码
- 优先检测最可能发生碰撞的层级

## 实现优先级

1. **第一阶段**：重写核心 `validate_position` 函数
2. **第二阶段**：更新所有调用方，移除距离检测代码
3. **第三阶段**：优化缓存机制和性能
4. **第四阶段**：清理冗余代码和注释

## 预期效果

- **准确性**：100%基于物理引擎的准确碰撞检测
- **一致性**：所有模块使用相同的检测逻辑
- **可维护性**：单一检测机制，易于调试和维护
- **性能**：通过缓存和优化保持可接受的性能水平

## 注意事项

- 不使用任何备选方案或fallback机制
- 不添加防御性编程代码
- 专注于demo阶段的功能实现
- 保持代码简洁直接，便于调试
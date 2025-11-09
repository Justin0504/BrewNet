# Profile Error 诊断和修复指南

## 问题描述
主页面拉取用户卡片时显示错误："Error: Some profile data is incomplete. Please refresh to try again."

## 错误原因分析

### 1. 数据库数据不完整
Profile表中的某些必需JSONB字段可能：
- 为NULL
- 缺少必需的子字段
- 包含错误的数据类型（如：Bool字段存储为Int）
- `available_timeslot`在错误的位置（应该在`networking_preferences`中，但可能在`core_identity`中）

### 2. 解码错误（DecodingError）
Swift应用解码Supabase返回的JSON数据时可能失败，原因包括：
- 缺少必需字段
- 类型不匹配
- 数据格式错误

## 已实施的修复

### 1. 增强错误诊断 (BrewNetMatchesView.swift)
✅ **改进点:**
- 添加了详细的DecodingError分析
- 显示缺失字段的具体路径
- 在控制台输出更详细的错误信息
- 保留原始错误信息以便调试

**位置:** `BrewNetMatchesView.swift` 第1560-1588行

```swift
// 现在会显示类似以下的详细错误：
// "Data format issue: Missing 'available_timeslot' at networking_preferences"
// 而不是简单的 "Some profile data is incomplete"
```

### 2. 增强Profile解码逻辑 (SupabaseModels.swift)
✅ **改进点:**
- 添加了自定义的`init(from decoder:)`方法
- 为每个JSONB字段提供独立的错误捕获和报告
- 打印具体哪个字段解码失败，包括user_id
- 更容易定位问题数据

**位置:** `SupabaseModels.swift` 第185-264行

### 3. 数据库诊断SQL脚本
✅ **创建了两个SQL脚本:**

#### a. `debug_profile_data.sql` - 诊断脚本
- 检查所有必需字段是否存在
- 检查各个JSONB字段的子字段完整性
- 识别`available_timeslot`位置错误
- 提供统计报告

#### b. `fix_incomplete_profiles.sql` - 修复脚本
- 自动修复缺失的数组字段（设为空数组而非NULL）
- 将`available_timeslot`从`core_identity`移动到`networking_preferences`
- 为缺失的必需字段提供默认值
- 验证修复后的数据完整性

### 4. 现有的详细诊断 (SupabaseService.swift)
✅ **已存在的功能:**
- `getProfile`方法已有完整的错误诊断
- 打印原始JSON响应
- 分析缺失的必需字段
- 详细的DecodingError报告

**位置:** `SupabaseService.swift` 第798-938行

## 诊断和修复步骤

### 步骤1: 运行诊断SQL
在Supabase Dashboard的SQL Editor中运行：
```bash
# 复制并运行
debug_profile_data.sql
```

查看输出，识别：
1. 有多少profiles不完整
2. 哪些字段最常缺失
3. 具体哪些用户的数据有问题

### 步骤2: 修复数据库数据
在Supabase Dashboard的SQL Editor中运行：
```bash
# 复制并运行
fix_incomplete_profiles.sql
```

这会：
- 修复所有缺失的必需字段
- 移动错位的`available_timeslot`
- 为数组字段设置空数组（而非NULL）
- 提供默认值

### 步骤3: 验证修复
运行最后的验证查询：
```sql
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN 
        core_identity IS NOT NULL 
        AND professional_background IS NOT NULL 
        AND networking_intention IS NOT NULL 
        AND networking_preferences IS NOT NULL
        AND networking_preferences->'available_timeslot' IS NOT NULL
        AND personality_social IS NOT NULL
        AND privacy_trust IS NOT NULL
    THEN 1 END) as complete_profiles
FROM profiles;
```

确保 `complete_profiles` = `total_profiles`

### 步骤4: 测试应用
1. 关闭应用
2. 清除应用缓存（如果需要）
3. 重新启动应用
4. 导航到主页面（BrewNetMatchesView）
5. 查看控制台输出

**查找以下日志:**
```
✅ Profile fetched successfully: [profile_id]
✅ Two-Tower recommendations loaded: X profiles
```

**如果仍有错误，查找:**
```
❌ Failed to decode core_identity for user [user_id]: [error]
❌ Failed to decode professional_background for user [user_id]: [error]
🔍 详细错误: Data format issue: [详细信息]
```

## 常见问题和解决方案

### 问题1: "Missing 'available_timeslot' at networking_preferences"
**原因:** `available_timeslot`在`core_identity`中而非`networking_preferences`中
**解决:** 运行`fix_incomplete_profiles.sql`会自动迁移

### 问题2: "Type mismatch for Bool"
**原因:** Bool字段在数据库中存储为0/1（Int）
**解决:** `DayTimeslots`和其他模型已经有容错的解码逻辑处理Int/Bool/String转换

### 问题3: "Missing value of type Array"
**原因:** 数组字段为NULL而非空数组
**解决:** 运行`fix_incomplete_profiles.sql`会将NULL数组转换为`[]`

### 问题4: 特定用户的profile持续失败
**步骤:**
1. 从控制台获取user_id
2. 运行诊断查询查看该用户的数据：
```sql
SELECT * FROM profiles WHERE user_id = 'USER_ID_HERE';
```
3. 手动检查JSONB字段结构
4. 对比正常的profile数据结构

## 预防措施

### 1. Profile创建时的验证
确保`ProfileSetupView`创建profile时，所有必需字段都有值：
- 数组字段初始化为`[]`而非留空
- Bool字段明确设置为true/false
- `available_timeslot`在`networking_preferences`中

### 2. 数据库约束
考虑添加PostgreSQL检查约束：
```sql
-- 示例：确保networking_preferences有available_timeslot
ALTER TABLE profiles
ADD CONSTRAINT check_available_timeslot
CHECK (networking_preferences ? 'available_timeslot');
```

### 3. 后端验证
在`SupabaseService.createProfile`和`updateProfile`中添加验证：
```swift
// 验证必需字段
guard !profile.professionalBackground.skills.isEmpty else {
    throw ProfileError.invalidData("Skills cannot be empty")
}
```

## 监控和维护

### 定期检查
建议定期运行诊断SQL（每周一次）：
```sql
-- 快速健康检查
SELECT 
    COUNT(*) FILTER (WHERE networking_preferences->'available_timeslot' IS NULL) as missing_timeslot,
    COUNT(*) FILTER (WHERE professional_background->'skills' IS NULL) as missing_skills,
    COUNT(*) FILTER (WHERE networking_intention->'selected_sub_intentions' IS NULL) as missing_intentions
FROM profiles;
```

### 日志监控
关注应用日志中的以下模式：
- `❌ Failed to decode` - 表示数据格式问题
- `⚠️ Missing key` - 表示缺失必需字段
- `Type mismatch` - 表示数据类型不一致

## 总结

通过以下改进，现在可以：
1. ✅ 快速识别哪个字段导致错误
2. ✅ 定位到具体的用户和数据
3. ✅ 自动修复大部分常见问题
4. ✅ 在控制台看到详细的诊断信息
5. ✅ 使用SQL脚本批量修复数据

如果问题仍然存在，请检查控制台输出的详细错误信息，并根据具体的字段路径进行针对性修复。


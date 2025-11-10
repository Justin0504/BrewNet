# 修复 "Missing key: profile_completion" 错误

## 🔴 错误信息
```
Failed to load profiles: The data couldn't be read because it is missing.
🔍 DecodingError detected:
   - Missing key: profile_completion
   - Path: 
```

## 🎯 问题原因

数据库的 `user_features` 表中缺少 `profile_completion` 字段。这个字段用于Two-Tower推荐系统，表示用户profile的完整度（0.0 到 1.0）。

## ✅ 快速修复（2分钟）

### 步骤1: 运行SQL修复脚本

在 **Supabase Dashboard** 的 SQL Editor 中运行：

```sql
-- 快速添加 profile_completion 字段
ALTER TABLE user_features 
ADD COLUMN IF NOT EXISTS profile_completion DOUBLE PRECISION DEFAULT 0.5;

-- 为现有记录设置默认值
UPDATE user_features 
SET profile_completion = 0.5 
WHERE profile_completion IS NULL;
```

### 步骤2: 重启应用

1. 完全关闭应用
2. 重新启动
3. 导航到主页面（探索用户卡片）
4. ✅ 错误应该消失了！

## 📋 完整修复（推荐）

如果你想要更准确的 profile_completion 值，运行完整的SQL脚本：

**文件**: `add_profile_completion_to_user_features.sql`

这个脚本会：
- ✅ 创建 `user_features` 表（如果不存在）
- ✅ 添加 `profile_completion` 字段
- ✅ 基于用户profile数据计算准确的完成度
- ✅ 创建索引以提高性能
- ✅ 显示统计和验证结果

## 🔧 已修复的代码

### UserTowerFeatures.swift
添加了容错的自定义解码器：

```swift
// 自定义解码器，为profileCompletion提供默认值
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    // ... 其他字段 ...
    
    // 数值特征（提供默认值）
    profileCompletion = try container.decodeIfPresent(Double.self, forKey: .profileCompletion) ?? 0.5
    // 即使数据库缺少这个字段，也会使用默认值 0.5 (50%)
}
```

**好处：**
- 即使数据库缺少字段也不会崩溃
- 自动提供合理的默认值
- 向后兼容旧数据

## 🔍 如何验证修复

运行以下SQL检查：

```sql
-- 检查 user_features 表结构
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_features'
ORDER BY ordinal_position;

-- 检查数据
SELECT 
    COUNT(*) as total,
    AVG(profile_completion) as avg_completion,
    COUNT(CASE WHEN profile_completion IS NULL THEN 1 END) as null_count
FROM user_features;
```

应该看到：
- ✅ `profile_completion` 列存在
- ✅ 类型为 `double precision`
- ✅ 所有记录都有值（null_count = 0）

## 📊 Profile Completion 计算逻辑

完成度基于以下因素计算：

| 项目 | 权重 |
|------|------|
| 基本信息完整 | 60% |
| 有技能标签 | +10% |
| 有爱好标签 | +10% |
| 有价值观标签 | +10% |
| 有照片 | +10% |

**示例：**
- 最低：30%（profile不完整）
- 中等：50%（基本完整，缺少详细信息）
- 良好：80%（基本完整 + 技能 + 爱好）
- 最高：100%（所有信息都完整）

## 🚀 后续优化建议

### 1. 自动同步 Profile Completion
在用户更新profile时自动更新 `user_features.profile_completion`：

```sql
-- 创建触发器（在profile更新时自动更新user_features）
CREATE OR REPLACE FUNCTION update_user_features_completion()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE user_features
    SET profile_completion = (
        -- 计算逻辑（与上面相同）
        0.6 + ...
    )
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_features_completion
AFTER INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_user_features_completion();
```

### 2. 定期重新计算
建议每周运行一次完整的重新计算脚本，确保数据准确。

## 💡 预防措施

1. **创建user_features时包含所有字段**
   - 确保新用户的 `user_features` 记录包含 `profile_completion`

2. **数据库迁移检查清单**
   - 添加新字段时提供默认值
   - 更新现有记录
   - 添加NOT NULL约束（如果适用）

3. **代码层面的防御**
   - 使用 `decodeIfPresent` 而不是 `decode`
   - 提供合理的默认值
   - 添加日志以追踪缺失字段

## 📝 相关文件

- `UserTowerFeatures.swift` - 用户特征模型
- `SupabaseService.swift` - 数据库服务（getUserFeatures, getAllCandidateFeatures）
- `SimpleTwoTowerEncoder.swift` - 推荐系统编码器
- `add_profile_completion_to_user_features.sql` - SQL修复脚本

## ✅ 完成检查清单

- [ ] 运行SQL添加 `profile_completion` 字段
- [ ] 更新现有记录的值
- [ ] 重启应用测试
- [ ] 检查Xcode控制台无错误
- [ ] 验证主页面正常加载用户卡片
- [ ] (可选) 创建自动同步触发器

完成后，"Missing key: profile_completion" 错误将彻底解决！🎉


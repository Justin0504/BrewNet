# ✅ Two-Tower SQL 部署检查清单

## 🔍 部署前检查

- [x] SQL 脚本语法正确
- [x] 外键引用正确（使用 `user_id` 而不是 `id`）
- [x] DO 块结构正确
- [x] 表结构定义完整
- [x] 索引创建完整
- [x] 函数定义完整
- [x] 触发器定义完整

## 🚀 部署步骤

### Step 1: 访问 Supabase Dashboard

🔗 https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy

### Step 2: 打开 SQL Editor

点击左侧菜单 "SQL Editor" → "New query"

### Step 3: 执行部署脚本

复制粘贴文件内容：
```
BrewNet/BrewNet/deploy_two_tower_complete.sql
```

点击 **"Run"** 按钮

### Step 4: 验证部署

执行验证脚本：
```
BrewNet/BrewNet/verify_two_tower_setup.sql
```

## ✅ 预期输出

```
==================================================
✅ Two-Tower Recommendation System Deployed!
==================================================

📊 Statistics:
   - Profiles: X
   - User Features Synced: X
   - Sync Rate: XX%

✅ Tables created: user_features, user_interactions, recommendation_cache
✅ Functions created: extract_skills, extract_functions, calculate_completion, sync_features
✅ Trigger created: trigger_sync_user_features
✅ Data initialized: Existing profiles synced

🎉 Deployment Complete!
==================================================
```

## ⚠️ 常见错误和修复

### 错误 1: 语法错误 RAISE NOTICE

**错误**: `42601: syntax error at or near "RAISE"`

**原因**: 独立的 RAISE NOTICE 语句不能在 SQL 脚本中直接执行

**修复**: ✅ 已修复 - 所有 RAISE NOTICE 都在 DO 块中

### 错误 2: 外键约束违反

**错误**: `23503: foreign key constraint "user_features_user_id_fkey" violates`

**原因**: 使用了 profiles 表的 `id` 而不是 `user_id`

**修复**: ✅ 已修复 - 修改为 `NEW.user_id` 和 `user_id`

### 错误 3: 表不存在

**错误**: `relation "users" does not exist`

**原因**: 基础表尚未创建

**修复**: 先执行 `create_invitations_and_matches_tables.sql`

## 📊 验证查询

### 检查表是否存在

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_features', 'user_interactions', 'recommendation_cache');
```

### 检查数据同步

```sql
SELECT 
    (SELECT COUNT(*) FROM profiles) as total_profiles,
    (SELECT COUNT(*) FROM user_features) as synced_features,
    ROUND((SELECT COUNT(*)::FLOAT FROM user_features) / 
          NULLIF((SELECT COUNT(*) FROM profiles), 0) * 100, 2) as sync_rate;
```

### 检查触发器

```sql
SELECT * FROM pg_trigger WHERE tgname = 'trigger_sync_user_features';
```

### 检查函数

```sql
SELECT proname 
FROM pg_proc 
WHERE proname IN ('extract_skills_from_development', 
                  'extract_functions_from_direction', 
                  'calculate_profile_completion', 
                  'sync_user_features');
```

## 🎯 部署后测试

### 1. 创建测试用户

在 iOS App 中创建新用户并完成资料

### 2. 检查数据同步

```sql
SELECT * FROM user_features WHERE user_id = '<test_user_id>';
```

### 3. 测试触发器

```sql
-- 更新 profile 触发同步
UPDATE profiles 
SET professional_background = professional_background || '{"updated": true}'::jsonb
WHERE user_id = '<test_user_id>';

-- 验证同步
SELECT updated_at FROM user_features WHERE user_id = '<test_user_id>';
```

### 4. 测试推荐

在 iOS App 中进入 "Matches" 标签，查看日志：

```
🚀 Using Two-Tower recommendation engine
✅ User encoded to embedding vector (64 dimensions)
📊 Top 5 scores: 0.823, 0.789, 0.756, 0.731, 0.698
✅ Two-Tower recommendations loaded: 20 profiles
```

## 📝 修复记录

| 日期 | 问题 | 修复 |
|------|------|------|
| 2024-12-28 | RAISE NOTICE 语法错误 | 合并到 DO 块 |
| 2024-12-28 | 外键约束违反 | 使用 `user_id` 而不是 `id` |

## 🔗 相关文件

- **部署脚本**: `BrewNet/BrewNet/deploy_two_tower_complete.sql`
- **验证脚本**: `BrewNet/BrewNet/verify_two_tower_setup.sql`
- **快速指南**: `BrewNet/QUICK_DEPLOY_TO_SUPABASE.md`
- **完整文档**: `BrewNet/README_TWO_TOWER_DEPLOYMENT.md`
- **总结**: `BrewNet/SQL_VALIDATION_COMPLETE.md`

---

**状态**: ✅ 所有已知问题已修复，可以部署


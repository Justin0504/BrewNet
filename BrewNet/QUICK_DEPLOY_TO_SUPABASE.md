# 🚀 Two-Tower 快速部署指南

## 📍 部署到 Supabase

### 步骤 1: 打开 Supabase Dashboard

🔗 **访问**: https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy

或手动导航：
1. 登录 https://supabase.com/dashboard
2. 选择项目：`jcxvdolcdifdghaibspy`

---

### 步骤 2: 打开 SQL Editor

1. 点击左侧菜单的 **"SQL Editor"**
2. 点击 **"New query"** 创建新查询

---

### 步骤 3: 复制 SQL 脚本

打开文件：
```
BrewNet/BrewNet/deploy_two_tower_complete.sql
```

**全选** (Cmd+A / Ctrl+A) → **复制** (Cmd+C / Ctrl+C)

---

### 步骤 4: 粘贴并执行

1. 在 Supabase SQL Editor 中**粘贴** (Cmd+V / Ctrl+V)
2. 点击右上角的 **"Run"** 按钮

**等待**: 约 5-10 秒

---

### 步骤 5: 查看结果

**预期输出**:
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

---

## ✅ 验证部署

### 方法 1: 在 SQL Editor 中验证

运行验证脚本：
```
BrewNet/BrewNet/verify_two_tower_setup.sql
```

### 方法 2: 在 Table Editor 中检查

1. 点击左侧菜单 **"Table Editor"**
2. 查看表：
   - ✅ `user_features` - 用户特征表
   - ✅ `user_interactions` - 交互记录表  
   - ✅ `recommendation_cache` - 推荐缓存表

### 方法 3: 在 iOS App 中测试

1. 打开 Xcode
2. 运行 `BrewNet` 项目
3. 进入 **"Matches"** 标签页
4. 查看日志输出：

```
🚀 Using Two-Tower recommendation engine
✅ User encoded to embedding vector (64 dimensions)
📊 Top 5 scores: 0.823, 0.789, 0.756, 0.731, 0.698
✅ Two-Tower recommendations loaded: 20 profiles
```

---

## 🔍 故障排除

### 问题 1: 执行失败

**错误**: `relation "users" does not exist`

**解决**: 先确保基础表已创建，参考 `create_invitations_and_matches_tables.sql`

---

### 问题 2: 触发器未工作

**检查**:
```sql
SELECT * FROM pg_trigger WHERE tgname = 'trigger_sync_user_features';
```

**如果为空**，重新运行：
```
BrewNet/BrewNet/sync_user_features_function.sql
```

---

### 问题 3: 数据未同步

**手动触发同步**:
```sql
-- 测试：选择一个用户
UPDATE profiles 
SET updated_at = NOW() 
WHERE id IN (SELECT id FROM profiles LIMIT 1);

-- 检查是否同步成功
SELECT * FROM user_features LIMIT 1;
```

**批量同步所有用户**:
```sql
UPDATE profiles SET updated_at = NOW();
SELECT COUNT(*) FROM user_features;
```

---

## 📊 监控

### 关键表数据量

```sql
SELECT 
    (SELECT COUNT(*) FROM profiles) as total_profiles,
    (SELECT COUNT(*) FROM user_features) as synced_features,
    (SELECT COUNT(*) FROM user_interactions) as total_interactions,
    (SELECT COUNT(*) FROM recommendation_cache) as cached_recommendations;
```

### 同步状态

```sql
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'No profiles yet'
        WHEN (SELECT COUNT(*) FROM user_features)::FLOAT / COUNT(*)::FLOAT >= 0.95 
        THEN '✅ Well synced'
        ELSE '⚠️ Needs sync'
    END as sync_status
FROM profiles;
```

---

## 🎯 下一步

部署成功后：

1. ✅ 验证 iOS App 中的推荐功能
2. ✅ 测试 Like/Pass/Match 交互
3. ✅ 检查缓存命中率
4. ⏳ 准备 Phase 2：集成测试

---

**部署链接**: https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy/editor

**有问题？** 查看 `README_TWO_TOWER_DEPLOYMENT.md` 了解更多细节


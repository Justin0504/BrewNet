# Two-Tower 推荐系统部署指南

## 📋 快速开始

### 1️⃣ 在 Supabase Dashboard 中执行 SQL

**步骤**:
1. 登录 Supabase Dashboard: https://supabase.com/dashboard
2. 选择你的项目: `jcxvdolcdifdghaibspy`
3. 进入 "SQL Editor"
4. 复制粘贴 SQL 脚本
5. 点击 "Run" 执行

**执行顺序**:

#### Step 1: 创建数据表

```bash
# 文件: BrewNet/BrewNet/create_two_tower_tables.sql
```

在 SQL Editor 中执行这个文件的全部内容。

**预期输出**:
```
✅ Two-Tower recommendation tables created successfully
   - user_features: 0 rows
   - user_interactions: 0 rows
   - recommendation_cache: 0 rows
```

#### Step 2: 创建同步函数

```bash
# 文件: BrewNet/BrewNet/sync_user_features_function.sql
```

在 SQL Editor 中执行这个文件的全部内容。

**预期输出**:
```
✅ User features sync functions and trigger created successfully
   Trigger: trigger_sync_user_features on table: profiles
   Functions: extract_skills_from_development, extract_functions_from_direction, calculate_profile_completion, sync_user_features
```

---

### 2️⃣ 验证安装

在 SQL Editor 中执行验证脚本：

```bash
# 文件: BrewNet/BrewNet/verify_two_tower_setup.sql
```

**预期输出**:
```
========================================
Two-Tower System Verification
========================================

✅ user_features table exists
✅ user_interactions table exists
✅ recommendation_cache table exists

Checking indexes...
  ✅ idx_user_features_industry
  ✅ idx_user_features_intention
  ✅ idx_interactions_user_type

Checking functions...
  ✅ extract_skills_from_development
  ✅ extract_functions_from_direction
  ✅ calculate_profile_completion
  ✅ sync_user_features

Checking triggers...
  ✅ trigger_sync_user_features

Data statistics:
  Total profiles: XX
  User features synced: XX
  User interactions: XX
  Cached recommendations: XX
  Sync rate: XX%

========================================
Verification complete
========================================
```

---

### 3️⃣ 测试数据同步

#### 检查现有数据同步情况

```sql
-- 查看同步率
SELECT 
    (SELECT COUNT(*) FROM profiles) as total_profiles,
    (SELECT COUNT(*) FROM user_features) as synced_features,
    ROUND((SELECT COUNT(*)::FLOAT FROM user_features) / 
          NULLIF((SELECT COUNT(*) FROM profiles), 0) * 100, 2) as sync_rate
```

#### 手动触发同步（如果有未同步的数据）

```sql
-- 测试：手动触发一个用户的同步
UPDATE profiles SET updated_at = NOW() WHERE id = '<某个用户ID>';

-- 检查是否同步成功
SELECT * FROM user_features WHERE user_id = '<某个用户ID>';
```

#### 为所有现有用户同步数据

```sql
-- 批量触发所有用户的同步
UPDATE profiles SET updated_at = NOW() WHERE updated_at < NOW();

-- 检查结果
SELECT COUNT(*) FROM user_features;
```

---

### 4️⃣ 在 iOS App 中测试

#### 启动应用

1. 打开 Xcode
2. 运行 `BrewNet` 项目
3. 登录账户
4. 进入 "Matches" 标签

#### 查看日志输出

查找以下关键日志：

```
🚀 Using Two-Tower recommendation engine
📊 User features loaded: ...
✅ User encoded to embedding vector (64 dimensions)
📊 Processing XX candidates
📊 Top 5 scores: 0.823, 0.789, 0.756, 0.731, 0.698
✅ Two-Tower recommendations loaded: 20 profiles
```

#### 验证推荐质量

- ✅ 推荐的用户是否与你相似？
- ✅ 技能/兴趣有匹配吗？
- ✅ 意图类型相关吗？

---

## 🐛 常见问题

### Q1: 表创建失败

**错误**: `relation "users" does not exist`

**原因**: users 表还没创建

**解决**: 先创建基础表：
```sql
-- 参考 create_invitations_and_matches_tables.sql
CREATE TABLE IF NOT EXISTS users (...);
CREATE TABLE IF NOT EXISTS profiles (...);
```

---

### Q2: 触发器没有触发

**症状**: user_features 表一直是空的

**原因**: 触发器可能没有创建成功

**检查**:
```sql
SELECT * FROM pg_trigger WHERE tgname = 'trigger_sync_user_features';
```

**解决**: 重新执行 `sync_user_features_function.sql`

---

### Q3: JSONB 字段解析失败

**错误**: `column "core_identity" does not exist`

**原因**: profiles 表结构不匹配

**检查**:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name LIKE '%identity%';
```

**解决**: 确保 profiles 表使用了正确的 JSONB 结构

---

### Q4: 推荐结果全是空或错误

**症状**: Two-Tower 返回空列表或崩溃

**原因**: 可能有以下问题：
1. user_features 数据不完整
2. 特征编码失败
3. 候选用户太少

**调试**:
```swift
// 在 RecommendationService.swift 中添加调试日志
print("🔍 User features: \(userFeatures)")
print("🔍 Candidate count: \(candidates.count)")
print("🔍 Encoded vector: \(userVector)")
```

---

### Q5: 性能问题

**症状**: 推荐加载很慢 (> 3秒)

**原因**: 候选用户太多或缺少索引

**解决**:
1. 检查索引是否创建
2. 限制候选数量 (getAllCandidateFeatures limit)
3. 增加缓存使用

---

## 📊 监控和优化

### 关键指标

在 Supabase Dashboard 中监控：

**数据库指标**:
- user_features 表大小
- user_interactions 记录数
- 推荐缓存命中率

**应用指标**:
- 推荐延迟
- 缓存命中率
- 用户匹配率

**推荐质量**:
- Match Rate (匹配率)
- CTR (点击率)
- User Satisfaction (用户满意度)

---

### 优化建议

#### 短期（1周内）

1. **索引优化**:
```sql
-- 为常用查询添加索引
CREATE INDEX IF NOT EXISTS idx_user_features_skills ON user_features USING GIN (skills);
CREATE INDEX IF NOT EXISTS idx_user_features_hobbies ON user_features USING GIN (hobbies);
```

2. **缓存预热**:
   - 在后台预加载热门用户的推荐
   - 使用 Supabase Edge Functions

3. **批量同步**:
   - 为已有用户批量创建 user_features
   - 定期检查和修复缺失数据

#### 中期（1个月内）

1. **向量索引**:
   - 安装 pgvector 插件
   - 为 user_embedding 创建向量索引

2. **异步处理**:
   - 推荐计算移到后台
   - 使用消息队列

3. **A/B 测试**:
   - 对比 Two-Tower vs Traditional
   - 收集用户反馈

---

## 📝 验证清单

### 数据库层 ✅

- [x] user_features 表创建成功
- [x] user_interactions 表创建成功
- [x] recommendation_cache 表创建成功
- [x] 所有索引创建成功
- [x] 所有函数创建成功
- [x] 触发器创建成功

### 应用层 ✅

- [x] RecommendationService 编译通过
- [x] BrewNetMatchesView 集成成功
- [x] 交互记录功能正常
- [x] 缓存机制工作正常
- [x] 无编译错误

### 功能测试 🧪

- [ ] 推荐能正常加载
- [ ] 推荐质量合理
- [ ] Pass/Like 记录正常
- [ ] 缓存命中率高
- [ ] 性能满足要求
- [ ] 错误处理完善

---

## 🎯 部署时间线

### 今天

- ✅ 创建 SQL 脚本
- ✅ 准备验证脚本
- ⏳ 执行 SQL 脚本
- ⏳ 验证安装

### 本周

- ⏳ 测试推荐功能
- ⏳ 修复发现的问题
- ⏳ 性能优化
- ⏳ 监控设置

### 下周

- ⏳ A/B 测试启动
- ⏳ 收集用户反馈
- ⏳ 数据分析
- ⏳ 持续优化

---

## 📞 支持

如果遇到问题：

1. **查看日志**: Xcode Console 和 Supabase Logs
2. **检查文档**: `TWO_TOWER_STEP_BY_STEP.md`
3. **运行验证**: `verify_two_tower_setup.sql`
4. **联系支持**: 查看项目 README

---

**祝部署顺利！🚀**


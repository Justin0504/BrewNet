# 信誉评分系统数据库设置指南

## 📋 快速开始

### 步骤 1: 打开 Supabase SQL Editor

1. 登录 [Supabase Dashboard](https://app.supabase.com)
2. 选择你的项目
3. 点击左侧菜单的 **SQL Editor**
4. 点击 **New query**

### 步骤 2: 执行 SQL 脚本

1. 打开文件 `create_credibility_system_tables.sql`
2. 复制全部内容
3. 粘贴到 Supabase SQL Editor
4. 点击 **Run** 按钮执行

### 步骤 3: 验证表创建

执行以下查询验证：

```sql
-- 查看所有新表
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('credibility_scores', 'meeting_ratings', 'misconduct_reports')
ORDER BY table_name;

-- 查看表结构
\d credibility_scores
\d meeting_ratings
\d misconduct_reports

-- 验证数据
SELECT 
    'credibility_scores' as table_name,
    COUNT(*) as row_count
FROM credibility_scores
UNION ALL
SELECT 
    'meeting_ratings',
    COUNT(*)
FROM meeting_ratings
UNION ALL
SELECT 
    'misconduct_reports',
    COUNT(*)
FROM misconduct_reports;
```

## 📊 创建的表结构

### 1. credibility_scores（信誉评分表）

| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | UUID | 用户ID（主键） |
| overall_score | DECIMAL(2,1) | 最终评分（0-5） |
| average_rating | DECIMAL(2,1) | 平均星级评分（0-5） |
| fulfillment_rate | DECIMAL(5,2) | 履约率（0-100%） |
| total_meetings | INT | 总见面次数 |
| total_no_shows | INT | 放鸽子次数 |
| last_meeting_date | TIMESTAMP | 最后见面日期 |
| tier | VARCHAR(50) | 信誉等级 |
| is_frozen | BOOLEAN | 是否冻结 |
| freeze_end_date | TIMESTAMP | 冻结结束日期 |
| is_banned | BOOLEAN | 是否封禁 |
| ban_reason | TEXT | 封禁原因 |
| gps_anomaly_count | INT | GPS异常次数 |
| mutual_high_rating_count | INT | 互刷分次数 |
| last_decay_date | TIMESTAMP | 最后衰减日期 |

### 2. meeting_ratings（评分记录表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 评分ID（主键） |
| meeting_id | UUID | 见面ID |
| rater_id | UUID | 评分者ID |
| rated_user_id | UUID | 被评分者ID |
| rating | DECIMAL(2,1) | 评分（0.5-5.0） |
| tags | JSONB | 评分标签 |
| timestamp | TIMESTAMP | 评分时间 |
| gps_verified | BOOLEAN | GPS验证 |
| meeting_duration | INT | 见面时长（秒） |

### 3. misconduct_reports（举报记录表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 举报ID（主键） |
| reporter_id | UUID | 举报者ID |
| reported_user_id | UUID | 被举报者ID |
| meeting_id | UUID | 相关见面ID |
| misconduct_type | VARCHAR(100) | 不当行为类型 |
| description | TEXT | 描述 |
| location | TEXT | 位置 |
| evidence | JSONB | 证据 |
| needs_follow_up | BOOLEAN | 需要跟进 |
| status | VARCHAR(50) | 状态 |
| review_notes | TEXT | 审核备注 |
| reviewed_at | TIMESTAMP | 审核时间 |
| reviewed_by | UUID | 审核者 |

### 4. coffee_chat_schedules（扩展字段）

新增字段：
- `user_rated` BOOLEAN - 用户是否已评分
- `participant_rated` BOOLEAN - 参与者是否已评分
- `user_rating_id` UUID - 用户评分记录ID
- `participant_rating_id` UUID - 参与者评分记录ID
- `met_at` TIMESTAMP - 见面确认时间

## 🔧 自动功能

### 1. 新用户自动创建信誉评分

当新用户注册时，自动创建信誉评分记录（默认3.0分）

```sql
-- 触发器已自动设置
-- 无需手动操作
```

### 2. 评分提交后自动更新

当用户提交评分后，被评分者的信誉评分自动重新计算

```sql
-- 示例：提交评分
INSERT INTO meeting_ratings (meeting_id, rater_id, rated_user_id, rating, tags, gps_verified)
VALUES (
    'meeting-uuid',
    'rater-uuid',
    'rated-user-uuid',
    4.5,
    '["Professional and helpful", "On time"]'::jsonb,
    true
);

-- 自动触发 calculate_credibility_score() 函数
-- rated-user-uuid 的信誉评分会自动更新
```

### 3. 信誉等级自动划分

| 评分范围 | 等级 | 权益 |
|---------|------|------|
| 4.6-5.0 | Highly Trusted | 匹配+60%, PRO 7折 |
| 4.1-4.5 | Well Trusted | 匹配+30%, PRO 8折 |
| 3.6-4.0 | Trusted | 匹配+10%, PRO 9折 |
| 2.6-3.5 | Normal | 无特殊权益 |
| 2.1-2.5 | Needs Improvement | - |
| 1.6-2.0 | Alert | 匹配-30%, 每日3次右划 |
| 1.1-1.5 | Low Trust | 匹配-60%, 每日1次右划 |
| 0.6-1.0 | Critical | 冻结72小时 |
| 0-0.5 | Banned | 永久封禁 |

## 🔐 安全策略（RLS）

所有表都启用了 Row Level Security：

- ✅ **credibility_scores**：所有人可查看评分，只有本人可修改
- ✅ **meeting_ratings**：只能查看与自己相关的评分，评分后不可修改
- ✅ **misconduct_reports**：只能查看自己的举报，不能修改

## 📝 常用查询

### 查询用户信誉评分

```sql
SELECT * FROM credibility_scores 
WHERE user_id = 'user-uuid';
```

### 查询待评分的见面

```sql
SELECT * FROM coffee_chat_schedules
WHERE user_id = 'user-uuid'
  AND has_met = TRUE
  AND user_rated = FALSE
  AND met_at > NOW() - INTERVAL '48 hours'
ORDER BY met_at DESC;
```

### 查询用户的评分历史

```sql
SELECT 
    mr.*,
    u.email as rated_user_email
FROM meeting_ratings mr
JOIN auth.users u ON mr.rated_user_id = u.id
WHERE mr.rater_id = 'user-uuid'
ORDER BY mr.timestamp DESC;
```

### 查询高信誉用户

```sql
SELECT 
    u.id,
    u.email,
    cs.overall_score,
    cs.tier,
    cs.total_meetings
FROM auth.users u
JOIN credibility_scores cs ON u.id = cs.user_id
WHERE cs.tier IN ('Highly Trusted', 'Well Trusted')
ORDER BY cs.overall_score DESC
LIMIT 20;
```

### 手动重新计算信誉评分

```sql
-- 为单个用户重新计算
SELECT calculate_credibility_score('user-uuid');

-- 为所有用户重新计算
DO $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN SELECT user_id FROM credibility_scores
    LOOP
        PERFORM calculate_credibility_score(user_record.user_id);
    END LOOP;
END $$;
```

## 🚨 故障排除

### 问题1：表已存在错误

如果遇到"table already exists"错误：

```sql
-- 删除旧表（谨慎操作！会丢失数据）
DROP TABLE IF EXISTS misconduct_reports CASCADE;
DROP TABLE IF EXISTS meeting_ratings CASCADE;
DROP TABLE IF EXISTS credibility_scores CASCADE;

-- 然后重新运行创建脚本
```

### 问题2：RLS策略冲突

如果遇到策略冲突：

```sql
-- 删除所有现有策略
DROP POLICY IF EXISTS "任何人可以查看信誉评分" ON credibility_scores;
DROP POLICY IF EXISTS "用户可以查看自己的信誉评分详情" ON credibility_scores;
-- ... 删除其他策略

-- 然后重新运行创建脚本
```

### 问题3：触发器已存在

```sql
-- 删除现有触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;
DROP TRIGGER IF EXISTS after_rating_insert ON meeting_ratings;

-- 然后重新运行创建脚本
```

## ✅ 验证清单

执行完脚本后，请验证：

- [ ] 3个新表已创建：`credibility_scores`, `meeting_ratings`, `misconduct_reports`
- [ ] `coffee_chat_schedules` 表已添加新字段
- [ ] 所有索引已创建
- [ ] RLS 策略已启用
- [ ] 触发器已创建
- [ ] 函数 `calculate_credibility_score` 可用
- [ ] 现有用户已有信誉评分记录（默认3.0分）

## 🎯 下一步

数据库表创建完成后：

1. ✅ 前端已集成评分UI（MeetingRatingView）
2. ✅ 前端已集成评分触发逻辑（CoffeeChatScheduleView）
3. ⏳ **需要创建后端 API 端点**（见下方）

### 需要的 API 端点

```typescript
// 1. 提交评分
POST /api/meetings/{meetingId}/rate
Body: {
  rating: 4.5,
  tags: ["Professional and helpful", "On time"],
  gpsVerified: true,
  meetingDuration: 3600
}

// 2. 获取用户信誉评分
GET /api/users/{userId}/credibility

// 3. 获取待评分列表
GET /api/meetings/pending-ratings

// 4. 提交举报
POST /api/reports/misconduct
Body: {
  reportedUserId: "uuid",
  meetingId: "uuid",
  misconductType: "Violence, threats, or intimidation",
  description: "...",
  location: "...",
  needsFollowUp: true
}
```

## 📚 相关文档

- `CREDIBILITY_SYSTEM_IMPLEMENTATION.md` - 完整系统说明
- `CREDIBILITY_RATING_INTEGRATION.md` - 前端集成指南
- `MeetingRatingView.swift` - 评分UI界面
- `CredibilitySystem.swift` - 数据模型定义

## 💡 提示

- 评分计算公式：**最终评分 = 70% × 星级评分 + 30% × 履约率得分**
- 评分范围：0.5-5.0，最小单位0.5
- 评分窗口：见面确认后48小时内有效
- 防刷分：同一见面只能评分一次
- 隐私保护：评分互不可见，防止报复性评分

祝你使用顺利！🎉


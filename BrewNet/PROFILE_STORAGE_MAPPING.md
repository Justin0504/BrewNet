# Profile 数据存储映射表

## 📋 概述

本文档说明 Profile Setup 中所有填写内容对应的数据库存储位置。

## ✅ 验证结果

**所有 Profile 填写内容都有对应的存储表！**

---

## 🗂️ 数据存储架构

### 主要存储方式：JSONB 字段

所有 Profile 数据存储在 `profiles` 表的 6 个 JSONB 字段中：

| Profile 部分 | 数据库字段 | 字段类型 | 状态 |
|-------------|-----------|---------|------|
| Core Identity | `core_identity` | JSONB | ✅ |
| Professional Background | `professional_background` | JSONB | ✅ |
| Networking Intention | `networking_intention` | JSONB | ✅ |
| Networking Preferences | `networking_preferences` | JSONB | ✅ |
| Personality & Social | `personality_social` | JSONB | ✅ |
| Privacy & Trust | `privacy_trust` | JSONB | ✅ |

---

## 📊 详细字段映射

### 1. Core Identity (核心身份信息)

**存储位置：** `profiles.core_identity` (JSONB)

| 字段名 | JSON 键名 | 数据类型 | 示例值 |
|--------|----------|---------|--------|
| 姓名 | `name` | String | "John Doe" |
| 邮箱 | `email` | String | "john@example.com" |
| 手机号 | `phone_number` | String? | "+1234567890" |
| 头像 | `profile_image` | String? | "https://..." |
| 简介 | `bio` | String? | "Software engineer..." |
| 代词 | `pronouns` | String? | "he/him" |
| 位置 | `location` | String? | "San Francisco, CA" |
| 个人网站 | `personal_website` | String? | "https://..." |
| GitHub | `github_url` | String? | "https://github.com/..." |
| LinkedIn | `linkedin_url` | String? | "https://linkedin.com/..." |
| 时区 | `time_zone` | String | "America/Los_Angeles" |
| 可用时间段 | `available_timeslot` | Object | `{sunday: {...}, ...}` |

**AvailableTimeslot 结构：**
```json
{
  "sunday": {
    "morning": true,
    "noon": false,
    "afternoon": true,
    "evening": false,
    "night": false
  },
  "monday": {...},
  ...
}
```

---

### 2. Professional Background (职业背景)

**存储位置：** `profiles.professional_background` (JSONB)

| 字段名 | JSON 键名 | 数据类型 | 存储位置 |
|--------|----------|---------|---------|
| 当前公司 | `current_company` | String? | JSONB |
| 职位 | `job_title` | String? | JSONB |
| 行业 | `industry` | String? | JSONB |
| 经验等级 | `experience_level` | Enum | JSONB |
| 教育背景 | `education` | String? | JSONB |
| 工作年限 | `years_of_experience` | Double? | JSONB |
| 职业阶段 | `career_stage` | Enum | JSONB |
| 技能 | `skills` | [String] | JSONB |
| 证书 | `certifications` | [String] | JSONB |
| 语言 | `languages_spoken` | [String] | JSONB |
| 工作经历 | `work_experiences` | [Object] | JSONB + 可选表 |

**工作经历 (WorkExperience) 结构：**
```json
{
  "id": "uuid",
  "company_name": "Google",
  "position": "Software Engineer",
  "start_year": 2020,
  "end_year": 2022,
  "position": "Senior Developer"
}
```

**可选存储：** `work_experiences` 表（用于优化查询）

---

### 3. Networking Intention (网络意图)

**存储位置：** `profiles.networking_intention` (JSONB)

| 字段名 | JSON 键名 | 数据类型 | 存储位置 |
|--------|----------|---------|---------|
| 主要意图 | `selected_intention` | Enum | JSONB |
| 子意图 | `selected_sub_intentions` | [Enum] | JSONB |
| 职业方向 | `career_direction` | Object? | JSONB |
| 技能发展 | `skill_development` | Object? | JSONB |
| 行业转换 | `industry_transition` | Object? | JSONB |

**CareerDirectionData 结构：**
```json
{
  "functions": [
    {
      "function_name": "Product Management",
      "learn_in": ["Mentorship", "Courses"],
      "guide_in": ["Industry Insights"]
    }
  ]
}
```

---

### 4. Networking Preferences (网络偏好)

**存储位置：** `profiles.networking_preferences` (JSONB)

| 字段名 | JSON 键名 | 数据类型 | 存储位置 |
|--------|----------|---------|---------|
| 偏好聊天格式 | `preferred_chat_format` | Enum | JSONB |
| 可用时间段 | `available_timeslot` | Object | JSONB |
| 偏好聊天时长 | `preferred_chat_duration` | String? | JSONB |

---

### 5. Personality & Social (个性社交)

**存储位置：** `profiles.personality_social` (JSONB)

| 字段名 | JSON 键名 | 数据类型 | 存储位置 |
|--------|----------|---------|---------|
| 破冰提示 | `icebreaker_prompts` | [Object] | JSONB |
| 价值观标签 | `values_tags` | [String] | JSONB |
| 兴趣爱好 | `hobbies` | [String] | JSONB |
| 偏好会议氛围 | `preferred_meeting_vibe` | Enum | JSONB |
| 自我介绍 | `self_introduction` | String? | JSONB |

**IcebreakerPrompt 结构：**
```json
{
  "prompt": "What's your favorite coffee?",
  "answer": "I love espresso!"
}
```

---

### 6. Privacy & Trust (隐私信任)

**存储位置：** `profiles.privacy_trust` (JSONB)

| 字段名 | JSON 键名 | 数据类型 | 存储位置 |
|--------|----------|---------|---------|
| 可见性设置 | `visibility_settings` | Object | JSONB |
| 验证状态 | `verified_status` | Enum | JSONB |
| 数据共享同意 | `data_sharing_consent` | Bool | JSONB |
| 举报偏好 | `report_preferences` | Object | JSONB |

**VisibilitySettings 结构：**
```json
{
  "company": "public",
  "email": "private",
  "phone_number": "private",
  "location": "public",
  "skills": "public",
  "interests": "public",
  "timeslot": "connections_only"
}
```

---

## 🗄️ 可选优化表

为了优化特定查询场景，以下表是可选的：

### work_experiences 表

**用途：** 优化工作经历查询（如搜索在特定公司工作过的用户）

**字段：**
- `id`: UUID
- `user_id`: UUID (外键 → users.id)
- `profile_id`: UUID (外键 → profiles.id)
- `company_name`: TEXT
- `position`: TEXT
- `start_year`: INTEGER
- `end_year`: INTEGER (NULL = 当前工作)

**状态：** ✅ 已创建（可选使用）

---

### education_backgrounds 表

**用途：** 优化教育背景查询（如搜索特定学校的用户）

**字段：**
- `id`: UUID
- `user_id`: UUID (外键 → users.id)
- `profile_id`: UUID (外键 → profiles.id)
- `school_name`: TEXT
- `degree_type`: TEXT
- `field_of_study`: TEXT
- `start_year`: INTEGER
- `end_year`: INTEGER (NULL = 在读)

**状态：** ✅ 已创建（可选使用）

---

## 📈 索引优化

### JSONB GIN 索引

已为常用查询创建 GIN 索引：

```sql
-- 全字段索引
CREATE INDEX idx_profiles_core_identity_gin ON profiles USING GIN (core_identity);
CREATE INDEX idx_profiles_professional_background_gin ON profiles USING GIN (professional_background);

-- 特定路径索引
CREATE INDEX idx_profiles_skills ON profiles USING GIN ((professional_background->'skills'));
CREATE INDEX idx_profiles_current_company ON profiles ((professional_background->>'current_company'));
CREATE INDEX idx_profiles_location ON profiles ((core_identity->>'location'));
```

---

## ✅ 完整性验证

运行 `complete_profile_tables.sql` 将：

1. ✅ 检查所有必需字段是否存在
2. ✅ 创建缺失的字段
3. ✅ 创建可选优化表
4. ✅ 创建 JSONB 索引
5. ✅ 验证最终配置

---

## 📝 总结

### 所有数据都有存储位置：

✅ **Core Identity** → `profiles.core_identity` (JSONB)
✅ **Professional Background** → `profiles.professional_background` (JSONB)
  - 可选：`work_experiences` 表（优化查询）
✅ **Networking Intention** → `profiles.networking_intention` (JSONB)
✅ **Networking Preferences** → `profiles.networking_preferences` (JSONB)
✅ **Personality & Social** → `profiles.personality_social` (JSONB)
✅ **Privacy & Trust** → `profiles.privacy_trust` (JSONB)

### 存储架构优势：

1. **灵活性**：JSONB 支持复杂嵌套结构
2. **性能**：GIN 索引支持高效 JSONB 查询
3. **完整性**：所有字段都在数据库中
4. **可扩展性**：可选表用于特定优化场景

---

## 🚀 下一步

1. 运行 `complete_profile_tables.sql` 确保所有配置完整
2. 运行 `verify_supabase_config.sql` 验证配置
3. 开始使用 Profile Setup 功能

**结论：所有 Profile 填写内容都有对应的存储表！**


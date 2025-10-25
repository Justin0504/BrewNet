# BrewNet Supabase 数据库配置指南

## 📋 概述

本指南将帮助您配置 Supabase 数据库以支持 BrewNet 应用的完整 Profile 系统。

## 🚀 快速开始

### 方法 1: 使用快速设置脚本（推荐）

1. **登录 Supabase Dashboard**
   - 访问: https://supabase.com/dashboard
   - 选择您的项目: `jcxvdolcdifdghaibspy`

2. **打开 SQL Editor**
   - 在左侧菜单中点击 "SQL Editor"
   - 点击 "New query"

3. **执行快速设置脚本**
   - 复制 `quick_profiles_setup.sql` 文件中的所有内容
   - 粘贴到 SQL Editor 中
   - 点击 "Run" 执行

### 方法 2: 使用完整配置脚本

如果您需要完整的数据库配置（包括所有表、索引、RLS 策略等），请使用 `supabase_setup.sql` 文件。

## 📊 数据库结构

### 核心表

#### 1. `users` 表
存储用户基础信息：
- `id`: 用户唯一标识符 (UUID)
- `email`: 邮箱地址
- `name`: 用户姓名
- `profile_setup_completed`: 是否完成资料设置
- 其他基础字段...

#### 2. `profiles` 表
存储用户详细资料（JSONB 格式）：
- `core_identity`: 核心身份信息
- `professional_background`: 职业背景
- `networking_intent`: 网络意图
- `personality_social`: 个性社交信息
- `privacy_trust`: 隐私信任设置

### JSONB 数据结构

#### Core Identity 结构
```json
{
  "firstName": "string",
  "lastName": "string",
  "email": "string",
  "phoneNumber": "string",
  "location": "string",
  "profileImage": "string"
}
```

#### Professional Background 结构
```json
{
  "company": "string",
  "jobTitle": "string",
  "industry": "string",
  "experienceLevel": "string",
  "skills": ["string"],
  "education": "string",
  "linkedinUrl": "string"
}
```

#### Networking Intent 结构
```json
{
  "primaryGoal": "string",
  "openToCoffeeChats": true,
  "availableTimeslots": {
    "monday": [{"start": "09:00", "end": "17:00"}],
    "tuesday": [{"start": "09:00", "end": "17:00"}]
  },
  "preferredMeetingTypes": ["string"],
  "targetAudience": "string"
}
```

#### Personality Social 结构
```json
{
  "interests": ["string"],
  "hobbies": ["string"],
  "icebreakerPrompts": ["string"],
  "communicationStyle": "string",
  "personalityTraits": ["string"]
}
```

#### Privacy Trust 结构
```json
{
  "visibilitySettings": {
    "company": "public",
    "email": "private",
    "phoneNumber": "private",
    "location": "public",
    "skills": "public",
    "interests": "public"
  },
  "verifiedStatus": "unverified",
  "dataSharingConsent": true,
  "reportPreferences": {
    "allowReports": true,
    "reportCategories": ["string"]
  }
}
```

## 🔐 安全配置

### 行级安全策略 (RLS)
- 用户只能查看和修改自己的 profile
- 其他用户的数据受到保护
- 支持匿名访问公共信息

### 索引优化
- `user_id` 索引：快速查找用户资料
- `created_at` 索引：按时间排序
- JSONB 字段支持高效查询

## 🛠️ 使用说明

### 1. 创建用户资料
```sql
INSERT INTO profiles (user_id, core_identity, professional_background, networking_intent, personality_social, privacy_trust)
VALUES (
  'user-uuid-here',
  '{"firstName": "John", "lastName": "Doe", ...}',
  '{"company": "Tech Corp", "jobTitle": "Developer", ...}',
  '{"primaryGoal": "Networking", "openToCoffeeChats": true, ...}',
  '{"interests": ["Technology", "Coffee"], ...}',
  '{"visibilitySettings": {...}, ...}'
);
```

### 2. 查询用户资料
```sql
SELECT * FROM profiles WHERE user_id = 'user-uuid-here';
```

### 3. 更新用户资料
```sql
UPDATE profiles 
SET core_identity = '{"firstName": "Updated Name", ...}',
    updated_at = NOW()
WHERE user_id = 'user-uuid-here';
```

## 🔍 故障排除

### 常见问题

1. **"Could not find the table 'public.profiles'"**
   - 确保已执行 `quick_profiles_setup.sql`
   - 检查表是否在正确的 schema 中

2. **权限错误**
   - 确保 RLS 策略已正确设置
   - 检查用户认证状态

3. **JSONB 查询问题**
   - 使用正确的 JSONB 操作符
   - 检查 JSON 格式是否正确

### 验证配置

运行以下查询验证配置是否正确：

```sql
-- 检查表是否存在
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name = 'profiles';

-- 检查 RLS 是否启用
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'profiles';

-- 检查索引
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'profiles';
```

## 📱 应用集成

配置完成后，您的 BrewNet 应用将能够：

1. ✅ 创建用户资料
2. ✅ 读取用户资料
3. ✅ 更新用户资料
4. ✅ 删除用户资料
5. ✅ 搜索和推荐用户
6. ✅ 隐私控制
7. ✅ 数据验证

## 🎯 下一步

1. 执行 SQL 配置脚本
2. 测试应用中的 Profile 功能
3. 根据需要调整隐私设置
4. 配置 AI 推荐系统（可选）

---

**需要帮助？** 如果您遇到任何问题，请检查：
- Supabase 项目连接状态
- SQL 脚本执行日志
- 应用中的错误信息

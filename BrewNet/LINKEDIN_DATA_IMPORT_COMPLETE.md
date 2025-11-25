# LinkedIn 数据导入功能 - 完整实现指南

## 🎉 实现完成

LinkedIn 数据导入功能已完全实现，包括数据库表结构、后端 API、前端界面和完整的数据流程。

## 📋 功能概览

### ✅ 已实现的功能

1. **数据库表结构**
   - `linkedin_profiles` 表：存储 LinkedIn 抓取的数据 + 状态 + consent 日志
   - `linkedin_import_audit` 表：审计日志，记录导入操作历史

2. **后端实现**
   - Supabase Edge Function (`linkedin-import`)：处理数据导入和清洗
   - 数据清洗和增强逻辑（标签提取、角色识别）
   - 完整的错误处理和日志记录

3. **前端实现**
   - AuthManager 更新：添加 LinkedIn 数据导入功能
   - ProfileSetupView 更新：在 Core Identity 步骤添加导入按钮
   - LinkedInPreviewView：数据预览和确认界面
   - 完整的用户体验流程

## 🚀 部署步骤

### 1. 数据库表创建

在 Supabase Dashboard 中运行 SQL：

```sql
-- 执行 create_linkedin_profiles_tables.sql 中的内容
```

或者直接在 Supabase SQL Editor 中执行：

```sql
-- linkedin_profiles 表：存储 LinkedIn 抓取的数据 + 状态 + consent 日志
CREATE TABLE IF NOT EXISTS linkedin_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  linkedin_id text UNIQUE,                -- LinkedIn member id (sub)
  vanity_name text,                       -- slug from linkedin URL
  headline text,
  raw_profile jsonb,                      -- raw JSON from /me
  email text,
  avatar_url text,
  import_status text DEFAULT 'pending',   -- pending / confirmed / failed / deleted
  consent_log jsonb,                      -- e.g. {consent_ts, ip, ua}
  last_fetched_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- linkedin_import_audit 表：可选的审计日志，记录导入操作历史
CREATE TABLE IF NOT EXISTS linkedin_import_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  linkedin_profile_id uuid,
  action text,            -- requested, fetched, user_confirmed, deleted
  detail jsonb,
  created_at timestamptz DEFAULT now()
);

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_linkedin_profiles_user_id ON linkedin_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_linkedin_profiles_linkedin_id ON linkedin_profiles(linkedin_id);
CREATE INDEX IF NOT EXISTS idx_linkedin_profiles_import_status ON linkedin_profiles(import_status);

-- RLS 策略
ALTER TABLE linkedin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE linkedin_import_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own linkedin profiles" ON linkedin_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own linkedin profiles" ON linkedin_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own linkedin profiles" ON linkedin_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "System can insert import audit" ON linkedin_import_audit
  FOR INSERT WITH CHECK (true);
```

### 2. 部署 Edge Functions

运行部署脚本：

```bash
./deploy-linkedin-functions.sh
```

此脚本将部署所有三个 LinkedIn 相关的函数：
- `linkedin-callback`
- `linkedin-exchange`
- `linkedin-import` (新增)

### 3. 设置环境变量

确保在 Supabase 中设置了以下环境变量：

```bash
supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv
supabase secrets set LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

## 🔄 完整数据流程

### 用户操作流程

1. **用户进入 Profile Setup** → 选择 "Core Identity" 步骤

2. **用户看到 LinkedIn 导入选项**：
   - 显示 consent 复选框（必须勾选）
   - 显示 "Sign in with LinkedIn" 按钮
   - 可选：手动输入 LinkedIn URL 进行额外抓取

3. **用户点击导入**：
   - 前端调用 `LinkedInAuthManager.startLinkedInLogin()`
   - 启动 LinkedIn OAuth 流程

4. **OAuth 流程**：
   - 用户在浏览器中登录 LinkedIn 并授权
   - LinkedIn 重定向回 App，返回 authorization code
   - 前端接收 code，通过 `handleLinkedInImport(code)` 发送给 `linkedin-import` 函数

5. **后端处理**：
   - `linkedin-import` 函数接收 code 和 user_id
   - 交换 code → access_token
   - 调用 LinkedIn API 获取用户资料
   - 清洗和处理数据
   - 存储到 `linkedin_profiles` 表（状态：pending）
   - 返回处理后的数据给前端

6. **用户确认**：
   - 前端显示 `LinkedInPreviewView` sheet
   - 用户可以查看/编辑导入的数据
   - 用户点击 "Confirm & Import"

7. **最终确认**：
   - 前端调用 `AuthManager.confirmLinkedInProfile()`
   - 后端更新 `linkedin_profiles` 状态为 'confirmed'
   - 将确认的数据合并到主 `users` 表
   - 记录审计日志

## 📊 数据映射

### LinkedIn API → 数据库字段

| LinkedIn 字段 | 存储位置 | 说明 |
|-------------|---------|------|
| `id` (sub) | `linkedin_profiles.linkedin_id` | 用户唯一标识符 |
| `localizedFirstName` + `localizedLastName` | `users.name` (确认后) | 合并为全名 |
| `localizedHeadline` | `linkedin_profiles.headline` | 职业标题 |
| `vanityName` | `linkedin_profiles.vanity_name` | 个人资料 URL 后缀 |
| Email | `users.email` + `linkedin_profiles.email` | 邮箱地址 |
| Profile Picture | `users.avatar_url` + `linkedin_profiles.avatar_url` | 头像 URL |
| Raw JSON | `linkedin_profiles.raw_profile` | 完整的 API 响应 |

### 数据增强

导入时自动进行以下数据增强：

1. **标签提取**：从 headline 中提取关键词（如公司、职位、技能）
2. **角色识别**：根据 headline 识别用户角色等级（student/engineer/senior 等）
3. **头像优化**：选择最高分辨率的头像
4. **URL 构造**：如果有 vanity name，构造完整的 LinkedIn URL

## 🎨 前端界面

### Core Identity 步骤中的导入界面

```
┌─ LinkedIn Profile Import ──────────────────┐
│                                           │
│ □ I consent to BrewNet accessing my       │
│   public LinkedIn profile...              │
│                                           │
│ [Sign in with LinkedIn]                   │
│                                           │
│ Or enter your LinkedIn profile URL:       │
│ [https://www.linkedin.com/in/...] [Fetch] │
│                                           │
└───────────────────────────────────────────┘
```

### 预览和确认界面

```
┌─ Review LinkedIn Data ─────────────────────┐
│ ◇ Avatar preview                          │
│                                           │
│ Full Name: [John Doe]                     │
│ Email: [john@example.com]                 │
│                                           │
│ Professional Headline:                    │
│ "Product Manager at Tech Corp"            │
│                                           │
│ LinkedIn Profile: linkedin.com/in/johndoe │
│                                           │
│ Extracted Tags:                           │
│ [Product] [Manager] [Tech Corp]           │
│                                           │
│ [Cancel]                    [Confirm]      │
└───────────────────────────────────────────┘
```

## 🔧 API 接口

### linkedin-import Edge Function

**Endpoint**: `POST /functions/v1/linkedin-import`

**Request Body**:
```json
{
  "code": "linkedin_authorization_code",
  "user_id": "user_uuid",
  "redirect_uri": "https://brewnet.app/auth/linkedin/callback"
}
```

**Response**:
```json
{
  "success": true,
  "profile": {
    "id": "import_record_uuid",
    "linkedin_id": "linkedin_member_id",
    "fullName": "John Doe",
    "headline": "Product Manager at Tech Corp",
    "email": "john@example.com",
    "avatarUrl": "https://...",
    "profileUrl": "https://www.linkedin.com/in/johndoe",
    "tags": ["Product", "Manager", "Tech Corp"]
  }
}
```

## 🛡️ 安全和隐私

### 权限控制

- **用户级别 RLS**：用户只能访问自己的 LinkedIn 数据
- **OAuth 范围**：仅使用 `openid profile email` 权限
- **数据隔离**：LinkedIn 数据与主用户数据分离存储

### 合规考虑

- **用户同意**：导入前必须明确获得用户同意
- **数据保留**：支持数据删除和撤销
- **审计日志**：记录所有导入操作
- **错误处理**：敏感信息不会在错误日志中泄露

## 🧪 测试步骤

### 端到端测试流程

1. **准备测试环境**：
   - 确保数据库表已创建
   - 确保 Edge Functions 已部署
   - 确保环境变量已设置

2. **测试 LinkedIn 登录**：
   - 在 App 中进入 Profile Setup
   - 勾选 consent 复选框
   - 点击 "Sign in with LinkedIn"
   - 完成 OAuth 流程

3. **验证数据导入**：
   - 检查预览界面是否显示正确的数据
   - 确认数据后检查数据库记录
   - 验证主 users 表是否正确更新

4. **测试错误情况**：
   - 取消 OAuth 流程
   - 使用无效的 LinkedIn 账户
   - 网络连接问题

## 📈 监控和维护

### 日志检查

```bash
# 查看函数日志
supabase functions logs linkedin-import

# 查看数据库记录
supabase db inspect
```

### 关键指标

- **导入成功率**：成功导入的用户比例
- **API 响应时间**：LinkedIn API 调用延迟
- **错误率**：不同类型错误的发生频率
- **用户确认率**：用户确认导入数据的比例

## 🚨 故障排除

### 常见问题

1. **403 Forbidden 错误**
   - 检查 LinkedIn 应用权限设置
   - 确认 OAuth scopes 配置正确

2. **导入失败**
   - 检查 Edge Function 日志
   - 验证数据库连接和权限

3. **预览界面不显示**
   - 检查前端通知监听器
   - 验证数据格式是否正确

## 🎯 下一步优化

### 可能的增强功能

1. **批量导入**：支持多个用户同时导入
2. **增量更新**：定期更新已导入的数据
3. **数据验证**：更严格的数据质量检查
4. **推荐系统集成**：利用导入数据改进匹配算法

---

## 📞 技术支持

如果遇到问题，请检查：
1. Supabase Dashboard 中的函数日志
2. Xcode 控制台中的前端日志
3. LinkedIn 开发者门户的应用状态

完整的实现代码已提交，包括数据库迁移、Edge Functions 和前端更新。

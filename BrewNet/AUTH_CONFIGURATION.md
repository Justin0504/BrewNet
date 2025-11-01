# BrewNet 认证配置指南

## 📋 概述

本指南说明如何配置 BrewNet 的认证系统，包括 Supabase Auth 的邮箱验证设置。

## 🔧 开发环境配置

### 禁用邮箱验证（仅限开发环境）

在开发阶段，如果不想每次都验证邮箱，可以在 Supabase Dashboard 中禁用邮箱验证：

1. **登录 Supabase Dashboard**
   - 访问: https://supabase.com/dashboard
   - 选择您的项目: `jcxvdolcdifdghaibspy`

2. **进入 Authentication 设置**
   - 在左侧菜单中点击 "Authentication"
   - 点击 "Settings" 标签
   - 滚动到 "Email Auth" 部分

3. **禁用邮箱确认**
   - 找到 "Enable email confirmations" 选项
   - 关闭该选项
   - 点击 "Save" 保存设置

4. **效果**
   - 新用户注册后无需验证邮箱即可登录
   - 立即可以测试注册和登录流程

### 手动验证已注册用户（开发调试）

如果已经注册了用户但未验证邮箱，可以手动将其标记为已验证：

#### 方法 1: 通过 SQL Editor

在 Supabase Dashboard 的 SQL Editor 中执行：

```sql
-- 手动验证指定邮箱的用户
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE email = '你的邮箱@example.com';
```

#### 方法 2: 通过 Dashboard UI

1. 进入 **Authentication** > **Users**
2. 找到目标用户
3. 点击用户详情
4. 在 "Confirmation" 部分
5. 点击 "Confirm user" 按钮

## 🔐 生产环境配置

### 启用邮箱验证（推荐）

在生产环境中，强烈建议启用邮箱验证：

1. **进入 Authentication 设置**
   - Authentication > Settings > Email Auth
   - 启用 "Enable email confirmations"

2. **配置邮箱模板**
   - Authentication > Email Templates
   - 自定义确认邮件模板（可选）

3. **配置 SMTP（如需要）**
   - Authentication > Settings > SMTP Settings
   - 配置自定义 SMTP 服务器
   - 或使用 Supabase 默认邮件服务

### 邮件提供商设置

确保已启用所需的认证提供商：

1. **Authentication** > **Providers**
2. 检查以下提供商是否已启用：
   - ✅ **Email** - 必需
   - ⚠️ **Phone** - 可选（如需手机号注册）
   - ⚠️ **Apple** - 可选（如需 Apple Sign In）
   - ⚠️ **Google** - 可选（如需 Google Sign In）

## 🛠️ 故障排除

### 问题 1: "Invalid login credentials" 错误

**可能原因：**
- 邮箱未验证
- 密码不正确
- 用户在 Supabase Auth 中不存在

**解决方案：**
1. 检查邮箱是否已验证（见上方手动验证步骤）
2. 确认密码正确
3. 检查 Authentication > Users 中是否存在该用户

### 问题 2: 注册后无法登录

**可能原因：**
- 邮箱验证功能已启用但用户未验证邮箱
- Supabase 服务连接问题

**解决方案：**
1. 查看注册日志确认是否成功
2. 检查邮箱中的验证邮件
3. 验证邮箱或禁用邮箱验证（开发环境）

### 问题 3: 旧用户无法登录

**可能原因：**
- 用户是通过旧版本的本地注册创建的
- 未在 Supabase Auth 中创建账号

**解决方案：**
1. 删除旧的用户记录
2. 重新注册账号

### 问题 4: 手机号注册登录失败

**可能原因：**
- Phone 提供商未启用
- Supabase Auth 不支持手机号登录

**解决方案：**
1. 检查 Phone 提供商是否已启用
2. 注意：当前版本可能仅支持邮箱登录

## 📊 验证用户状态

### 检查用户是否已验证

在 SQL Editor 中执行：

```sql
-- 查看所有用户及其验证状态
SELECT 
    id,
    email,
    email_confirmed_at,
    created_at,
    CASE 
        WHEN email_confirmed_at IS NOT NULL THEN '已验证'
        ELSE '未验证'
    END as verification_status
FROM auth.users
ORDER BY created_at DESC;
```

## 🔗 相关资源

- [Supabase Auth 文档](https://supabase.com/docs/guides/auth)
- [认证提供商配置](https://supabase.com/docs/guides/auth/providers)
- [邮箱验证指南](https://supabase.com/docs/guides/auth/auth-email-verify)

## ⚠️ 重要提示

1. **开发环境**：可以禁用邮箱验证以提高开发效率
2. **生产环境**：强烈建议启用邮箱验证以提高安全性
3. **密码重置**：确保配置了密码重置流程
4. **日志监控**：定期检查认证失败日志

---

**需要帮助？** 如果遇到问题，请检查：
- Supabase Dashboard 中的认证日志
- 应用中的控制台日志
- 网络连接状态


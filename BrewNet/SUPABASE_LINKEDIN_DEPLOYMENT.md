# Supabase LinkedIn OAuth 完整部署指南

本指南将帮助你完整部署 LinkedIn OAuth 的两个 Edge Functions：
1. **linkedin-callback** - Callback 中转服务器
2. **linkedin-exchange** - Token Exchange 后端

## 📋 前置要求

1. **Supabase 项目**：`jcxvdolcdifdghaibspy`
2. **LinkedIn Developer Account**：已创建应用并获取 Client ID 和 Client Secret
3. **Supabase CLI**：已安装并登录
4. **域名**：`brewnet.app`（可选，用于自定义域名）

## 🚀 步骤 1: 安装和配置 Supabase CLI

### 1.1 安装 Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# 或使用 npm
npm install -g supabase

# 验证安装
supabase --version
```

### 1.2 登录 Supabase

```bash
supabase login
```

这会打开浏览器，要求你登录 Supabase 账户。

### 1.3 链接到项目

```bash
cd /Users/heady/Documents/BrewNet/BrewNet
supabase link --project-ref jcxvdolcdifdghaibspy
```

输入项目数据库密码（在 Supabase Dashboard → Settings → Database 中查看）。

## 🚀 步骤 2: 部署 Callback 中转服务器

### 2.1 检查函数文件

确保文件存在：
```
supabase/functions/linkedin-callback/index.ts
```

### 2.2 部署函数

```bash
supabase functions deploy linkedin-callback --no-verify-jwt
```

**说明：**
- `--no-verify-jwt`：因为这是公开的 callback endpoint，不需要 JWT 验证

### 2.3 验证部署

部署成功后，你会看到：
```
Deploying function linkedin-callback...
Function linkedin-callback deployed successfully!
Function URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
```

### 2.4 测试 Callback 函数

```bash
# 测试重定向功能
curl "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=test123&state=test456"

# 应该返回 302 重定向到：
# Location: brewnet://auth/linkedin?code=test123&state=test456
```

## 🚀 步骤 3: 配置环境变量（Token Exchange）

### 3.1 获取 LinkedIn 凭证

1. 登录 [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. 进入你的应用
3. 在 **Auth** 标签页找到：
   - **Client ID**: `782dcovcs9zyfv`
   - **Client Secret**: （点击 "Show" 查看）

### 3.2 设置 Supabase 环境变量

在 Supabase Dashboard 中设置：

1. 打开 [Supabase Dashboard](https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy)
2. 进入 **Settings** → **Edge Functions**
3. 点击 **Secrets** 标签
4. 添加以下环境变量：

```
LINKEDIN_CLIENT_ID=782dcovcs9zyfv
LINKEDIN_CLIENT_SECRET=你的_LINKEDIN_CLIENT_SECRET
LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

**或者使用 CLI 设置：**

```bash
# 设置 Client ID
supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv

# 设置 Client Secret（替换为实际值）
supabase secrets set LINKEDIN_CLIENT_SECRET=你的实际密钥

# 设置 Redirect URI
supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

### 3.3 验证环境变量

```bash
# 查看所有 secrets（不会显示值）
supabase secrets list
```

## 🚀 步骤 4: 部署 Token Exchange 后端

### 4.1 检查函数文件

确保文件存在：
```
supabase/functions/linkedin-exchange/index.ts
```

### 4.2 部署函数

```bash
supabase functions deploy linkedin-exchange --no-verify-jwt
```

**说明：**
- `--no-verify-jwt`：因为 iOS App 直接调用，不需要 Supabase JWT

### 4.3 验证部署

部署成功后，你会看到：
```
Deploying function linkedin-exchange...
Function linkedin-exchange deployed successfully!
Function URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
```

### 4.4 测试 Token Exchange 函数

```bash
# 注意：这需要真实的 authorization code，所以这个测试会失败
# 但可以验证函数是否部署成功
curl -X POST https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange \
  -H "Content-Type: application/json" \
  -d '{"code":"test_code","redirect_uri":"https://brewnet.app/auth/linkedin/callback"}'

# 应该返回错误（因为 code 无效），但说明函数已部署
```

## 🌐 步骤 5: 配置自定义域名（可选）

如果你想使用 `https://brewnet.app` 而不是 Supabase 默认域名：

### 5.1 在 Supabase Dashboard 配置

1. 进入 **Settings** → **Custom Domains**
2. 点击 **Add Domain**
3. 输入：`brewnet.app`
4. 按照提示配置 DNS 记录

### 5.2 配置 DNS

在你的域名注册商添加 CNAME 记录：
```
Type: CNAME
Name: @ (或 brewnet)
Value: jcxvdolcdifdghaibspy.supabase.co
TTL: 3600
```

### 5.3 配置路由规则

在 Supabase Dashboard → **Settings** → **Edge Functions** → **Routes**：

添加路由：
- **Path**: `/auth/linkedin/callback`
- **Function**: `linkedin-callback`

### 5.4 更新 iOS App 配置

如果使用自定义域名，需要更新 `AuthManager.swift`：

```swift
private let redirectURI = "https://brewnet.app/auth/linkedin/callback"
```

Token Exchange URL 也需要更新（如果配置了自定义域名）：

```swift
guard let backendURL = URL(string: "https://brewnet.app/api/auth/linkedin/exchange") else {
```

但更简单的方式是继续使用 Supabase 默认域名，只需要配置 callback 的自定义域名。

## 🔧 步骤 6: 更新 iOS App 配置

### 6.1 更新 Callback URL

在 `AuthManager.swift` 中，确保 `redirectURI` 正确：

```swift
private let redirectURI = "https://brewnet.app/auth/linkedin/callback"
// 或使用 Supabase 默认域名：
// private let redirectURI = "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback"
```

### 6.2 更新 Token Exchange URL

在 `AuthManager.swift` 中，更新 `exchangeCodeWithBackend` 方法：

```swift
guard let backendURL = URL(string: "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange") else {
```

## 🔐 步骤 7: 配置 LinkedIn Developer Portal

### 7.1 添加 Redirect URL

1. 登录 [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. 进入你的应用
3. 点击 **Auth** 标签
4. 在 **OAuth 2.0 settings** 中，找到 **Authorized Redirect URLs**
5. 点击 **Add redirect URL**
6. 添加：
   ```
   https://brewnet.app/auth/linkedin/callback
   ```
   或（如果使用 Supabase 默认域名）：
   ```
   https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
   ```
7. 点击 **Update**

### 7.2 验证配置

确保以下信息正确：
- **Client ID**: `782dcovcs9zyfv`
- **Client Secret**: 已保存（用于 Edge Function 环境变量）
- **Redirect URLs**: 包含你的 callback URL

## ✅ 步骤 8: 测试完整流程

### 8.1 测试 Checklist

- [ ] Callback 函数已部署并可访问
- [ ] Token Exchange 函数已部署并可访问
- [ ] 环境变量已设置
- [ ] LinkedIn Redirect URL 已配置
- [ ] iOS App 中的 URL 配置正确

### 8.2 端到端测试

1. **在 iOS App 中**：
   - 打开 Profile Setup
   - 勾选 LinkedIn consent
   - 点击 "Import from LinkedIn"

2. **预期流程**：
   - App 打开 LinkedIn 授权页面
   - 用户授权后，LinkedIn 重定向到 callback URL
   - Callback 函数重定向到 `brewnet://auth/linkedin?code=...`
   - App 接收回调，调用 Token Exchange
   - Token Exchange 返回 profile 数据
   - App 显示 "Imported LinkedIn Data"

### 8.3 查看日志

在 Supabase Dashboard → **Edge Functions** → **Logs** 中查看函数执行日志：

```bash
# 使用 CLI 查看日志
supabase functions logs linkedin-callback
supabase functions logs linkedin-exchange
```

## 🐛 故障排除

### 问题 1: 函数部署失败

**错误**: `Function deployment failed`

**解决方案**:
- 检查 Deno 版本（Supabase 使用 Deno 1.x）
- 确保 `index.ts` 文件语法正确
- 查看详细错误信息：`supabase functions deploy linkedin-callback --debug`

### 问题 2: 环境变量未生效

**错误**: `Missing LinkedIn credentials`

**解决方案**:
- 确认环境变量已设置：`supabase secrets list`
- 重新部署函数：`supabase functions deploy linkedin-exchange --no-verify-jwt`
- 检查变量名拼写是否正确

### 问题 3: CORS 错误

**错误**: `CORS policy blocked`

**解决方案**:
- 检查函数中的 `corsHeaders` 配置
- 确保 iOS App 的请求头正确

### 问题 4: Redirect URI 不匹配

**错误**: LinkedIn 报错 "redirect_uri does not match"

**解决方案**:
- 确保 LinkedIn Developer Portal 中的 Redirect URL 完全匹配
- 检查 URL 编码是否正确
- 验证没有多余的斜杠或空格

### 问题 5: Token Exchange 返回错误

**错误**: `Failed to exchange code for token`

**解决方案**:
- 检查 Client ID 和 Client Secret 是否正确
- 验证 Redirect URI 与 LinkedIn 配置一致
- 查看 Supabase 函数日志获取详细错误

## 📊 监控和维护

### 查看函数使用情况

在 Supabase Dashboard → **Edge Functions** → **Metrics** 中查看：
- 函数调用次数
- 平均响应时间
- 错误率

### 更新函数

```bash
# 修改代码后重新部署
supabase functions deploy linkedin-callback --no-verify-jwt
supabase functions deploy linkedin-exchange --no-verify-jwt
```

### 回滚到之前的版本

```bash
# 查看部署历史
supabase functions list

# 回滚到特定版本（如果支持）
# 注意：Supabase 可能需要手动回滚
```

## 🔒 安全最佳实践

1. **永远不要在客户端存储 Client Secret**
   - ✅ 使用 Edge Function 环境变量
   - ❌ 不要放在 iOS App 代码中

2. **使用 HTTPS**
   - 所有 callback URL 必须是 HTTPS
   - LinkedIn 要求 HTTPS

3. **验证 State 参数**
   - iOS App 中已实现 state 验证
   - 防止 CSRF 攻击

4. **限制函数访问**
   - 考虑添加 rate limiting
   - 监控异常请求

5. **定期轮换密钥**
   - 定期更新 Client Secret
   - 更新 Supabase 环境变量

## 📝 总结

部署完成后，你将拥有：

1. ✅ **Callback 中转服务器**
   - URL: `https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`
   - 或: `https://brewnet.app/auth/linkedin/callback`（如果配置了自定义域名）

2. ✅ **Token Exchange 后端**
   - URL: `https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange`

3. ✅ **完整的 OAuth 流程**
   - LinkedIn 授权 → Callback → Token Exchange → Profile 数据

## 🆘 需要帮助？

- Supabase 文档: https://supabase.com/docs/guides/functions
- LinkedIn OAuth 文档: https://learn.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin-v2
- 项目 Issues: 在 GitHub 仓库中创建 issue


# LinkedIn OAuth 完整实现总结

## 📦 已创建的文件

### Supabase Edge Functions

1. **Callback 中转服务器**
   - `supabase/functions/linkedin-callback/index.ts`
   - 接收 LinkedIn OAuth 回调，重定向到 App Scheme

2. **Token Exchange 后端**
   - `supabase/functions/linkedin-exchange/index.ts`
   - 交换 authorization code 为 access token
   - 获取 LinkedIn profile 和 email

### 配置文件

3. **Supabase 配置**
   - `supabase/config.toml` - Supabase 项目配置
   - `supabase/.gitignore` - Git 忽略文件

### 文档

4. **部署指南**
   - `SUPABASE_LINKEDIN_DEPLOYMENT.md` - 完整部署指南（详细）
   - `DEPLOYMENT_QUICK_START.md` - 快速部署指南（5分钟）
   - `LINKEDIN_CALLBACK_SETUP.md` - Callback 服务器设置指南

### 部署脚本

5. **自动化部署**
   - `deploy-linkedin-functions.sh` - 一键部署脚本

### iOS 代码更新

6. **AuthManager.swift**
   - 已更新为使用 Supabase Edge Functions
   - Token Exchange URL: `https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange`

## 🚀 快速开始（3 步）

### 1. 安装 Supabase CLI

```bash
brew install supabase/tap/supabase
# 或
npm install -g supabase
```

### 2. 设置环境变量

```bash
supabase login
supabase link --project-ref jcxvdolcdifdghaibspy

# 设置 LinkedIn 凭证（从 LinkedIn Developer Portal 获取）
supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv
supabase secrets set LINKEDIN_CLIENT_SECRET=你的实际密钥
supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

### 3. 部署函数

```bash
# 方式 1: 使用部署脚本（推荐）
./deploy-linkedin-functions.sh

# 方式 2: 手动部署
supabase functions deploy linkedin-callback --no-verify-jwt
supabase functions deploy linkedin-exchange --no-verify-jwt
```

## 📋 完整部署步骤

### 步骤 1: 准备环境

```bash
# 1. 安装 Supabase CLI
brew install supabase/tap/supabase

# 2. 登录 Supabase
supabase login

# 3. 链接项目
cd /Users/heady/Documents/BrewNet/BrewNet
supabase link --project-ref jcxvdolcdifdghaibspy
```

### 步骤 2: 配置 LinkedIn 凭证

1. 登录 [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. 进入你的应用
3. 在 **Auth** 标签找到 **Client Secret**（点击 "Show"）
4. 设置环境变量：

```bash
supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv
supabase secrets set LINKEDIN_CLIENT_SECRET=你的实际密钥
supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

### 步骤 3: 部署函数

```bash
# 部署 Callback 中转服务器
supabase functions deploy linkedin-callback --no-verify-jwt

# 部署 Token Exchange 后端
supabase functions deploy linkedin-exchange --no-verify-jwt
```

### 步骤 4: 配置 LinkedIn Redirect URL

1. 在 LinkedIn Developer Portal → 你的应用 → **Auth** 标签
2. 在 **Authorized Redirect URLs** 中添加：
   ```
   https://brewnet.app/auth/linkedin/callback
   ```
   或（如果使用 Supabase 默认域名）：
   ```
   https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
   ```
3. 点击 **Update**

### 步骤 5: 测试

1. 在 iOS App 中打开 Profile Setup
2. 勾选 LinkedIn consent
3. 点击 "Import from LinkedIn"
4. 完成授权流程
5. 应该看到 "Imported LinkedIn Data" 显示

## 🔗 函数 URL

部署成功后，函数 URL 为：

- **Callback**: 
  ```
  https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
  ```

- **Token Exchange**: 
  ```
  https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
  ```

## 🔍 验证部署

### 测试 Callback 函数

```bash
curl "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=test123&state=test456"
# 应该返回 302 重定向到: brewnet://auth/linkedin?code=test123&state=test456
```

### 查看函数日志

```bash
# 查看 Callback 函数日志
supabase functions logs linkedin-callback

# 查看 Exchange 函数日志
supabase functions logs linkedin-exchange

# 实时查看日志
supabase functions logs linkedin-callback --follow
```

### 在 Supabase Dashboard 查看

1. 登录 [Supabase Dashboard](https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy)
2. 进入 **Edge Functions**
3. 查看函数列表和日志

## 📊 工作流程

```
1. 用户点击 "Import from LinkedIn"
   ↓
2. iOS App 打开 LinkedIn 授权页面
   URL: https://www.linkedin.com/oauth/v2/authorization?...
   ↓
3. 用户授权后，LinkedIn 重定向到：
   https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=XXX&state=YYY
   ↓
4. Callback 函数接收请求，302 重定向到：
   brewnet://auth/linkedin?code=XXX&state=YYY
   ↓
5. ASWebAuthenticationSession 捕获 app scheme 回调
   ↓
6. iOS App 调用 Token Exchange：
   POST https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
   Body: { "code": "XXX", "redirect_uri": "https://brewnet.app/auth/linkedin/callback" }
   ↓
7. Exchange 函数：
   - 用 code 换取 access_token
   - 调用 LinkedIn API 获取 profile
   - 调用 LinkedIn API 获取 email
   - 返回完整 profile 数据
   ↓
8. iOS App 接收 profile，显示 "Imported LinkedIn Data"
```

## 🐛 常见问题

### Q: 函数部署失败？

**A:** 检查：
- Supabase CLI 是否最新版本
- 是否已登录：`supabase login`
- 项目是否已链接：`supabase link --project-ref jcxvdolcdifdghaibspy`
- 查看详细错误：`supabase functions deploy linkedin-callback --debug`

### Q: Token Exchange 返回 "Missing LinkedIn credentials"？

**A:** 检查环境变量：
```bash
supabase secrets list
```
确保设置了：
- `LINKEDIN_CLIENT_ID`
- `LINKEDIN_CLIENT_SECRET`
- `LINKEDIN_REDIRECT_URI`

### Q: LinkedIn 报错 "redirect_uri does not match"？

**A:** 确保：
- LinkedIn Developer Portal 中的 Redirect URL 完全匹配
- URL 没有多余的斜杠或空格
- 使用 HTTPS（不是 HTTP）

### Q: App 没有收到回调？

**A:** 检查：
- `Info.plist` 中是否配置了 `brewnet` URL scheme
- `ASWebAuthenticationSession` 的 `callbackURLScheme` 是否为 `"brewnet"`
- Callback 函数是否正确返回 302 重定向

### Q: 如何查看函数执行日志？

**A:** 
```bash
# CLI
supabase functions logs linkedin-callback
supabase functions logs linkedin-exchange

# Dashboard
# Supabase Dashboard → Edge Functions → Logs
```

## 🔒 安全注意事项

1. ✅ **Client Secret 安全**
   - 使用 Supabase Secrets（环境变量）
   - 永远不要提交到代码仓库
   - 定期轮换密钥

2. ✅ **HTTPS 要求**
   - 所有 callback URL 必须是 HTTPS
   - LinkedIn 强制要求 HTTPS

3. ✅ **State 验证**
   - iOS App 中已实现 state 验证
   - 防止 CSRF 攻击

4. ✅ **错误处理**
   - 函数中有完整的错误处理
   - 不会泄露敏感信息

## 📝 更新和维护

### 更新函数代码

```bash
# 修改代码后重新部署
supabase functions deploy linkedin-callback --no-verify-jwt
supabase functions deploy linkedin-exchange --no-verify-jwt
```

### 更新环境变量

```bash
# 更新 Client Secret
supabase secrets set LINKEDIN_CLIENT_SECRET=新的密钥

# 重新部署函数以应用新环境变量
supabase functions deploy linkedin-exchange --no-verify-jwt
```

### 查看函数版本

```bash
supabase functions list
```

## 📚 相关文档

- **详细部署指南**: `SUPABASE_LINKEDIN_DEPLOYMENT.md`
- **快速开始**: `DEPLOYMENT_QUICK_START.md`
- **Callback 设置**: `LINKEDIN_CALLBACK_SETUP.md`
- **Supabase 文档**: https://supabase.com/docs/guides/functions
- **LinkedIn OAuth 文档**: https://learn.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin-v2

## ✅ 部署检查清单

- [ ] Supabase CLI 已安装
- [ ] 已登录 Supabase
- [ ] 项目已链接
- [ ] 环境变量已设置（CLIENT_ID, CLIENT_SECRET, REDIRECT_URI）
- [ ] Callback 函数已部署
- [ ] Exchange 函数已部署
- [ ] LinkedIn Redirect URL 已配置
- [ ] iOS App URL 配置正确
- [ ] 测试 OAuth 流程成功

## 🎉 完成！

部署完成后，你的 LinkedIn OAuth 集成应该可以正常工作了！

如有问题，请查看：
- 函数日志：`supabase functions logs`
- Supabase Dashboard：Edge Functions 页面
- 详细文档：`SUPABASE_LINKEDIN_DEPLOYMENT.md`


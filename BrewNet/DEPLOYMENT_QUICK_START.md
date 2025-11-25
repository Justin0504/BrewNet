# LinkedIn OAuth 快速部署指南

## 🚀 5 分钟快速部署

### 步骤 1: 安装 Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# 或
npm install -g supabase
```

### 步骤 2: 登录并链接项目

```bash
cd /Users/heady/Documents/BrewNet/BrewNet
supabase login
supabase link --project-ref jcxvdolcdifdghaibspy
```

### 步骤 3: 设置环境变量

```bash
# 获取 LinkedIn Client Secret（从 LinkedIn Developer Portal）
# 然后设置：
supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv
supabase secrets set LINKEDIN_CLIENT_SECRET=你的实际密钥
supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

### 步骤 4: 部署两个函数

```bash
# 部署 Callback 中转服务器
supabase functions deploy linkedin-callback --no-verify-jwt

# 部署 Token Exchange 后端
supabase functions deploy linkedin-exchange --no-verify-jwt
```

### 步骤 5: 配置 LinkedIn

1. 登录 [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. 进入你的应用 → **Auth** 标签
3. 添加 Redirect URL: `https://brewnet.app/auth/linkedin/callback`
   - 或使用 Supabase 默认域名: `https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`

### 步骤 6: 测试

在 iOS App 中：
1. 打开 Profile Setup
2. 勾选 LinkedIn consent
3. 点击 "Import from LinkedIn"
4. 完成授权流程

## ✅ 验证部署

### 测试 Callback 函数

```bash
curl "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=test&state=test"
# 应该返回 302 重定向到 brewnet://auth/linkedin?code=test&state=test
```

### 查看函数日志

```bash
supabase functions logs linkedin-callback
supabase functions logs linkedin-exchange
```

## 📚 详细文档

查看完整部署指南：`SUPABASE_LINKEDIN_DEPLOYMENT.md`

## 🔗 函数 URL

- **Callback**: `https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`
- **Token Exchange**: `https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange`

## ⚠️ 注意事项

1. **Client Secret 安全**：永远不要提交到代码仓库
2. **HTTPS 要求**：LinkedIn 要求所有 redirect_uri 必须是 HTTPS
3. **State 验证**：iOS App 中已实现，防止 CSRF 攻击


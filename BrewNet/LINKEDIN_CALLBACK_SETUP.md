# LinkedIn OAuth Callback 中转服务器设置指南

## 概述

LinkedIn OAuth 流程需要两个独立的服务器端点：

1. **Callback 中转服务器** (`https://brewnet.app/auth/linkedin/callback`)
   - 接收 LinkedIn 的 OAuth 回调
   - 302 重定向到 App Scheme (`brewnet://auth/linkedin?code=...&state=...`)

2. **Token Exchange 后端** (`https://api.brewnet.app/api/auth/linkedin/exchange`)
   - 接收 App 发送的 authorization code
   - 使用 `client_secret` 向 LinkedIn 换取 access token
   - 获取用户 profile 和 email
   - 返回给 App

## 已创建的文件

### 方案 1: Supabase Edge Function（推荐）
- `supabase/functions/linkedin-callback/index.ts` - Deno Edge Function

### 方案 2: 独立 Node.js 服务器
- `server/linkedin-callback-server.js` - Express 服务器
- `server/package.json` - 依赖配置
- `server/vercel.json` - Vercel 部署配置
- `server/README.md` - 详细部署说明

## 快速开始（Supabase Edge Function）

### 1. 安装 Supabase CLI

```bash
npm install -g supabase
```

### 2. 登录并链接项目

```bash
supabase login
supabase link --project-ref jcxvdolcdifdghaibspy
```

### 3. 部署函数

```bash
supabase functions deploy linkedin-callback
```

### 4. 配置自定义域名（可选）

1. 在 Supabase Dashboard → Settings → Custom Domains
2. 添加 `brewnet.app`
3. 配置 DNS 记录（CNAME 指向 Supabase）
4. 设置路由规则：
   - Path: `/auth/linkedin/callback`
   - Function: `linkedin-callback`

**函数 URL：**
- 默认：`https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`
- 自定义域名：`https://brewnet.app/auth/linkedin/callback`

## 快速开始（独立 Node.js 服务器）

### 1. 安装依赖

```bash
cd server
npm install
```

### 2. 本地测试

```bash
npm start
```

服务器将在 `http://localhost:3001` 运行

### 3. 部署到 Vercel（推荐）

```bash
npm i -g vercel
vercel
```

按照提示配置：
- 项目名称：`brewnet-linkedin-callback`
- 自定义域名：`brewnet.app`
- 路由：`/auth/linkedin/callback`

### 4. 部署到其他平台

参考 `server/README.md` 获取详细说明：
- Railway
- Render
- DigitalOcean App Platform
- AWS Lambda

## LinkedIn Developer Portal 配置

1. 登录 [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. 进入你的应用设置
3. 在 **Auth** → **OAuth 2.0 settings** 中添加：
   - **Authorized Redirect URLs**: `https://brewnet.app/auth/linkedin/callback`

## 工作流程

```
1. 用户点击 "Import from LinkedIn"
   ↓
2. App 打开 LinkedIn 授权页面
   URL: https://www.linkedin.com/oauth/v2/authorization?...
   ↓
3. 用户授权后，LinkedIn 重定向到：
   https://brewnet.app/auth/linkedin/callback?code=XXX&state=YYY
   ↓
4. Callback 中转服务器接收请求
   ↓
5. 服务器 302 重定向到：
   brewnet://auth/linkedin?code=XXX&state=YYY
   ↓
6. ASWebAuthenticationSession 捕获 app scheme 回调
   ↓
7. App 调用 Token Exchange 后端：
   POST https://api.brewnet.app/api/auth/linkedin/exchange
   Body: { "code": "XXX", "redirect_uri": "https://brewnet.app/auth/linkedin/callback" }
   ↓
8. 后端返回 profile 数据
   ↓
9. App 显示 "Imported LinkedIn Data"
```

## 测试

### 测试 Callback 服务器

```bash
# 本地测试
curl "http://localhost:3001/auth/linkedin/callback?code=test123&state=test456"

# 应该返回 302 重定向到：
# Location: brewnet://auth/linkedin?code=test123&state=test456
```

### 测试完整流程

1. 在 App 中点击 "Import from LinkedIn"
2. 完成 LinkedIn 授权
3. 应该自动跳回 App 并显示导入的数据

## 故障排除

### 问题 1: 重定向不工作

**症状：** App 没有收到回调

**解决方案：**
- 检查 `Info.plist` 中是否配置了 `brewnet` URL scheme
- 检查 `ASWebAuthenticationSession` 的 `callbackURLScheme` 是否为 `"brewnet"`
- 验证 callback 服务器是否正确返回 302 重定向

### 问题 2: LinkedIn 报错 "redirect_uri does not match"

**症状：** LinkedIn 拒绝授权，显示 redirect_uri 不匹配

**解决方案：**
- 确保 LinkedIn Developer Portal 中的 Redirect URL 完全匹配：
  - ✅ `https://brewnet.app/auth/linkedin/callback`
  - ❌ `https://brewnet.app/auth/linkedin/callback/` (多了一个斜杠)
  - ❌ `http://brewnet.app/auth/linkedin/callback` (必须是 HTTPS)

### 问题 3: 服务器无法访问

**症状：** 无法访问 `https://brewnet.app/auth/linkedin/callback`

**解决方案：**
- 检查 DNS 配置
- 验证 SSL 证书
- 检查防火墙设置
- 查看服务器日志

### 问题 4: State 验证失败

**症状：** App 显示 "State mismatch"

**解决方案：**
- 确保 `currentState` 在 `startLinkedInLogin()` 中正确设置
- 验证 state 参数在重定向过程中没有被修改

## 安全注意事项

1. **永远不要在客户端存储 `client_secret`**
   - Token exchange 必须在后端完成
   - 使用环境变量存储敏感信息

2. **验证 State 参数**
   - 防止 CSRF 攻击
   - 代码中已实现 state 验证

3. **使用 HTTPS**
   - LinkedIn 要求所有 redirect_uri 必须是 HTTPS
   - 确保 SSL 证书有效

4. **日志记录**
   - 记录所有 OAuth 回调（但不记录敏感信息）
   - 监控异常请求

## 下一步

1. ✅ 部署 Callback 中转服务器
2. ⏳ 实现 Token Exchange 后端（`/api/auth/linkedin/exchange`）
3. ⏳ 测试完整 OAuth 流程
4. ⏳ 配置生产环境监控

## 相关文件

- `BrewNet/AuthManager.swift` - iOS OAuth 客户端代码
- `server/README.md` - 详细部署说明
- `supabase/functions/linkedin-callback/index.ts` - Supabase Edge Function


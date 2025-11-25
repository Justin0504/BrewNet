# 域名替换指南：从 brewnet.app 到 Supabase 默认域名

## 📋 替换方案

由于 `brewnet.app` 域名已被占用，我们将使用 **Supabase 默认域名**：

**新域名：**
```
https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
```

**注意：** `brewnet://` 是 App 的 URL Scheme，**不需要修改**。

---

## 🔄 完整替换步骤

### 步骤 1: 更新 Supabase 环境变量

```bash
supabase secrets set LINKEDIN_REDIRECT_URI=https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
```

### 步骤 2: 更新 iOS App 代码

文件：`BrewNet/AuthManager.swift`

将：
```swift
private let redirectURI = "https://brewnet.app/auth/linkedin/callback"
```

替换为：
```swift
private let redirectURI = "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback"
```

### 步骤 3: 更新 Supabase Edge Function

文件：`supabase/functions/linkedin-exchange/index.ts`

将：
```typescript
const redirectURI = redirect_uri || Deno.env.get("LINKEDIN_REDIRECT_URI") || "https://brewnet.app/auth/linkedin/callback"
```

替换为：
```typescript
const redirectURI = redirect_uri || Deno.env.get("LINKEDIN_REDIRECT_URI") || "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback"
```

### 步骤 4: 更新 Supabase 配置

文件：`supabase/config.toml`

将：
```toml
additional_redirect_urls = ["https://brewnet.app", "brewnet://"]
```

替换为：
```toml
additional_redirect_urls = ["brewnet://"]
```

### 步骤 5: 重新部署 Edge Functions

```bash
# 重新部署 Exchange 函数（因为代码有变化）
supabase functions deploy linkedin-exchange --no-verify-jwt

# Callback 函数不需要重新部署（代码没变）
```

### 步骤 6: 更新 LinkedIn Developer Portal

1. 登录 [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. 进入你的应用（Client ID: 782dcovcs9zyfv）
3. 在 **Auth** 标签页找到 **Authorized Redirect URLs**
4. **删除**旧的：`https://brewnet.app/auth/linkedin/callback`
5. **添加**新的：`https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`
6. 点击 **Update**

---

## ✅ 验证替换

### 测试 Callback 函数

```bash
curl -s -o /dev/null -w "%{redirect_url}\n" "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=test123&state=test456"
```

**预期输出：**
```
brewnet://auth/linkedin?code=test123&state=test456
```

### 测试完整流程

1. 在 iOS App 中打开 Profile Setup
2. 勾选 LinkedIn consent
3. 点击 "Import from LinkedIn"
4. 完成授权流程
5. 应该看到 "Imported LinkedIn Data"

---

## 📝 需要修改的文件清单

### 必须修改的文件：

1. ✅ `BrewNet/AuthManager.swift` - iOS App 代码
2. ✅ `supabase/functions/linkedin-exchange/index.ts` - Edge Function
3. ✅ `supabase/config.toml` - Supabase 配置
4. ✅ Supabase 环境变量（通过 CLI）
5. ✅ LinkedIn Developer Portal 配置

### 文档文件（可选，不影响功能）：

- `DEPLOY_NOW.md`
- `LINKEDIN_OAUTH_COMPLETE.md`
- `SUPABASE_LINKEDIN_DEPLOYMENT.md`
- `DEPLOYMENT_QUICK_START.md`
- `LINKEDIN_CALLBACK_SETUP.md`
- `deploy-commands.sh`
- `deploy-linkedin-functions.sh`
- `server/README.md`

---

## 🚨 重要注意事项

1. **App Scheme 不变**：`brewnet://` 是 App 的 URL Scheme，**不需要修改**
2. **必须更新 LinkedIn**：LinkedIn Developer Portal 中的 Redirect URL **必须**更新为新域名
3. **环境变量**：确保 Supabase 环境变量已更新
4. **重新部署**：Exchange 函数需要重新部署以应用代码更改

---

## 🔍 替换后的完整 URL

- **Callback URL**: 
  ```
  https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
  ```

- **Token Exchange URL** (在 iOS App 中):
  ```
  https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
  ```

- **App Scheme** (不变):
  ```
  brewnet://auth/linkedin
  ```

---

## 🎯 快速执行脚本

运行以下命令快速完成替换：

```bash
# 1. 更新环境变量
supabase secrets set LINKEDIN_REDIRECT_URI=https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback

# 2. 重新部署 Exchange 函数
supabase functions deploy linkedin-exchange --no-verify-jwt

# 3. 验证
curl -s -o /dev/null -w "%{redirect_url}\n" "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=test&state=test"
```

然后手动更新：
- iOS App 代码（`AuthManager.swift`）
- LinkedIn Developer Portal


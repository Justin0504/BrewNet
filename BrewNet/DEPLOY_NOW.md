# 🚀 LinkedIn OAuth 立即部署指南

## ✅ 步骤 1: 登录 Supabase

在终端运行以下命令（会打开浏览器）：

```bash
supabase login
```

**或者**，如果你有 Supabase Access Token，可以设置环境变量：

```bash
export SUPABASE_ACCESS_TOKEN=你的token
```

获取 Token：https://supabase.com/dashboard/account/tokens

---

## ✅ 步骤 2: 链接项目

```bash
cd /Users/heady/Documents/BrewNet/BrewNet
supabase link --project-ref jcxvdolcdifdghaibspy
```

输入项目数据库密码（在 Supabase Dashboard → Settings → Database 中查看）

---

## ✅ 步骤 3: 设置环境变量

运行以下命令设置 LinkedIn 凭证：

```bash
# 设置 Client ID
supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv

# 设置 Client Secret（请替换为你的实际 secret）
supabase secrets set LINKEDIN_CLIENT_SECRET=YOUR_LINKEDIN_CLIENT_SECRET_HERE

# 设置 Redirect URI
supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

**验证环境变量已设置：**

```bash
supabase secrets list
```

应该看到：
- LINKEDIN_CLIENT_ID
- LINKEDIN_CLIENT_SECRET
- LINKEDIN_REDIRECT_URI

---

## ✅ 步骤 4: 部署 Callback 函数

```bash
supabase functions deploy linkedin-callback --no-verify-jwt
```

**预期输出：**
```
Deploying function linkedin-callback...
Function linkedin-callback deployed successfully!
Function URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
```

---

## ✅ 步骤 5: 部署 Token Exchange 函数

```bash
supabase functions deploy linkedin-exchange --no-verify-jwt
```

**预期输出：**
```
Deploying function linkedin-exchange...
Function linkedin-exchange deployed successfully!
Function URL: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
```

---

## ✅ 步骤 6: 配置 LinkedIn Developer Portal

1. 登录 [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. 进入你的应用（Client ID: 782dcovcs9zyfv）
3. 点击 **Auth** 标签
4. 在 **OAuth 2.0 settings** 中找到 **Authorized Redirect URLs**
5. 点击 **Add redirect URL**
6. 添加以下 URL（二选一）：

   **选项 1（推荐，如果配置了自定义域名）：**
   ```
   https://brewnet.app/auth/linkedin/callback
   ```

   **选项 2（使用 Supabase 默认域名）：**
   ```
   https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
   ```

7. 点击 **Update**

---

## ✅ 步骤 7: 验证部署

### 测试 Callback 函数

```bash
curl "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=test123&state=test456"
```

**预期结果：** 返回 302 重定向，Location 头为：
```
brewnet://auth/linkedin?code=test123&state=test456
```

### 查看函数日志

```bash
# Callback 函数日志
supabase functions logs linkedin-callback

# Exchange 函数日志
supabase functions logs linkedin-exchange
```

---

## ✅ 步骤 8: 测试完整流程

1. 在 iOS App 中打开 Profile Setup
2. 勾选 "I consent to BrewNet accessing my public LinkedIn profile..."
3. 点击 "Import from LinkedIn"
4. 完成 LinkedIn 授权
5. 应该看到 "Imported LinkedIn Data" 显示：
   - Name
   - Headline
   - Email

---

## 🔗 部署后的函数 URL

- **Callback**: 
  ```
  https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
  ```

- **Token Exchange**: 
  ```
  https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
  ```

---

## 🐛 故障排除

### 问题 1: 登录失败

**解决方案：**
- 确保网络连接正常
- 尝试使用 Access Token：`export SUPABASE_ACCESS_TOKEN=你的token`
- 检查 Supabase 账户是否有效

### 问题 2: 链接项目失败

**解决方案：**
- 确认项目 ID 正确：`jcxvdolcdifdghaibspy`
- 检查数据库密码是否正确
- 在 Supabase Dashboard 中重置数据库密码（如果需要）

### 问题 3: 环境变量未生效

**解决方案：**
- 确认变量名拼写正确（区分大小写）
- 重新部署函数：`supabase functions deploy linkedin-exchange --no-verify-jwt`
- 检查 secrets：`supabase secrets list`

### 问题 4: 函数部署失败

**解决方案：**
- 检查函数文件是否存在：`ls supabase/functions/linkedin-callback/index.ts`
- 查看详细错误：`supabase functions deploy linkedin-callback --debug`
- 确保 Deno 版本兼容（Supabase 会自动处理）

### 问题 5: LinkedIn 报错 "redirect_uri does not match"

**解决方案：**
- 确保 LinkedIn Developer Portal 中的 Redirect URL **完全匹配**
- 检查 URL 没有多余的空格或斜杠
- 确保使用 HTTPS（不是 HTTP）

---

## 📊 一键部署脚本

如果你想使用自动化脚本，运行：

```bash
chmod +x deploy-linkedin-functions.sh
./deploy-linkedin-functions.sh
```

**注意：** 脚本会检查环境变量，如果未设置会提示你。

---

## ✅ 完成检查清单

部署完成后，确认以下项目：

- [ ] Supabase CLI 已安装
- [ ] 已登录 Supabase
- [ ] 项目已链接
- [ ] 环境变量已设置（CLIENT_ID, CLIENT_SECRET, REDIRECT_URI）
- [ ] Callback 函数已部署
- [ ] Exchange 函数已部署
- [ ] LinkedIn Redirect URL 已配置
- [ ] 测试 Callback 函数成功
- [ ] 在 iOS App 中测试完整流程成功

---

## 🎉 完成！

部署完成后，你的 LinkedIn OAuth 集成应该可以正常工作了！

如有问题，请查看：
- 函数日志：`supabase functions logs`
- Supabase Dashboard：https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy/edge-functions
- 详细文档：`SUPABASE_LINKEDIN_DEPLOYMENT.md`


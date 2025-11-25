# ✅ 域名替换完成总结

## 🎯 替换结果

**旧域名：** `https://brewnet.app/auth/linkedin/callback`  
**新域名：** `https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`

---

## ✅ 已完成的替换

### 1. iOS App 代码
- ✅ `BrewNet/AuthManager.swift` - 已更新 `redirectURI`

### 2. Supabase Edge Function
- ✅ `supabase/functions/linkedin-exchange/index.ts` - 已更新默认 redirect URI

### 3. Supabase 配置
- ✅ `supabase/config.toml` - 已移除 `https://brewnet.app`，保留 `brewnet://`

### 4. Supabase 环境变量
- ✅ `LINKEDIN_REDIRECT_URI` - 已更新为新域名

### 5. Edge Function 部署
- ✅ `linkedin-exchange` - 已重新部署

---

## 🔗 新的 URL 配置

### Callback URL（LinkedIn 重定向到这里）
```
https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback
```

### Token Exchange URL（iOS App 调用）
```
https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange
```

### App Scheme（不变）
```
brewnet://auth/linkedin
```

---

## ⚠️ 重要：必须手动更新 LinkedIn Developer Portal

### 步骤：

1. **登录** [LinkedIn Developer Portal](https://www.linkedin.com/developers/)

2. **进入你的应用**
   - Client ID: `782dcovcs9zyfv`

3. **更新 Redirect URL**
   - 点击 **Auth** 标签
   - 在 **OAuth 2.0 settings** 中找到 **Authorized Redirect URLs**
   - **删除**旧的：`https://brewnet.app/auth/linkedin/callback`
   - **添加**新的：`https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`
   - 点击 **Update**

4. **验证**
   - 确保新 URL 在列表中
   - 确保旧 URL 已删除

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

## 📋 替换检查清单

- [x] iOS App 代码已更新
- [x] Edge Function 代码已更新
- [x] Supabase 配置已更新
- [x] Supabase 环境变量已更新
- [x] Edge Function 已重新部署
- [ ] **LinkedIn Developer Portal 已更新** ⚠️ **必须手动完成**
- [ ] 完整流程已测试

---

## 🎉 完成！

所有代码和配置已替换完成。**请务必更新 LinkedIn Developer Portal 中的 Redirect URL**，然后测试完整流程。

如有问题，请查看：
- 函数日志：`supabase functions logs linkedin-callback`
- Supabase Dashboard：https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy/functions


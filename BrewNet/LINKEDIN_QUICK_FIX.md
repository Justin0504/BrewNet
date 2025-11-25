# LinkedIn 权限错误快速修复

## 🔍 错误解读

```
Failed to fetch LinkedIn profile: Not enough permissions to access: me.GET.NO_VERSION
Insufficient permissions. Check LinkedIn app scopes.
```

### 错误含义
- **`me.GET.NO_VERSION`**: LinkedIn API 拒绝访问用户信息
- **原因**: LinkedIn 应用未启用 "Sign In with LinkedIn using OpenID Connect" 产品

---

## ⚡ 快速修复（5分钟）

### 步骤 1: 检查 LinkedIn 产品状态

1. 访问：https://www.linkedin.com/developers/apps
2. 点击你的应用（Client ID: `782dcovcs9zyfv`）
3. 点击左侧 **"Products"** 标签
4. 查找 **"Sign In with LinkedIn using OpenID Connect"**

### 步骤 2: 启用产品

**如果显示 "Request Access" 或 "Enable"：**
- 点击按钮
- 填写申请表单（简单描述用途即可）
- 提交申请

**如果显示 "Approved" 或 "Enabled"：**
- ✅ 产品已启用，继续下一步

**如果显示 "Pending"：**
- ⏳ 等待审核（通常 1-3 个工作日）

### 步骤 3: 验证 OAuth 配置

1. 点击 **"Auth"** 标签
2. 检查 **OAuth 2.0 settings** → **Default scopes**
3. 确保包含：
   ```
   openid
   profile
   email
   ```
4. 如果缺少，点击 **"Edit"** 添加

### 步骤 4: 检查应用状态

在应用详情页面顶部，确认状态为：
- ✅ **"Live"** 或 **"Development"**
- ❌ 不是 **"Draft"**

### 步骤 5: 重新测试

1. 在 iOS App 中重新点击 "Import from LinkedIn"
2. 完成授权流程
3. 应该可以成功获取 profile

---

## 🚨 如果产品审核未通过

### 临时方案：检查 endpoint 配置

如果产品已启用但仍然报错，可能需要使用不同的 endpoint。让我检查并更新代码。

---

## ✅ 验证清单

- [ ] "Sign In with LinkedIn using OpenID Connect" 产品已启用
- [ ] OAuth scopes 包含 `openid`, `profile`, `email`
- [ ] 应用状态为 "Live" 或 "Development"
- [ ] Redirect URL 已配置
- [ ] 用户已重新授权

---

## 📞 需要帮助？

如果按照上述步骤操作后仍然失败：
1. 查看 Supabase Dashboard 日志获取详细错误
2. 检查 LinkedIn Developer Portal 中的产品状态
3. 确认所有配置项都已正确设置


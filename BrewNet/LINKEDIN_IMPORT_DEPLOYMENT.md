# LinkedIn 数据导入功能 - 快速部署指南

## ⚡ 快速部署清单

### ✅ 已完成的代码更新

1. **数据库表结构**：`create_linkedin_profiles_tables.sql`
2. **Edge Function**：`supabase/functions/linkedin-import/index.ts`
3. **前端更新**：
   - `AuthManager.swift`：添加导入和确认方法
   - `SupabaseService.swift`：添加数据库操作方法
   - `ProfileSetupView.swift`：添加预览界面和流程

### 🚀 部署步骤

#### 1. 数据库迁移（必须）
```sql
-- 在 Supabase SQL Editor 中执行
-- 文件：create_linkedin_profiles_tables.sql
```

#### 2. 部署 Edge Function（必须）
```bash
# 运行更新后的部署脚本
./deploy-linkedin-functions.sh

# 或者手动部署
supabase functions deploy linkedin-import --no-verify-jwt
```

#### 3. 验证环境变量（必须）
```bash
# 检查是否已设置
supabase secrets list | grep LINKEDIN

# 如果缺失，设置它们
supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv
supabase secrets set LINKEDIN_CLIENT_SECRET=your_secret_here
supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback
```

### 🧪 测试验证

#### 功能测试步骤：
1. 启动 iOS App
2. 进入 Profile Setup → Core Identity
3. 勾选 "I consent..." 复选框
4. 点击 "Sign in with LinkedIn"
5. 完成 LinkedIn OAuth 登录
6. 验证预览界面显示正确数据
7. 确认导入，检查数据是否正确保存

#### 日志检查：
```bash
# 查看函数日志
supabase functions logs linkedin-import

# 查看数据库
# 在 Supabase Dashboard 中检查 linkedin_profiles 表
```

### 🔧 如果遇到问题

#### 常见错误及解决方案：

1. **"Function not found"**
   - 确认 Edge Function 已成功部署
   - 检查函数 URL 是否正确

2. **"Database table doesn't exist"**
   - 确认已运行数据库迁移脚本
   - 检查表是否在正确的 schema 中

3. **LinkedIn OAuth 失败**
   - 检查 LinkedIn 开发者门户权限
   - 确认 redirect URI 配置正确

4. **预览界面不显示**
   - 检查前端通知监听器是否正确设置
   - 查看 Xcode 控制台日志

### 📊 监控要点

- **导入成功率**：在 Supabase Dashboard 中监控
- **错误日志**：定期检查 Edge Function 日志
- **用户反馈**：关注导入流程的用户体验

---

## 🎯 核心功能验证

✅ **OAuth 流程**：LinkedIn 登录和授权
✅ **数据抓取**：成功获取用户资料
✅ **数据清洗**：正确处理和格式化数据
✅ **预览界面**：用户可以查看和编辑数据
✅ **数据确认**：成功保存到数据库
✅ **审计日志**：记录所有操作

**部署完成后，功能即可投入使用！** 🎉

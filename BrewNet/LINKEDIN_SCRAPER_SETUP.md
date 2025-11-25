# LinkedIn Profile Scraper 设置指南

## 概述

由于 LinkedIn API 的权限限制，我们实现了一个 HTML 爬取方案来获取用户的 LinkedIn profile 信息，特别是 `headline` 等字段。

## 功能说明

### 1. 自动爬取（通过 OAuth 登录后）
- 当用户通过 LinkedIn OAuth 登录后，系统会：
  1. 尝试从 API 获取 profile URL
  2. 如果 headline 缺失，自动尝试爬取 LinkedIn profile HTML
  3. 从 HTML 中提取 headline 和其他结构化数据

### 2. 手动输入 Profile URL
- 用户可以在 Core Identity 页面手动输入 LinkedIn profile URL
- 点击 "Fetch" 按钮来爬取数据
- 爬取的数据会与 OAuth 获取的数据合并

## 部署步骤

### 1. 部署 Scraper Function

```bash
cd /Users/heady/Documents/BrewNet/BrewNet
supabase functions deploy linkedin-scraper --no-verify-jwt
```

### 2. 部署更新后的 Exchange Function

```bash
supabase functions deploy linkedin-exchange --no-verify-jwt
```

## 工作流程

### 自动流程（OAuth 登录）
1. 用户点击 "Sign in with LinkedIn"
2. 完成 OAuth 授权
3. `linkedin-exchange` 函数：
   - 从 UserInfo 端点获取基本信息
   - 尝试从 v2 API 获取 headline（可能失败）
   - 如果 headline 缺失，尝试获取或构建 profile URL
   - 调用 `linkedin-scraper` 函数爬取 HTML
   - 从 HTML 中提取 headline 和其他数据
   - 返回完整的数据给前端

### 手动流程（输入 URL）
1. 用户在 Core Identity 页面输入 LinkedIn profile URL
2. 点击 "Fetch" 按钮
3. 前端调用 `linkedin-scraper` 函数
4. Scraper 爬取 HTML 并提取数据
5. 数据与现有 profile 数据合并

## 数据结构

### Scraper 返回的数据结构

```typescript
{
  success: true,
  profileUrl: "https://www.linkedin.com/in/haiyue-zhang-a0139b351/",
  data: {
    headline?: string,           // 职业标题
    location?: string,            // 位置
    about?: string,              // 关于我
    experience?: Array<{         // 工作经历
      title?: string,
      company?: string,
      duration?: string
    }>,
    education?: Array<{          // 教育背景
      school?: string,
      degree?: string,
      field?: string,
      duration?: string
    }>,
    skills?: string[]            // 技能
  }
}
```

## 注意事项

### ⚠️ 重要警告

1. **LinkedIn 服务条款**
   - LinkedIn 可能不允许爬取其网站内容
   - 此功能仅用于获取用户自己的数据
   - 请确保遵守 LinkedIn 的使用条款

2. **反爬虫机制**
   - LinkedIn 可能有反爬虫保护
   - 如果请求被阻止，会返回错误信息
   - 可能需要添加更多 headers 或使用代理

3. **HTML 结构变化**
   - LinkedIn 可能随时更改其 HTML 结构
   - 如果爬取失败，可能需要更新解析逻辑

4. **Rate Limiting**
   - 避免频繁请求同一 profile
   - 实现适当的缓存机制

## 故障排除

### 问题 1: Scraper 返回 403 Forbidden

**原因**: LinkedIn 阻止了请求

**解决方案**:
1. 检查 User-Agent header 是否正确
2. 尝试添加更多 headers（如 Referer）
3. 考虑使用代理服务器

### 问题 2: 无法解析 HTML

**原因**: LinkedIn 的 HTML 结构可能已更改

**解决方案**:
1. 检查日志中的 HTML 响应
2. 更新 `parseLinkedInHTML` 函数中的选择器
3. 尝试使用不同的解析方法（如 JSON-LD）

### 问题 3: Profile URL 无法获取

**原因**: API 不返回 profile URL

**解决方案**:
1. 让用户手动输入 profile URL
2. 尝试从其他来源获取（如用户的 email signature）

## 测试

### 测试 Scraper Function

```bash
curl -X POST https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-scraper \
  -H "Content-Type: application/json" \
  -d '{"profileUrl": "https://www.linkedin.com/in/haiyue-zhang-a0139b351/"}'
```

### 测试完整流程

1. 在 App 中进入 Core Identity 页面
2. 勾选 LinkedIn 同意框
3. 点击 "Sign in with LinkedIn"
4. 完成授权后，检查是否成功获取 headline
5. 如果失败，尝试手动输入 profile URL 并点击 "Fetch"

## 日志查看

查看 Supabase Dashboard 中的函数日志：
- `linkedin-exchange`: https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy/functions/linkedin-exchange/logs
- `linkedin-scraper`: https://supabase.com/dashboard/project/jcxvdolcdifdghaibspy/functions/linkedin-scraper/logs

## 未来改进

1. **更好的 HTML 解析**
   - 使用更健壮的解析库
   - 支持更多数据字段

2. **缓存机制**
   - 缓存已爬取的 profile 数据
   - 避免重复请求

3. **错误处理**
   - 更详细的错误信息
   - 自动重试机制

4. **数据验证**
   - 验证爬取的数据格式
   - 清理和标准化数据




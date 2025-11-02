# BrewNet 头像上传配置指南

## 📋 概述

本文档说明如何配置 Supabase Storage 以支持用户头像上传功能。

---

## 🎯 配置步骤

### 步骤 1: 创建存储桶

1. **登录 Supabase Dashboard**
   - 访问: https://supabase.com/dashboard
   - 选择您的项目: `jcxvdolcdifdghaibspy`

2. **进入 Storage 页面**
   - 在左侧菜单中点击 "Storage"
   - 点击 "Buckets" 标签

3. **创建新存储桶**
   - 点击 "New bucket" 按钮
   - 填写以下信息：
     ```
     Name: avatars
     Public bucket: ✅ Enabled (开启公共访问)
     File size limit: 5 MB (可选)
     Allowed MIME types: image/jpeg,image/png,image/webp,image/gif (可选)
     ```
   - 点击 "Create bucket"

---

### 步骤 2: 配置存储策略

在 Supabase Dashboard 的 **Storage > Policies** 中创建以下策略：

#### Policy 1: Users can upload their own avatars

```
Policy name: "Users can upload their own avatars"
Bucket: avatars
Target roles: Authenticated
Operation: INSERT

Policy definition:
bucket_id = 'avatars'

Policy with check:
bucket_id = 'avatars' AND owner_id = auth.uid()
```

#### Policy 2: Users can update their own avatars

```
Policy name: "Users can update their own avatars"
Bucket: avatars
Target roles: Authenticated
Operation: UPDATE

Policy definition:
bucket_id = 'avatars' AND owner_id = auth.uid()

Policy with check:
bucket_id = 'avatars' AND owner_id = auth.uid()
```

#### Policy 3: Users can delete their own avatars

```
Policy name: "Users can delete their own avatars"
Bucket: avatars
Target roles: Authenticated
Operation: DELETE

Policy definition:
bucket_id = 'avatars' AND owner_id = auth.uid()
```

#### Policy 4: Anyone can view avatars (public access)

```
Policy name: "Anyone can view avatars"
Bucket: avatars
Target roles: Public
Operation: SELECT

Policy definition:
bucket_id = 'avatars'
```

---

## 📁 文件路径结构

### 推荐的路径格式

```
{user_id}/avatar.{extension}
```

**示例：**
```
dbb4d116-84f0-4ba5-82f5-161f27976bb8/avatar.jpg
550e8400-e29b-41d4-a716-446655440000/avatar.png
```

### 为什么使用这种结构？

1. **用户隔离**：每个用户的文件在独立文件夹中
2. **易于管理**：可以轻松删除某个用户的所有文件
3. **符合 RLS 策略**：策略通过检查 `foldername[1]` 来验证用户 ID

---

## 🔗 公共 URL 格式

上传后的文件可以通过以下 URL 访问：

```
https://{project-url}/storage/v1/object/public/avatars/{user_id}/avatar.{ext}
```

**实际示例：**
```
https://jcxvdolcdifdghaibspy.supabase.co/storage/v1/object/public/avatars/dbb4d116-84f0-4ba5-82f5-161f27976bb8/avatar.jpg
```

---

## ✅ 验证配置

运行验证 SQL 脚本：

```sql
-- 检查存储桶是否存在
SELECT name, public, file_size_limit 
FROM storage.buckets 
WHERE name = 'avatars';

-- 检查策略是否配置
SELECT 
    name,
    bucket_id,
    definition,
    check_definition
FROM storage.policies
WHERE bucket_id = 'avatars';
```

或直接运行：
```bash
sql/BrewNet/supabase_storage_setup.sql
```

---

## 🛡️ 安全建议

### 1. 文件大小限制

推荐设置最大文件大小为 **5MB**，防止用户上传过大的图片。

### 2. 文件类型限制

只允许图片类型：
- `image/jpeg` (.jpg, .jpeg)
- `image/png` (.png)
- `image/webp` (.webp)
- `image/gif` (.gif)

### 3. 图片验证

在应用端应该：
- 验证文件大小
- 验证文件类型
- 压缩图片（可选）
- 验证图片尺寸

---

## 📱 应用集成

### iOS 端实现

图片上传逻辑已在 `ProfileSetupView.swift` 的 `CoreIdentityStep` 中实现：

1. **用户选择图片**：使用 `PhotosPicker`
2. **显示预览**：在界面上显示选择的图片
3. **上传到 Storage**：将图片上传到 Supabase Storage
4. **保存 URL**：将公共 URL 保存到 `profiles.core_identity.profileImage`

### 下一步

需要在 `SupabaseService` 中添加图片上传方法：

```swift
func uploadProfileImage(userId: String, imageData: Data) async throws -> String {
    // TODO: 实现图片上传到 Supabase Storage
}
```

---

## 🔍 故障排除

### 问题 1: 无法上传图片

**可能原因：**
- 存储桶未创建
- 策略未配置
- 认证失败

**解决方案：**
1. 检查存储桶是否存在
2. 验证策略配置
3. 检查用户是否已登录

### 问题 2: 无法访问图片 URL

**可能原因：**
- 存储桶不是 public
- URL 格式不正确

**解决方案：**
1. 确认存储桶的 "Public bucket" 选项已启用
2. 验证 URL 格式正确

### 问题 3: 权限错误

**可能原因：**
- RLS 策略配置错误
- 文件路径不符合策略要求

**解决方案：**
1. 检查策略的 policy definition
2. 确保文件路径格式为 `{user_id}/filename`

---

## 📚 相关资源

- [Supabase Storage 文档](https://supabase.com/docs/guides/storage)
- [Storage Policies 配置指南](https://supabase.com/docs/guides/storage/policies)
- [JavaScript Storage API](https://supabase.com/docs/reference/javascript/storage)

---

## ⚠️ 重要提示

1. **公共存储桶**：头像存储桶设置为 public 以便在应用中显示
2. **路径规范**：严格按照 `{user_id}/filename` 格式
3. **文件清理**：考虑实现定期清理未使用头像的功能
4. **CDN 优化**：Supabase 会自动使用 CDN 加速图片访问

---

**配置完成后，用户可以在 Profile Setup 中上传头像！**


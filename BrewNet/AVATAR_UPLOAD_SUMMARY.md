# 头像上传功能实现总结

## 📋 概述

已完成头像上传功能实现，包括：
1. Supabase Storage 配置脚本
2. iOS 端上传逻辑
3. UI 交互和状态管理

---

## ✅ 已完成的功能

### 1. Supabase Storage 配置

**文件：** `supabase_storage_setup.sql`

- 存储桶验证 SQL
- 配置说明文档
- 注意事项与故障排除

**需要在 Supabase Dashboard 中手动配置：**

1. 创建存储桶：
   - Storage > Buckets > New bucket
   - Name: `avatars`
   - Public bucket: ✅ Enabled

2. 配置策略（Storage > Policies）：
   - Users can upload their own avatars (INSERT)
   - Users can update their own avatars (UPDATE)
   - Users can delete their own avatars (DELETE)
   - Anyone can view avatars (SELECT)

### 2. iOS 代码实现

#### SupabaseService.swift

**新增方法：**

```swift
/// 上传用户头像到 Supabase Storage
func uploadProfileImage(userId: String, imageData: Data, fileExtension: String = "jpg") async throws -> String {
    // 上传到 avatars bucket
    // 返回公共 URL
}

/// 删除用户头像
func deleteProfileImage(userId: String) async throws {
    // 从 avatars bucket 删除
}
```

**特性：**
- 自动检测图片格式（JPEG、PNG、GIF、WebP）
- 文件路径：`{userId}/avatar.{ext}`
- 公共 URL 自动生成
- 错误处理和日志记录

#### ProfileSetupView.swift

**修改的组件：**

```swift
struct CoreIdentityStep: View {
    // 新增状态管理
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImageData: Data? = nil
    @State private var profileImageURL: String? = nil
    @State private var isUploadingImage = false
}
```

**功能：**
- 图片选择（PhotosPicker）
- 实时预览
- 立即上传
- 上传进度指示
- 删除头像
- 格式检测
- 状态管理

---

## 📁 文件结构

### 新增文件

1. `BrewNet/supabase_storage_setup.sql`
   - Storage 配置验证脚本

2. `BrewNet/STORAGE_SETUP_GUIDE.md`
   - Storage 配置指南

3. `BrewNet/AVATAR_UPLOAD_SUMMARY.md`
   - 功能总结（本文档）

### 修改文件

1. `BrewNet/BrewNet/SupabaseService.swift`
   - 新增 Storage 操作方法

2. `BrewNet/BrewNet/ProfileSetupView.swift`
   - 新增头像上传 UI 和逻辑

---

## 🔄 工作流程

### 用户上传头像流程

1. 用户点击 "Choose Photo"
2. 选择图片后立即加载到 `profileImageData`
3. 检测图片格式（JPEG、PNG、GIF、WebP）
4. 显示上传进度指示器
5. 上传到 Supabase Storage：`avatars/{userId}/avatar.{ext}`
6. 获取公共 URL
7. 保存 URL 到 `profileImageURL`
8. 更新 UI 显示图片

### 数据流程

```
用户选择图片
    ↓
profileImageData (Data)
    ↓
上传到 Supabase Storage
    ↓
获取公共 URL
    ↓
profileImageURL (String)
    ↓
保存到 CoreIdentity.profileImage
    ↓
存储在 profiles.core_identity JSONB
```

---

## 🔗 公共 URL 格式

```
https://jcxvdolcdifdghaibspy.supabase.co/storage/v1/object/public/avatars/{userId}/avatar.{ext}
```

**示例：**
```
https://jcxvdolcdifdghaibspy.supabase.co/storage/v1/object/public/avatars/dbb4d116-84f0-4ba5-82f5-161f27976bb8/avatar.jpg
```

---

## 🛡️ 安全与限制

### RLS 策略

- 用户只能上传/更新/删除自己的头像
- 所有人可以查看所有头像（公共访问）
- 通过 `auth.uid()` 验证用户身份
- 文件路径必须为 `{userId}/filename`

### 文件限制

- 推荐最大文件大小：5MB
- 支持格式：JPEG、PNG、GIF、WebP
- 推荐尺寸：400x400 像素

---

## 🎨 UI 特性

### 上传状态指示

- **正常状态：** "Choose Photo" 按钮
- **上传中：** "Uploading..." + ProgressView
- **上传完成：** 显示图片 + "Remove" 按钮

### 图片显示优先级

1. 新选择的图片（`profileImageData`）
2. 已上传的图片（`profileImageURL`）
3. 默认头像图标

---

## 🐛 故障排除

### 问题：无法上传图片

**可能原因：**
- 存储桶未创建
- 策略未配置
- 用户未登录

**解决方案：**
1. 检查 Supabase Dashboard Storage 配置
2. 验证 RLS 策略
3. 确认用户已登录

### 问题：图片无法显示

**可能原因：**
- 存储桶不是 public
- URL 格式错误
- 网络问题

**解决方案：**
1. 确认存储桶的 "Public bucket" 选项已启用
2. 验证 URL 格式
3. 检查网络连接

### 问题：权限错误

**可能原因：**
- RLS 策略配置错误
- 文件路径不符合规范

**解决方案：**
1. 检查策略的 policy definition
2. 确保文件路径为 `{userId}/filename` 格式

---

## 📝 下一步

### 待实现功能

1. 图片压缩：上传前压缩大图片
2. 图片裁剪：提供裁剪功能
3. 多种尺寸：生成缩略图
4. 缓存优化：本地缓存头像
5. 批量上传：支持多张图片

### 优化建议

1. 添加图片尺寸验证
2. 支持 GIF 动画
3. 添加图片编辑工具
4. 实现图片懒加载
5. 添加 CDN 加速配置

---

## 📚 相关文档

- [Supabase Storage 文档](https://supabase.com/docs/guides/storage)
- [Storage Policies 配置](https://supabase.com/docs/guides/storage/policies)
- [Supabase Swift SDK Storage API](https://supabase.com/docs/reference/swift/storage)

---

**头像上传功能已完全实现！** 🎉

用户可以：
1. ✅ 选择并上传头像
2. ✅ 实时查看上传进度
3. ✅ 删除已有头像
4. ✅ 头像自动保存到 Supabase
5. ✅ 在多设备间同步头像


# 📸 照片保存和加载故障排查指南

## 问题描述
- ✅ 图片文件上传到了 Storage (avatars/photos 文件夹)
- ❌ Save 后退出再进入 Edit Profile，照片没有显示
- ❌ 照片的 caption (文字说明) 没有保存

## 🔍 排查步骤

### 步骤 1: 检查数据库字段是否存在

在 Supabase SQL Editor 中运行：

```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('work_photos', 'lifestyle_photos')
ORDER BY column_name;
```

**预期结果**：应该看到两个字段
```
column_name         | data_type | column_default
--------------------|-----------|----------------------------------
lifestyle_photos    | jsonb     | '{"photos": []}'::jsonb
work_photos         | jsonb     | '{"photos": []}'::jsonb
```

**如果字段不存在**：运行数据库迁移
```sql
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS work_photos JSONB DEFAULT '{"photos": []}'::jsonb,
ADD COLUMN IF NOT EXISTS lifestyle_photos JSONB DEFAULT '{"photos": []}'::jsonb;
```

---

### 步骤 2: 检查数据是否保存到数据库

运行以下查询，查看你的 profile 数据：

```sql
-- 替换 'your-user-id' 为你的实际 user_id
SELECT 
    user_id,
    work_photos,
    lifestyle_photos,
    updated_at
FROM profiles
WHERE user_id = 'your-user-id';
```

或者查看所有最近更新的 profiles：

```sql
SELECT 
    user_id,
    jsonb_pretty(work_photos) as work_photos_formatted,
    jsonb_pretty(lifestyle_photos) as lifestyle_photos_formatted,
    updated_at
FROM profiles
ORDER BY updated_at DESC
LIMIT 3;
```

**预期结果示例**：
```json
{
  "photos": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "image_url": "https://xxx.supabase.co/storage/v1/object/public/avatars/user-id/photos/work_photo_xxx.jpg",
      "caption": "Working on a new project"
    }
  ]
}
```

**可能的问题**：

#### A. 字段值为 `null`
说明数据没有保存到数据库。检查 App 日志。

#### B. 字段值为 `{"photos": []}`
说明数据结构正确，但照片数组为空。可能原因：
- `profileData.workPhotos` 或 `profileData.lifestylePhotos` 在保存时为空
- `updateProfileData()` 函数没有正确收集照片数据

#### C. 字段有值，但格式错误
比如：
```json
// 错误格式 (使用了 camelCase)
{
  "photos": [
    {
      "id": "xxx",
      "imageUrl": "...",  // ❌ 应该是 image_url
      "caption": "..."
    }
  ]
}
```

这是 CodingKeys 配置问题。检查 `ProfileModels.swift` 中 Photo 的 CodingKeys。

---

### 步骤 3: 查看 App 日志

上传照片并点击 Save 后，在 Xcode Console 中查找以下日志：

#### 上传照片时：
```
📤 Uploading photo for user: xxx, fileName: work_photo_xxx.jpg
✅ [work] 图片上传成功，URL: https://...
💾 updateProfileData() 被调用，当前类型: Work Photos
💾 [Work][0] 保存: URL=https://..., Caption=My caption
💾 最终 Work Photos 数量: 1
```

#### 保存到数据库时：
```
💾 saveCurrentStep() called for step 6
🔄 Updating existing profile...
📸 [updateProfile] 准备保存 Work Photos: 1 张
   [0] id=xxx, url=https://..., caption=My caption
📸 Work Photos 转换为字典成功
🔄 Updating profile with SDK .update() method...
✅ Profile updated in database successfully
```

#### 重新加载数据时：
```
🔄 Reloading saved profile data...
✅ Profile data reloaded from saved profile
🔄 profileData.workPhotos 变化，重新加载...
📥 loadExistingPhotos() 被调用，selectedPhotoType: Work Photos
📥 加载了 1 张 Work Photos
📥 当前类型 [Work Photos] 有 1 张照片
📥 [Work Photos][0] 加载图片: https://...
📥 loadExistingPhotos() 完成，uploadedImageURLs 数量: 1
```

**常见错误日志**：

#### 错误 1: Caption 没有保存
```
💾 [Work][0] 保存: URL=https://..., Caption=nil  // ❌ Caption 是 nil
```
**原因**：`captions[index]` 数组没有更新，或者在 `updateProfileData()` 时没有包含 caption。

#### 错误 2: 照片数组为空
```
💾 最终 Work Photos 数量: 0  // ❌ 应该 > 0
```
**原因**：`uploadedImageURLs` 字典为空，或者 `updateProfileData()` 逻辑有问题。

#### 错误 3: 数据库更新失败
```
❌ Failed to update profile via SDK: ...
```
**原因**：数据库错误或网络问题。查看错误详情。

#### 错误 4: 重新加载时没有数据
```
📥 加载了 0 张 Work Photos  // ❌ 应该 > 0
```
**原因**：
- 数据库中没有保存成功
- `SupabaseProfile` 解码失败
- `profileData.workPhotos` 为 nil

---

### 步骤 4: 验证 Photo 模型的 CodingKeys

打开 `ProfileModels.swift`，确认 `Photo` 结构体的 CodingKeys 正确：

```swift
struct Photo: Codable, Equatable, Identifiable {
    let id: String
    var imageUrl: String?
    var caption: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"  // ⭐ 必须是 snake_case
        case caption
    }
    // ...
}
```

**关键点**：
- `imageUrl` 在代码中使用 camelCase
- 但在 JSON 中必须是 `image_url` (snake_case)
- Supabase 使用 snake_case

---

### 步骤 5: 测试完整流程

#### 测试 A: 上传一张工作照片并保存

1. 打开 App，进入 Profile Setup Step 6
2. 选择 "Work Photos"
3. 上传一张照片
4. 在 caption 输入框输入 "Test work photo"
5. 点击 "Save"
6. **检查日志**：
   ```
   💾 [Work][0] 保存: URL=https://..., Caption=Test work photo
   📸 [updateProfile] 准备保存 Work Photos: 1 张
   ```
7. **检查数据库**：
   ```sql
   SELECT work_photos FROM profiles WHERE user_id = 'your-user-id';
   ```
8. **关闭 App 并重新打开**
9. 进入 Edit Profile → Step 6
10. **预期结果**：应该看到刚才上传的照片和 caption

#### 测试 B: 切换照片类型

1. 在 Step 6 上传一张 Work Photo，caption 为 "Work"
2. 切换到 "Lifestyle Photos"
3. 上传一张 Lifestyle Photo，caption 为 "Lifestyle"
4. 点击 "Save"
5. **检查日志**：
   ```
   💾 最终 Work Photos 数量: 1
   💾 最终 Lifestyle Photos 数量: 1
   ```
6. **关闭 App 并重新打开**
7. 进入 Edit Profile → Step 6
8. **预期结果**：
   - Work Photos 标签下应该看到 Work 照片
   - Lifestyle Photos 标签下应该看到 Lifestyle 照片

---

## 🔧 修复方案

### 修复 1: 确保 updateProfileData() 在合适的时机被调用

已修改的代码确保在以下时机调用 `updateProfileData()`:
- ✅ 照片上传完成后
- ✅ 用户输入 caption 后
- ✅ 用户删除照片后

### 修复 2: 正确同步 UI 状态到数据模型

`updateProfileData()` 函数现在会：
1. 遍历 `uploadedImageURLs` 字典
2. 为每个 URL 创建 `Photo` 对象
3. 从 `captions` 数组中获取对应的 caption
4. 更新 `workPhotos` 或 `lifestylePhotos` 数组
5. 保存到 `profileData`

### 修复 3: 保存后自动重新加载数据

`saveCurrentStep()` 现在会：
1. 保存数据到数据库
2. 从数据库返回的数据重新加载到 `profileData`
3. 触发 UI 更新

### 修复 4: 响应数据变化自动刷新 UI

添加了 `.onChange` 监听器：
```swift
.onChange(of: profileData.workPhotos) { _ in
    loadExistingPhotos()
}
.onChange(of: profileData.lifestylePhotos) { _ in
    loadExistingPhotos()
}
```

---

## 📝 已修改的文件

1. **ProfileSetupView.swift**
   - 修改了 `updateProfileData()` 函数（第 3250-3302 行）
   - 添加了 `.onChange` 监听器（第 3066-3075 行）
   - 增强了 `loadExistingPhotos()` 的日志（第 3100-3147 行）
   - 修改了 `saveCurrentStep()` 重新加载数据（第 472-493 行）

2. **SupabaseService.swift**
   - 在 `updateProfile()` 函数中添加了详细的调试日志（第 977-1011 行）

---

## ✅ 验证清单

在宣布问题解决前，请确认：

- [ ] 数据库中有 `work_photos` 和 `lifestyle_photos` 字段
- [ ] 上传照片后，App 日志显示正确的 URL 和 caption
- [ ] 点击 Save 后，数据库中可以看到照片数据（使用 SQL 查询）
- [ ] 关闭 App 重新打开后，Edit Profile 中可以看到已保存的照片
- [ ] 照片的 caption 正确显示
- [ ] 可以切换 Work Photos 和 Lifestyle Photos，两种都正确显示

---

## 🆘 仍然无法解决？

如果按照上述步骤仍然无法解决，请提供以下信息：

1. **数据库查询结果**：
   ```sql
   SELECT work_photos, lifestyle_photos FROM profiles WHERE user_id = 'your-user-id';
   ```

2. **App 完整日志**（从上传照片到保存完成）

3. **具体的错误现象**：
   - 照片完全不显示？
   - 照片显示但 caption 丢失？
   - 只有一种类型的照片丢失？
   - 保存时有错误提示吗？

4. **Xcode Console 中的错误信息**

---

## 📚 相关文件

- `/Users/justin/BrewNet-Fresh/BrewNet/BrewNet/ProfileSetupView.swift`
- `/Users/justin/BrewNet-Fresh/BrewNet/BrewNet/ProfileModels.swift`
- `/Users/justin/BrewNet-Fresh/BrewNet/BrewNet/SupabaseService.swift`
- `/Users/justin/BrewNet-Fresh/BrewNet/check_photos_data.sql`
- `/Users/justin/BrewNet-Fresh/BrewNet/migrate_photos_complete.sql`


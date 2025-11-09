# Work & Lifestyle Photos 迁移文档

## 概述
将原来的 `Moments` 板块替换为 `Work Photos` 和 `Lifestyle Photos` 两个独立的照片集合。

## 主要变更

### 1. 数据模型变更 (ProfileModels.swift)

#### 删除：
- `struct Moments`
- `struct Moment`

#### 新增：
- `struct PhotoCollection` - 照片集合容器
- `struct Photo` - 单个照片模型
- `enum PhotoType` - 照片类型（Work / Lifestyle）

#### 字段变更：
```swift
// BrewNetProfile
- let moments: Moments?
+ let workPhotos: PhotoCollection?
+ let lifestylePhotos: PhotoCollection?

// ProfileCreationData
- var moments: Moments?
+ var workPhotos: PhotoCollection?
+ var lifestylePhotos: PhotoCollection?
```

### 2. UI 变更 (ProfileSetupView.swift)

#### Step 6 标题和描述：
- 标题：从 "Highlights" 改为 "Work & Lifestyle Photos"
- 描述：从 "Share your highlights - upload up to 6 photos with captions" 改为 "Share your work and lifestyle - up to 10 photos each"

#### 新功能：
- 添加了照片类型选择器（Segmented Control）
- 支持两个独立的照片集合
- 每个集合最多 10 张照片（原来是 6 张）
- 照片类型切换时自动加载对应的照片

#### 组件重命名：
- `MomentsStep` → `WorkAndLifestylePhotosStep`

### 3. 数据库变更 (update_photos_schema.sql)

#### 新字段：
```sql
ALTER TABLE profiles
ADD COLUMN work_photos JSONB DEFAULT '{"photos": []}'::jsonb,
ADD COLUMN lifestyle_photos JSONB DEFAULT '{"photos": []}'::jsonb;
```

#### 数据结构：
```json
{
  "photos": [
    {
      "id": "uuid",
      "image_url": "https://...",
      "caption": "..."
    }
  ]
}
```

### 4. Supabase 集成变更

#### SupabaseModels.swift：
```swift
struct SupabaseProfile {
    - let moments: Moments?
    + let workPhotos: PhotoCollection?
    + let lifestylePhotos: PhotoCollection?
}
```

#### SupabaseService.swift：
- 更新 `uploadMomentImage()` 函数：
  - 文件路径从 `{userId}/moments/{fileName}` 改为 `{userId}/photos/{fileName}`
  - 日志信息更新

### 5. 其他文件变更

#### ProfileDisplayView.swift：
- 更新所有 SupabaseProfile 创建时的字段名

## 数据迁移指南

### 选项 1：保留旧数据
如果需要将现有的 moments 数据迁移到 work_photos：

```sql
UPDATE profiles
SET work_photos = moments
WHERE moments IS NOT NULL;
```

### 选项 2：清理旧数据
如果不需要保留旧数据，可以删除 moments 字段：

```sql
ALTER TABLE profiles DROP COLUMN IF EXISTS moments;
```

## 文件名命名规则

### 新的文件命名格式：
- Work Photos: `work_photo_{userId}_{uuid}.jpg`
- Lifestyle Photos: `lifestyle_photo_{userId}_{uuid}.jpg`

### 旧的文件命名格式（已废弃）：
- Moments: `moment_{userId}_{uuid}.jpg`

## 功能对比

| 功能 | Moments (旧) | Work & Lifestyle Photos (新) |
|------|-------------|------------------------------|
| 照片集合数量 | 1 个 | 2 个（独立） |
| 每个集合最大照片数 | 6 张 | 10 张 |
| 分类 | 无 | Work / Lifestyle |
| 切换方式 | N/A | Segmented Control |
| 存储路径 | {userId}/moments/ | {userId}/photos/ |

## 测试清单

- [ ] 新用户创建 Work Photos
- [ ] 新用户创建 Lifestyle Photos
- [ ] 上传多张照片（最多 10 张）
- [ ] 切换照片类型
- [ ] 删除照片
- [ ] 编辑照片标题
- [ ] 保存并加载 Work Photos
- [ ] 保存并加载 Lifestyle Photos
- [ ] 数据库正确存储 JSON 结构

## 注意事项

1. **向后兼容性**：旧的 `moments` 字段暂时保留在数据库中，确保现有数据不丢失
2. **存储空间**：每个用户最多可以上传 20 张照片（2 个集合 × 10 张）
3. **文件管理**：旧的 moments 图片仍然存在于 `{userId}/moments/` 路径下
4. **UI 状态**：切换照片类型时会重置当前页面索引

## 后续工作

- [ ] 在 Profile 展示页面添加 Work Photos 和 Lifestyle Photos 的显示
- [ ] 考虑是否需要迁移现有用户的 moments 数据
- [ ] 决定是否删除旧的 moments 字段和相关代码
- [ ] 更新 API 文档（如果有）


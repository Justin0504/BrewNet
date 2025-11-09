# 📊 数据库迁移指南

## 目标
将照片系统从单一的 `moments` 字段迁移到 `work_photos` 和 `lifestyle_photos` 两个独立字段。

## 🚀 执行步骤

### 1. 登录 Supabase Dashboard
1. 访问 [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. 选择你的 BrewNet 项目
3. 点击左侧菜单的 **SQL Editor**

### 2. 执行迁移 SQL

#### 方法 A：一键执行完整迁移（推荐）
1. 在 SQL Editor 中，点击 **New Query**
2. 复制 `migrate_photos_complete.sql` 的全部内容
3. 粘贴到编辑器中
4. 点击 **Run** 按钮执行

#### 方法 B：逐步执行（更安全）

**第一步：添加新字段**
```sql
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS work_photos JSONB DEFAULT '{"photos": []}'::jsonb,
ADD COLUMN IF NOT EXISTS lifestyle_photos JSONB DEFAULT '{"photos": []}'::jsonb;
```

**第二步：添加注释**
```sql
COMMENT ON COLUMN profiles.work_photos IS 'Work-related photos collection (up to 10 photos)';
COMMENT ON COLUMN profiles.lifestyle_photos IS 'Lifestyle photos collection (up to 10 photos)';
```

**第三步：验证字段是否创建成功**
```sql
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('work_photos', 'lifestyle_photos')
ORDER BY column_name;
```

你应该看到类似这样的结果：
```
column_name         | data_type | column_default
--------------------|-----------|----------------------------------
lifestyle_photos    | jsonb     | '{"photos": []}'::jsonb
work_photos         | jsonb     | '{"photos": []}'::jsonb
```

### 3. 验证迁移结果

在 SQL Editor 中运行：
```sql
-- 查看表结构
\d profiles

-- 或者使用标准 SQL
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('work_photos', 'lifestyle_photos');
```

### 4. （可选）迁移现有 moments 数据

如果你有现有的 moments 数据想要保留：
```sql
UPDATE profiles
SET work_photos = moments
WHERE moments IS NOT NULL 
  AND moments != 'null'::jsonb 
  AND work_photos = '{"photos": []}'::jsonb;
```

### 5. （可选）删除旧的 moments 字段

⚠️ **警告：只有在确认所有数据迁移成功后才执行此步骤！**

```sql
-- 首先检查数据
SELECT user_id, moments, work_photos, lifestyle_photos 
FROM profiles 
WHERE moments IS NOT NULL 
LIMIT 5;

-- 如果确认无误，删除旧字段
ALTER TABLE profiles DROP COLUMN IF EXISTS moments;
```

## 📝 数据结构说明

### work_photos 和 lifestyle_photos 格式

```json
{
  "photos": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "image_url": "https://xxxx.supabase.co/storage/v1/object/public/avatars/user-id/photos/work_1.jpg",
      "caption": "Working on a new project"
    },
    {
      "id": "650e8400-e29b-41d4-a716-446655440001",
      "image_url": "https://xxxx.supabase.co/storage/v1/object/public/avatars/user-id/photos/work_2.jpg",
      "caption": "Team meeting"
    }
  ]
}
```

### 字段特点
- 每个字段最多存储 **10 张照片**
- 默认值：`{"photos": []}`
- 类型：JSONB
- 可为空：No

## ✅ 验证清单

迁移完成后，请确认：

- [ ] `work_photos` 字段已创建
- [ ] `lifestyle_photos` 字段已创建
- [ ] 两个字段的默认值都是 `{"photos": []}`
- [ ] 两个字段的类型都是 JSONB
- [ ] 字段注释已添加
- [ ] 如果有旧数据，已成功迁移到新字段
- [ ] App 可以正常创建和读取 profile

## 🔧 故障排除

### 问题 1：字段创建失败
**错误信息**: `permission denied for table profiles`

**解决方案**: 确保你使用的是数据库管理员账户，或者在 Supabase Dashboard 的 SQL Editor 中执行。

### 问题 2：默认值格式错误
**错误信息**: `invalid input syntax for type json`

**解决方案**: 确保使用正确的格式：
```sql
'{"photos": []}'::jsonb
```

### 问题 3：App 读取数据失败
**排查步骤**:
1. 检查 `SupabaseModels.swift` 中的 `CodingKeys` 是否正确：
   ```swift
   case workPhotos = "work_photos"
   case lifestylePhotos = "lifestyle_photos"
   ```
2. 检查 `SupabaseService.swift` 中的字段名是否匹配
3. 在 Supabase Dashboard 的 Table Editor 中手动查看数据

## 📞 需要帮助？

如果遇到问题：
1. 检查 Supabase Dashboard 的 Logs 部分
2. 在 SQL Editor 中运行验证查询
3. 查看 App 的 console 日志

## 🎉 完成！

迁移完成后，你的 BrewNet App 将支持：
- ✅ 独立的工作照片集合（最多 10 张）
- ✅ 独立的生活照片集合（最多 10 张）
- ✅ 更清晰的数据结构
- ✅ 更好的用户体验


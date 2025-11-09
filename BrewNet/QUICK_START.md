# 🚀 快速开始：数据库迁移

## 只需 3 步完成迁移！

### 第 1 步：打开 Supabase SQL Editor

1. 访问 https://supabase.com/dashboard
2. 选择你的 BrewNet 项目
3. 点击左侧的 **SQL Editor**

### 第 2 步：执行这段 SQL（复制粘贴）

```sql
-- 添加新字段
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS work_photos JSONB DEFAULT '{"photos": []}'::jsonb,
ADD COLUMN IF NOT EXISTS lifestyle_photos JSONB DEFAULT '{"photos": []}'::jsonb;

-- 添加注释
COMMENT ON COLUMN profiles.work_photos IS 'Work-related photos (up to 10)';
COMMENT ON COLUMN profiles.lifestyle_photos IS 'Lifestyle photos (up to 10)';
```

点击 **Run** 按钮执行。

### 第 3 步：验证是否成功

在 SQL Editor 中运行：

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('work_photos', 'lifestyle_photos');
```

**期望结果：**
```
column_name         | data_type
--------------------|----------
lifestyle_photos    | jsonb
work_photos         | jsonb
```

## ✅ 完成！

如果看到上面的结果，说明迁移成功！现在你可以：

1. 在 Xcode 中运行 App
2. 创建新的 profile
3. 上传 Work Photos 和 Lifestyle Photos（每个最多 10 张）

## 🆘 遇到问题？

查看详细文档：
- 📖 `DATABASE_MIGRATION_GUIDE.md` - 完整迁移指南
- 🔍 `verify_migration.sql` - 详细验证脚本
- 📝 `WORK_LIFESTYLE_PHOTOS_MIGRATION.md` - 技术变更文档

## 📌 重要提示

- ⚠️ 这个迁移**不会删除**旧的 `moments` 字段
- ✅ 现有数据**不会丢失**
- 🆕 新用户将自动使用新的照片系统
- 📦 如需迁移旧数据，请参考 `DATABASE_MIGRATION_GUIDE.md`


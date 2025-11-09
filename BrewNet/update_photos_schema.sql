-- 更新 profiles 表的照片字段
-- 将 moments 字段改为 work_photos 和 lifestyle_photos
-- 每个字段可以存储最多 10 张照片

-- 1. 添加新字段
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS work_photos JSONB DEFAULT '{"photos": []}'::jsonb,
ADD COLUMN IF NOT EXISTS lifestyle_photos JSONB DEFAULT '{"photos": []}'::jsonb;

-- 2. 可选：如果需要迁移旧数据，将 moments 数据迁移到 work_photos
-- UPDATE profiles
-- SET work_photos = moments
-- WHERE moments IS NOT NULL;

-- 3. 可选：删除旧的 moments 字段（如果确定不需要了）
-- ALTER TABLE profiles DROP COLUMN IF EXISTS moments;

-- 4. 添加注释
COMMENT ON COLUMN profiles.work_photos IS 'Work-related photos collection (up to 10 photos)';
COMMENT ON COLUMN profiles.lifestyle_photos IS 'Lifestyle photos collection (up to 10 photos)';

-- 数据结构示例：
-- work_photos: {"photos": [{"id": "uuid", "image_url": "https://...", "caption": "..."}, ...]}
-- lifestyle_photos: {"photos": [{"id": "uuid", "image_url": "https://...", "caption": "..."}, ...]}


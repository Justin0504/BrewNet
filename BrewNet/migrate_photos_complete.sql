-- ==========================================
-- 照片系统完整迁移脚本
-- 从 moments 迁移到 work_photos 和 lifestyle_photos
-- ==========================================

-- 步骤 1: 检查当前表结构
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('moments', 'work_photos', 'lifestyle_photos')
ORDER BY column_name;

-- 步骤 2: 添加新字段（如果不存在）
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS work_photos JSONB DEFAULT '{"photos": []}'::jsonb,
ADD COLUMN IF NOT EXISTS lifestyle_photos JSONB DEFAULT '{"photos": []}'::jsonb;

-- 步骤 3: 如果有旧的 moments 数据，可以迁移到 work_photos（可选）
-- 取消下面的注释来执行迁移
/*
UPDATE profiles
SET work_photos = moments
WHERE moments IS NOT NULL 
  AND moments != 'null'::jsonb 
  AND work_photos = '{"photos": []}'::jsonb;
*/

-- 步骤 4: 添加字段注释
COMMENT ON COLUMN profiles.work_photos IS 'Work-related photos collection (up to 10 photos). Format: {"photos": [{"id": "uuid", "image_url": "url", "caption": "text"}]}';
COMMENT ON COLUMN profiles.lifestyle_photos IS 'Lifestyle photos collection (up to 10 photos). Format: {"photos": [{"id": "uuid", "image_url": "url", "caption": "text"}]}';

-- 步骤 5: 验证新字段是否创建成功
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('work_photos', 'lifestyle_photos')
ORDER BY column_name;

-- 步骤 6: 查看现有数据的迁移状态（如果有数据）
SELECT 
    id,
    user_id,
    CASE 
        WHEN moments IS NOT NULL THEN 'Has moments data'
        ELSE 'No moments data'
    END as moments_status,
    CASE 
        WHEN work_photos != '{"photos": []}'::jsonb THEN 'Has work photos'
        ELSE 'Empty work photos'
    END as work_photos_status,
    CASE 
        WHEN lifestyle_photos != '{"photos": []}'::jsonb THEN 'Has lifestyle photos'
        ELSE 'Empty lifestyle photos'
    END as lifestyle_photos_status
FROM profiles
LIMIT 10;

-- 步骤 7: （可选）如果确认迁移成功且不再需要 moments 字段，可以删除
-- ⚠️ 警告：删除前请确保数据已备份！
-- 取消下面的注释来删除 moments 字段
/*
ALTER TABLE profiles DROP COLUMN IF EXISTS moments;
*/

-- ==========================================
-- 执行完成后的数据结构示例
-- ==========================================
-- work_photos 格式:
-- {
--   "photos": [
--     {
--       "id": "550e8400-e29b-41d4-a716-446655440000",
--       "image_url": "https://your-bucket.supabase.co/storage/v1/object/public/avatars/user-id/photos/work_1.jpg",
--       "caption": "Working at the office"
--     }
--   ]
-- }

-- lifestyle_photos 格式:
-- {
--   "photos": [
--     {
--       "id": "650e8400-e29b-41d4-a716-446655440001",
--       "image_url": "https://your-bucket.supabase.co/storage/v1/object/public/avatars/user-id/photos/lifestyle_1.jpg",
--       "caption": "Weekend hiking"
--     }
--   ]
-- }


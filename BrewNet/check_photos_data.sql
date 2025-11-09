-- ==========================================
-- 检查照片数据是否正确保存
-- ==========================================

-- 1. 检查 work_photos 和 lifestyle_photos 字段是否存在
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('work_photos', 'lifestyle_photos')
ORDER BY column_name;

-- 2. 查看所有 profiles 的照片数据
SELECT 
    id,
    user_id,
    work_photos,
    lifestyle_photos,
    created_at,
    updated_at
FROM profiles
ORDER BY updated_at DESC
LIMIT 10;

-- 3. 检查哪些 profiles 有照片数据
SELECT 
    user_id,
    CASE 
        WHEN work_photos IS NULL THEN 'NULL'
        WHEN work_photos::text = '{"photos": []}' THEN 'Empty array'
        ELSE 'Has photos'
    END as work_photos_status,
    CASE 
        WHEN lifestyle_photos IS NULL THEN 'NULL'
        WHEN lifestyle_photos::text = '{"photos": []}' THEN 'Empty array'
        ELSE 'Has photos'
    END as lifestyle_photos_status,
    -- 提取照片数量
    jsonb_array_length(work_photos->'photos') as work_photos_count,
    jsonb_array_length(lifestyle_photos->'photos') as lifestyle_photos_count
FROM profiles
ORDER BY updated_at DESC
LIMIT 10;

-- 4. 详细查看某个用户的照片数据（替换 'your-user-id' 为实际的 user_id）
/*
SELECT 
    user_id,
    work_photos,
    lifestyle_photos,
    jsonb_pretty(work_photos) as work_photos_formatted,
    jsonb_pretty(lifestyle_photos) as lifestyle_photos_formatted
FROM profiles
WHERE user_id = 'your-user-id';
*/

-- 5. 检查照片数据的结构是否正确
SELECT 
    user_id,
    -- 检查 work_photos 结构
    jsonb_typeof(work_photos) as work_photos_type,
    jsonb_typeof(work_photos->'photos') as work_photos_array_type,
    work_photos->'photos'->0->'id' as first_work_photo_id,
    work_photos->'photos'->0->'image_url' as first_work_photo_url,
    work_photos->'photos'->0->'caption' as first_work_photo_caption,
    -- 检查 lifestyle_photos 结构
    jsonb_typeof(lifestyle_photos) as lifestyle_photos_type,
    jsonb_typeof(lifestyle_photos->'photos') as lifestyle_photos_array_type,
    lifestyle_photos->'photos'->0->'id' as first_lifestyle_photo_id,
    lifestyle_photos->'photos'->0->'image_url' as first_lifestyle_photo_url,
    lifestyle_photos->'photos'->0->'caption' as first_lifestyle_photo_caption
FROM profiles
WHERE work_photos->'photos'->0 IS NOT NULL 
   OR lifestyle_photos->'photos'->0 IS NOT NULL
ORDER BY updated_at DESC
LIMIT 5;

-- ==========================================
-- 预期结果：
-- ==========================================
-- 1. work_photos 和 lifestyle_photos 字段应该存在，类型为 jsonb
-- 2. 照片数据格式应该是：
--    {
--      "photos": [
--        {
--          "id": "uuid",
--          "image_url": "https://...",
--          "caption": "..." (可选)
--        }
--      ]
--    }
-- 3. 如果没有照片，应该是 {"photos": []} 而不是 null

-- ==========================================
-- 故障排查：
-- ==========================================
-- 如果发现问题：
--
-- A. 字段不存在
--    → 运行 migrate_photos_complete.sql 或 update_photos_schema.sql
--
-- B. 字段值为 NULL
--    → 检查应用代码中的 SupabaseService.createProfile 和 updateProfile
--    → 确保正确序列化 PhotoCollection 为 JSONB
--
-- C. 照片数据格式错误
--    → 检查 Photo 和 PhotoCollection 的 CodingKeys
--    → 确保使用 snake_case (image_url) 而不是 camelCase
--
-- D. 有图片文件但数据库中没有记录
--    → 图片上传成功，但 profile 更新失败
--    → 检查应用日志中的错误信息


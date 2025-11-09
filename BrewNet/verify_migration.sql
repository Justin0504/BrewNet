-- ==========================================
-- 验证照片系统迁移是否成功
-- ==========================================

-- 1. 检查新字段是否存在
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('work_photos', 'lifestyle_photos')
ORDER BY column_name;

-- 期望结果：
-- column_name       | data_type | column_default            | is_nullable
-- ------------------|-----------|---------------------------|-------------
-- lifestyle_photos  | jsonb     | '{"photos": []}'::jsonb  | NO
-- work_photos       | jsonb     | '{"photos": []}'::jsonb  | NO

-- 2. 检查字段注释
SELECT 
    col_description('profiles'::regclass, attnum) as column_comment,
    attname as column_name
FROM pg_attribute
WHERE attrelid = 'profiles'::regclass
AND attname IN ('work_photos', 'lifestyle_photos')
ORDER BY attname;

-- 3. 检查现有数据（如果有的话）
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN work_photos IS NOT NULL THEN 1 END) as has_work_photos,
    COUNT(CASE WHEN lifestyle_photos IS NOT NULL THEN 1 END) as has_lifestyle_photos,
    COUNT(CASE WHEN work_photos != '{"photos": []}'::jsonb THEN 1 END) as non_empty_work_photos,
    COUNT(CASE WHEN lifestyle_photos != '{"photos": []}'::jsonb THEN 1 END) as non_empty_lifestyle_photos
FROM profiles;

-- 4. 查看示例数据（前5条）
SELECT 
    id,
    user_id,
    work_photos,
    lifestyle_photos,
    created_at
FROM profiles
ORDER BY created_at DESC
LIMIT 5;

-- 5. 验证 JSON 结构是否正确
SELECT 
    id,
    user_id,
    jsonb_typeof(work_photos) as work_photos_type,
    jsonb_typeof(lifestyle_photos) as lifestyle_photos_type,
    work_photos->'photos' as work_photos_array,
    lifestyle_photos->'photos' as lifestyle_photos_array
FROM profiles
LIMIT 3;

-- 期望结果：
-- - work_photos_type 和 lifestyle_photos_type 应该都是 'object'
-- - work_photos_array 和 lifestyle_photos_array 应该是空数组 [] 或包含照片对象的数组

-- ==========================================
-- ✅ 如果以上查询都返回正确结果，说明迁移成功！
-- ==========================================


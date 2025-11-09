-- ==========================================
-- 完整验证数据库结构
-- ==========================================

-- 1. 检查 profiles 表是否存在
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles'
) as profiles_table_exists;

-- 2. 检查所有 profiles 表的列
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- 3. 特别检查照片相关字段
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('work_photos', 'lifestyle_photos', 'moments')
ORDER BY column_name;

-- 4. 检查当前用户的完整 profile 数据
SELECT 
    id,
    user_id,
    core_identity,
    work_photos,
    lifestyle_photos,
    created_at,
    updated_at
FROM profiles
WHERE user_id = '7a9380a5-d34d-40de-8e44-f1002aa5512a';

-- 5. 测试插入一个测试照片数据（不会真的插入，只是测试格式）
DO $$
DECLARE
    test_data jsonb := '{
        "photos": [
            {
                "id": "test-id",
                "image_url": "https://test.com/test.jpg",
                "caption": "Test caption"
            }
        ]
    }'::jsonb;
BEGIN
    RAISE NOTICE 'Test data is valid JSONB: %', test_data;
    RAISE NOTICE 'Photos array length: %', jsonb_array_length(test_data->'photos');
END $$;

-- 6. 检查是否有 RLS (Row Level Security) 策略阻止更新
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'profiles';

-- ==========================================
-- 预期结果：
-- ==========================================
-- 1. profiles_table_exists 应该是 true
-- 2. 应该看到 work_photos 和 lifestyle_photos 字段，类型为 jsonb
-- 3. 字段默认值应该是 '{"photos": []}'::jsonb
-- 4. 应该能看到你的 profile 数据
-- 5. 测试数据应该显示 "Test data is valid JSONB"
-- 6. 如果有 RLS 策略，检查是否允许 UPDATE 操作


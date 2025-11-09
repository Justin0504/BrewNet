-- 检查当前用户的位置信息
-- 用户 ID: 7a9380a5-d34d-40de-8e44-f1002aa5512a

-- 1. 检查 users 表中的 location 字段
SELECT 
    id,
    name,
    email,
    location as users_location,
    profile_setup_completed
FROM users 
WHERE id = '7a9380a5-d34d-40de-8e44-f1002aa5512a';

-- 2. 检查 profiles 表中的 core_identity.location 字段
SELECT 
    id,
    user_id,
    core_identity->>'location' as profile_location,
    core_identity->>'name' as profile_name,
    core_identity
FROM profiles 
WHERE user_id = '7a9380a5-d34d-40de-8e44-f1002aa5512a';

-- 3. 如果 location 为空，可以手动更新（测试用）
-- 注意：实际使用时请通过 App 的 Profile 页面更新

-- 方法 A：更新 users 表
-- UPDATE users 
-- SET location = 'San Francisco, CA, USA'
-- WHERE id = '7a9380a5-d34d-40de-8e44-f1002aa5512a';

-- 方法 B：更新 profiles 表中的 core_identity JSONB
-- UPDATE profiles 
-- SET core_identity = jsonb_set(
--     core_identity,
--     '{location}',
--     '"San Francisco, CA, USA"'
-- )
-- WHERE user_id = '7a9380a5-d34d-40de-8e44-f1002aa5512a';

-- 4. 验证更新后的数据
-- SELECT 
--     u.id,
--     u.name,
--     u.location as users_location,
--     p.core_identity->>'location' as profile_location
-- FROM users u
-- LEFT JOIN profiles p ON p.user_id = u.id
-- WHERE u.id = '7a9380a5-d34d-40de-8e44-f1002aa5512a';


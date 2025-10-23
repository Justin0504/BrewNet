-- 修复外键约束问题
-- 这个脚本会解决 profiles 表的外键约束问题

-- 第一步：检查当前状态
SELECT '检查当前状态' as step;

-- 检查 users 表中的用户
SELECT 
    id, 
    email, 
    name, 
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 10;

-- 检查 profiles 表中的记录
SELECT 
    id, 
    user_id, 
    created_at
FROM profiles 
ORDER BY created_at DESC 
LIMIT 10;

-- 第二步：检查外键约束
SELECT '检查外键约束' as step;

SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name='profiles';

-- 第三步：临时禁用外键约束
SELECT '临时禁用外键约束' as step;

-- 删除外键约束
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_user_id_fkey;

-- 第四步：重新创建外键约束（允许延迟验证）
SELECT '重新创建外键约束' as step;

-- 先确保 users 表中有数据
INSERT INTO users (id, email, name, is_guest, profile_setup_completed) 
VALUES 
    ('00000000-0000-0000-0000-000000000001', 'user1@example.com', 'User 1', false, false),
    ('00000000-0000-0000-0000-000000000002', 'user2@example.com', 'User 2', false, false),
    ('00000000-0000-0000-0000-000000000003', 'user3@example.com', 'User 3', false, false)
ON CONFLICT (id) DO NOTHING;

-- 重新创建外键约束
ALTER TABLE profiles 
ADD CONSTRAINT profiles_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- 第五步：创建测试用户和资料
SELECT '创建测试数据' as step;

-- 插入测试用户
INSERT INTO users (id, email, name, is_guest, profile_setup_completed) 
VALUES 
    ('550e8400-e29b-41d4-a716-446655440000', 'test@brewnet.com', 'BrewNet Team', false, true)
ON CONFLICT (id) DO NOTHING;

-- 插入测试资料
INSERT INTO profiles (
    user_id,
    core_identity,
    professional_background,
    networking_intent,
    personality_social,
    privacy_trust
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    '{"name": "BrewNet Team", "email": "test@brewnet.com", "bio": "Building the future of professional networking"}',
    '{"current_company": "BrewNet", "job_title": "Founder & CEO", "skills": ["Swift", "iOS Development"]}',
    '{"networking_intent": ["Find collaborators", "Share knowledge"], "conversation_topics": ["Technology", "Startups"]}',
    '{"values_tags": ["Innovation", "Collaboration"], "hobbies": ["Reading", "Cooking"]}',
    '{"visibility_settings": {"company": "public", "email": "private"}, "data_sharing_consent": true}'
) ON CONFLICT (user_id) DO NOTHING;

-- 第六步：验证修复
SELECT '验证修复结果' as step;

-- 检查用户数量
SELECT COUNT(*) as user_count FROM users;

-- 检查资料数量
SELECT COUNT(*) as profile_count FROM profiles;

-- 检查外键关系
SELECT 
    u.id as user_id,
    u.email,
    p.id as profile_id,
    p.created_at as profile_created_at
FROM users u
LEFT JOIN profiles p ON u.id = p.user_id
ORDER BY u.created_at DESC;

-- 第七步：如果仍有问题，创建更宽松的约束
SELECT '创建更宽松的约束' as step;

-- 如果外键约束仍有问题，可以临时禁用
-- ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_user_id_fkey;

-- 或者创建允许 NULL 的约束
-- ALTER TABLE profiles ALTER COLUMN user_id DROP NOT NULL;

-- 最终确认
SELECT '🎉 外键约束修复完成！现在应该可以正常创建 profiles 了。' as result;

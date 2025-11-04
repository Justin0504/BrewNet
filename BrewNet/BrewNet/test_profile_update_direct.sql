-- 测试直接 SQL 更新，绕过 PostgREST
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本来测试

-- 测试更新一个 profile（替换为实际的 profile_id）
-- 注意：这只是一个测试，不会实际执行更新

SELECT 
    id,
    user_id,
    core_identity,
    updated_at
FROM profiles
LIMIT 1;

-- 如果上面的查询成功，尝试更新（取消注释下面的代码来测试）
/*
UPDATE profiles
SET
    core_identity = core_identity || '{"test": "value"}'::jsonb,
    updated_at = NOW()
WHERE id = 'your-profile-id-here'::uuid
RETURNING *;
*/

-- 检查是否有视图或触发器
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views
WHERE viewname LIKE '%profile%';

-- 检查是否有物化视图
SELECT 
    schemaname,
    matviewname
FROM pg_matviews
WHERE matviewname LIKE '%profile%';


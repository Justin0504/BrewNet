-- 测试脚本：检查 last_seen_at 字段和 RLS 策略
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 1. 检查字段是否存在
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users' 
  AND column_name IN ('last_seen_at', 'is_online', 'last_login_at')
ORDER BY column_name;

-- 2. 检查 RLS 是否启用
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'users';

-- 3. 检查现有的 RLS 策略
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE tablename = 'users'
ORDER BY policyname;

-- 4. 检查当前用户的 last_seen_at 值（替换 YOUR_USER_ID）
-- SELECT id, email, last_seen_at, is_online, last_login_at
-- FROM users
-- WHERE id = 'YOUR_USER_ID';

-- 5. 手动测试更新（替换 YOUR_USER_ID 和 YOUR_AUTH_UID）
-- UPDATE users
-- SET last_seen_at = NOW(), is_online = true
-- WHERE id = 'YOUR_USER_ID';


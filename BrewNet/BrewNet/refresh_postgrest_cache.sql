-- 刷新 PostgREST schema cache
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 方法 1: 使用 NOTIFY 刷新 PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 方法 2: 检查 PostgREST 配置
SELECT 
    schemaname,
    tablename
FROM pg_tables
WHERE tablename = 'profiles';

-- 方法 3: 检查是否有权限问题
SELECT 
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'profiles';

-- 方法 4: 验证 RPC 函数是否存在且可访问
SELECT 
    proname,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'update_profile_jsonb';


-- 检查是否有触发器或函数可能干扰 profile 更新
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本来诊断问题

-- 1. 检查 profiles 表上的触发器
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'profiles'
ORDER BY trigger_name;

-- 2. 检查是否有函数引用了 profiles 表
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) LIKE '%profiles%'
ORDER BY p.proname;

-- 3. 检查 profiles 表的列定义
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- 4. 检查是否有 RLS (Row Level Security) 策略
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

-- 5. 检查 update_profile_jsonb 函数的定义
SELECT 
    proname,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'update_profile_jsonb';


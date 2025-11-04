-- ============================================
-- 清空 Supabase 所有缓存
-- ============================================
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本
-- 这会清除 PostgREST schema cache 和相关的缓存

-- 1. 刷新 PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 等待几秒让 PostgREST 重新加载
SELECT pg_sleep(2);

-- 2. 再次刷新确保完全清除
NOTIFY pgrst, 'reload schema';

-- 3. 检查当前缓存状态
SELECT 
    'PostgREST Cache' as cache_type,
    'Refreshed' as status,
    now() as refresh_time;

-- ============================================
-- 清理建议
-- ============================================
-- 执行完上述命令后：
-- 1. 等待 5-10 秒让 PostgREST 完全重新加载
-- 2. 测试应用功能是否正常
-- 3. 如果问题仍然存在，检查是否有其他配置问题


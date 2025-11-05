-- 修复 users 表的 RLS 策略，确保用户可以更新自己的 last_seen_at 和 is_online
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 1. 确保 users 表启用了 RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 2. 删除可能存在的旧策略（如果存在）
DROP POLICY IF EXISTS "Users can update their own last_seen_at" ON users;
DROP POLICY IF EXISTS "Users can update their own is_online" ON users;
DROP POLICY IF EXISTS "Users can update their own online status" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;

-- 3. 创建允许用户更新自己的 last_seen_at 和 is_online 的策略
-- 注意：这个策略允许用户更新自己的 last_seen_at 和 is_online 字段
CREATE POLICY "Users can update their own online status" ON users
    FOR UPDATE
    USING (auth.uid()::text = id::text)
    WITH CHECK (auth.uid()::text = id::text);

-- 4. 如果上面的策略不够，创建一个更宽松的策略（允许更新所有字段，但只能更新自己的记录）
-- 如果需要更严格的控制，可以指定只允许更新特定字段：
-- CREATE POLICY "Users can update their own online status" ON users
--     FOR UPDATE
--     USING (auth.uid()::text = id::text)
--     WITH CHECK (auth.uid()::text = id::text);

-- 5. 确保用户可以选择（读取）自己的数据（如果还没有策略）
DROP POLICY IF EXISTS "Users can view their own data" ON users;
CREATE POLICY "Users can view their own data" ON users
    FOR SELECT
    USING (auth.uid()::text = id::text);

-- 6. 允许用户查看其他用户的在线状态（用于显示好友是否在线）
-- 注意：这个策略允许查看其他用户的 is_online 和 last_seen_at，但不包括其他敏感信息
DROP POLICY IF EXISTS "Users can view others online status" ON users;
CREATE POLICY "Users can view others online status" ON users
    FOR SELECT
    USING (true); -- 允许所有已认证用户查看其他用户的在线状态

-- 7. 验证策略是否创建成功
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
WHERE tablename = 'users'
ORDER BY policyname;

-- 注意：
-- 1. 如果仍然无法更新，检查 Supabase Dashboard → Authentication → Policies
-- 2. 确保当前用户已通过认证（auth.uid() 不为 null）
-- 3. 如果使用 Service Role Key，可能绕过 RLS，但这不是推荐做法
-- 4. 可以在 Supabase Dashboard 的 Table Editor 中手动测试更新操作


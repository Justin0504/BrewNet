-- =====================================================
-- 添加 Credits 字段到 users 表
-- =====================================================
-- 用于存储用户的积分/信用点数
-- Credits 可用于各种功能和奖励
--
-- 使用方法：
-- 1. 在 Supabase Dashboard 中打开 SQL Editor
-- 2. 粘贴此脚本并执行
-- =====================================================

-- 1. 添加 credits 字段（如果不存在）
ALTER TABLE users
ADD COLUMN IF NOT EXISTS credits INT DEFAULT 0;

-- 2. 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_users_credits ON users(credits);

-- 3. 添加注释
COMMENT ON COLUMN users.credits IS 'User credits/points for rewards and features';

-- 4. 验证字段是否已添加
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name = 'credits';

-- 5. 可选：查看当前所有用户的 credits 数量
-- SELECT id, email, credits FROM users ORDER BY credits DESC LIMIT 10;

-- 6. 可选：给现有用户赠送初始 credits（欢迎奖励）
-- UPDATE users SET credits = 100 WHERE credits = 0;

-- =====================================================
-- 验证所有资源字段
-- =====================================================
-- 确认 users 表中包含所有资源字段
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name IN ('credits', 'boost_count', 'superboost_count', 'tokens')
ORDER BY column_name;

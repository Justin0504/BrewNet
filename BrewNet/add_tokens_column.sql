-- =====================================================
-- 添加 Tokens 字段到 users 表
-- =====================================================
-- 用于存储用户购买的 Tokens 数量
-- Tokens 可用于 Coffee Chat 邀请和其他高级功能
--
-- 使用方法：
-- 1. 在 Supabase Dashboard 中打开 SQL Editor
-- 2. 粘贴此脚本并执行
-- =====================================================

-- 1. 添加 tokens 字段
ALTER TABLE users
ADD COLUMN IF NOT EXISTS tokens INT DEFAULT 0;

-- 2. 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_users_tokens ON users(tokens);

-- 3. 添加注释
COMMENT ON COLUMN users.tokens IS 'User token balance for Coffee Chats and premium features';

-- 4. 验证字段是否已添加
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name = 'tokens';

-- =====================================================
-- Token 价格档位参考（仅供参考）
-- =====================================================
-- $4.99   → 50 Tokens   (≈ $0.10 / Token)
-- $9.99   → 120 Tokens  (≈ $0.083 / Token, +20% Bonus)
-- $19.99  → 260 Tokens  (≈ $0.077 / Token, +30% Bonus)
-- $49.99  → 700 Tokens  (≈ $0.071 / Token, +40% Bonus)
-- $99.99  → 1,500 Tokens (≈ $0.066 / Token, +50% Bonus)
-- =====================================================

-- 5. 可选：查看当前所有用户的 tokens 数量
-- SELECT id, email, tokens FROM users ORDER BY tokens DESC LIMIT 10;

-- 6. 可选：给现有用户赠送初始 tokens（欢迎奖励）
-- UPDATE users SET tokens = 10 WHERE tokens = 0;


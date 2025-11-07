-- 快速修复 BrewNet Pro 数据库错误
-- 复制粘贴这整个脚本到 Supabase Dashboard > SQL Editor 中运行

-- 添加 Pro 相关列
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_pro BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS pro_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS pro_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS likes_remaining INTEGER DEFAULT 10,
ADD COLUMN IF NOT EXISTS likes_depleted_at TIMESTAMP WITH TIME ZONE;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_users_is_pro ON users(is_pro);
CREATE INDEX IF NOT EXISTS idx_users_pro_end ON users(pro_end);

-- 验证列已添加（应该返回 5 行）
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('is_pro', 'pro_start', 'pro_end', 'likes_remaining', 'likes_depleted_at')
ORDER BY column_name;


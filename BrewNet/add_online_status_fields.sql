-- 添加用户在线状态相关字段到 users 表
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 添加 is_online 字段（布尔类型，默认为 false）
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- 添加 last_seen_at 字段（时间戳，记录用户最后活跃时间）
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 为 is_online 字段添加注释
COMMENT ON COLUMN users.is_online IS '用户当前是否在线';

-- 为 last_seen_at 字段添加注释
COMMENT ON COLUMN users.last_seen_at IS '用户最后活跃时间';

-- 创建索引以提高查询性能（可选）
CREATE INDEX IF NOT EXISTS idx_users_is_online ON users(is_online);
CREATE INDEX IF NOT EXISTS idx_users_last_seen_at ON users(last_seen_at);

-- 更新现有用户：设置默认值
UPDATE users 
SET is_online = false, last_seen_at = COALESCE(last_login_at, NOW())
WHERE is_online IS NULL OR last_seen_at IS NULL;


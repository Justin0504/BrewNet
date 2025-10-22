-- 创建 users 表的 SQL 脚本
-- 请在 Supabase Dashboard 的 SQL Editor 中执行

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    phone_number TEXT,
    is_guest BOOLEAN DEFAULT FALSE,
    profile_image TEXT,
    bio TEXT,
    company TEXT,
    job_title TEXT,
    location TEXT,
    skills TEXT,
    interests TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 启用 Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 创建策略（允许所有操作）
CREATE POLICY "Enable all operations for authenticated users" ON users FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for anonymous users" ON users FOR ALL USING (true);

-- 插入测试用户
INSERT INTO users (id, email, name, is_guest) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'test@brewnet.com', 'BrewNet Team', false);

-- 显示创建结果
SELECT 'Users table created successfully!' as status;

-- 修复缺失的列问题
-- 这个脚本将添加缺失的列到 users 表

-- 1. 首先检查当前 users 表结构
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. 添加缺失的列到 users 表
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS company TEXT,
ADD COLUMN IF NOT EXISTS job_title TEXT,
ADD COLUMN IF NOT EXISTS location TEXT,
ADD COLUMN IF NOT EXISTS skills TEXT,
ADD COLUMN IF NOT EXISTS interests TEXT,
ADD COLUMN IF NOT EXISTS profile_setup_completed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. 如果 created_at 列不存在，也添加它
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 4. 确保所有列都有正确的默认值
UPDATE users 
SET 
    profile_setup_completed = COALESCE(profile_setup_completed, FALSE),
    last_login_at = COALESCE(last_login_at, NOW()),
    updated_at = COALESCE(updated_at, NOW()),
    created_at = COALESCE(created_at, NOW())
WHERE 
    profile_setup_completed IS NULL 
    OR last_login_at IS NULL 
    OR updated_at IS NULL 
    OR created_at IS NULL;

-- 5. 创建触发器函数（如果不存在）
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 6. 创建或更新触发器
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 7. 确保 RLS 已启用
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 8. 重新创建策略（如果不存在）
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON users;
DROP POLICY IF EXISTS "Enable all operations for anonymous users" ON users;

CREATE POLICY "Enable all operations for authenticated users" ON users 
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable all operations for anonymous users" ON users 
    FOR ALL USING (true) WITH CHECK (true);

-- 9. 创建索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_profile_setup_completed ON users(profile_setup_completed);

-- 10. 验证修复结果
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 11. 检查 profiles 表是否存在且结构正确
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT '✅ 缺失的列已添加！users 表现在包含所有必需的列。' as result;

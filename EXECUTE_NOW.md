# 立即执行修复

## 问题
您遇到"缺少 core_identity 列"的错误，需要立即修复数据库架构。

## 解决步骤

### 1. 打开 Supabase Dashboard
- 登录您的 Supabase 账户
- 选择您的项目

### 2. 进入 SQL Editor
- 点击左侧菜单的 "SQL Editor"
- 点击 "New query"

### 3. 执行修复脚本
复制以下完整脚本并粘贴到 SQL Editor 中：

```sql
-- 简单直接的修复脚本
-- 请按顺序执行以下步骤

-- 步骤 1: 检查当前状态
SELECT '步骤 1: 检查当前数据库状态' as step;

-- 检查 users 表是否存在
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public') 
        THEN 'users 表存在' 
        ELSE 'users 表不存在' 
    END as users_table_status;

-- 检查 profiles 表是否存在
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles' AND table_schema = 'public') 
        THEN 'profiles 表存在' 
        ELSE 'profiles 表不存在' 
    END as profiles_table_status;

-- 步骤 2: 删除有问题的表（如果存在）
SELECT '步骤 2: 清理现有表' as step;

-- 删除 profiles 表（如果存在）
DROP TABLE IF EXISTS profiles CASCADE;

-- 删除 users 表（如果存在）
DROP TABLE IF EXISTS users CASCADE;

-- 步骤 3: 重新创建 users 表
SELECT '步骤 3: 创建 users 表' as step;

CREATE TABLE users (
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
    profile_setup_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 步骤 4: 创建 profiles 表
SELECT '步骤 4: 创建 profiles 表' as step;

CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    core_identity JSONB NOT NULL,
    professional_background JSONB NOT NULL,
    networking_intent JSONB NOT NULL,
    personality_social JSONB NOT NULL,
    privacy_trust JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 步骤 5: 启用行级安全
SELECT '步骤 5: 启用行级安全' as step;

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 步骤 6: 创建安全策略
SELECT '步骤 6: 创建安全策略' as step;

-- Users 表策略
CREATE POLICY "Enable all operations for authenticated users" ON users 
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable all operations for anonymous users" ON users 
    FOR ALL USING (true) WITH CHECK (true);

-- Profiles 表策略
CREATE POLICY "Users can view their own profile" ON profiles 
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own profile" ON profiles 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own profile" ON profiles 
    FOR UPDATE USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete their own profile" ON profiles 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- 步骤 7: 创建触发器
SELECT '步骤 7: 创建触发器' as step;

-- 创建触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 步骤 8: 创建索引
SELECT '步骤 8: 创建索引' as step;

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_profiles_user_id ON profiles(user_id);
CREATE INDEX idx_profiles_created_at ON profiles(created_at);

-- 步骤 9: 验证修复
SELECT '步骤 9: 验证修复结果' as step;

-- 检查表结构
SELECT 
    'users' as table_name,
    column_name, 
    data_type
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 
    'profiles' as table_name,
    column_name, 
    data_type
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 最终确认
SELECT '🎉 数据库修复完成！现在可以正常保存用户资料了。' as result;
```

### 4. 点击 "Run" 执行
- 点击 SQL Editor 右上角的 "Run" 按钮
- 等待脚本执行完成
- 查看执行结果

### 5. 验证修复
执行完成后，您应该看到：
- ✅ 各个步骤的执行状态
- ✅ 表结构信息
- ✅ "数据库修复完成" 的确认消息

### 6. 测试应用
- 重新启动您的应用
- 尝试创建用户资料
- 应该不再出现 "缺少 core_identity 列" 的错误

## 如果仍有问题

如果执行脚本后仍有问题，请：
1. 检查是否有错误消息
2. 确认所有步骤都执行成功
3. 重新启动应用
4. 清除应用缓存

这个脚本会完全重建数据库表，确保所有必需的列都存在且类型正确。

-- 修复字段长度限制问题
-- 这个脚本将移除或增加字段的长度限制

-- 1. 首先检查当前表结构
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. 修改 users 表的字段类型，移除长度限制
ALTER TABLE users 
ALTER COLUMN name TYPE TEXT,
ALTER COLUMN email TYPE TEXT,
ALTER COLUMN phone_number TYPE TEXT,
ALTER COLUMN profile_image TYPE TEXT,
ALTER COLUMN bio TYPE TEXT,
ALTER COLUMN company TYPE TEXT,
ALTER COLUMN job_title TYPE TEXT,
ALTER COLUMN location TYPE TEXT,
ALTER COLUMN skills TYPE TEXT,
ALTER COLUMN interests TYPE TEXT;

-- 3. 如果 profiles 表存在，也检查其字段
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. 确保 profiles 表使用 JSONB 类型（无长度限制）
ALTER TABLE profiles 
ALTER COLUMN core_identity TYPE JSONB,
ALTER COLUMN professional_background TYPE JSONB,
ALTER COLUMN networking_intent TYPE JSONB,
ALTER COLUMN personality_social TYPE JSONB,
ALTER COLUMN privacy_trust TYPE JSONB;

-- 5. 验证修改结果
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('users', 'profiles')
AND table_schema = 'public'
ORDER BY table_name, ordinal_position;

SELECT '✅ 字段长度限制已修复！现在可以保存更长的文本内容了。' as result;

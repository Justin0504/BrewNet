-- 快速添加 profile_completion 字段（简化版，2分钟完成）
-- 修复 "Missing key: profile_completion" 错误

-- 步骤1: 添加字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'user_features' 
        AND column_name = 'profile_completion'
    ) THEN
        ALTER TABLE user_features 
        ADD COLUMN profile_completion DOUBLE PRECISION DEFAULT 0.5;
        
        RAISE NOTICE '✅ Added profile_completion column';
    ELSE
        RAISE NOTICE 'ℹ️  profile_completion column already exists';
    END IF;
END $$;

-- 步骤2: 为现有记录设置默认值
UPDATE user_features 
SET profile_completion = 0.5 
WHERE profile_completion IS NULL;

-- 步骤3: 验证
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN profile_completion IS NOT NULL THEN 1 END) as has_completion,
    AVG(profile_completion) as avg_completion
FROM user_features;

-- 完成！
SELECT '✅ Quick fix completed! All user_features records now have profile_completion field.' as status;


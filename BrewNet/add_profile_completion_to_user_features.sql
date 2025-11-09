-- 为 user_features 表添加 profile_completion 字段
-- 修复 "Missing key: profile_completion" 错误

-- 1. 检查 user_features 表是否存在
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_name = 'user_features'
);

-- 2. 如果表不存在，创建它（包含所有必需字段）
CREATE TABLE IF NOT EXISTS user_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- 稀疏特征
    location TEXT,
    time_zone TEXT,
    industry TEXT,
    experience_level TEXT,
    career_stage TEXT,
    main_intention TEXT,
    
    -- 多值特征（JSONB数组）
    skills JSONB DEFAULT '[]'::jsonb,
    hobbies JSONB DEFAULT '[]'::jsonb,
    values JSONB DEFAULT '[]'::jsonb,
    languages JSONB DEFAULT '[]'::jsonb,
    sub_intentions JSONB DEFAULT '[]'::jsonb,
    skills_to_learn JSONB DEFAULT '[]'::jsonb,
    skills_to_teach JSONB DEFAULT '[]'::jsonb,
    
    -- 数值特征
    years_of_experience DOUBLE PRECISION DEFAULT 0.0,
    profile_completion DOUBLE PRECISION DEFAULT 0.5,
    is_verified INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 如果表已存在但缺少 profile_completion 字段，添加它
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'user_features' 
        AND column_name = 'profile_completion'
    ) THEN
        ALTER TABLE user_features 
        ADD COLUMN profile_completion DOUBLE PRECISION DEFAULT 0.5;
        
        RAISE NOTICE 'Added profile_completion column to user_features table';
    ELSE
        RAISE NOTICE 'profile_completion column already exists';
    END IF;
END $$;

-- 4. 更新现有记录，计算 profile_completion 值
-- 基于用户profile的完整性计算（如果profiles表存在）
UPDATE user_features uf
SET profile_completion = (
    SELECT 
        CASE 
            -- 检查必需字段完整性，计算完成度
            WHEN p.core_identity IS NOT NULL 
                AND p.professional_background IS NOT NULL 
                AND p.networking_intention IS NOT NULL 
                AND p.networking_preferences IS NOT NULL
                AND p.personality_social IS NOT NULL
                AND p.privacy_trust IS NOT NULL
            THEN 
                -- 基本完整度：60%
                0.6 +
                -- 如果有技能：+10%
                CASE WHEN jsonb_array_length(p.professional_background->'skills') > 0 THEN 0.1 ELSE 0 END +
                -- 如果有爱好：+10%
                CASE WHEN jsonb_array_length(p.personality_social->'hobbies') > 0 THEN 0.1 ELSE 0 END +
                -- 如果有价值观：+10%
                CASE WHEN jsonb_array_length(p.personality_social->'values_tags') > 0 THEN 0.1 ELSE 0 END +
                -- 如果有照片：+10%
                CASE WHEN p.work_photos IS NOT NULL OR p.lifestyle_photos IS NOT NULL THEN 0.1 ELSE 0 END
            ELSE 0.3 -- 不完整的profile默认30%
        END
    FROM profiles p
    WHERE p.user_id = uf.user_id
)
WHERE EXISTS (
    SELECT 1 FROM profiles p WHERE p.user_id = uf.user_id
);

-- 5. 为没有对应profile的user_features设置默认值
UPDATE user_features
SET profile_completion = 0.5
WHERE profile_completion IS NULL 
   OR profile_completion = 0;

-- 6. 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_user_features_user_id ON user_features(user_id);
CREATE INDEX IF NOT EXISTS idx_user_features_profile_completion ON user_features(profile_completion);

-- 7. 验证更新结果
SELECT 
    COUNT(*) as total_records,
    AVG(profile_completion) as avg_completion,
    MIN(profile_completion) as min_completion,
    MAX(profile_completion) as max_completion,
    COUNT(CASE WHEN profile_completion >= 0.8 THEN 1 END) as highly_complete,
    COUNT(CASE WHEN profile_completion >= 0.5 AND profile_completion < 0.8 THEN 1 END) as moderately_complete,
    COUNT(CASE WHEN profile_completion < 0.5 THEN 1 END) as low_complete
FROM user_features;

-- 8. 显示一些示例记录
SELECT 
    uf.user_id,
    uf.location,
    uf.industry,
    uf.profile_completion,
    -- 兼容处理：支持JSONB和TEXT[]两种类型
    CASE 
        WHEN jsonb_typeof(uf.skills) = 'array' THEN jsonb_array_length(uf.skills)
        ELSE 0
    END as skills_count,
    CASE 
        WHEN jsonb_typeof(uf.hobbies) = 'array' THEN jsonb_array_length(uf.hobbies)
        ELSE 0
    END as hobbies_count
FROM user_features uf
ORDER BY uf.profile_completion DESC
LIMIT 10;

-- 完成提示
DO $$
BEGIN
    RAISE NOTICE '✅ user_features table updated successfully!';
    RAISE NOTICE 'All records now have profile_completion field with appropriate values.';
END $$;


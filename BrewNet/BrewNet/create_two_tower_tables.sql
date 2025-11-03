-- Two-Tower Recommendation System Tables
-- Created: 2024-12-28
-- Purpose: 为 Two-Tower 推荐模型创建数据表

-- 1. 用户特征表
CREATE TABLE IF NOT EXISTS user_features (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- 稀疏特征
    location VARCHAR(100),
    time_zone VARCHAR(50),
    industry VARCHAR(100),
    experience_level VARCHAR(50),
    career_stage VARCHAR(50),
    main_intention VARCHAR(50),
    
    -- 多值特征 (JSONB)
    skills JSONB DEFAULT '[]'::jsonb,
    hobbies JSONB DEFAULT '[]'::jsonb,
    values JSONB DEFAULT '[]'::jsonb,
    languages JSONB DEFAULT '[]'::jsonb,
    sub_intentions JSONB DEFAULT '[]'::jsonb,
    
    -- 学习/教授配对
    skills_to_learn JSONB DEFAULT '[]'::jsonb,
    skills_to_teach JSONB DEFAULT '[]'::jsonb,
    functions_to_learn JSONB DEFAULT '[]'::jsonb,
    functions_to_teach JSONB DEFAULT '[]'::jsonb,
    
    -- 数值特征
    years_of_experience FLOAT DEFAULT 0,
    profile_completion FLOAT DEFAULT 0,
    is_verified INT DEFAULT 0,
    
    -- Embedding 向量 (用于 ANN 检索)
    user_embedding FLOAT[],
    
    -- 元数据
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_user_features_industry ON user_features(industry);
CREATE INDEX IF NOT EXISTS idx_user_features_intention ON user_features(main_intention);
CREATE INDEX IF NOT EXISTS idx_user_features_created ON user_features(created_at);

COMMENT ON TABLE user_features IS '用户特征表，用于 Two-Tower 推荐模型的特征存储';

-- 2. 用户交互表
CREATE TABLE IF NOT EXISTS user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL CHECK (interaction_type IN ('like', 'pass', 'match')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, target_user_id, interaction_type)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_interactions_user_type ON user_interactions(user_id, interaction_type);
CREATE INDEX IF NOT EXISTS idx_interactions_target ON user_interactions(target_user_id);
CREATE INDEX IF NOT EXISTS idx_interactions_created ON user_interactions(created_at);

COMMENT ON TABLE user_interactions IS '用户交互日志表，记录用户的 like/pass/match 行为';

-- 3. 推荐缓存表
CREATE TABLE IF NOT EXISTS recommendation_cache (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    recommended_user_ids JSONB,
    scores JSONB,
    model_version VARCHAR(50) DEFAULT 'baseline',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_cache_expires ON recommendation_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_cache_model ON recommendation_cache(model_version);

COMMENT ON TABLE recommendation_cache IS '推荐结果缓存表，提高推荐响应速度';

-- 完成提示
DO $$
BEGIN
    RAISE NOTICE '✅ Two-Tower recommendation tables created successfully';
    RAISE NOTICE '   - user_features: % rows', (SELECT COUNT(*) FROM user_features);
    RAISE NOTICE '   - user_interactions: % rows', (SELECT COUNT(*) FROM user_interactions);
    RAISE NOTICE '   - recommendation_cache: % rows', (SELECT COUNT(*) FROM recommendation_cache);
END $$;


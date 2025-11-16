-- 为 user_features 表添加行为量化指标字段
-- 实现活跃度分数、连接意愿分数和导师潜力分数存储

-- 1. 检查 user_features 表是否存在
SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_name = 'user_features'
);

-- 2. 如果表不存在，创建完整的表（包含所有字段）
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

    -- ========== 行为量化指标 ==========
    activity_score SMALLINT DEFAULT 5,  -- 活跃度分数 (0-10)
    connect_score SMALLINT DEFAULT 5,   -- 连接意愿分数 (0-10)
    mentor_score SMALLINT DEFAULT 5,    -- 导师潜力分数 (0-10)

    -- 原始行为数据（用于重新计算）
    sessions_7d INTEGER DEFAULT 0,       -- 7天内会话数
    messages_sent_7d INTEGER DEFAULT 0,  -- 7天内发送消息数
    matches_7d INTEGER DEFAULT 0,        -- 7天内匹配数
    last_active_at TIMESTAMP WITH TIME ZONE, -- 最后活跃时间

    -- 行为指标细节（JSONB存储）
    behavioral_metrics JSONB DEFAULT '{}'::jsonb,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 如果表已存在但缺少行为量化字段，逐一添加
DO $$
BEGIN
    -- 添加行为分数字段
    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'activity_score') THEN
        ALTER TABLE user_features ADD COLUMN activity_score SMALLINT DEFAULT 5;
        RAISE NOTICE 'Added activity_score column to user_features table';
    END IF;

    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'connect_score') THEN
        ALTER TABLE user_features ADD COLUMN connect_score SMALLINT DEFAULT 5;
        RAISE NOTICE 'Added connect_score column to user_features table';
    END IF;

    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'mentor_score') THEN
        ALTER TABLE user_features ADD COLUMN mentor_score SMALLINT DEFAULT 5;
        RAISE NOTICE 'Added mentor_score column to user_features table';
    END IF;

    -- 添加原始行为数据字段
    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'sessions_7d') THEN
        ALTER TABLE user_features ADD COLUMN sessions_7d INTEGER DEFAULT 0;
        RAISE NOTICE 'Added sessions_7d column to user_features table';
    END IF;

    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'messages_sent_7d') THEN
        ALTER TABLE user_features ADD COLUMN messages_sent_7d INTEGER DEFAULT 0;
        RAISE NOTICE 'Added messages_sent_7d column to user_features table';
    END IF;

    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'matches_7d') THEN
        ALTER TABLE user_features ADD COLUMN matches_7d INTEGER DEFAULT 0;
        RAISE NOTICE 'Added matches_7d column to user_features table';
    END IF;

    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'last_active_at') THEN
        ALTER TABLE user_features ADD COLUMN last_active_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added last_active_at column to user_features table';
    END IF;

    -- 添加行为指标详情JSONB字段
    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'behavioral_metrics') THEN
        ALTER TABLE user_features ADD COLUMN behavioral_metrics JSONB DEFAULT '{}'::jsonb;
        RAISE NOTICE 'Added behavioral_metrics column to user_features table';
    END IF;

END $$;

-- 4. 创建或更新行为指标计算函数
CREATE OR REPLACE FUNCTION calculate_behavioral_metrics(
    sessions_7d INTEGER,
    messages_sent_7d INTEGER,
    matches_7d INTEGER,
    last_active_days INTEGER,
    response_rate_30d DOUBLE PRECISION,
    pass_rate DOUBLE PRECISION,
    avg_response_time_hours DOUBLE PRECISION,
    profile_publicness_score DOUBLE PRECISION,
    past_mentorship_count INTEGER,
    is_verified BOOLEAN,
    is_pro_user BOOLEAN,
    seniority_level DOUBLE PRECISION
)
RETURNS JSONB AS $$
DECLARE
    activity_raw DOUBLE PRECISION;
    connect_raw DOUBLE PRECISION;
    mentor_raw DOUBLE PRECISION;
    result JSONB;
BEGIN
    -- 计算活跃度分数 (0-10)
    activity_raw := (
        0.3 * GREATEST(0, LEAST(1, sessions_7d::DOUBLE PRECISION / 20.0)) +
        0.3 * GREATEST(0, LEAST(1, messages_sent_7d::DOUBLE PRECISION / 50.0)) +
        0.2 * GREATEST(0, LEAST(1, matches_7d::DOUBLE PRECISION / 10.0)) +
        0.2 * GREATEST(0, LEAST(1, 1.0 / (1.0 + last_active_days)))
    ) * 10.0;

    -- 计算连接意愿分数 (0-10)
    connect_raw := (
        0.25 * profile_publicness_score +
        0.35 * GREATEST(0, LEAST(1, response_rate_30d)) +
        0.15 * GREATEST(0, LEAST(1, 1.0 / (1.0 + avg_response_time_hours))) +
        0.15 * GREATEST(0, LEAST(1, pass_rate)) +
        0.10 * (CASE WHEN is_pro_user THEN 1.0 ELSE 0.0 END)
    ) * 10.0;

    -- 计算导师潜力分数 (0-10)
    mentor_raw := (
        0.3 * GREATEST(0, LEAST(1, past_mentorship_count::DOUBLE PRECISION / 20.0)) +
        0.25 * (CASE WHEN is_verified THEN 1.0 ELSE 0.0 END) +
        0.2 * seniority_level +
        0.15 * (activity_raw / 10.0) +
        0.1 * 0.5  -- 平均会话评分，可后续扩展
    ) * 10.0;

    -- 构建结果JSON
    result := jsonb_build_object(
        'activity_score', ROUND(activity_raw)::INTEGER,
        'connect_score', ROUND(connect_raw)::INTEGER,
        'mentor_score', ROUND(mentor_raw)::INTEGER,
        'sessions_7d', sessions_7d,
        'messages_sent_7d', messages_sent_7d,
        'matches_7d', matches_7d,
        'last_active_days', last_active_days,
        'response_rate_30d', response_rate_30d,
        'pass_rate', pass_rate,
        'avg_response_time_hours', avg_response_time_hours,
        'profile_publicness_score', profile_publicness_score,
        'past_mentorship_count', past_mentorship_count,
        'is_verified', is_verified,
        'is_pro_user', is_pro_user,
        'seniority_level', seniority_level,
        'calculated_at', NOW()
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 5. 更新现有记录的行为指标（如果有足够的数据）
UPDATE user_features uf
SET
    -- 设置默认行为分数（中等水平）
    activity_score = 5,
    connect_score = 5,
    mentor_score = 5,

    -- 设置默认原始数据
    sessions_7d = 0,
    messages_sent_7d = 0,
    matches_7d = 0,
    last_active_at = COALESCE(
        (SELECT MAX(updated_at) FROM profiles WHERE user_id = uf.user_id),
        NOW() - INTERVAL '30 days'
    ),

    -- 初始化行为指标JSON
    behavioral_metrics = '{
        "activity_score": 5,
        "connect_score": 5,
        "mentor_score": 5,
        "sessions_7d": 0,
        "messages_sent_7d": 0,
        "matches_7d": 0,
        "last_active_days": 30,
        "response_rate_30d": 0.5,
        "pass_rate": 0.5,
        "avg_response_time_hours": 24.0,
        "profile_publicness_score": 0.5,
        "past_mentorship_count": 0,
        "is_verified": false,
        "is_pro_user": false,
        "seniority_level": 0.0,
        "calculated_at": "1970-01-01T00:00:00Z"
    }'::jsonb,

    updated_at = NOW()
WHERE activity_score IS NULL;

-- 更新动态字段 - 分开处理避免类型推断问题
UPDATE user_features uf
SET behavioral_metrics = jsonb_set(uf.behavioral_metrics, '{is_verified}', (uf.is_verified::INTEGER > 0)::TEXT::jsonb)
WHERE activity_score IS NULL;

UPDATE user_features uf
SET behavioral_metrics = jsonb_set(uf.behavioral_metrics, '{seniority_level}',
    to_jsonb(GREATEST(0.0, LEAST(1.0, COALESCE(uf.years_of_experience, 0.0) / 20.0))))
WHERE activity_score IS NULL;

UPDATE user_features uf
SET behavioral_metrics = jsonb_set(uf.behavioral_metrics, '{calculated_at}', to_jsonb(NOW()::TEXT))
WHERE activity_score IS NULL;

UPDATE user_features uf
SET behavioral_metrics = jsonb_set(uf.behavioral_metrics, '{last_active_days}',
    to_jsonb(EXTRACT(EPOCH FROM (NOW() - COALESCE(
        (SELECT MAX(updated_at) FROM profiles WHERE user_id = uf.user_id),
        NOW() - INTERVAL '30 days'
    )))::INTEGER / 86400))
WHERE activity_score IS NULL;

-- 6. 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_user_features_activity_score ON user_features(activity_score);
CREATE INDEX IF NOT EXISTS idx_user_features_connect_score ON user_features(connect_score);
CREATE INDEX IF NOT EXISTS idx_user_features_mentor_score ON user_features(mentor_score);
CREATE INDEX IF NOT EXISTS idx_user_features_last_active_at ON user_features(last_active_at);
CREATE INDEX IF NOT EXISTS idx_user_features_behavioral_metrics ON user_features USING gin(behavioral_metrics);

-- 7. 创建触发器函数来自动更新 updated_at
CREATE OR REPLACE FUNCTION update_user_features_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. 创建触发器
DROP TRIGGER IF EXISTS trigger_update_user_features_updated_at ON user_features;
CREATE TRIGGER trigger_update_user_features_updated_at
    BEFORE UPDATE ON user_features
    FOR EACH ROW
    EXECUTE FUNCTION update_user_features_updated_at();

-- 9. 验证更新结果
SELECT
    COUNT(*) as total_records,
    AVG(activity_score) as avg_activity_score,
    AVG(connect_score) as avg_connect_score,
    AVG(mentor_score) as avg_mentor_score,
    COUNT(CASE WHEN activity_score >= 7 THEN 1 END) as high_activity_users,
    COUNT(CASE WHEN connect_score >= 7 THEN 1 END) as high_connect_users,
    COUNT(CASE WHEN mentor_score >= 7 THEN 1 END) as high_mentor_users
FROM user_features;

-- 10. 显示一些示例记录
SELECT
    uf.user_id,
    uf.activity_score,
    uf.connect_score,
    uf.mentor_score,
    uf.sessions_7d,
    uf.messages_sent_7d,
    uf.matches_7d,
    uf.last_active_at,
    uf.behavioral_metrics->>'calculated_at' as calculated_at
FROM user_features uf
ORDER BY uf.activity_score DESC
LIMIT 10;

-- 完成提示
DO $$
BEGIN
    RAISE NOTICE '✅ user_features table updated successfully with behavioral metrics!';
    RAISE NOTICE 'Added columns: activity_score, connect_score, mentor_score, sessions_7d, messages_sent_7d, matches_7d, last_active_at, behavioral_metrics';
    RAISE NOTICE 'Created calculate_behavioral_metrics() function for score computation';
    RAISE NOTICE 'All existing records initialized with default behavioral scores';
END $$;

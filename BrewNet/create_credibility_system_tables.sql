-- ============================================
-- 信誉评分系统数据库表
-- ============================================

-- 1. 信誉评分表
CREATE TABLE IF NOT EXISTS credibility_scores (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    overall_score DECIMAL(2,1) DEFAULT 3.0 CHECK (overall_score >= 0.0 AND overall_score <= 5.0),
    average_rating DECIMAL(2,1) DEFAULT 3.0 CHECK (average_rating >= 0.0 AND average_rating <= 5.0),
    fulfillment_rate DECIMAL(5,2) DEFAULT 100.0 CHECK (fulfillment_rate >= 0 AND fulfillment_rate <= 100),
    total_meetings INT DEFAULT 0 CHECK (total_meetings >= 0),
    total_no_shows INT DEFAULT 0 CHECK (total_no_shows >= 0),
    last_meeting_date TIMESTAMP WITH TIME ZONE,
    tier VARCHAR(50) DEFAULT 'Normal' CHECK (tier IN ('Highly Trusted', 'Well Trusted', 'Trusted', 'Normal', 'Needs Improvement', 'Alert', 'Low Trust', 'Critical', 'Banned')),
    is_frozen BOOLEAN DEFAULT FALSE,
    freeze_end_date TIMESTAMP WITH TIME ZONE,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    gps_anomaly_count INT DEFAULT 0 CHECK (gps_anomaly_count >= 0),
    mutual_high_rating_count INT DEFAULT 0 CHECK (mutual_high_rating_count >= 0),
    last_decay_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 评分记录表
CREATE TABLE IF NOT EXISTS meeting_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meeting_id UUID NOT NULL,
    rater_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rated_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rating DECIMAL(2,1) NOT NULL CHECK (rating >= 0.5 AND rating <= 5.0),
    tags JSONB DEFAULT '[]'::jsonb,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    gps_verified BOOLEAN DEFAULT FALSE,
    meeting_duration INT,  -- 秒
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 确保一个会议一个人只能评分一次
    UNIQUE(meeting_id, rater_id)
);

-- 3. 举报记录表
CREATE TABLE IF NOT EXISTS misconduct_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    meeting_id UUID,
    misconduct_type VARCHAR(100) NOT NULL CHECK (misconduct_type IN ('Violence, threats, or intimidation', 'Sexual harassment or unwanted physical contact', 'Stalking or invasion of privacy', 'Fraud, impersonation, or coercive sales', 'Other serious misconduct')),
    description TEXT NOT NULL,
    location TEXT,
    evidence JSONB,  -- 存储文件URL数组
    needs_follow_up BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'Pending Review' CHECK (status IN ('Pending Review', 'Under Investigation', 'Verified - Action Taken', 'Not Verified', 'Dismissed')),
    review_notes TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. 扩展 coffee_chat_schedules 表（添加评分相关字段）
ALTER TABLE coffee_chat_schedules
ADD COLUMN IF NOT EXISTS user_rated BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS participant_rated BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS user_rating_id UUID REFERENCES meeting_ratings(id),
ADD COLUMN IF NOT EXISTS participant_rating_id UUID REFERENCES meeting_ratings(id),
ADD COLUMN IF NOT EXISTS met_at TIMESTAMP WITH TIME ZONE;

-- ============================================
-- 索引优化
-- ============================================

-- credibility_scores 索引
CREATE INDEX IF NOT EXISTS idx_credibility_tier ON credibility_scores(tier);
CREATE INDEX IF NOT EXISTS idx_credibility_score ON credibility_scores(overall_score DESC);
CREATE INDEX IF NOT EXISTS idx_credibility_last_meeting ON credibility_scores(last_meeting_date);
CREATE INDEX IF NOT EXISTS idx_credibility_frozen ON credibility_scores(is_frozen) WHERE is_frozen = TRUE;
CREATE INDEX IF NOT EXISTS idx_credibility_banned ON credibility_scores(is_banned) WHERE is_banned = TRUE;

-- meeting_ratings 索引
CREATE INDEX IF NOT EXISTS idx_meeting_ratings_rater ON meeting_ratings(rater_id);
CREATE INDEX IF NOT EXISTS idx_meeting_ratings_rated_user ON meeting_ratings(rated_user_id);
CREATE INDEX IF NOT EXISTS idx_meeting_ratings_meeting ON meeting_ratings(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_ratings_timestamp ON meeting_ratings(timestamp DESC);

-- misconduct_reports 索引
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON misconduct_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user ON misconduct_reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON misconduct_reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_timestamp ON misconduct_reports(timestamp DESC);

-- coffee_chat_schedules 索引（评分相关）
CREATE INDEX IF NOT EXISTS idx_schedules_unrated_user ON coffee_chat_schedules(user_id, has_met, user_rated) WHERE has_met = TRUE AND user_rated = FALSE;
CREATE INDEX IF NOT EXISTS idx_schedules_unrated_participant ON coffee_chat_schedules(participant_id, has_met, participant_rated) WHERE has_met = TRUE AND participant_rated = FALSE;

-- ============================================
-- 触发器：自动更新 updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- credibility_scores 触发器
DROP TRIGGER IF EXISTS update_credibility_scores_updated_at ON credibility_scores;
CREATE TRIGGER update_credibility_scores_updated_at
    BEFORE UPDATE ON credibility_scores
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- misconduct_reports 触发器
DROP TRIGGER IF EXISTS update_misconduct_reports_updated_at ON misconduct_reports;
CREATE TRIGGER update_misconduct_reports_updated_at
    BEFORE UPDATE ON misconduct_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- RLS (Row Level Security) 策略
-- ============================================

-- 启用 RLS
ALTER TABLE credibility_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE misconduct_reports ENABLE ROW LEVEL SECURITY;

-- credibility_scores 策略
-- 所有人可以查看信誉评分（公开信息）
CREATE POLICY "任何人可以查看信誉评分"
ON credibility_scores FOR SELECT
TO authenticated
USING (true);

-- 只有用户自己或系统可以插入/更新信誉评分
CREATE POLICY "用户可以查看自己的信誉评分详情"
ON credibility_scores FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- meeting_ratings 策略
-- 用户只能查看与自己相关的评分
CREATE POLICY "用户可以查看自己的评分记录"
ON meeting_ratings FOR SELECT
TO authenticated
USING (auth.uid() = rater_id OR auth.uid() = rated_user_id);

-- 用户只能插入自己作为评分者的记录
CREATE POLICY "用户可以提交评分"
ON meeting_ratings FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = rater_id);

-- 评分提交后不可修改
-- （不需要 UPDATE 策略）

-- misconduct_reports 策略
-- 用户只能查看自己提交的举报
CREATE POLICY "用户可以查看自己的举报"
ON misconduct_reports FOR SELECT
TO authenticated
USING (auth.uid() = reporter_id);

-- 用户只能提交自己作为举报者的记录
CREATE POLICY "用户可以提交举报"
ON misconduct_reports FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = reporter_id);

-- 用户不能修改或删除举报（只有管理员可以）
-- （不需要 UPDATE/DELETE 策略）

-- ============================================
-- 初始化函数：为现有用户创建信誉评分记录
-- ============================================

CREATE OR REPLACE FUNCTION initialize_credibility_scores()
RETURNS void AS $$
BEGIN
    INSERT INTO credibility_scores (user_id)
    SELECT id FROM auth.users
    WHERE id NOT IN (SELECT user_id FROM credibility_scores)
    ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 执行初始化
SELECT initialize_credibility_scores();

-- ============================================
-- 触发器：新用户自动创建信誉评分记录
-- ============================================

CREATE OR REPLACE FUNCTION create_credibility_score_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO credibility_scores (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;
CREATE TRIGGER on_auth_user_created_create_credibility
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_credibility_score_for_new_user();

-- ============================================
-- 函数：计算信誉评分
-- ============================================

CREATE OR REPLACE FUNCTION calculate_credibility_score(p_user_id UUID)
RETURNS void AS $$
DECLARE
    v_average_rating DECIMAL(2,1);
    v_total_ratings INT;
    v_fulfillment_rate DECIMAL(5,2);
    v_fulfillment_score DECIMAL(2,1);
    v_overall_score DECIMAL(2,1);
    v_tier VARCHAR(50);
    v_total_meetings INT;
    v_total_no_shows INT;
BEGIN
    -- 1. 计算平均评分
    SELECT COALESCE(AVG(rating), 3.0), COUNT(*)
    INTO v_average_rating, v_total_ratings
    FROM meeting_ratings
    WHERE rated_user_id = p_user_id;
    
    -- 四舍五入到0.5
    v_average_rating := ROUND(v_average_rating * 2) / 2;
    
    -- 2. 获取履约率
    SELECT 
        COALESCE(fulfillment_rate, 100.0),
        COALESCE(total_meetings, 0),
        COALESCE(total_no_shows, 0)
    INTO v_fulfillment_rate, v_total_meetings, v_total_no_shows
    FROM credibility_scores
    WHERE user_id = p_user_id;
    
    -- 3. 履约率转评分 (0-5)
    v_fulfillment_score := CASE
        WHEN v_fulfillment_rate >= 95 THEN 5.0
        WHEN v_fulfillment_rate >= 90 THEN 4.5
        WHEN v_fulfillment_rate >= 85 THEN 4.0
        WHEN v_fulfillment_rate >= 80 THEN 3.5
        WHEN v_fulfillment_rate >= 70 THEN 3.0
        WHEN v_fulfillment_rate >= 60 THEN 2.5
        WHEN v_fulfillment_rate >= 50 THEN 2.0
        WHEN v_fulfillment_rate >= 40 THEN 1.5
        WHEN v_fulfillment_rate >= 30 THEN 1.0
        ELSE 0.5
    END;
    
    -- 4. 计算最终评分: 70% 评分 + 30% 履约率
    v_overall_score := 0.7 * v_average_rating + 0.3 * v_fulfillment_score;
    
    -- 四舍五入到0.5
    v_overall_score := ROUND(v_overall_score * 2) / 2;
    
    -- 5. 确定等级
    v_tier := CASE
        WHEN v_overall_score >= 4.6 THEN 'Highly Trusted'
        WHEN v_overall_score >= 4.1 THEN 'Well Trusted'
        WHEN v_overall_score >= 3.6 THEN 'Trusted'
        WHEN v_overall_score >= 2.6 THEN 'Normal'
        WHEN v_overall_score >= 2.1 THEN 'Needs Improvement'
        WHEN v_overall_score >= 1.6 THEN 'Alert'
        WHEN v_overall_score >= 1.1 THEN 'Low Trust'
        WHEN v_overall_score >= 0.6 THEN 'Critical'
        ELSE 'Banned'
    END;
    
    -- 6. 更新信誉评分
    UPDATE credibility_scores
    SET 
        overall_score = v_overall_score,
        average_rating = v_average_rating,
        tier = v_tier,
        updated_at = NOW()
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 触发器：评分提交后自动更新信誉评分
-- ============================================

CREATE OR REPLACE FUNCTION on_rating_submitted()
RETURNS TRIGGER AS $$
BEGIN
    -- 更新被评分用户的信誉评分
    PERFORM calculate_credibility_score(NEW.rated_user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS after_rating_insert ON meeting_ratings;
CREATE TRIGGER after_rating_insert
    AFTER INSERT ON meeting_ratings
    FOR EACH ROW
    EXECUTE FUNCTION on_rating_submitted();

-- ============================================
-- 函数：标记见面并更新统计
-- ============================================

CREATE OR REPLACE FUNCTION mark_meeting_completed(
    p_schedule_id UUID,
    p_user_id UUID
)
RETURNS void AS $$
DECLARE
    v_other_user_id UUID;
BEGIN
    -- 获取对方的用户ID
    SELECT CASE 
        WHEN user_id = p_user_id THEN participant_id
        ELSE user_id
    END INTO v_other_user_id
    FROM coffee_chat_schedules
    WHERE id = p_schedule_id;
    
    -- 更新双方的 total_meetings 和 last_meeting_date
    UPDATE credibility_scores
    SET 
        total_meetings = total_meetings + 1,
        last_meeting_date = NOW(),
        updated_at = NOW()
    WHERE user_id IN (p_user_id, v_other_user_id);
    
    -- 重新计算双方的信誉评分
    PERFORM calculate_credibility_score(p_user_id);
    PERFORM calculate_credibility_score(v_other_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 查询示例
-- ============================================

-- 查询用户信誉评分
-- SELECT * FROM credibility_scores WHERE user_id = 'xxx';

-- 查询待评分的见面
-- SELECT * FROM coffee_chat_schedules
-- WHERE user_id = 'xxx'
--   AND has_met = TRUE
--   AND user_rated = FALSE
--   AND met_at > NOW() - INTERVAL '48 hours'
-- ORDER BY met_at DESC;

-- 查询用户的评分历史
-- SELECT * FROM meeting_ratings
-- WHERE rater_id = 'xxx' OR rated_user_id = 'xxx'
-- ORDER BY timestamp DESC;

-- 查询高信誉用户
-- SELECT u.id, u.email, cs.*
-- FROM auth.users u
-- JOIN credibility_scores cs ON u.id = cs.user_id
-- WHERE cs.tier IN ('Highly Trusted', 'Well Trusted')
-- ORDER BY cs.overall_score DESC;

-- ============================================
-- 完成
-- ============================================

COMMENT ON TABLE credibility_scores IS '用户信誉评分表';
COMMENT ON TABLE meeting_ratings IS '见面评分记录表';
COMMENT ON TABLE misconduct_reports IS '不当行为举报表';

-- 显示所有表
SELECT 
    'credibility_scores' as table_name,
    COUNT(*) as row_count
FROM credibility_scores
UNION ALL
SELECT 
    'meeting_ratings',
    COUNT(*)
FROM meeting_ratings
UNION ALL
SELECT 
    'misconduct_reports',
    COUNT(*)
FROM misconduct_reports;


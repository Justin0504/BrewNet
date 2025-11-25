-- =============================================
-- 信誉评分系统完整配置 SQL
-- 执行位置：Supabase Dashboard → SQL Editor
-- =============================================

-- 步骤 1: 创建信誉评分表（如果不存在）
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

-- 步骤 2: 创建索引（如果不存在）
CREATE INDEX IF NOT EXISTS idx_credibility_tier ON credibility_scores(tier);
CREATE INDEX IF NOT EXISTS idx_credibility_score ON credibility_scores(overall_score DESC);
CREATE INDEX IF NOT EXISTS idx_credibility_last_meeting ON credibility_scores(last_meeting_date);
CREATE INDEX IF NOT EXISTS idx_credibility_frozen ON credibility_scores(is_frozen) WHERE is_frozen = TRUE;
CREATE INDEX IF NOT EXISTS idx_credibility_banned ON credibility_scores(is_banned) WHERE is_banned = TRUE;

-- 步骤 3: 启用 RLS
ALTER TABLE credibility_scores ENABLE ROW LEVEL SECURITY;

-- 步骤 4: 删除现有策略（如果存在），然后重新创建
-- 策略 1: 任何人可以查看信誉评分
DROP POLICY IF EXISTS "任何人可以查看信誉评分" ON credibility_scores;
CREATE POLICY "任何人可以查看信誉评分"
ON credibility_scores FOR SELECT
TO authenticated
USING (true);

-- 策略 2: 服务角色可以插入（用于触发器）
DROP POLICY IF EXISTS "Service role can insert credibility scores" ON credibility_scores;
DROP POLICY IF EXISTS "Service role can insert" ON credibility_scores;
CREATE POLICY "Service role can insert credibility scores"
ON credibility_scores FOR INSERT
TO service_role
WITH CHECK (true);

-- 策略 3: 用户可以查看和更新自己的详情
DROP POLICY IF EXISTS "用户可以查看自己的信誉评分详情" ON credibility_scores;
CREATE POLICY "用户可以查看自己的信誉评分详情"
ON credibility_scores FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 步骤 5: 创建触发器函数（带错误处理，防止失败阻止用户创建）
CREATE OR REPLACE FUNCTION create_credibility_score_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 使用 BEGIN...EXCEPTION 块防止触发器失败导致用户创建失败
    BEGIN
        INSERT INTO credibility_scores (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
        
        RAISE NOTICE '✅ 为新用户创建信誉评分: %', NEW.id;
    EXCEPTION WHEN OTHERS THEN
        -- 记录错误但不阻止用户创建
        RAISE WARNING '⚠️ 创建信誉评分失败（用户 %）: %', NEW.id, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 步骤 6: 创建或替换触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;
CREATE TRIGGER on_auth_user_created_create_credibility
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_credibility_score_for_new_user();

-- 步骤 7: 为现有用户补充信誉评分（如果不存在）
INSERT INTO credibility_scores (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM credibility_scores)
ON CONFLICT (user_id) DO NOTHING;

-- 步骤 8: 验证配置
DO $$
DECLARE
    v_auth_count INT;
    v_credibility_count INT;
    v_missing_count INT;
BEGIN
    -- 统计
    SELECT COUNT(*) INTO v_auth_count FROM auth.users;
    SELECT COUNT(*) INTO v_credibility_count FROM credibility_scores;
    SELECT COUNT(*) INTO v_missing_count
    FROM auth.users au
    LEFT JOIN credibility_scores cs ON au.id = cs.user_id
    WHERE cs.user_id IS NULL;
    
    -- 显示结果
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ 信誉评分系统配置完成';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'auth.users 总数: %', v_auth_count;
    RAISE NOTICE 'credibility_scores 总数: %', v_credibility_count;
    RAISE NOTICE '缺少评分的用户: %', v_missing_count;
    
    IF v_missing_count = 0 THEN
        RAISE NOTICE '✅ 所有用户都有信誉评分记录';
    ELSE
        RAISE NOTICE '⚠️ 还有 % 个用户缺少信誉评分（已自动补充）', v_missing_count;
    END IF;
    
    RAISE NOTICE '==============================================';
    RAISE NOTICE '下一步：在应用中注册新用户进行测试';
    RAISE NOTICE '==============================================';
END $$;

-- 步骤 9: 显示触发器信息
SELECT 
    trigger_name,
    event_manipulation,
    event_object_schema || '.' || event_object_table as full_table_name,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_credibility';

-- 步骤 10: 显示策略信息
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'credibility_scores'
ORDER BY policyname;

-- =============================================
-- 完成
-- =============================================


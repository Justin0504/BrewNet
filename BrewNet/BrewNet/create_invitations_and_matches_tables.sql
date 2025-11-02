-- ============================================================
-- Supabase 数据库表创建脚本
-- 用于 invitations（邀请）和 matches（匹配）表
-- ============================================================

-- ============================================================
-- 1. 创建 invitations（邀请）表
-- ============================================================
CREATE TABLE IF NOT EXISTS invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
    reason_for_interest TEXT,
    sender_profile JSONB, -- 发送者的简要资料信息
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引以优化查询性能
CREATE INDEX IF NOT EXISTS idx_invitations_sender_id ON invitations(sender_id);
CREATE INDEX IF NOT EXISTS idx_invitations_receiver_id ON invitations(receiver_id);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON invitations(status);
CREATE INDEX IF NOT EXISTS idx_invitations_created_at ON invitations(created_at);

-- 创建复合索引用于常见查询
CREATE INDEX IF NOT EXISTS idx_invitations_sender_status ON invitations(sender_id, status);
CREATE INDEX IF NOT EXISTS idx_invitations_receiver_status ON invitations(receiver_id, status);

-- 防止重复邀请：同一个发送者不能向同一个接收者发送多个待处理的邀请
-- 使用唯一索引而不是 UNIQUE 约束，因为需要 WHERE 条件
CREATE UNIQUE INDEX IF NOT EXISTS idx_invitations_unique_pending 
    ON invitations(sender_id, receiver_id) 
    WHERE status = 'pending';

-- ============================================================
-- 2. 更新 matches（匹配）表（如果已存在需要更新结构）
-- ============================================================
-- 如果 matches 表不存在，创建它
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    matched_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    matched_user_name TEXT NOT NULL,
    match_type TEXT NOT NULL DEFAULT 'mutual' CHECK (match_type IN ('mutual', 'invitation_based', 'recommended')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引以优化查询性能
CREATE INDEX IF NOT EXISTS idx_matches_user_id ON matches(user_id);
CREATE INDEX IF NOT EXISTS idx_matches_matched_user_id ON matches(matched_user_id);
CREATE INDEX IF NOT EXISTS idx_matches_is_active ON matches(is_active);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON matches(created_at);

-- 创建复合索引用于常见查询
CREATE INDEX IF NOT EXISTS idx_matches_user_active ON matches(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_matches_matched_user_active ON matches(matched_user_id, is_active);

-- 防止重复匹配：同一对用户只能有一个活跃的匹配记录
-- 使用唯一索引而不是 UNIQUE 约束，因为需要 WHERE 条件
CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_unique_active 
    ON matches(user_id, matched_user_id) 
    WHERE is_active = TRUE;

-- ============================================================
-- 3. 创建 updated_at 自动更新触发器函数
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为 invitations 表添加触发器
DROP TRIGGER IF EXISTS update_invitations_updated_at ON invitations;
CREATE TRIGGER update_invitations_updated_at
    BEFORE UPDATE ON invitations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 为 matches 表添加触发器
DROP TRIGGER IF EXISTS update_matches_updated_at ON matches;
CREATE TRIGGER update_matches_updated_at
    BEFORE UPDATE ON matches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 4. 启用行级安全 (Row Level Security)
-- ============================================================

-- 为 invitations 表启用 RLS
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

-- 删除现有策略（如果存在）
DROP POLICY IF EXISTS "Users can view sent invitations" ON invitations;
DROP POLICY IF EXISTS "Users can view received invitations" ON invitations;
DROP POLICY IF EXISTS "Users can create invitations" ON invitations;
DROP POLICY IF EXISTS "Users can update their invitations" ON invitations;
DROP POLICY IF EXISTS "Users can delete their invitations" ON invitations;

-- 用户可以看到他们发送的邀请
CREATE POLICY "Users can view sent invitations" ON invitations
    FOR SELECT
    USING (auth.uid()::text = sender_id::text);

-- 用户可以看到他们收到的邀请
CREATE POLICY "Users can view received invitations" ON invitations
    FOR SELECT
    USING (auth.uid()::text = receiver_id::text);

-- 用户可以创建邀请（作为发送者）
CREATE POLICY "Users can create invitations" ON invitations
    FOR INSERT
    WITH CHECK (auth.uid()::text = sender_id::text);

-- 发送者可以更新他们发送的邀请
CREATE POLICY "Users can update sent invitations" ON invitations
    FOR UPDATE
    USING (auth.uid()::text = sender_id::text)
    WITH CHECK (auth.uid()::text = sender_id::text);

-- 接收者可以更新他们收到的邀请（接受/拒绝）
CREATE POLICY "Users can update received invitations" ON invitations
    FOR UPDATE
    USING (auth.uid()::text = receiver_id::text)
    WITH CHECK (auth.uid()::text = receiver_id::text);

-- 发送者可以删除他们发送的邀请（取消邀请）
CREATE POLICY "Users can delete their sent invitations" ON invitations
    FOR DELETE
    USING (auth.uid()::text = sender_id::text);

-- 为 matches 表启用 RLS
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- 删除现有策略（如果存在）
DROP POLICY IF EXISTS "Users can view their matches" ON matches;
DROP POLICY IF EXISTS "Users can create matches" ON matches;
DROP POLICY IF EXISTS "Users can update their matches" ON matches;
DROP POLICY IF EXISTS "Users can delete their matches" ON matches;

-- 用户可以看到与他们相关的匹配（作为 user_id 或 matched_user_id）
CREATE POLICY "Users can view their matches" ON matches
    FOR SELECT
    USING (auth.uid()::text = user_id::text OR auth.uid()::text = matched_user_id::text);

-- 用户可以创建匹配记录（系统创建，通常通过触发器）
CREATE POLICY "Users can create matches" ON matches
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text OR auth.uid()::text = matched_user_id::text);

-- 用户可以更新他们相关的匹配
CREATE POLICY "Users can update their matches" ON matches
    FOR UPDATE
    USING (auth.uid()::text = user_id::text OR auth.uid()::text = matched_user_id::text)
    WITH CHECK (auth.uid()::text = user_id::text OR auth.uid()::text = matched_user_id::text);

-- 用户可以删除他们相关的匹配
CREATE POLICY "Users can delete their matches" ON matches
    FOR DELETE
    USING (auth.uid()::text = user_id::text OR auth.uid()::text = matched_user_id::text);

-- ============================================================
-- 5. 创建函数：当邀请被接受时自动创建匹配
-- ============================================================
CREATE OR REPLACE FUNCTION create_match_on_invitation_accepted()
RETURNS TRIGGER AS $$
BEGIN
    -- 当邀请状态从其他状态变为 'accepted' 时，创建匹配记录
    IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
        -- 为发送者创建匹配记录
        INSERT INTO matches (user_id, matched_user_id, matched_user_name, match_type, is_active)
        VALUES (
            NEW.sender_id,
            NEW.receiver_id,
            (SELECT name FROM users WHERE id = NEW.receiver_id),
            'invitation_based',
            TRUE
        )
        ON CONFLICT (user_id, matched_user_id) WHERE is_active = TRUE
        DO UPDATE SET 
            is_active = TRUE,
            updated_at = NOW();
        
        -- 为接收者创建匹配记录（双向匹配）
        INSERT INTO matches (user_id, matched_user_id, matched_user_name, match_type, is_active)
        VALUES (
            NEW.receiver_id,
            NEW.sender_id,
            (SELECT name FROM users WHERE id = NEW.sender_id),
            'invitation_based',
            TRUE
        )
        ON CONFLICT (user_id, matched_user_id) WHERE is_active = TRUE
        DO UPDATE SET 
            is_active = TRUE,
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器
DROP TRIGGER IF EXISTS trigger_create_match_on_invitation_accepted ON invitations;
CREATE TRIGGER trigger_create_match_on_invitation_accepted
    AFTER UPDATE ON invitations
    FOR EACH ROW
    WHEN (NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted'))
    EXECUTE FUNCTION create_match_on_invitation_accepted();

-- ============================================================
-- 完成提示
-- ============================================================
SELECT '✅ invitations 和 matches 表创建完成！' as result;


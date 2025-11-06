-- Coffee Chat Invitations and Schedules Tables
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- ============================================
-- 1. 创建 coffee_chat_invitations 表
-- ============================================
CREATE TABLE IF NOT EXISTS coffee_chat_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    receiver_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE,
    scheduled_date TIMESTAMP WITH TIME ZONE,
    location TEXT,
    notes TEXT
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_coffee_chat_invitations_sender_id 
    ON coffee_chat_invitations(sender_id);
CREATE INDEX IF NOT EXISTS idx_coffee_chat_invitations_receiver_id 
    ON coffee_chat_invitations(receiver_id);
CREATE INDEX IF NOT EXISTS idx_coffee_chat_invitations_status 
    ON coffee_chat_invitations(status);
CREATE INDEX IF NOT EXISTS idx_coffee_chat_invitations_created_at 
    ON coffee_chat_invitations(created_at DESC);

-- 创建部分唯一索引：确保一个用户不能向同一个用户发送多个待处理的邀请
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_pending_invitation 
    ON coffee_chat_invitations(sender_id, receiver_id) 
    WHERE status = 'pending';

-- ============================================
-- 2. 创建 coffee_chat_schedules 表
-- ============================================
CREATE TABLE IF NOT EXISTS coffee_chat_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    participant_name TEXT NOT NULL,
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    location TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- 确保同一对用户不能在同一时间有多个日程（可选约束）
    CONSTRAINT unique_user_participant_date UNIQUE (user_id, participant_id, scheduled_date)
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_coffee_chat_schedules_user_id 
    ON coffee_chat_schedules(user_id);
CREATE INDEX IF NOT EXISTS idx_coffee_chat_schedules_participant_id 
    ON coffee_chat_schedules(participant_id);
CREATE INDEX IF NOT EXISTS idx_coffee_chat_schedules_scheduled_date 
    ON coffee_chat_schedules(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_coffee_chat_schedules_user_date 
    ON coffee_chat_schedules(user_id, scheduled_date);

-- ============================================
-- 3. 启用 Row Level Security (RLS)
-- ============================================
ALTER TABLE coffee_chat_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE coffee_chat_schedules ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. RLS 策略 - coffee_chat_invitations
-- ============================================

-- 用户可以查看自己发送或接收的邀请
CREATE POLICY "Users can view their own invitations"
    ON coffee_chat_invitations
    FOR SELECT
    USING (
        auth.uid()::text = sender_id::text OR 
        auth.uid()::text = receiver_id::text
    );

-- 用户可以创建自己发送的邀请
CREATE POLICY "Users can create invitations they send"
    ON coffee_chat_invitations
    FOR INSERT
    WITH CHECK (
        auth.uid()::text = sender_id::text
    );

-- 接收者可以更新邀请状态（接受/拒绝）
CREATE POLICY "Receivers can update invitation status"
    ON coffee_chat_invitations
    FOR UPDATE
    USING (
        auth.uid()::text = receiver_id::text AND 
        status = 'pending'
    )
    WITH CHECK (
        auth.uid()::text = receiver_id::text
    );

-- 发送者可以删除自己发送的待处理邀请
CREATE POLICY "Senders can delete pending invitations"
    ON coffee_chat_invitations
    FOR DELETE
    USING (
        auth.uid()::text = sender_id::text AND 
        status = 'pending'
    );

-- ============================================
-- 5. RLS 策略 - coffee_chat_schedules
-- ============================================

-- 用户可以查看自己的日程
CREATE POLICY "Users can view their own schedules"
    ON coffee_chat_schedules
    FOR SELECT
    USING (
        auth.uid()::text = user_id::text OR 
        auth.uid()::text = participant_id::text
    );

-- 用户可以创建自己的日程（通过接受邀请时自动创建）
CREATE POLICY "Users can create their own schedules"
    ON coffee_chat_schedules
    FOR INSERT
    WITH CHECK (
        auth.uid()::text = user_id::text OR 
        auth.uid()::text = participant_id::text
    );

-- 用户可以更新自己的日程
CREATE POLICY "Users can update their own schedules"
    ON coffee_chat_schedules
    FOR UPDATE
    USING (
        auth.uid()::text = user_id::text OR 
        auth.uid()::text = participant_id::text
    )
    WITH CHECK (
        auth.uid()::text = user_id::text OR 
        auth.uid()::text = participant_id::text
    );

-- 用户可以删除自己的日程
CREATE POLICY "Users can delete their own schedules"
    ON coffee_chat_schedules
    FOR DELETE
    USING (
        auth.uid()::text = user_id::text OR 
        auth.uid()::text = participant_id::text
    );

-- ============================================
-- 6. 添加注释（可选，用于文档）
-- ============================================
COMMENT ON TABLE coffee_chat_invitations IS '存储咖啡聊天邀请记录';
COMMENT ON TABLE coffee_chat_schedules IS '存储已确认的咖啡聊天日程';

COMMENT ON COLUMN coffee_chat_invitations.status IS '邀请状态: pending(待处理), accepted(已接受), rejected(已拒绝)';
COMMENT ON COLUMN coffee_chat_invitations.scheduled_date IS '接受邀请后的预定日期时间（仅在接受时填充）';
COMMENT ON COLUMN coffee_chat_invitations.location IS '接受邀请后的地点（仅在接受时填充）';
COMMENT ON COLUMN coffee_chat_invitations.notes IS '接受邀请时的备注（仅在接受时填充）';

-- ============================================
-- 7. 验证表创建（可选测试查询）
-- ============================================
-- 取消注释以下查询来验证表是否创建成功：

-- SELECT 
--     table_name,
--     column_name,
--     data_type,
--     is_nullable
-- FROM information_schema.columns
-- WHERE table_name IN ('coffee_chat_invitations', 'coffee_chat_schedules')
-- ORDER BY table_name, ordinal_position;

-- SELECT 
--     tablename,
--     rowsecurity as rls_enabled
-- FROM pg_tables
-- WHERE schemaname = 'public' 
--   AND tablename IN ('coffee_chat_invitations', 'coffee_chat_schedules');


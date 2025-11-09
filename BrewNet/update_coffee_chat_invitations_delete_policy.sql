-- 更新 coffee_chat_invitations 表的删除策略
-- 允许发送者和接收者都能删除已接受的邀请

-- 删除旧的策略（如果存在）
DROP POLICY IF EXISTS "Senders can delete pending invitations" ON coffee_chat_invitations;

-- 创建新策略：发送者可以删除自己发送的待处理邀请
CREATE POLICY "Senders can delete pending invitations"
    ON coffee_chat_invitations
    FOR DELETE
    USING (
        auth.uid()::text = sender_id::text AND 
        status = 'pending'
    );

-- 创建新策略：发送者和接收者都可以删除已接受的邀请
CREATE POLICY "Both parties can delete accepted invitations"
    ON coffee_chat_invitations
    FOR DELETE
    USING (
        (auth.uid()::text = sender_id::text OR auth.uid()::text = receiver_id::text) AND 
        status = 'accepted'
    );


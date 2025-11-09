-- 清理已取消或无效的coffee chat邀请和消息
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- ============================================
-- 1. 删除所有coffee_chat_invitations表中已删除但仍有相关消息的记录
-- ============================================

-- 首先，查看是否有需要清理的邀请记录
-- SELECT id, sender_id, receiver_id, status, created_at 
-- FROM coffee_chat_invitations 
-- WHERE status NOT IN ('pending', 'accepted');

-- 删除所有非pending和accepted状态的邀请记录（如果有的话）
DELETE FROM coffee_chat_invitations 
WHERE status NOT IN ('pending', 'accepted');

-- ============================================
-- 2. 删除messages表中所有coffee_chat_invitation类型的消息
-- ============================================

-- 查看需要删除的消息数量
-- SELECT COUNT(*) 
-- FROM messages 
-- WHERE message_type = 'coffee_chat_invitation';

-- 删除所有coffee_chat_invitation类型的消息
DELETE FROM messages 
WHERE message_type = 'coffee_chat_invitation';

-- ============================================
-- 3. 清理coffee_chat_schedules表中没有对应邀请的记录
-- ============================================

-- 查看需要清理的日程记录
-- SELECT cs.id, cs.user_id, cs.participant_id, cs.scheduled_date, cs.location
-- FROM coffee_chat_schedules cs
-- LEFT JOIN coffee_chat_invitations cci ON 
--     ((cci.sender_id = cs.user_id AND cci.receiver_id = cs.participant_id) OR
--      (cci.sender_id = cs.participant_id AND cci.receiver_id = cs.user_id))
--     AND cci.status = 'accepted'
--     AND cci.scheduled_date = cs.scheduled_date
--     AND cci.location = cs.location
-- WHERE cci.id IS NULL;

-- 删除没有对应accepted邀请的日程记录
DELETE FROM coffee_chat_schedules cs
WHERE NOT EXISTS (
    SELECT 1 
    FROM coffee_chat_invitations cci
    WHERE cci.status = 'accepted'
    AND (
        (cci.sender_id = cs.user_id AND cci.receiver_id = cs.participant_id) OR
        (cci.sender_id = cs.participant_id AND cci.receiver_id = cs.user_id)
    )
    AND cci.scheduled_date = cs.scheduled_date
    AND cci.location = cs.location
);

-- ============================================
-- 4. 验证清理结果
-- ============================================

-- 查看剩余的邀请记录
SELECT COUNT(*) as remaining_invitations, status
FROM coffee_chat_invitations
GROUP BY status;

-- 查看是否还有coffee_chat_invitation类型的消息
SELECT COUNT(*) as remaining_invitation_messages
FROM messages
WHERE message_type = 'coffee_chat_invitation';

-- 查看剩余的日程记录
SELECT COUNT(*) as remaining_schedules
FROM coffee_chat_schedules;


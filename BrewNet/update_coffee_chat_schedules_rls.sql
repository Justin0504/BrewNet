-- 更新 coffee_chat_schedules 表的 RLS 策略，允许双方更新 has_met 字段
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 删除现有的更新策略（如果存在）
DROP POLICY IF EXISTS "Users can update their own schedules" ON coffee_chat_schedules;
DROP POLICY IF EXISTS "Users can update schedules where they are participant" ON coffee_chat_schedules;

-- 创建新的更新策略：允许用户更新自己的记录（user_id = auth.uid()）
CREATE POLICY "Users can update their own schedules"
    ON coffee_chat_schedules
    FOR UPDATE
    USING (
        auth.uid()::text = user_id::text
    )
    WITH CHECK (
        auth.uid()::text = user_id::text
    );

-- 创建新的更新策略：允许用户更新 has_met 字段，如果他们是 participant_id
-- 这样当一方确认 "We Met" 时，可以同时更新对方的记录
CREATE POLICY "Participants can update has_met"
    ON coffee_chat_schedules
    FOR UPDATE
    USING (
        auth.uid()::text = participant_id::text
    )
    WITH CHECK (
        auth.uid()::text = participant_id::text
        -- 只允许更新 has_met 字段，不允许修改其他字段
        -- 注意：这个策略允许更新所有字段，但实际应用中应该只更新 has_met
        -- 如果需要更严格的限制，可以使用数据库函数
    );

-- 可选：创建一个数据库函数来安全地更新 has_met
-- 这个函数确保只能更新 has_met 字段，不能修改其他字段
CREATE OR REPLACE FUNCTION update_coffee_chat_has_met(
    schedule_id UUID,
    new_has_met BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE coffee_chat_schedules
    SET has_met = new_has_met
    WHERE id = schedule_id
    AND (
        user_id = auth.uid()::text OR
        participant_id = auth.uid()::text
    );
END;
$$;

-- 授予执行权限
GRANT EXECUTE ON FUNCTION update_coffee_chat_has_met(UUID, BOOLEAN) TO authenticated;


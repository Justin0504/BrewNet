-- 从 profiles 表的 core_identity JSONB 列中删除 available_timeslot 字段
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 1. 先查看有多少记录包含 available_timeslot 字段（可选，用于验证）
SELECT 
    COUNT(*) as total_profiles,
    COUNT(*) FILTER (WHERE core_identity ? 'available_timeslot') as profiles_with_timeslot
FROM profiles;

-- 2. 查看一些示例数据（可选，用于确认）
SELECT 
    id,
    user_id,
    core_identity->'available_timeslot' as available_timeslot_value,
    core_identity
FROM profiles
WHERE core_identity ? 'available_timeslot'
LIMIT 5;

-- 3. 从所有 profile 记录的 core_identity 中删除 available_timeslot 字段
UPDATE profiles
SET 
    core_identity = core_identity - 'available_timeslot',
    updated_at = NOW()
WHERE core_identity ? 'available_timeslot';

-- 4. 验证删除结果（可选，用于确认）
SELECT 
    COUNT(*) as total_profiles,
    COUNT(*) FILTER (WHERE core_identity ? 'available_timeslot') as profiles_with_timeslot_remaining
FROM profiles;

-- 如果还有剩余的 available_timeslot 字段，应该显示为 0
-- 如果 total_profiles 和 profiles_with_timeslot_remaining 相同，说明删除成功


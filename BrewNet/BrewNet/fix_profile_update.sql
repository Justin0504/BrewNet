-- 诊断和修复 profile 更新问题
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 1. 首先检查 profiles 表的结构
SELECT 
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. 检查是否有触发器
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'profiles';

-- 3. 检查 update_profile_jsonb 函数是否存在
SELECT 
    proname,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'update_profile_jsonb';

-- 4. 测试函数是否能正常工作（使用示例数据）
-- 注意：需要替换为实际的 profile_id
/*
SELECT update_profile_jsonb(
    'your-profile-id-here'::uuid,
    'your-user-id-here'::uuid,
    '{"name": "Test"}'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb
);
*/

-- 5. 如果函数有问题，尝试创建一个更简单的版本
CREATE OR REPLACE FUNCTION simple_update_profile(
    profile_id_param UUID,
    user_id_param UUID,
    core_identity_param JSONB,
    professional_background_param JSONB,
    networking_intention_param JSONB,
    networking_preferences_param JSONB,
    personality_social_param JSONB,
    privacy_trust_param JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
AS $$
    UPDATE profiles
    SET
        user_id = user_id_param,
        core_identity = core_identity_param,
        professional_background = professional_background_param,
        networking_intention = networking_intention_param,
        networking_preferences = networking_preferences_param,
        personality_social = personality_social_param,
        privacy_trust = privacy_trust_param,
        updated_at = NOW()
    WHERE id = profile_id_param;
    
    SELECT jsonb_build_object(
        'id', id,
        'user_id', user_id,
        'core_identity', core_identity,
        'professional_background', professional_background,
        'networking_intention', networking_intention,
        'networking_preferences', networking_preferences,
        'personality_social', personality_social,
        'privacy_trust', privacy_trust,
        'created_at', created_at,
        'updated_at', updated_at
    )
    FROM profiles
    WHERE id = profile_id_param;
$$;

GRANT EXECUTE ON FUNCTION simple_update_profile TO anon, authenticated;


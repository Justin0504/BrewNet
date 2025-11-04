-- 创建一个更简单的 RPC 函数，接受单个 JSON 字符串
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 删除旧函数
DROP FUNCTION IF EXISTS update_profile_simple(TEXT, TEXT);

-- 创建简单函数，接受完整的 profile JSON
CREATE OR REPLACE FUNCTION update_profile_simple(
    profile_id_param TEXT,
    profile_json TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
    profile_data JSONB;
    updated_row RECORD;
BEGIN
    -- 将 JSON 字符串转换为 JSONB
    profile_data := profile_json::jsonb;
    
    -- 更新记录
    UPDATE public.profiles
    SET
        user_id = (profile_data->>'user_id')::uuid,
        core_identity = profile_data->'core_identity',
        professional_background = profile_data->'professional_background',
        networking_intention = profile_data->'networking_intention',
        networking_preferences = profile_data->'networking_preferences',
        personality_social = profile_data->'personality_social',
        privacy_trust = profile_data->'privacy_trust',
        updated_at = NOW()
    WHERE id = profile_id_param::uuid
    RETURNING * INTO updated_row;
    
    -- 检查是否有记录被更新
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile with id % not found', profile_id_param;
    END IF;
    
    -- 将更新后的记录转换为 JSONB
    SELECT jsonb_build_object(
        'id', updated_row.id,
        'user_id', updated_row.user_id,
        'core_identity', updated_row.core_identity,
        'professional_background', updated_row.professional_background,
        'networking_intention', updated_row.networking_intention,
        'networking_preferences', updated_row.networking_preferences,
        'personality_social', updated_row.personality_social,
        'privacy_trust', updated_row.privacy_trust,
        'created_at', updated_row.created_at,
        'updated_at', updated_row.updated_at
    ) INTO result;
    
    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION update_profile_simple TO anon, authenticated;


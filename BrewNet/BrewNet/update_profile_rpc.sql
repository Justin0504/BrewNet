-- 创建一个 RPC 函数来更新 profile，避免 PostgREST 的类型转换问题
-- 请在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 首先删除旧函数（如果存在）
-- 使用动态 SQL 删除所有重载的函数
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT oid::regprocedure as func_name 
        FROM pg_proc 
        WHERE proname = 'update_profile_jsonb'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_name || ' CASCADE';
        RAISE NOTICE 'Dropped function: %', r.func_name;
    END LOOP;
END $$;

-- 创建新函数，返回 JSONB 对象
-- 接受 TEXT 参数（JSON 字符串）并转换为 JSONB，避免 PostgREST 的类型推断问题
-- 注意：参数名使用下划线分隔，避免与表名冲突
CREATE OR REPLACE FUNCTION update_profile_jsonb(
    p_profile_id TEXT,
    p_user_id TEXT,
    p_core_identity TEXT DEFAULT '{}',
    p_professional_background TEXT DEFAULT '{}',
    p_networking_intention TEXT DEFAULT '{}',
    p_networking_preferences TEXT DEFAULT '{}',
    p_personality_social TEXT DEFAULT '{}',
    p_privacy_trust TEXT DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
    updated_row RECORD;
BEGIN
    -- 先更新记录，将 TEXT 参数转换为 JSONB
    -- 使用完全限定的表名和明确的类型转换
    UPDATE public.profiles
    SET
        user_id = p_user_id::uuid,
        core_identity = p_core_identity::jsonb,
        professional_background = p_professional_background::jsonb,
        networking_intention = p_networking_intention::jsonb,
        networking_preferences = p_networking_preferences::jsonb,
        personality_social = p_personality_social::jsonb,
        privacy_trust = p_privacy_trust::jsonb,
        updated_at = NOW()
    WHERE public.profiles.id = p_profile_id::uuid
    RETURNING * INTO updated_row;
    
    -- 检查是否有记录被更新
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile with id % not found', p_profile_id;
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

-- 授予执行权限
GRANT EXECUTE ON FUNCTION update_profile_jsonb TO anon, authenticated;


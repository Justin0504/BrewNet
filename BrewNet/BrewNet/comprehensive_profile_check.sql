-- ============================================================
-- 全面的 profiles 表检查和修复脚本
-- 用途：检查 profiles 表的所有字段和 JSON 结构
-- 执行位置：Supabase Dashboard -> SQL Editor
-- ============================================================

DO $$
DECLARE
    table_exists BOOLEAN;
    missing_columns TEXT[] := ARRAY[]::TEXT[];
    required_columns TEXT[] := ARRAY[
        'id',
        'user_id',
        'core_identity',
        'professional_background',
        'networking_intention',
        'networking_preferences',
        'personality_social',
        'privacy_trust',
        'created_at',
        'updated_at'
    ];
    col TEXT;
    col_exists BOOLEAN;
    invalid_json_count INT;
    total_profiles INT;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '开始全面检查 profiles 表...';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- 1. 检查表是否存在
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE NOTICE '❌ profiles 表不存在！';
        RAISE NOTICE '请执行 fix_profiles_table.sql 脚本来创建表。';
        RETURN;
    ELSE
        RAISE NOTICE '✅ profiles 表存在';
    END IF;
    
    -- 2. 检查所有必需的列
    RAISE NOTICE '';
    RAISE NOTICE '--- 检查必需的列 ---';
    FOREACH col IN ARRAY required_columns
    LOOP
        SELECT EXISTS (
            SELECT FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'profiles'
            AND column_name = col
        ) INTO col_exists;
        
        IF NOT col_exists THEN
            missing_columns := array_append(missing_columns, col);
            RAISE NOTICE '❌ 缺少列: %', col;
        ELSE
            -- 显示列的信息
            DECLARE
                data_type TEXT;
                nullable_flag TEXT;
                column_default TEXT;
            BEGIN
                SELECT 
                    c.udt_name,
                    c.is_nullable,
                    c.column_default
                INTO data_type, nullable_flag, column_default
                FROM information_schema.columns c
                WHERE c.table_schema = 'public'
                AND c.table_name = 'profiles'
                AND c.column_name = col;
                
                RAISE NOTICE '✅ 列存在: % | 类型: % | 可空: % | 默认值: %', 
                    col, data_type, nullable_flag, COALESCE(column_default, 'NULL');
            END;
        END IF;
    END LOOP;
    
    -- 3. 统计表中的记录数
    SELECT COUNT(*) INTO total_profiles FROM profiles;
    RAISE NOTICE '';
    RAISE NOTICE '--- 数据统计 ---';
    RAISE NOTICE '总记录数: %', total_profiles;
    
    -- 4. 检查 JSON 字段的有效性
    IF total_profiles > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '--- 检查 JSON 字段有效性 ---';
        
        -- 检查 core_identity
        SELECT COUNT(*) INTO invalid_json_count
        FROM profiles
        WHERE core_identity IS NULL 
           OR NOT (core_identity::text ~ '^{.*}$');
        
        IF invalid_json_count > 0 THEN
            RAISE NOTICE '⚠️ 警告: % 条记录的 core_identity 无效或为 NULL', invalid_json_count;
        ELSE
            RAISE NOTICE '✅ core_identity 字段全部有效';
        END IF;
        
        -- 检查 professional_background
        SELECT COUNT(*) INTO invalid_json_count
        FROM profiles
        WHERE professional_background IS NULL 
           OR NOT (professional_background::text ~ '^{.*}$');
        
        IF invalid_json_count > 0 THEN
            RAISE NOTICE '⚠️ 警告: % 条记录的 professional_background 无效或为 NULL', invalid_json_count;
        ELSE
            RAISE NOTICE '✅ professional_background 字段全部有效';
        END IF;
        
        -- 检查 networking_intention
        SELECT COUNT(*) INTO invalid_json_count
        FROM profiles
        WHERE networking_intention IS NULL 
           OR NOT (networking_intention::text ~ '^{.*}$');
        
        IF invalid_json_count > 0 THEN
            RAISE NOTICE '⚠️ 警告: % 条记录的 networking_intention 无效或为 NULL', invalid_json_count;
        ELSE
            RAISE NOTICE '✅ networking_intention 字段全部有效';
        END IF;
        
        -- 检查 networking_preferences
        SELECT COUNT(*) INTO invalid_json_count
        FROM profiles
        WHERE networking_preferences IS NULL 
           OR NOT (networking_preferences::text ~ '^{.*}$');
        
        IF invalid_json_count > 0 THEN
            RAISE NOTICE '⚠️ 警告: % 条记录的 networking_preferences 无效或为 NULL', invalid_json_count;
        ELSE
            RAISE NOTICE '✅ networking_preferences 字段全部有效';
        END IF;
        
        -- 检查 personality_social
        SELECT COUNT(*) INTO invalid_json_count
        FROM profiles
        WHERE personality_social IS NULL 
           OR NOT (personality_social::text ~ '^{.*}$');
        
        IF invalid_json_count > 0 THEN
            RAISE NOTICE '⚠️ 警告: % 条记录的 personality_social 无效或为 NULL', invalid_json_count;
        ELSE
            RAISE NOTICE '✅ personality_social 字段全部有效';
        END IF;
        
        -- 检查 privacy_trust
        SELECT COUNT(*) INTO invalid_json_count
        FROM profiles
        WHERE privacy_trust IS NULL 
           OR NOT (privacy_trust::text ~ '^{.*}$');
        
        IF invalid_json_count > 0 THEN
            RAISE NOTICE '⚠️ 警告: % 条记录的 privacy_trust 无效或为 NULL', invalid_json_count;
        ELSE
            RAISE NOTICE '✅ privacy_trust 字段全部有效';
        END IF;
        
        -- 5. 检查 core_identity 中的必需字段
        RAISE NOTICE '';
        RAISE NOTICE '--- 检查 core_identity 中的必需字段 ---';
        
        DECLARE
            missing_name_count INT;
            missing_email_count INT;
            missing_time_zone_count INT;
        BEGIN
            SELECT COUNT(*) INTO missing_name_count
            FROM profiles
            WHERE core_identity->>'name' IS NULL OR core_identity->>'name' = '';
            
            SELECT COUNT(*) INTO missing_email_count
            FROM profiles
            WHERE core_identity->>'email' IS NULL OR core_identity->>'email' = '';
            
            SELECT COUNT(*) INTO missing_time_zone_count
            FROM profiles
            WHERE core_identity->>'time_zone' IS NULL OR core_identity->>'time_zone' = '';
            
            IF missing_name_count > 0 THEN
                RAISE NOTICE '⚠️ 警告: % 条记录的 core_identity.name 缺失或为空', missing_name_count;
            ELSE
                RAISE NOTICE '✅ core_identity.name 字段全部有效';
            END IF;
            
            IF missing_email_count > 0 THEN
                RAISE NOTICE '⚠️ 警告: % 条记录的 core_identity.email 缺失或为空', missing_email_count;
            ELSE
                RAISE NOTICE '✅ core_identity.email 字段全部有效';
            END IF;
            
            IF missing_time_zone_count > 0 THEN
                RAISE NOTICE '⚠️ 警告: % 条记录的 core_identity.time_zone 缺失或为空', missing_time_zone_count;
            ELSE
                RAISE NOTICE '✅ core_identity.time_zone 字段全部有效';
            END IF;
        END;
        
        -- 6. 显示示例数据（如果有问题）
        RAISE NOTICE '';
        RAISE NOTICE '--- 问题记录示例 ---';
        DECLARE
            problem_profile RECORD;
        BEGIN
            FOR problem_profile IN
                SELECT 
                    id,
                    user_id,
                    CASE 
                        WHEN core_identity IS NULL THEN 'core_identity 为 NULL'
                        WHEN core_identity->>'name' IS NULL OR core_identity->>'name' = '' THEN '缺少 name'
                        WHEN core_identity->>'email' IS NULL OR core_identity->>'email' = '' THEN '缺少 email'
                        ELSE '无问题'
                    END as issue
                FROM profiles
                WHERE core_identity IS NULL 
                   OR core_identity->>'name' IS NULL 
                   OR core_identity->>'name' = ''
                   OR core_identity->>'email' IS NULL
                   OR core_identity->>'email' = ''
                LIMIT 5
            LOOP
                RAISE NOTICE '  - Profile ID: % | User ID: % | 问题: %', 
                    problem_profile.id, problem_profile.user_id, problem_profile.issue;
            END LOOP;
        END;
    END IF;
    
    -- 7. 检查索引
    RAISE NOTICE '';
    RAISE NOTICE '--- 检查索引 ---';
    DECLARE
        index_exists BOOLEAN;
    BEGIN
        SELECT EXISTS (
            SELECT FROM pg_indexes
            WHERE schemaname = 'public'
            AND tablename = 'profiles'
            AND indexname = 'idx_profiles_user_id'
        ) INTO index_exists;
        
        IF index_exists THEN
            RAISE NOTICE '✅ 索引 idx_profiles_user_id 存在';
        ELSE
            RAISE NOTICE '⚠️ 索引 idx_profiles_user_id 不存在';
        END IF;
        
        SELECT EXISTS (
            SELECT FROM pg_indexes
            WHERE schemaname = 'public'
            AND tablename = 'profiles'
            AND indexname = 'idx_profiles_created_at'
        ) INTO index_exists;
        
        IF index_exists THEN
            RAISE NOTICE '✅ 索引 idx_profiles_created_at 存在';
        ELSE
            RAISE NOTICE '⚠️ 索引 idx_profiles_created_at 不存在';
        END IF;
    END;
    
    -- 8. 检查 RLS 策略
    RAISE NOTICE '';
    RAISE NOTICE '--- 检查 RLS 策略 ---';
    DECLARE
        rls_enabled BOOLEAN;
        policy_count INT;
        table_name_check TEXT;
    BEGIN
        SELECT 
            t.tablename,
            t.rowsecurity
        INTO table_name_check, rls_enabled
        FROM pg_tables t
        WHERE t.schemaname = 'public'
        AND t.tablename = 'profiles';
        
        IF rls_enabled THEN
            RAISE NOTICE '✅ RLS 已启用';
        ELSE
            RAISE NOTICE '⚠️ RLS 未启用';
        END IF;
        
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies
        WHERE schemaname = 'public'
        AND tablename = 'profiles';
        
        RAISE NOTICE '策略数量: %', policy_count;
    END;
    
    -- 9. 总结
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    IF array_length(missing_columns, 1) IS NULL THEN
        RAISE NOTICE '✅ 所有必需的列都存在！';
    ELSE
        RAISE NOTICE '❌ 发现缺失的列: %', array_to_string(missing_columns, ', ');
        RAISE NOTICE '请执行 fix_profiles_table.sql 脚本来修复这些问题。';
    END IF;
    RAISE NOTICE '========================================';
    
END $$;

-- 显示表的完整结构
SELECT 
    column_name,
    data_type,
    udt_name,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'profiles'
ORDER BY ordinal_position;

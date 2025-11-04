-- ============================================================
-- 检查 profiles 表结构脚本
-- 用途：检查 profiles 表是否存在以及所有必需的列是否存在
-- 执行位置：Supabase Dashboard -> SQL Editor
-- ============================================================

DO $$
DECLARE
    table_exists BOOLEAN;
    missing_columns TEXT[] := ARRAY[]::TEXT[];
    required_columns TEXT[] := ARRAY[
        'core_identity',
        'professional_background',
        'networking_intention',
        'networking_preferences',
        'personality_social',
        'privacy_trust'
    ];
    col TEXT;
    col_exists BOOLEAN;
BEGIN
    -- 1. 检查 profiles 表是否存在
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE NOTICE '❌ profiles 表不存在！';
        RAISE NOTICE '请执行 fix_profiles_table.sql 脚本来创建表。';
    ELSE
        RAISE NOTICE '✅ profiles 表存在';
        
        -- 2. 检查每个必需的列是否存在
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
                -- 检查列的数据类型
                DECLARE
                    data_type TEXT;
                BEGIN
                    SELECT column_name || ' (' || udt_name || ')'
                    INTO data_type
                    FROM information_schema.columns
                    WHERE table_schema = 'public'
                    AND table_name = 'profiles'
                    AND column_name = col;
                    
                    RAISE NOTICE '✅ 列存在: %', data_type;
                END;
            END IF;
        END LOOP;
        
        -- 3. 检查是否有 NULL 值的记录
        DECLARE
            null_core_identity_count INT;
            null_professional_background_count INT;
        BEGIN
            SELECT COUNT(*) INTO null_core_identity_count
            FROM profiles
            WHERE core_identity IS NULL;
            
            SELECT COUNT(*) INTO null_professional_background_count
            FROM profiles
            WHERE professional_background IS NULL;
            
            IF null_core_identity_count > 0 THEN
                RAISE NOTICE '⚠️ 警告: % 条记录的 core_identity 为 NULL', null_core_identity_count;
            END IF;
            
            IF null_professional_background_count > 0 THEN
                RAISE NOTICE '⚠️ 警告: % 条记录的 professional_background 为 NULL', null_professional_background_count;
            END IF;
        END;
        
        -- 4. 总结
        IF array_length(missing_columns, 1) IS NULL THEN
            RAISE NOTICE '';
            RAISE NOTICE '========================================';
            RAISE NOTICE '✅ 所有必需的列都存在！';
            RAISE NOTICE '========================================';
        ELSE
            RAISE NOTICE '';
            RAISE NOTICE '========================================';
            RAISE NOTICE '❌ 发现缺失的列: %', array_to_string(missing_columns, ', ');
            RAISE NOTICE '请执行 fix_profiles_table.sql 脚本来修复这些问题。';
            RAISE NOTICE '========================================';
        END IF;
    END IF;
    
    -- 5. 显示表的完整结构
    RAISE NOTICE '';
    RAISE NOTICE '--- profiles 表当前结构 ---';
    FOR col IN
        SELECT column_name || ' | ' || udt_name || ' | ' || 
               CASE WHEN is_nullable = 'NO' THEN 'NOT NULL' ELSE 'NULL' END
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'profiles'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '%', col;
    END LOOP;
    
END $$;
